#!/usr/bin/python

import sys
import zmq
import random
import time
import os
import datetime
import getopt
import socket
import threading

def handler(socket, msg):
    ti = str(threading.currentThread().ident)
    print ti + "] Handling new message " 
    #print msg
    
    if len(msg) == 4:
        msgfrom = msg[0]
        msgtxt  = msg[1]
        msgid   = msg[2]
        reply_wanted = msg[3]
        print "\tid:" + msgid + " reply_wanted:" + reply_wanted
        
        if reply_wanted == "1":
            print "\tthey want a reply. sending it."
            socket.send_multipart([msgfrom, 'fooreply', msgid])

        
routerport = 8123
myname = "ZMQROUTERDEMO"

context = zmq.Context()
print "Create ROUTER socket on " + str(routerport)
socket = context.socket(zmq.ROUTER)
socket.bind("tcp://*:" + str(routerport))
socket.setsockopt(zmq.IDENTITY, myname)


print "main] loop running"

while True:
    m = socket.recv_multipart()
    thread = threading.Thread(target=handler, args=(socket,m,))
    thread.start()