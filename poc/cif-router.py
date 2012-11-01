#!/usr/bin/python
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

myname = "cif-router"

def register(clientname, apikey):
    # zmq doesnt have a disconnect, so if we xsub.connect() multiple times
    # to the same client, we'll start recving duplicates of that clients
    # messages. to avoid this, we track who we've connected to and if we
    # see the same client more than once, we dont call connect() again.
    
    #if clientname in clients :
    #    print "\talready registered"
    #    return 'ALREADY-REGISTERED'
    
    if apikey != None:
        if validate_apikey(apikey) == control_pb2.ControlType.SUCCESS:
            clients.register(clientname)
            return control_pb2.ControlType.SUCCESS
        return control_pb2.ControlType.FAILED
    else:
        # the only place we call with apikey=None is when cif-db connects
        # because the apikey is specified on the command line (and validated
        # in the main routine)
        clients.register(clientname)
        return control_pb2.ControlType.SUCCESS
    return control_pb2.ControlType.FAILED

def dosubscribe(m):
    if m.src in publishers :
        print "dosubscribe: we've seen this client before. re-using old connection."
        return validate_apikey(m.apikey)
    elif validate_apikey(m.apikey) == control_pb2.ControlType.SUCCESS:
        print "dosubscribe: New publisher to connect to " + msg.src
        publishers[m.src] = time.time()
        addr = m.iPublishRequest.ipaddress
        port = m.iPublishRequest.port
        print "dosubscribe: connect our xsub -> xpub on " + addr + ":" + str(port)
        xsub.connect("tcp://" + addr + ":" + str(port))
        return control_pb2.ControlType.SUCCESS
    return control_pb2.ControlType.FAILED

def unregister(clientname, apikey):
    if validate_apikey(apikey) == control_pb2.ControlType.SUCCESS and clients.isregistered(clientname):
        print "\tunregistered"
        clients.unregister(clientname)
        return control_pb2.ControlType.SUCCESS
    print "\tclient unknown or unauthorized"
    return control_pb2.ControlType.FAILED

def list_clients(apikey):
    if validate_apikey(apikey) == control_pb2.ControlType.SUCCESS:
        return clients.asmessage()
    return None

def validate_apikey(apikey):
    """
    Make sure the given apikey exists, is not revoked, is not expired.
    This routine just determines "are you allowed to connect to us?"
    """
    if apikey != None:
        return control_pb2.ControlType.SUCCESS
    return control_pb2.ControlType.FAILED

def myrelay(pubport):
    relaycount = 0
    print "[myrelay] Create XPUB socket on " + str(pubport)
    xpub = context.socket(zmq.PUB)
    xpub.bind("tcp://*:" + str(pubport))
    
    while True:
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
                

        print "[myrelay] " + str(relaycount) + " recvd(" + str(len(m)) + " bytes)"
        #print "[myrelay] got msg on our xsub socket: " , m
        xpub.send(m)
    
def usage():
    print "cif-router [-r routerport] [-p pubport] [-m myid] [-dn dbname] [-dk dbkey] [-h]"
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

context = zmq.Context()
clients = Clients()
mystats = RouterStats()
publishers = {}
routerport = 5555
publisherport = 5556
myid = "cif-router"
dbkey = 'a8fd97c3-9f8b-477b-b45b-ba06719a0088'
dbname = 'cif-db'

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
    elif o == "-h":
        usage()
        sys.exit(2)
        
print "Create ROUTER socket on " + str(routerport)
socket = context.socket(zmq.ROUTER)
socket.bind("tcp://*:" + str(routerport))
socket.setsockopt(zmq.IDENTITY, myname)

print "Create XSUB socket"
xsub = context.socket(zmq.SUB)
xsub.setsockopt(zmq.SUBSCRIBE, '')

print "Connect XSUB<->XPUB"
thread = threading.Thread(target=myrelay, args=(publisherport,))
thread.start()

print "Entering event loop"

