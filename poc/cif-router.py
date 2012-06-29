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
#            REGISTERED, UNREGISTERED, WHORU, OK, FAILED
#
# a typical use case:
# 
# cif-smrt's REQ connects to ROUTER and sends a REGISTER message with dst=cif-router
# cif-router's ROUTER responds with REGISTERED
#    [the above eventually will imply encryption/authentication]
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

sys.path.append('/usr/local/lib/cif-protocol/pb-python/gen-py')
import msg_pb2
import feed_pb2
import RFC5070_IODEF_v1_pb2
import MAEC_v2_pb2


myname = "cif-router"

def register(clientname):
    # zmq doesnt have a disconnect, so if we xsub.connect() multiple times
    # to the same client, we'll start recving duplicates of that clients
    # messages. to avoid this, we track who we've connected to and if we
    # see the same client more than once, we dont call connect() again.
    
    #if clientname in clients :
    #    print "\talready registered"
    #    return 'ALREADY-REGISTERED'
    

    clients[clientname] = time.time()
    return 'REGISTERED'

def dosubscribe(clientname):
    if clientname in publishers :
        print "we've seen this client before. re-using old connection."
    else :
        publishers[clientname] = time.time()
        t = str(clientname).split('|')
        print "dosubscribe: connect our xsub -> xpub on " + t[0]
        xsub.connect("tcp://" + t[0])
    return 'OK'

def unregister(clientname):
    if clientname in clients :
        print "\tunregistered"
        # see explanation in register()
        #del clients[clientname]
        return 'UNREGISTERED'
    print "\tclient unknown"
    return 'WHORU'

def list_clients():
    l = ''
    for k in clients.keys():
        l = l + "%{client}s %{time}d\n" % { 'client' : k, 'time' : clients[k] }
    return l

def myrelay(pubport):
#    zmq.device(zmq.FORWARDER, xpub, xsub)
    relaycount = 0
    print "[myrelay] Create XPUB socket on " + str(pubport)
    xpub = context.socket(zmq.PUB)
    xpub.bind("tcp://*:" + str(pubport))
    while True:
        relaycount = relaycount + 1
        print "[myrelay] " + str(relaycount) + " recv()"
        m = xsub.recv()
        #print "[myrelay] got msg on our xsub socket: " , m
        xpub.send(m)
    
def usage():
    print "cif-router [-r routerport] [-p pubport] [-m myid] [-h]"
    print "   routerport = 5555, pubport = 5556, myid = cif-router"
        
try:
    opts, args = getopt.getopt(sys.argv[1:], 'p:r:m:h')
except getopt.GetoptError, err:
    print str(err)
    usage()
    sys.exit(2)

context = zmq.Context()
clients = {}
publishers = {}
routerport = 5555
publisherport = 5556
myid = "cif-router"

for o, a in opts:
    if o == "-r":
        routerport = a
    elif o == "-p":
        publisherport = a
    elif o == "-m":
        myid = a
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
    while True:
        print "Get incoming message"
        msg = socket.recv_multipart()
    
        print "Got msg: ", msg

        msgfrom = msg[0]
        msgto = msg[2]
        msgcontent = msg[4]
    
        if msgto == myname :
            print "msg for me!"
        
            if msgcontent == "REGISTER":
                  print "REGISTER " + msgfrom
                  rv = register(msgfrom)
                  socket.send_multipart( [ msgfrom, '', rv, '', 
                                          json.dumps({ 'REQ' : routerport, 'PUB' : publisherport }) ] )
                              
            elif msgcontent == "UNREGISTER":
                print "UNREGISTER" + msgfrom
                rv = unregister(msgfrom)
                socket.send_multipart( [ msgfrom, '', rv ] )
            
            elif msgcontent == "LIST-CLIENTS":
                 print "LIST-CLIENTS for " + msgfrom
                 rv = list_clients()
                 socket.send_multipart( [ msgfrom, '', 'OK', '', rv ] )
                 
            elif msgcontent == "IPUBLISH":
                 print "IPUBLISH " + msgfrom
                 rv = dosubscribe(msgfrom)
                 socket.send_multipart( [msgfrom, '', 'OK', '', rv ] )

except KeyboardInterrupt:
    print "Shut down."
    if thread.isAlive():
        try:
            thread._Thread__stop()
        except:
            print(str(thread.getName()) + ' could not be terminated')
    sys.exit(0)

    
    