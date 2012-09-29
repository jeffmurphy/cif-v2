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

sys.path.append('/usr/local/lib/cif-protocol/pb-python/gen-py')
import msg_pb2
import feed_pb2
import RFC5070_IODEF_v1_pb2
import MAEC_v2_pb2
import control_pb2
import cifsupport

sys.path.append('../../cif-router/poc')
from CIF.CtrlCommands.Clients import *
from CIF.Foundation import Foundation


    
def usage():
    print "\
    # poc-subscriber [-c 5656] [-r cif-router:5555] [-m name]\n\
    #     -c  control port (REQ - for inbound messages)\n\
    #     -r  cif-router hostname:port\n\
    #     -m  my name\n"
    


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
apikey = "1234567890abcdef"

global cf
cf = Foundation({'apikey' : apikey,
                 'myip'   : myip,
                 'cifrouter' : cifrouter,
                 'controlport' : controlport,
                 'myid' : myid,
                 'routerid' : "cif-router"
                 })


try:
    print "Register with " + cifrouter + " (req->rep)"
    cf.ctrlsocket()
    (routerport, routerpubport) = cf.register()

    subscriber = cf.subscribersocket()
    
    time.sleep(1) # wait for router to connect, sort of lame but see this a lot in zmq code
    
    while True:
        msg = msg_pb2.MessageType()
        msg.ParseFromString(subscriber.recv())
        
        count = 0
        for mt in msg.submissionRequest:
            count = count + 1
            if mt.baseObjectType == "MAEC_v2":
                maec = MAEC_v2_pb2.maecPlaceholder()
                maec.ParseFromString(msg.submissionRequest[0].data)
                print " Got MAEC_v2: ", maec.msg
            elif mt.baseObjectType == "RFC5070_IODEF_v1_pb2":
                iodef = RFC5070_IODEF_v1_pb2.IODEF_DocumentType()
                iodef.ParseFromString(msg.submissionRequest[0].data)
                print " Got IODEF: ", iodef
            else:
                print " Got unimplemented type: " + mt.baseObjectType

        print "\nProcessed ", count, " messages"
        
    cf.unregister()
    
except KeyboardInterrupt:
    cf.ctrlc()

