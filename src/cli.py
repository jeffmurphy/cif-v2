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
from CIF.CtrlCommands.Ping import *

from CIF.Foundation import Foundation

def usage():
    print "\
    # cli.py [-c 5657] [-r cif-router:5555] [-m name] [-a apikey] [-D 0-9]\n\
    #     -c  control port (REQ - for inbound messages)\n\
    #     -r  cif-router hostname:port\n\
    #     -m  my name\n"


def listClients(myid, apikey):
    cf.sendmsg(Clients.makecontrolmsg(myid, 'cif-router', apikey), listClientsFinished)

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

def ping(myid, apikey, dst, num):
    more = True
    ps = 1
    print "\nPING " + dst
    while more:
        c = Ping.makerequest(myid, dst, apikey, ps)
        ps = ps + 1
        cf.sendmsg(c, pingFinished)
        time.sleep(1)
        if num != -1:  # -1 = forever
            num = num - 1
            if num < 1:
                more = False

def pingFinished(msg):
    if msg.type == control_pb2.ControlType.REPLY and msg.command == control_pb2.ControlType.PING and msg.status == control_pb2.ControlType.SUCCESS:
        recv = time.time()
        # 64 bytes from 10.211.55.4: icmp_seq=1 ttl=64 time=0.085 ms
        print "%d bytes from %s: seq=%d time=%.4f ms" % ( len(str(msg)), msg.src, msg.pingRequest.pingseq, (recv - msg.pingRequest.ts))
    else:
        print "Got a reply back to my ping, but it doesn't look right: ", msg

def help():
    print "commands: clients, debug #, ping <dst> [qty=1], help, exit"

global debug
debug = 2

try:
    opts, args = getopt.getopt(sys.argv[1:], 'c:r:m:D:k:h')
except getopt.GetoptError, err:
    print str(err)
    usage()
    sys.exit(2)

controlport = "5657"
cifrouter = "sdev.nickelsoft.com:5555"
myid = "cli(%s)" % (os.getlogin()) #, os.getpid())
apikey = "1234567890abcdef"

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
    elif o == "-D":
        debug = a
    elif o == "-k":
        apikey = a


myip = socket.gethostbyname(socket.gethostname()) # has caveats

global cf

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
                listClients(myid, apikey)
                
            elif parts[0] == "ping":
                num = 1
                if len(parts) == 3:
                    num = int(parts[2])
                ping(myid, apikey, parts[1], num)
                
            else:
                help()
        
    cf.unregister()
    
except KeyboardInterrupt:
    cf.ctrlc()

