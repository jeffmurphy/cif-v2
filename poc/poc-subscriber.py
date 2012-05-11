#!/usr/bin/python
#
# poc-subscriber proof of concept
#
# poc-subscriber [-c 5656] [-r cif-router:5555] [-m name] [-h]
#     -c  control port (REQ - for inbound messages)
#     -r  cif-router hostname:port
#     -m  my name
#
# cif-subscriber uses the following sockets:
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
#     XSUB
#       for subscribing to messages
#
# a typical use case:
# 
# poc-subscriber REQ connects to cif-router's ROUTER
#  sends REGISTER message to cif-router
#  waits for REGISTERED message
#  connects to cif-router's XPUB port
#  loops and reads messages until control-c

import sys
import zmq
import random
import time
import os
import datetime
import json
import getopt
import socket

#sys.path.append('./gen-py')
#from cifipc.ttypes import *

sys.path.append('./protopy')
import cifipc_pb2

def ctrlsocket(myname, cifrouter):
    # Socket to talk to cif-router
    req = context.socket(zmq.REQ);
    req.setsockopt(zmq.IDENTITY, myname)
    req.connect('tcp://' + cifrouter)
    return req

def subscribersocket(publisher):
    # Socket to publish from
    print "Creating subscriber socket and connecting to " + publisher
    subscriber = context.socket(zmq.SUB)
    subscriber.connect('tcp://' + publisher)
    subscriber.setsockopt(zmq.SUBSCRIBE, '')
    return subscriber

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
    routerport = 0
    routerpubport = 0
    
    print "Send REGISTER to cif-router (" + cifrouter + ")"
    req.send_multipart(["cif-router", "", "REGISTER"])
    reply = req.recv_multipart();
    print "Got reply: " , reply
    if reply[0] == 'REGISTERED':
        print "registered successfully"
        rv = json.loads(reply[2])
        routerport = rv['REQ']
        routerpubport = rv['PUB']
    elif reply[0] == 'ALREADY-REGISTERED':
        print "already registered?"

    return (routerport, routerpubport)
        
def ctrlc(req, cifrouter):
    print "Shutting down."
    unregister(req, cifrouter)
    sys.exit(0)
    
def usage():
    print "\
    # poc-subscriber [-c 5656] [-r cif-router:5555] [-m name]\n\
    #     -c  control port (REQ - for inbound messages)\n\
    #     -r  cif-router hostname:port\n\
    #     -m  my name\n"
    
def ctrl(rep, controlport):
    print "Creating control socket on :" + controlport
    # Socket to accept control requests on
    rep = context.socket(zmq.REP);
    rep.bind('tcp://*:' + controlport);

global req

try:
    opts, args = getopt.getopt(sys.argv[1:], 'c:r:m:h')
except getopt.GetoptError, err:
    print str(err)
    usage()
    sys.exit(2)

controlport = "5656"
cifrouter = "sdev.nickelsoft.com:5555"
myid = "poc-subscriber"

for o, a in opts:
    if o == "-c":
        controlport = a
    elif o == "-m":
        myid = a
    elif o == "-r":
        cifrouter = a
    elif o == "-h":
        usage()
        sys.exit(2)

myip = socket.gethostbyname(socket.gethostname()) # has caveats

print "ZMQ::Context"

context = zmq.Context()
myname = myip + ":" + controlport + "|" + myid


try:
    print "Register with " + cifrouter + " (req->rep)"
    req = ctrlsocket(myname, cifrouter)
    (routerport, routerpubport) = register(req, cifrouter)
    routerhname = cifrouter.split(':')

    subscriber = subscribersocket(routerhname[0] + ":" + str(routerpubport))
    
    time.sleep(1) # wait for router to connect, sort of lame but see this a lot in zmq code
    
    while True:
        msg = cifipc_pb2.TestMessage()
        msg.ParseFromString(subscriber.recv())
        print "Got msg: ", msg
        
    unregister(req, cifrouter)
    
except KeyboardInterrupt:
    ctrlc(req, cifrouter)

