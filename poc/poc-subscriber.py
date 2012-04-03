#!/usr/bin/python
#
# poc-subscriber proof of concept
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

context = zmq.Context()
myname = "127.0.0.1:5657|poc-publisher";

print "ZMQ::Context"

print "Register with cif-router:5555 (req->rep)"

# Socket to talk to cif-router
req = context.socket(zmq.REQ);
req.setsockopt(zmq.IDENTITY, myname)
req.connect('tcp://127.0.0.1:5555');

print "Creating control socket on :5656"
# Socket to accept control requests on
rep = context.socket(zmq.REP);
rep.bind('tcp://*:5656');

# Socket to publish from

print "Creating publisher socket on 5657"
publisher = context.socket(zmq.PUB);
publisher.bind('tcp://*:5657');

print "Send REGISTER to cif-router"
req.send_multipart(["cif-router", "", "REGISTER"])
reply = req.recv_multipart();
print "Got reply: " , reply
if reply[0] == 'REGISTERED':
    print "registered successfully"
    # cif-router should connect to our PUB socket
elif reply[0] == 'ALREADY-REGISTERED':
    print "already registered?"

while True:
    print "publishing a message " 
    publisher.send('message ' + str(time.time()))
    time.sleep(1)

