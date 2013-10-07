#!/usr/bin/python
#

# 
# cif-router proof of concept
#
# cif-router [-p pubport] [-r routerport] [-m myname] [-h] 
#      -p  default: 5556
#      -r  default: 5555
#      -m  default: cif-router
#
# cif-router is a zmq device with the following sockets:
#     XPUB 
#       for republishing messages 
#     XSUB
#       for subscribing to message feeds
#     ROUTER
#       for routing REQ/REP messages between clients
#       also for accepting REQs from clients
#         locally accepted types:
#            REGISTER, UNREGISTER, LIST-CLIENTS
#         locally generated replies:
#            UNAUTHORIZED, OK, FAILED
#
# communication between router and clients is via CIF.msg passing
# the 'ControlStruct' portion of CIF.msg is used for communication
#
# a typical use case:
# 
# cif-smrt's REQ connects to ROUTER and sends a REGISTER message with dst=cif-router
# cif-router's ROUTER responds with SUCCESS (if valid) or UNAUTHORIZED (if not valid)
#     the apikey will be validated during this step
# cif-router's XSUB connects to cif-smrt's XPUB
# cif-smrt begins publishing CIF messages 
# cif-router re-publishes the CIF messages to clients connected to cif-router's XPUB 
#    clients may be: cif-correlator, cif-db

import sys
import zmq
import time
import datetime
import threading
import getopt
import json
import pprint
import struct

sys.path.append('/usr/local/lib/cif-protocol/pb-python/gen-py')
import msg_pb2
import feed_pb2
import RFC5070_IODEF_v1_pb2
import MAEC_v2_pb2
import control_pb2
import cifsupport

sys.path.append('../../libcif/lib')

from CIF.RouterStats import *
from CIF.CtrlCommands.Clients import *
from CIF.CtrlCommands.Ping import *
from CIFRouter.MiniClient import *
from CIF.CtrlCommands.ThreadTracker import ThreadTracker

myname = "cif-router"

def dosubscribe(client, m):
    client = m.src
    if client in publishers :
        print "dosubscribe: we've seen this client before. re-using old connection."
        return control_pb2.ControlType.SUCCESS
    elif clients.isregistered(client) == True:
        if clients.apikey(client) == m.apikey:
            print "dosubscribe: New publisher to connect to " + client
            publishers[client] = time.time()
            addr = m.iPublishRequest.ipaddress
            port = m.iPublishRequest.port
            print "dosubscribe: connect our xsub -> xpub on " + addr + ":" + str(port)
            xsub.connect("tcp://" + addr + ":" + str(port))
            return control_pb2.ControlType.SUCCESS
        print "dosubscribe: iPublish from a registered client with a bad apikey: " + client + " " + m.apikey
    print "dosubscribe: iPublish from a client who isnt registered: \"" + client + "\""
    return control_pb2.ControlType.FAILED

def list_clients(client, apikey):
    if clients.isregistered(client) == True and clients.apikey(client) == apikey:
        return clients.asmessage()
    return None

def make_register_reply(msgfrom, _apikey):
    msg = control_pb2.ControlType()
    msg.version = msg.version # required
    msg.type = control_pb2.ControlType.REPLY
    msg.command = control_pb2.ControlType.REGISTER
    msg.dst = msgfrom
    msg.src = "cif-router"
    print "mrr " + _apikey
    msg.apikey = _apikey

    return msg

def make_unregister_reply(msgfrom, _apikey):
    msg = control_pb2.ControlType()
    msg.version = msg.version # required
    msg.type = control_pb2.ControlType.REPLY
    msg.command = control_pb2.ControlType.UNREGISTER
    msg.dst = msgfrom
    msg.src = "cif-router"
    msg.apikey = _apikey

    return msg

def make_msg_seq(msg):
    _md5 = hashlib.md5()
    _md5.update(msg.SerializeToString())
    return _md5.digest()

