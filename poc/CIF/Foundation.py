import datetime
import time
import os
import msg_pb2
import control_pb2
import cifsupport
import threading
import zmq
import sys
import hashlib

sys.path.append('/usr/local/lib/cif-protocol/pb-python/gen-py')
import msg_pb2
import feed_pb2
import RFC5070_IODEF_v1_pb2
import MAEC_v2_pb2
import control_pb2
import cifsupport

"""
Foundation provides routines for configuring ZMQ from a client
perspective: registering, unregistering, etc.

It also provides the primary event loop for handling ZMQ replies.
"""


class Foundation(object):
    def __init__ (self):
        self._lock = threading.RLock()
        self.debug = 0
        self.context = zmq.Context()
        self.callback_registry = {}
        self.callback_registry_lock = threading.Lock()

        self.subscriber = None
        self.publisher = None
        self.req = None
                
        # we want the register, unregister and ipublish commands to be
        # synchronous. the following helps achieve that
        
        self.register_synchronizer = None
        self.register_reply = None
        
        self.unregister_synchronizer = None
        self.unregister_reply = None

        self.ipublish_synchonizer = None
        self.ipublish_reply = None
        
        # the event loop thread. a daemon so that if our main thread exits,
        # this thread doesn't keep the process alive
        
        self.evthread = threading.Thread(target=self.eventloop, args=())
        self.evthread.daemon = True
        self.evthread.start()
        

    def md5(self, s):
        _md5 = hashlib.md5()
        _md5.update(s)
        return _md5.digest()
    
    def setdebug(self, _d):
        pd = self.debug
        self.debug = _d
        return pd
    
    def getdebug(self):
        return self.debug
    

    def ctrlsocket(self, myip, controlport, myid, cifrouter):
        # Socket to talk to cif-router
        self.req = self.context.socket(zmq.DEALER);
        myname = myip + ":" + controlport + "|" + myid
        self.req.setsockopt(zmq.IDENTITY, myname)
        self.req.connect('tcp://' + cifrouter)
        return self.req
    
    def subscribersocket(self, publisher):
        # Socket to publish from
        if self.debug > 1:
            print "Creating subscriber socket and connecting to " + publisher
        self.subscriber = self.context.socket(zmq.SUB)
        self.subscriber.connect('tcp://' + publisher)
        self.subscriber.setsockopt(zmq.SUBSCRIBE, '')
        return self.subscriber
    
    def publishsocket(self, publisherport):
        # Socket to publish from
        self.publisher = self.context.socket(zmq.PUB)
        self.publisher.bind('tcp://*:' + publisherport)
        self.publisherport = publisherport
        return self.publisher

    def registerFinished(self, decoded_msg):
        self.register_reply = decoded_msg
        self.register_synchronizer.release() # should cause register to proceed


    def unregisterFinished(self, decoded_msg):
        self.unregister_reply = decoded_msg
        self.unregister_synchronizer.release() # should cause unregister to proceed


    def unregister(self, apikey, cifrouter, myid):
        if self.debug > 1:
            print "Send UNREGISTER to cif-router (" + cifrouter + ")"
        
        msg = control_pb2.ControlType()
        msg.version = msg.version # required
        msg.apikey = apikey
        msg.type = control_pb2.ControlType.COMMAND
        msg.command = control_pb2.ControlType.UNREGISTER
        msg.dst = 'cif-router'
        msg.src = myid

        msg.seq = self.md5(msg.SerializeToString())
        
        self.sendmsg(msg, self.unregisterFinished)
        self.unregister_synchronizer = threading.Semaphore(0)
        self.unregister_synchronizer.acquire() # synchronizer is initialized to 0 so this will block

        if self.debug > 2:
            print "\tGot reply."
        if self.unregister_reply.status == control_pb2.ControlType.SUCCESS:
            if self.debug > 2:
                print "\t\tunregistered successfully"
        else:
            if self.debug > 2:
                print "\t\tnot sure? " + self.unregister_reply.status
    
    
    def register(self, apikey, myip, myid, cifrouter):
        routerport = 0
        routerpubport = 0
        
        if self.debug > 1:
            print "Send REGISTER to cif-router (" + cifrouter + ")"
        
        msg = control_pb2.ControlType()
        msg.version = msg.version # required
        msg.apikey = apikey
        msg.type = control_pb2.ControlType.COMMAND
        msg.command = control_pb2.ControlType.REGISTER
        msg.dst = 'cif-router'
        msg.src = myid
        msg.seq = self.md5(msg.SerializeToString())

        if self.debug > 2:
            print "\tSending REGISTER: ", msg
        
        self.sendmsg(msg, self.registerFinished)
        self.register_synchronizer = threading.Semaphore(0)
        self.register_synchronizer.acquire() # synchronizer is initialized to 0 so this will block
        
    
        if self.debug > 2:
            print "\tGot reply: ", self.register_reply
            
        routerport = self.register_reply.registerResponse.REQport
        routerpubport = self.register_reply.registerResponse.PUBport
        if self.register_reply.status == control_pb2.ControlType.SUCCESS:
            if self.debug > 2:
                print "\t\tregistered successfully"
            return (routerport, routerpubport)
        elif self.register_reply.status == control_pb2.ControlType.DUPLICATE:
            if self.debug > 2:
                print "\t\talready registered?"
            return (routerport, routerpubport)
        else:
            if self.debug > 2:
                print "\t\tregister failed."
    
        return (0,0)
        
    def ipublishFinished(self, decoded_msg):
        self.ipublish_reply = decoded_msg
        self.ipublish_synchronizer.release() # should cause register to proceed
    
    def ipublish(self, apikey, myip, myid, cifrouter):
        msg = control_pb2.ControlType()
        msg.version = msg.version # required
        msg.apikey = apikey
        msg.type = control_pb2.ControlType.COMMAND
        msg.command = control_pb2.ControlType.IPUBLISH
        msg.dst = 'cif-router'
        msg.src = myid
        msg.iPublishRequest.port = int(self.publisherport)
        msg.iPublishRequest.ipaddress = myip
        msg.seq = self.md5(msg.SerializeToString())
        self.sendmsg(msg, self.ipublishFinished)
        self.ipublish_synchronizer = threading.Semaphore(0)
        self.ipublish_synchronizer.acquire() # synchronizer is initialized to 0 so this will block
        if self.ipublish_reply.status == control_pb2.ControlType.SUCCESS:
            # TODO cif-router should connect to our PUB socket (zmq won't tell us)
            # TODO zmq_ctx feature may let us be sure the router connected. bother with it?
            i = 1 # NOP for now
        elif msg.status != control_pb2.ControlType.SUCCESS:
            raise Exception("Router has a problem with us? " + msg.status)
        
    def ctrlc(self, apikey, cifrouter, myid):
        print "Shutting down."
        self.unregister(apikey, cifrouter, myid)
        sys.exit(0)
    
    def ctrl(self, rep, controlport):
        if self.debug > 1:
            print "Creating control socket on :" + controlport
        # Socket to accept control requests on
        rep = self.context.socket(zmq.REP);
        rep.bind('tcp://*:' + controlport);
        
    def eventloop(self):
        """
        The eventloop runs in its own thread. It listens for inbound messages
        on the control socket (a DEALER socket). These messages are replies
        to outbound requests (control messages). When a reply is received,
        a thread is created and a user specified callback is called in that 
        thread.
        """
        while True:
            ti = str(threading.currentThread().ident)
            if self.debug > 2:
                print ti + "] eventloop: Waiting for a reply"
            r = self.req.recv_multipart()
            if self.debug > 2:
                print ti + "] eventloop: Got reply: "#, r
            
            if len(r) > 0:
                msg = r[0]
                decoded_msg = control_pb2.ControlType()
                decoded_msg.ParseFromString(msg)
                
                try:
                    cifsupport.versionCheck(decoded_msg)
                    
                    msgid = decoded_msg.seq
                    
                    self.callback_registry_lock.acquire()
        
                    if msgid in self.callback_registry:
                        if self.debug > 2:
                            print ti + "] eventloop: Callback specified. Calling it."
                        # create a separate thread so the callback doesn't influence the event loop
                        cbthread = threading.Thread(target = self.callback_registry[msgid], args=(decoded_msg,))
                        cbthread.start()
                        del self.callback_registry[msgid]
                    else:
                        if self.debug > 2:
                            print ti + "] eventloop: Reply is bad (unexpected, no callback available). Discarding."
        
                    self.callback_registry_lock.release()
                except Exception as e:
                    print "ERROR: eventloop: Received message was bad: ", e


    def sendmsg(self, msg, callback):
            
        """ 
        Send a unicast message on a socket. Messages are always sent asynchronously.
        If a callback is specified, it will be called when a reply is received.
        """
    
        if self.req != None and msg != None:
            if callback != None:
                self.callback_registry_lock.acquire()
                self.callback_registry[msg.seq] = callback
                self.callback_registry_lock.release()
            self.req.send_multipart([msg.SerializeToString()])
            
            