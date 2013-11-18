#!/usr/bin/python

"""
Example of an zmq dealer. A dealer is just a REQ socket that
doesn't block waiting for a reply. In this example, we send
messages and randomly indicate in the message whether or not
we expect a reply. When a reply is received (in the 'handler' 
thread) a callback will be used to process the reply.

This is the basic communication pattern used in CIF zmq
client code. 
"""

import sys
import zmq
import random
import time
import os
import datetime
import getopt
import socket
import threading

global callback_registry
global callback_registry_lock

callback_registry = {}
callback_registry_lock = threading.Lock()



def sendmsg(socket, msg, msgid, callback):
        
    """ 
    Send a message on a socket. Messages are always sent asynchronously.
    If a callback is specified, it will be called when a reply is received.
    """

    if socket != None and msg != None:
        reply_wanted = 0
        if callback != None:
            reply_wanted = 1
            callback_registry_lock.acquire()
            callback_registry[msgid] = callback
            callback_registry_lock.release()
        socket.send_multipart([msg, msgid, str(reply_wanted)])
        
    
def handler(socket):
    """
    event loop - processes replies to sent messages
    """
    while True:
        ti = str(threading.currentThread().ident)
        print ti + "] Waiting for a reply"
        r = socket.recv_multipart()
        print ti + "] Got reply: ", r
        
        if len(r) == 2:
            msgtxt = r[0]
            msgid  = r[1]

            callback_registry_lock.acquire()

            if msgid in callback_registry:
                print ti + "] Reply is good."
                cbthread = threading.Thread(target = callback_registry[msgid], args=(msgtxt,))
                cbthread.start()
                del callback_registry[msgid]
            else:
                print ti + "] Reply is bad (unexpected). Discarding."

            callback_registry_lock.release()

        
def mycallback(msg):
    print "in callback"
    
routerport = 8123
myname = "ZMQDEALERDEMO"

context = zmq.Context()
print "Create DEALER socket on " + str(routerport)
socket = context.socket(zmq.DEALER)
socket.connect("tcp://localhost:" + str(routerport))
socket.setsockopt(zmq.IDENTITY, myname)

thread = threading.Thread(target=handler, args=(socket,))
thread.start()

print "main] loop running"

while True:
    time.sleep(1)
    
    # randomly indicate that we'd like a reply. if we want one, start a thread to wait for it
    # the timestamp is the message ID
    
    reply_wanted = random.randint(0,1)
    msg_id = str(time.time())
    if reply_wanted == 0:
        sendmsg(socket, 'foobar!', msg_id, None)
    else:
        sendmsg(socket, 'foobar!', msg_id, mycallback)
        
