#!/usr/bin/python
#
# cli.py
#
# cli.py [-c 5657] [-r cif-router:5555] [-m name] [-h]
#     -c  control port (REQ - for inbound messages)
#     -r  cif-router hostname:port
#     -m  my name
#
# cli.py uses the following sockets:
#     REP 
#       for 'control' messages 
#          SHUTDOWN
#          PING
#     REQ 
#       for requesting things
#          REGISTER
#          [other commands]
#
# a typical use case:
# 
# cli.py REQ connects to cif-router's ROUTER
#  sends REGISTER message to cif-router
#  waits for REGISTERED message
#  sends additional commands to cif-router's ROUTER port
#  processes replies

import sys
import zmq
import random
import time
import os
import datetime
import json
import getopt
import socket
import fileinput

sys.path.append('/usr/local/lib/cif-protocol/pb-python/gen-py')
import msg_pb2
import feed_pb2
import RFC5070_IODEF_v1_pb2
import MAEC_v2_pb2
import control_pb2
import cifsupport

sys.path.append('../../libcif/lib')
from CIF.CtrlCommands.Clients import *
from CIF.Foundation import Foundation

def usage():
    print "\
    # cli.py [-c 5657] [-r cif-router:5555] [-m name]\n\
    #     -c  control port (REQ - for inbound messages)\n\
    #     -r  cif-router hostname:port\n\
    #     -m  my name\n"


def listClients(myid):
    cf.sendmsg(Clients.makecontrolmsg(myid, 'cif-router'), listClientsFinished)

def listClientsFinished(msg):
    #print "\tReply contains ", str(len(msg.listClientsResponse.client)), " entries."
    #print "\tReply contains ", str(len(msg.listClientsResponse.connectTimestamp)), " entries."

    if msg.status & control_pb2.ControlType.SUCCESS == control_pb2.ControlType.SUCCESS:
        print "%20s %s" % ("Client", "Connected At")

        for i in range(0, len(msg.listClientsResponse.client)):
            cts = time.ctime(int(msg.listClientsResponse.connectTimestamp[i]))
            print "%20s %s" % (msg.listClientsResponse.client[i], cts)
    else:
        if debug > 2:
            print "\t\tlist clients failed. " + msg.status


          
def help():
    print "commands: clients, debug #, help, exit"

global debug
debug = 5

try:
    opts, args = getopt.getopt(sys.argv[1:], 'c:r:m:h')
except getopt.GetoptError, err:
    print str(err)
    usage()
    sys.exit(2)

controlport = "5657"
cifrouter = "sdev.nickelsoft.com:5555"
myid = "cli(%s)" % (os.getlogin()) #, os.getpid())

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

global cf
apikey = "1234567890abcdef"

cf = Foundation({'apikey': apikey, 
                 'myip': myip, 
                 'cifrouter': cifrouter,
                 'controlport': controlport,
                 'routerid': "cif-router",
                 'myid': myid})

cf.setdebug(debug)

try:
    if debug > 1:
        print "Register with " + cifrouter + " (req->rep)"
        
    cf.ctrlsocket()
    (routerport, routerpubport) = cf.register()
    routerhname = cifrouter.split(':')
    
    time.sleep(1) # wait for router to connect, sort of lame but see this a lot in zmq code
    
    stillGoing = True
    while stillGoing:
        print ">>> ",
        line = sys.stdin.readline()

        parts = line.split()

        if len(parts) > 0:
            if parts[0] == "exit":
                stillGoing = False

            elif parts[0] == "help":
                help()
            
            elif parts[0] == "debug":
                debug = int(parts[1])
                
            elif parts[0] == "clients":
                listClients(myid)
                
            else:
                help()
        
    cf.unregister()
    
except KeyboardInterrupt:
    cf.ctrlc()