def handle_miniclient_reply(socket, routerport, publisherport):
    pending_registers = miniclient.pending_apikey_lookups()
    print "pending_apikey_lookups: ", pending_registers
    
    for apikey in pending_registers:
        if apikey in register_wait_map:
            reply_to = register_wait_map[apikey]
            apikey_results = miniclient.get_pending_apikey(apikey)
            
            print "  send reply to: ", reply_to
            msg = make_register_reply(reply_to['msgfrom'], apikey)
            msg.status = control_pb2.ControlType.FAILED
            
            if apikey_results != None:
                if apikey_results.revoked == False:
                    if apikey_results.expires == 0 or apikey_results.expires >= time.time():
                        msg.registerResponse.REQport = routerport
                        msg.registerResponse.PUBport = publisherport
                        msg.status = control_pb2.ControlType.SUCCESS
                        clients.register(reply_to['msgfrom'], reply_to['from_zmqid'], apikey)
                        print " Register succeeded."
                    else:
                        print " Register failed: key expired"
                else:
                    print " Register failed: key revoked"
            else:
                print " Register failed: unknown key"
                
            msg.seq = reply_to['msgseq']
            socket.send_multipart([reply_to['from_zmqid'], '', msg.SerializeToString()])
            del register_wait_map[apikey]
        elif apikey in unregister_wait_map:
            reply_to = unregister_wait_map[apikey]
            apikey_results = miniclient.get_pending_apikey(apikey)
            
            print "  send reply to: ", reply_to
            msg = make_unregister_reply(reply_to['msgfrom'], apikey)
            msg.status = control_pb2.ControlType.FAILED
            
            if apikey_results != None:
                if apikey_results.revoked == False:
                    if apikey_results.expires == 0 or apikey_results.expires >= time.time():
                        msg.status = control_pb2.ControlType.SUCCESS
                        clients.unregister(reply_to['msgfrom'])
                        print " Unregister succeeded."
                    else:
                        print " Unregister failed: key expired"
                else:
                    print " Unregister failed: key revoked"
            else:
                print " Unregister failed: unknown key"
                
            msg.seq = reply_to['msgseq'] 
            socket.send_multipart([reply_to['from_zmqid'], '', msg.SerializeToString()])
            del unregister_wait_map[apikey]
            
            
        miniclient.remove_pending_apikey(apikey)

def myrelay(pubport):
    relaycount = 0
    print "[myrelay] Create XPUB socket on " + str(pubport)
    xpub = context.socket(zmq.PUB)
    xpub.bind("tcp://*:" + str(pubport))
    
    while True:
        try:
            relaycount = relaycount + 1
            m = xsub.recv()
            
            _m = msg_pb2.MessageType()
            _m.ParseFromString(m)
            
            if _m.type == msg_pb2.MessageType.QUERY:
                mystats.setrelayed(1, 'QUERY')
            elif _m.type == msg_pb2.MessageType.REPLY:
                mystats.setrelayed(1, 'REPLY')
            elif _m.type == msg_pb2.MessageType.SUBMISSION:
                mystats.setrelayed(1, 'SUBMISSION')
                
                for bmt in _m.submissionRequest:
                    mystats.setrelayed(1, bmt.baseObjectType)
                    
    
            print "[myrelay] total:%d got:%d bytes" % (relaycount, len(m)) 
            #print "[myrelay] got msg on our xsub socket: " , m
            xpub.send(m)

        except Exception as e:
            print "[myrelay] invalid message received: ", e
    
def usage():
    print "cif-router [-r routerport] [-p pubport] [-m myid] [-a myapikey] [-dn dbname] [-dk dbkey] [-h]"
    print "   routerport = 5555, pubport = 5556, myid = cif-router"
    print "   dbkey = a8fd97c3-9f8b-477b-b45b-ba06719a0088"
    print "   dbname = cif-db"
        
try:
    opts, args = getopt.getopt(sys.argv[1:], 'p:r:m:h')
except getopt.GetoptError, err:
    print str(err)
    usage()
    sys.exit(2)

global mystats
global clients
global thread_tracker

context = zmq.Context()
clients = Clients()
mystats = RouterStats()
publishers = {}
routerport = 5555
publisherport = 5556
myid = "cif-router"
dbkey = 'a8fd97c3-9f8b-477b-b45b-ba06719a0088'
dbname = 'cif-db'
global apikey
apikey = 'a1fd11c1-1f1b-477b-b45b-ba06719a0088'
miniclient = None
miniclient_id = myid + "-miniclient"
register_wait_map = {}
unregister_wait_map = {}


for o, a in opts:
    if o == "-r":
        routerport = a
    elif o == "-p":
        publisherport = a
    elif o == "-m":
        myid = a
    elif o == "-dk":
        dbkey = a
    elif o == "-dn":
        dbname = a
    elif o == "-a":
        apikey = a
    elif o == "-h":
        usage()
        sys.exit(2)
        
print "Create ROUTER socket on " + str(routerport)
global socket
socket = context.socket(zmq.ROUTER)
socket.bind("tcp://*:" + str(routerport))
socket.setsockopt(zmq.IDENTITY, myname)

poller = zmq.Poller()
poller.register(socket, zmq.POLLIN)

