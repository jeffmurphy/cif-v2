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
#  sends REGISTER message to cif-router
#  waits for REGISTERED message
#  sends IPUBLISH message to cif-router to indicate we are a publisher
#  waits for connections to our XPUB port
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
    # poc-publisher [-c 5656] [-p 5657] [-r cif-router:5555] [-t #] [-c #]\n\
    #     -c  control port (REQ - for inbound messages)\n\
    #     -p  publisher port (PUB)\n\
    #     -r  cif-router hostname:port\n\
    #     -t  secs between publishing messages (decimal like 0.5 is ok)\n\
    #     -n  number of messages to send (and then quit)\n\
    #     -k  apikey\n"
    


try:
    opts, args = getopt.getopt(sys.argv[1:], 'c:p:r:t:m:h')
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
apikey = "12345abcdef"

for o, a in opts:
    if o == "-c":
        controlport = a
    elif o == "-k":
        apikey = a
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

global cf
cf = Foundation()


try:
    print "Register with " + cifrouter + " (req->rep)"

    cf.ctrlsocket(myip, controlport, myid, cifrouter)
    (routerport, routerpubport) = cf.register(apikey, myip, myid, cifrouter)
    publisher = cf.publishsocket(publisherport)
    cf.ipublish(apikey, myip, myid, cifrouter)
    
    time.sleep(1) # wait for router to connect, sort of lame but see this a lot in zmq code
    
    hasMore = True
    while hasMore:      
        sys.stdout.write ("[forever]" if (count == -1) else str(count))
        
        msg = msg_pb2.MessageType()
        msg.version = msg.version # required
        msg.apikey = apikey
        msg.guid = '123456-abcdef'
        msg.type = msg_pb2.MessageType.SUBMISSION

        maec = MAEC_v2_pb2.maecPlaceholder()
        maec.msg = "test message: " + str(count) + " " + str(time.time())

        sr = msg.submissionRequest.add()
        sr.baseObjectType = 'MAEC_v2'
        sr.data = maec.SerializeToString()

        print " publishing a message: ", maec.msg 
        publisher.send(msg.SerializeToString())
        time.sleep(sleeptime)
        if count == 0:
            hasMore = False
        elif count > 0:
            count = count - 1
        
    cf.unregister(apikey, cifrouter, myid)
    
except KeyboardInterrupt:
    cf.ctrlc(apikey, cifrouter, myid)
    