try:
    open_for_business = False
    
    while True:
        print "[up " + str(int(mystats.getuptime())) + "s]: Get incoming message"
        rawmsg = socket.recv_multipart()
        #print " Got ", rawmsg
        
        msg = control_pb2.ControlType()
        
        try:
            msg.ParseFromString(rawmsg[2])
        except Exception as e:
            print "Received message isn't a protobuf: ", e
            mystats.setbad()
        else:
            msgreallyfrom = rawmsg[0] # save the ZMQ identity of who sent us this message
            
            #print "Got msg: ", msg
    
            try:
                cifsupport.versionCheck(msg)
            except Exception as e:
                print "Received message has incompatible version: ", e
                mystats.setbadversion(1, msg.version)
            else:
            
                if cifsupport.isControl(msg):
                    msgfrom = msg.src
                    msgto = msg.dst
                    msgcommand = msg.command
                    msgid = msg.seq
                    
                    if msgfrom != '' and msg.apikey != '':
                        if msgto == myname and msg.type == control_pb2.ControlType.COMMAND:
                            print "COMMAND for me: ", msgcommand
                            
                            mystats.setcontrols(1, msgcommand)
                            
                            """
                            For REGISTER:
                                We allow only the db to register with us while we are not
                                open_for_business. Once the DB registers, we are open_for_business
                                since we can then start validating apikeys. Until that time, we can
                                only validate the dbkey that is specified on the command line when
                                you launch this program.
                            """
                            if msgcommand == control_pb2.ControlType.REGISTER:
                                  print "REGISTER from: " + msgfrom
                                  
                                  msg.status = control_pb2.ControlType.FAILED
                                  msg.type = control_pb2.ControlType.REPLY
                                  msg.seq = msgid
                                  
                                  if msgfrom == dbname and msg.apikey == dbkey:
                                      rv = register(msgfrom, None)
                                      msg.status = control_pb2.ControlType.SUCCESS
                                      msg.registerResponse.REQport = routerport
                                      msg.registerResponse.PUBport = publisherport
                                      open_for_business = True
                                      print " DB has connected successfully. Sending reply."
                                      
                                  elif open_for_business == True:
                                      rv = register(msgfrom, msg.apikey)
                                      msg.registerResponse.REQport = routerport
                                      msg.registerResponse.PUBport = publisherport
                                      msg.status = rv
                                      if rv == control_pb2.ControlType.SUCCESS:
                                          print " Registered successfully. Sending reply."
                                      else:
                                          print " Registration failed (unauthorized)."
                                  else:
                                      print " Not open_for_business yet. Go away."
    
                                  socket.send_multipart([msgreallyfrom, '', msg.SerializeToString()])
                                              
                            elif msgcommand == control_pb2.ControlType.UNREGISTER:
                                """
                                If the database unregisters, then we are not open_for_business any more.
                                """
                                print "UNREGISTER from: " + msgfrom
                                if open_for_business == True:
                                    if msgfrom == dbname and msg.apikey == dbkey:
                                        open_for_business = False
                                        rv = unregister(msgfrom, None)
                                        msg.status = rv
                                        msg.seq = msgid
                                    else:
                                        # TODO check apikey with db
                                        rv = unregister(msgfrom, msg.apikey)
                                        msg.status = rv
                                        msg.seq = msgid
                                        
                                    socket.send_multipart([ msgreallyfrom, '', msg.SerializeToString()])
                            
                            elif msgcommand == control_pb2.ControlType.LISTCLIENTS:
                                 print "LIST-CLIENTS for: " + msgfrom
                                 if open_for_business == True:
                                     rv = list_clients(msg.apikey)
                                     msg.seq = msgid
                                     msg.status = msg.status | control_pb2.ControlType.FAILED


                                     if rv != None:
                                         msg.status = msg.status | control_pb2.ControlType.SUCCESS
                                         msg.listClientsResponse.client.extend(rv.client)
                                         msg.listClientsResponse.connectTimestamp.extend(rv.connectTimestamp)
                                     
                                     socket.send_multipart( [ msgreallyfrom, '', msg.SerializeToString() ] )
                                 
                            elif msgcommand == control_pb2.ControlType.IPUBLISH:
                                 print "IPUBLISH from: " + msgfrom
                                 if open_for_business == True:
                                     rv = dosubscribe(msg)
                                     msg.status = rv
                                     socket.send_multipart( [msgreallyfrom, '', msg.SerializeToString()] )
                        else:
                            print "COMMAND for someone else: cmd=", msgcommand, "src=", msgfrom, " dst=", msgto
                    else:
                        print "msgfrom and/or msg.apikey is empty"
                        
except KeyboardInterrupt:
    print "Shut down."
    if thread.isAlive():
        try:
            thread._Thread__stop()
        except:
            print(str(thread.getName()) + ' could not be terminated')
    sys.exit(0)

    
    