print "Create XSUB socket"
xsub = context.socket(zmq.SUB)
xsub.setsockopt(zmq.SUBSCRIBE, '')

print "Connect XSUB<->XPUB"
thread = threading.Thread(target=myrelay, args=(publisherport,))
thread.start()
while not thread.isAlive():
    print "waiting for pubsub relay thread to become alive"
    time.sleep(1)
thread_tracker = ThreadTracker(False)
thread_tracker.add(id=thread.ident, user='Router', host='localhost', state='Running', info="PUBSUB Relay")


print "Entering event loop"

try:
    open_for_business = False
    
    while True:
        sockets_with_data_ready = dict(poller.poll(1000))
        #print "[up " + str(int(mystats.getuptime())) + "s]: Wakeup: "

        if miniclient != None:
            if miniclient.pending() == True:
                print "\tMiniclient has replies we need to handle."
                handle_miniclient_reply(socket, routerport, publisherport)
            
        if sockets_with_data_ready and sockets_with_data_ready.get(socket) == zmq.POLLIN:
            print "[up " + str(int(mystats.getuptime())) + "s]: Got an inbound message"
            rawmsg = socket.recv_multipart()
            #print " Got ", rawmsg
            
            msg = control_pb2.ControlType()
            
            try:
                msg.ParseFromString(rawmsg[2])
            except Exception as e:
                print "Received message isn't a protobuf: ", e
                mystats.setbad()
            else:
                from_zmqid = rawmsg[0] # save the ZMQ identity of who sent us this message
                
                #print "Got msg: "#, msg.seq
        
                try:
                    cifsupport.versionCheck(msg)
                except Exception as e:
                    print "\tReceived message has incompatible version: ", e
                    mystats.setbadversion(1, msg.version)
                else:
                
                    if cifsupport.isControl(msg):
                        msgfrom = msg.src
                        msgto = msg.dst
                        msgcommand = msg.command
                        msgcommandtext = control_pb2._CONTROLTYPE_COMMANDTYPE.values_by_number[msg.command].name
                        msgid = msg.seq
                        
                        if msgfrom != '' and msg.apikey != '':
                            if msgto == myname and msg.type == control_pb2.ControlType.REPLY:
                                print "\tREPLY for me: ", msgcommand
                                if msgcommand == control_pb2.ControlType.APIKEY_GET:
                                    print "\tReceived a REPLY for an APIKEY_GET"
                                        
                            elif msgto == myname and msg.type == control_pb2.ControlType.COMMAND:
                                print "\tCOMMAND for me: ", msgcommandtext
                                
                                mystats.setcontrols(1, msgcommandtext)
                                
                                """
                                For REGISTER:
                                    We allow only the db to register with us while we are not
                                    open_for_business. Once the DB registers, we are open_for_business
                                    since we can then start validating apikeys. Until that time, we can
                                    only validate the dbkey that is specified on the command line when
                                    you launch this program.
                                """
                                if msgcommand == control_pb2.ControlType.REGISTER:
                                      print "\tREGISTER from: " + msgfrom
                                      
                                      msg.status = control_pb2.ControlType.FAILED
                                      msg.type = control_pb2.ControlType.REPLY
                                      msg.seq = msgid
                                      
                                      if msgfrom == miniclient_id and msg.apikey == apikey:
                                          clients.register(msgfrom, from_zmqid, msg.apikey)
                                          msg.status = control_pb2.ControlType.SUCCESS
                                          msg.registerResponse.REQport = routerport
                                          msg.registerResponse.PUBport = publisherport
                                          print "\tMiniClient has registered."
                                          socket.send_multipart([from_zmqid, '', msg.SerializeToString()])

                                      elif msgfrom == dbname and msg.apikey == dbkey:
                                          clients.register(msgfrom, from_zmqid, msg.apikey)
                                          msg.status = control_pb2.ControlType.SUCCESS
                                          msg.registerResponse.REQport = routerport
                                          msg.registerResponse.PUBport = publisherport
                                          open_for_business = True
                                          print "\tDB has connected successfully. Sending reply to DB."
                                          print "\tStarting embedded client"
                                          miniclient = MiniClient(apikey, "127.0.0.1", "127.0.0.1:" + str(routerport), 5557, miniclient_id, thread_tracker, True)
                                          socket.send_multipart([from_zmqid, '', msg.SerializeToString()])

                                      elif open_for_business == True:
                                          """
                                          Since we need to wait for the DB to response, we note this pending request, ask the miniclient
                                          to handle the lookup. We will poll the MC to see if the lookup has finished. Reply to client 
                                          will be sent from handle_miniclient_reply()
                                          """
                                          miniclient.lookup_apikey(msg.apikey)
                                          register_wait_map[msg.apikey] = {'msgfrom': msgfrom, 'from_zmqid': from_zmqid, 'msgseq': msg.seq}

                                      else:
                                          print "\tNot open_for_business yet. Go away."
        
                                                  
                                elif msgcommand == control_pb2.ControlType.UNREGISTER:
                                    """
                                    If the database unregisters, then we are not open_for_business any more.
                                    """
                                    print "\tUNREGISTER from: " + msgfrom
                                    if open_for_business == True:
                                        if msgfrom == dbname and msg.apikey == dbkey:
                                            print "\t\tDB unregistered. Closing for business."
                                            open_for_business = False
                                            clients.unregister(msgfrom)
                                            msg.status = control_pb2.ControlType.SUCCESS
                                            msg.seq = msgid
                                            socket.send_multipart([ from_zmqid, '', msg.SerializeToString()])
                                        else:
                                            """
                                            Since we need to wait for the DB to response, we note this pending request, ask the miniclient
                                            to handle the lookup. We will poll the MC to see if the lookup has finished. Reply to the client
                                            will be sent from handle_miniclient_reply() 
                                            """
                                            miniclient.lookup_apikey(msg.apikey)
                                            unregister_wait_map[msg.apikey] = {'msgfrom': msgfrom, 'from_zmqid': from_zmqid, 'msgseq': msg.seq}
                                
                                elif msgcommand == control_pb2.ControlType.LISTCLIENTS:
                                     print "\tLIST-CLIENTS for: " + msgfrom
                                     if open_for_business == True:
                                         rv = list_clients(msg.src, msg.apikey)
                                         msg.seq = msgid
                                         msg.status = msg.status | control_pb2.ControlType.FAILED
    
                                         if rv != None:
                                             msg.status = msg.status | control_pb2.ControlType.SUCCESS
                                             msg.listClientsResponse.client.extend(rv.client)
                                             msg.listClientsResponse.connectTimestamp.extend(rv.connectTimestamp)
                                         
                                         socket.send_multipart( [ from_zmqid, '', msg.SerializeToString() ] )
                                
                                elif msg.command == control_pb2.ControlType.STATS:
                                    print "\tSTATS for: " + msgfrom
                                    
                                    if open_for_business == True:
                                        tmp = msg.dst
                                        msg.dst = msg.src
                                        msg.src = tmp
                                        msg.status = control_pb2.ControlType.SUCCESS
                                        msg.statsResponse.statsType = control_pb2.StatsResponse.ROUTER
                                        msg.statsResponse.stats = mystats.asjson()
                                        
                                        socket.send_multipart( [ from_zmqid, '', msg.SerializeToString() ] )
                                    
                                elif msg.command == control_pb2.ControlType.THREADS_LIST:
                                    tmp = msg.dst
                                    msg.dst = msg.src
                                    msg.src = tmp
                                    msg.status = control_pb2.ControlType.SUCCESS
                                    thread_tracker.asmessage(msg.listThreadsResponse)
                                    socket.send_multipart( [ from_zmqid, '', msg.SerializeToString() ] )
                        
                                if msg.command == control_pb2.ControlType.PING:
                                    c = Ping.makereply(msg)
                                    socket.send_multipart( [ from_zmqid, '', c.SerializeToString() ] )
                                    
                                elif msgcommand == control_pb2.ControlType.IPUBLISH:
                                     print "\tIPUBLISH from: " + msgfrom
                                     if open_for_business == True:
                                         rv = dosubscribe(from_zmqid, msg)
                                         msg.status = rv
                                         socket.send_multipart( [from_zmqid, '', msg.SerializeToString()] )
                            else:
                                print "\tCOMMAND for someone else: cmd=", msgcommandtext, "src=", msgfrom, " dst=", msgto
                                msgto_zmqid = clients.getzmqidentity(msgto)
                                if msgto_zmqid != None:
                                    socket.send_multipart([msgto_zmqid, '', msg.SerializeToString()])
                                else:
                                    print "\tUnknown message destination: ", msgto
                        else:
                            print "\tmsgfrom and/or msg.apikey is empty"
                        
except KeyboardInterrupt:
    print "Shut down."
    if thread.isAlive():
        try:
            thread._Thread__stop()
        except:
            print(str(thread.getName()) + ' could not be terminated')
    sys.exit(0)

    
    
