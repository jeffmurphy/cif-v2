#!/usr/bin/python
#
# cif-router proof of concept
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
#            REGISTERED, ALREADY-REGISTERED, UNREGISTERED, WHORU, OK, FAILED
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

myname = "cif-router"

def register(clientname):
    if clientname in clients :
        print "\talready registered"
        return 'ALREADY-REGISTERED'
    clients[clientname] = time.time()
    t = str(clientname).split('|')
    print "connect our xsub -> xpub on " + t[0]

    xsub.connect("tcp://" + t[0])
    return 'REGISTERED'

def unregister(clientname):
    if clientname in clients :
        print "\tunregistered"
        del clients[clientname]
        return 'UNREGISTERED'
    print "\tclient unknown"
    return 'WHORU'

def list_clients():
    l = ''
    for k in clients.keys():
        l = l + "%{client}s %{time}d\n" % { 'client' : k, 'time' : clients[k] }
    return l

def myrelay():
#    zmq.device(zmq.FORWARDER, xpub, xsub)
    relaycount = 0
    print "[myrelay] Create XPUB socket on 5556"
    xpub = context.socket(zmq.PUB)
    xpub.bind("tcp://*:5556")
    while True:
        relaycount = relaycount + 1
        print "[myrelay] " + str(relaycount) + " recv()"
        m = xsub.recv()
        print "[myrelay] got msg on our xsub socket: " , m

    
context = zmq.Context()
clients = {}

print "Create ROUTER socket on 5555"
socket = context.socket(zmq.ROUTER)
socket.bind("tcp://*:5555")
socket.setsockopt(zmq.IDENTITY, myname)

print "Create XSUB socket"
xsub = context.socket(zmq.SUB)
xsub.setsockopt(zmq.SUBSCRIBE, '')

print "Connect XSUB<->XPUB"
thread = threading.Thread(target=myrelay, args=())
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
                  socket.send_multipart( [ msgfrom, '', rv ] )
            
            elif msgcontent == "UNREGISTER":
                print "UNREGISTER" + msgfrom
                rv = unregister(msgfrom)
                socket.send_multipart( [ msgfrom, '', rv ] )
            
            elif msgcontent == "LIST-CLIENTS":
                 print "LIST-CLIENTS for " + msgfrom
                 rv = list_clients()
                 socket.send_multipart( [ msgfrom, '', 'OK', '', rv ] )

except KeyboardInterrupt:
    print "Shut down."
    if thread.isAlive():
        try:
            thread._Thread__stop()
        except:
            print(str(thread.getName()) + ' could not be terminated')
    sys.exit(0)

    
    