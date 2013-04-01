import datetime
import time
import os
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

apikey, myip, cifrouter, controlport, publisherport, myid, routerid

"""


class Foundation(object):
    def __init__ (self, p):
        self.p = p
        self.apikey = self.param('apikey')
        self.myip = self.param('myip')
        
        self.cifrouter = self.param('cifrouter')
        x = self.cifrouter.split(':')
        self.router_hname = x[0]
        self.routerport = x[1]
        
        self.controlport = str(self.param('controlport'))
        self.publisherport = str(self.param('publisherport'))
        
        self.routerpubport = None  # set by 'register'
        self.myid = self.param('myid')
        self.routerid = self.param('routerid')
        
        self._lock = threading.RLock()
        self.debug = 0
        self.context = zmq.Context()
        self.callback_registry = {}
        self.callback_registry_lock = threading.Lock()

        self.subscriber = None
        self.publisher = None
        self.req = None
        self.rep = None
                
        # we want the register, unregister and ipublish commands to be
        # synchronous. the following helps achieve that
        
        self.register_synchronizer = None
        self.register_reply = None
        
        self.unregister_synchronizer = None
        self.unregister_reply = None

        self.ipublish_synchonizer = None
        self.ipublish_reply = None
        
        self.defaultcallback = None
        

        
    def param(self, k):
        if k in self.p:
            return self.p[k]
        return None
    
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
    
    def setdefaultcallback(self, cb):
        self.defaultcallback = cb
        
    def ctrlsocket(self):
        # Socket to talk to cif-router
        self.req = self.context.socket(zmq.DEALER);
        myname = self.myip + ":" + self.controlport + "|" + self.myid
        self.req.setsockopt(zmq.IDENTITY, myname)
        self.req.connect('tcp://' + self.cifrouter)
        
        # the event loop thread. a daemon so that if our main thread exits,
        # this thread doesn't keep the process alive
        
        self.evthread = threading.Thread(target=self.eventloop, name="Foundation Ctrlsocket Eventloop daemon", args=())
        self.evthread.daemon = True
        self.evthread.start()
        
        return self.req
    
    def subscribersocket(self):
        remote_publisher = 'tcp://' + self.router_hname + ":" + str(self.routerpubport)
        if self.debug > 1:
            print "Creating subscriber socket and connecting to " + remote_publisher
        self.subscriber = self.context.socket(zmq.SUB)
        self.subscriber.connect(remote_publisher)
        self.subscriber.setsockopt(zmq.SUBSCRIBE, '')
        return self.subscriber
    
    def publishsocket(self):
        # Socket to publish from
        self.publisher = self.context.socket(zmq.PUB)
        self.publisher.bind('tcp://*:' + self.publisherport)
        return self.publisher

    def registerFinished(self, decoded_msg):
        self.register_reply = decoded_msg
        self.register_synchronizer.release() # should cause register to proceed


    def unregisterFinished(self, decoded_msg):
        self.unregister_reply = decoded_msg
        self.unregister_synchronizer.release() # should cause unregister to proceed


    def unregister(self):
        if self.debug > 1:
            print "Send UNREGISTER to cif-router (" + self.cifrouter + ")"
        
        msg = control_pb2.ControlType()
        msg.version = msg.version # required
        msg.apikey = self.apikey
        msg.type = control_pb2.ControlType.COMMAND
        msg.command = control_pb2.ControlType.UNREGISTER
        msg.dst = 'cif-router'
        msg.src = self.myid

        msg.seq = self.md5(msg.SerializeToString())
        
        self.unregister_synchronizer = threading.Semaphore(0)
        self.sendmsg(msg, self.unregisterFinished)
        self.unregister_synchronizer.acquire() # synchronizer is initialized to 0 so this will block

        if self.debug > 2:
            print "\tGot reply."
        if self.unregister_reply.status == control_pb2.ControlType.SUCCESS:
            if self.debug > 2:
                print "\t\tunregistered successfully"
        else:
            if self.debug > 2:
                print "\t\tnot sure? " + str(self.unregister_reply.status)
    
    
    def register(self):
        self.routerport = 0
        self.routerpubport = 0
        
        if self.debug > 1:
            print "Send REGISTER to cif-router (" + self.cifrouter + ")"
        
        msg = control_pb2.ControlType()
        msg.version = msg.version # required
        msg.apikey = self.apikey
        msg.type = control_pb2.ControlType.COMMAND
        msg.command = control_pb2.ControlType.REGISTER
        msg.dst = self.routerid
        msg.src = self.myid
        msg.seq = self.md5(msg.SerializeToString())

        if self.debug > 2:
            print "\tSending REGISTER: ", msg
        
        self.register_synchronizer = threading.Semaphore(0)
        self.sendmsg(msg, self.registerFinished)
        self.register_synchronizer.acquire() # synchronizer is initialized to 0 so this will block
        
    
        if self.debug > 2:
            print "\tGot reply: ", self.register_reply
            

        if self.register_reply.status == control_pb2.ControlType.SUCCESS:
            self.routerport = self.register_reply.registerResponse.REQport
            self.routerpubport = self.register_reply.registerResponse.PUBport
            if self.debug > 2:
                print "\t\tregistered successfully"
            return (self.routerport, self.routerpubport)
        elif self.register_reply.status == control_pb2.ControlType.DUPLICATE:
            self.routerport = self.register_reply.registerResponse.REQport
            self.routerpubport = self.register_reply.registerResponse.PUBport
            if self.debug > 2:
                print "\t\talready registered?"
            return (self.routerport, self.routerpubport)
        else:
            if self.debug > 2:
                print "\t\tregister failed."
    
        return (0,0)
        
    def ipublishFinished(self, decoded_msg):
        self.ipublish_reply = decoded_msg
        self.ipublish_synchronizer.release() # should cause register to proceed
    
    def ipublish(self):
        msg = control_pb2.ControlType()
        msg.version = msg.version # required
        msg.apikey = self.apikey
        msg.type = control_pb2.ControlType.COMMAND
        msg.command = control_pb2.ControlType.IPUBLISH
        msg.dst = self.routerid
        msg.src = self.myid
        msg.iPublishRequest.port = int(self.publisherport)
        msg.iPublishRequest.ipaddress = self.myip
        msg.seq = self.md5(msg.SerializeToString())

        self.ipublish_synchronizer = threading.Semaphore(0)
        self.sendmsg(msg, self.ipublishFinished)
        self.ipublish_synchronizer.acquire() # synchronizer is initialized to 0 so this will block
        if self.ipublish_reply.status == control_pb2.ControlType.SUCCESS:
            # TODO cif-router should connect to our PUB socket (zmq won't tell us)
            # TODO zmq_ctx feature may let us be sure the router connected. bother with it?
            i = 1 # NOP for now
        elif msg.status != control_pb2.ControlType.SUCCESS:
            raise Exception("Router has a problem with us? " + msg.status)
        
    def ctrlc(self):
        ac = threading.activeCount()
        if self.debug > 0:
            print "Shutting down Foundation."
            for t in threading.enumerate():
                print "\tactive thread: " + t.name
        #print "Active threads: " + str(ac)
        self.unregister()
        #if self.evthread.isAlive() == True:
        #    print "Event thread is alive."
        sys.exit(0)
    
    def ctrl(self):
        if self.debug > 1:
            print "Creating control socket on :" + self.controlport
        # Socket to accept control requests on
        self.rep = self.context.socket(zmq.REP);
        self.rep.bind('tcp://*:' + self.controlport);
        
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
                msg = r[1]
                decoded_msg = control_pb2.ControlType()
                decoded_msg.ParseFromString(msg)
                control_command = 0
                if decoded_msg.type == control_pb2.ControlType.COMMAND:
                    control_command = decoded_msg.command
                
                print ti + "] eventloop: msg: ", decoded_msg
                try:
                    cifsupport.versionCheck(decoded_msg)
                    
                    msgid = decoded_msg.seq
                    
                    self.callback_registry_lock.acquire()
        
                    if msgid in self.callback_registry:
                        if self.debug > 2:
                            print ti + "] eventloop: Callback specified. Calling it.", self.callback_registry
                        
                        # create a separate thread so the callback doesn't influence the event loop
                        # these threads should be short lived
                        
                        cbthread = threading.Thread(target = self.callback_registry[msgid], name="callback:" + str(control_command), args=(decoded_msg,))
                        cbthread.start()
                        del self.callback_registry[msgid]
                    else:
                        if self.defaultcallback != None:
                            dcbthread = threading.Thread(target = self.defaultcallback, name="defaultcallback:" + str(control_command), args=(decoded_msg,))
                            dcbthread.start()
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
            self.req.send_multipart(['', msg.SerializeToString()])
            
            