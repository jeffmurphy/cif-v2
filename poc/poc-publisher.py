#!/usr/bin/python
#
# poc-publisher proof of concept
#
# poc-publisher [-c 5656] [-p 5657] [-r cif-router:5555] [-t #] [-c #] [-m name] [-h]
#     -c  control port (REQ - for inbound messages)
#     -p  publisher port (PUB)
#     -r  cif-router hostname:port
#     -t  secs between publishing messages (decimal like 0.5 is ok)
#     -n  number of messages to send (and then quit)
#     -m  my name
#
# cif-publisher uses the following sockets:
#     REP 
#       for 'control' messages 
#          SHUTDOWN
#          STATS
#          PING
#          PAUSE
#          RESUME
#     REQ 
#       for requesting things
#          REGISTER
#          IPUBLISH
#     XPUB
#       for publishing messages
#
# a typical use case:
# 
# poc-publisher REQ connects to cif-router's ROUTER
#  sends REGISTER message with dst=cif-router
#  waits for REGISTERED message
#  waits for connections to poc-pubs XPUB port
#  publishes messages via XPUB until control-c

import sys
import zmq
import random
import time
import os
import datetime
import threading
import getopt
import socket


def ctrlsocket(myname, cifrouter):
    # Socket to talk to cif-router
    req = context.socket(zmq.REQ);
    req.setsockopt(zmq.IDENTITY, myname)
    req.connect('tcp://' + cifrouter)
    return req

def publishsocket(publisherport):
    # Socket to publish from
    print "Creating publisher socket on " + publisherport
    publisher = context.socket(zmq.PUB);
    publisher.bind('tcp://*:' + publisherport);
    return publisher

def unregister(req, cifrouter):
    print "Send UNREGISTER to cif-router (" + cifrouter + ")"
    req.send_multipart(["cif-router", "", "UNREGISTER"])
    reply = req.recv_multipart();
    print "Got reply: " , reply
    if reply[0] == 'UNREGISTERED':
        print "unregistered successfully"
    else:
        print "not sure? " + reply[0]

def register(req, cifrouter):
    print "Send REGISTER to cif-router (" + cifrouter + ")"
    req.send_multipart(["cif-router", "", "REGISTER"])
    reply = req.recv_multipart();
    print "Got reply: " , reply
    if reply[0] == 'REGISTERED':
        print "registered successfully"
        # cif-router should connect to our PUB socket
    elif reply[0] == 'ALREADY-REGISTERED':
        print "already registered?"

def ctrlc(req, cifrouter):
    print "Shutting down."
    unregister(req, cifrouter)
    sys.exit(0)
    
def usage():
    print "\
    # poc-publisher [-c 5656] [-p 5657] [-r cif-router:5555] [-t #] [-c #]\n\
    #     -c  control port (REQ - for inbound messages)\n\
    #     -p  publisher port (PUB)\n\
    #     -r  cif-router hostname:port\n\
    #     -t  secs between publishing messages (decimal like 0.5 is ok)\n\
    #     -n  number of messages to send (and then quit)\n"
    
def ctrl(rep, controlport):
    print "Creating control socket on :" + controlport
    # Socket to accept control requests on
    rep = context.socket(zmq.REP);
    rep.bind('tcp://*:' + controlport);

global req

try:
    opts, args = getopt.getopt(sys.argv[1:], 'c:p:r:t:n:h')
except getopt.GetoptError, err:
    print str(err)
    usage()
    sys.exit(2)

controlport = "5656"
publisherport = "5657"
cifrouter = "sdev.nickelsoft.com:5555"
sleeptime = 1.0
count = -1
myid = "poc-publisher"

for o, a in opts:
    if o == "-c":
        controlport = a
    elif o == "-p":
        publisherport = a
    elif o == "-m":
        myid = a
    elif o == "-r":
        cifrouter = a
    elif o == "-t":
        sleeptime = float(a)
    elif o == "-n":
        count = int(a)
        if count > 0:
            count -= 1
    elif o == "-h":
        usage()
        sys.exit(2)

myip = socket.gethostbyname(socket.gethostname()) # has caveats

print "ZMQ::Context"

context = zmq.Context()
myname = myip + ":" + publisherport + "|" + myid


try:
    print "Register with " + cifrouter + " (req->rep)"
    req = ctrlsocket(myname, cifrouter)
    register(req, cifrouter)
    publisher = publishsocket(publisherport)

    time.sleep(1) # wait for router to connect, sort of lame but see this a lot in zmq code
    
    hasMore = True
    while hasMore:      
        sys.stdout.write ("[forever]" if (count == -1) else str(count))
        print " publishing a message " 
        publisher.send(str(count) + ' message ' + str(time.time()))
        time.sleep(sleeptime)
        if count == 0:
            hasMore = False
        elif count > 0:
            count = count - 1
        
    unregister(req, cifrouter)
    
except KeyboardInterrupt:
    ctrlc(req, cifrouter)
    