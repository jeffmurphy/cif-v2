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
from texttable import Texttable

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
from CIF.CtrlCommands.ThreadTracker import ThreadTracker

from CIF.Foundation import Foundation

from CIF.RouterStats import *

def usage():
    print "\
    # cli.py [-c 5657] [-r cif-router:5555] [-m name] [-a apikey] [-D 0-9]\n\
    #     -c  control port (REQ - for inbound messages)\n\
    #     -r  cif-router hostname:port\n\
    #     -m  my name\n"


def listThreads(myid, apikey, dst):
    cf.sendmsg(ThreadTracker.makecontrolmsg(myid, dst, apikey), listThreadsFinished)

def listThreadsFinished(msg):
    if debug > 2:
        print msg
            
    if msg.status & control_pb2.ControlType.SUCCESS == control_pb2.ControlType.SUCCESS:
        table = Texttable(max_width=160)
        table.set_cols_dtype(['i', 't', 't', 't', 'i', 't', 't'])
        table.set_cols_width([16, 10, 20, 20, 8, 8, 30])
        table.add_row(["ID", "User", "Host", "Command", "Runtime", "State", "Info"])
        for i in range(0, len(msg.listThreadsResponse.id)):
            table.add_row([msg.listThreadsResponse.id[i], 
                           msg.listThreadsResponse.user[i],
                           msg.listThreadsResponse.host[i],
                           msg.listThreadsResponse.command[i],
                           msg.listThreadsResponse.runtime[i],
                           msg.listThreadsResponse.state[i],
                           msg.listThreadsResponse.info[i]
                           ])
        print table.draw() + "\n"
    else:
        print "\t\tlist threads failed. " + msg.status
        
def listClients(myid, apikey):
    cf.sendmsg(Clients.makecontrolmsg(myid, 'cif-router', apikey), listClientsFinished)

def listClientsFinished(msg):
    #print "\tReply contains ", str(len(msg.listClientsResponse.client)), " entries."
    #print "\tReply contains ", str(len(msg.listClientsResponse.connectTimestamp)), " entries."
    
    if debug > 2:
        print msg
            
    if msg.status & control_pb2.ControlType.SUCCESS == control_pb2.ControlType.SUCCESS:

        print "%20s %s" % ("Client", "Connected At")

        for i in range(0, len(msg.listClientsResponse.client)):
            cts = time.ctime(int(msg.listClientsResponse.connectTimestamp[i]))
            print "%20s %s" % (msg.listClientsResponse.client[i], cts)
    else:
        print "\t\tlist clients failed. " + msg.status

def stats(myid, apikey, dst='cif-router'):
    cf.sendmsg(RouterStats.makecontrolmsg(myid, dst, apikey), statsFinished)

def statsFinished(msg):
    if msg.status == control_pb2.ControlType.SUCCESS:
        st = control_pb2._STATSRESPONSE_STATSTYPE.values_by_number[msg.statsResponse.statsType].name
        print "stats received for: " + st
        print "stats contents: " + msg.statsResponse.stats
    else:
        print "stats reply indicates failure: " + msg.statsResponse.statusMsg
    
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
    print "commands: clients, debug #, ping <dst> [qty=1], threads <dst>, help, exit"

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
apikey = 'a2fd22c2-2f2b-477b-b45b-ba06719a0088'

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
global thread_tracker
thread_tracker = ThreadTracker(False)

cf = Foundation({'apikey': apikey, 
                 'myip': myip, 
                 'cifrouter': cifrouter,
                 'controlport': controlport,
                 'routerid': "cif-router",
                 'myid': myid,
                 'thread_tracker': thread_tracker})

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
                if len(parts) < 2:
                    print "usage: debug [0-9]"
                else:
                    debug = int(parts[1])
                
            elif parts[0] == "clients":
                listClients(myid, apikey)
            
            elif parts[0] == "threads":
                if len(parts) < 2:
                    print "usage: threads [target]\nuse 'clients' for available targets."
                else:
                    listThreads(myid, apikey, parts[1])
            
            elif parts[0] == "stats":
                stats(myid, apikey)
                
            elif parts[0] == "ping":
                num = 1
                if len(parts) < 2 or len(parts) > 3:
                    print "usage: ping [dest] <number of pings>"
                else:
                    if len(parts) == 3:
                        num = int(parts[2])
                    ping(myid, apikey, parts[1], num)
                
            else:
                help()
        
    cf.unregister()
    
except KeyboardInterrupt:
    cf.ctrlc()

