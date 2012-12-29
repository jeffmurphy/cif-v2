import sys
import zmq
import time
import datetime
import threading
import getopt
import json
import pprint
import struct
from collections import deque

sys.path.append('/usr/local/lib/cif-protocol/pb-python/gen-py')
import msg_pb2
import feed_pb2
import RFC5070_IODEF_v1_pb2
import MAEC_v2_pb2
import control_pb2
import cifsupport

from CIF.Foundation import Foundation
from CIF.CtrlCommands.APIKeys import APIKeys

"""
Create an embedded client so that cif-router can talk to 
cif-db without using its router socket. The cif-router
can ask this miniclient to send commands to other connected
agents as well as receive replies.

"""

class MiniClient(object):
    def __init__ (self, apikey, myip, cifrouter, controlport, myid, debug):
        self._lock = threading.RLock()
        self.cf = Foundation({'apikey': apikey, 
		                 'myip': myip, 
		                 'cifrouter': cifrouter,
		                 'controlport': controlport,
		                 'routerid': "cif-router",
		                 'myid': myid})
        self.cf.setdebug(debug)
        self.debug = debug
        self.work_queue = deque()
        self.condition = threading.Condition()
        self.myid = myid
        self.myapikey = apikey

        self.pending_apikey_replies = {}
        self.pending_apikey_replies_lock = threading.RLock()
        
        self.apikey_cache = {}
        self.apikey_cache_lock = threading.RLock()
        
        if self.debug == 1:
            print "MiniClient: starting thread"
        self.t = threading.Thread(target=self.run, args=())
        self.t.daemon = True
        self.t.start()
        
    def run(self):
        if self.debug == 1:
            print "MiniClient running"
        if self.debug == 1:
            print "MiniClient: creating control socket."
        self.cf.ctrlsocket()
        if self.debug == 1:
            print "MiniClient: registering with router."
        self.cf.register()

        self.condition.acquire()

        while True:
            if self.debug == 1:
                print "MiniClient: waiting for work"
            self.condition.wait()
        
            if self.debug == 1:
                print "MiniClient: got work " + str(len(self.work_queue))
    
            try:
                self._lock.acquire()
                work = self.work_queue.pop()
                self._lock.release()
                print "MiniClient: command=" + work['command']
                if work['command'] == "lookup_apikey":
                    self.do_lookup_apikey(work)

            except IndexError:
                break
                
        self.condition.release()

    def pending(self):
        self.pending_apikey_replies_lock.acquire()
        n = len(self.pending_apikey_replies)
        self.pending_apikey_replies_lock.release()
        if n > 0:
            return True
        return False
    
    def pending_apikey_lookups(self):
        """
        Returns a list of all apikeys we've looked up for the router,
        but not the cached keys. 
        """
        self.pending_apikey_replies_lock.acquire()
        ks = self.pending_apikey_replies.keys()
        self.pending_apikey_replies_lock.release()
        return ks
    
    """
    Given an apikey, returns the apikey record that the db replied with
    and removes the reply from our internal list. Returns None if we 
    know nothing about the apikey
    """
    
    def get_pending_apikey(self, apikey):
        self.pending_apikey_replies_lock.acquire()
        r = None
        if apikey in self.pending_apikey_replies:
            r = self.pending_apikey_replies[apikey]
            del self.pending_apikey_replies[apikey]
        self.pending_apikey_replies_lock.release()
        return r
    
    def remove_pending_apikey(self, apikey):
        self.pending_apikey_replies_lock.acquire()
        if apikey in self.pending_apikey_replies:
            del self.pending_apikey_replies[apikey]
        self.pending_apikey_replies_lock.release()
        
    def do_lookup_apikey(self, work):
        print "do_lookup_apikey: " + work['apikey']
        
        apikey = work['apikey']
        
        self.apikey_cache_lock.acquire()
        
        if apikey in self.apikey_cache:
            self.pending_apikey_replies_lock.acquire()
            self.pending_apikey_replies[apikey] = self.apikey_cache[apikey]
            self.pending_apikey_replies_lock.release()
        else:
            self.fetch_apikey(apikey)
            
        self.apikey_cache_lock.release()
        
    def fetch_apikey(self, apikey):
        req = APIKeys.makerequest(self.myid, "cif-db", apikey, control_pb2.ControlType.APIKEY_GET)
        req.apikey = self.myapikey
        req.seq = APIKeys.makeseq(req)
        print "fetch_apikey: sending to cif-db: ", req
    
        self.cf.sendmsg(req, self.fetch_apikey_finished)
        
    def fetch_apikey_finished(self, msg):
        print "fetch_apikey_finished: ", msg
        print " "
        
        if msg.status == control_pb2.ControlType.SUCCESS:
            self.pending_apikey_replies_lock.acquire()
            self.apikey_cache_lock.acquire()
            for reply in msg.apiKeyResponseList:
                self.pending_apikey_replies[reply.apikey] = reply
                self.apikey_cache[reply.apikey] = reply
            self.pending_apikey_replies_lock.release()
            self.apikey_cache_lock.release()

    def lookup_apikey(self, apikey):
        if apikey != None:
            print "MiniClient.lookup_apikey(" + apikey + "): acquiring lock"
            self._lock.acquire()
            self.work_queue.append({'command': 'lookup_apikey', 'apikey': apikey })
            print "MiniClient.lookup_apikey(" + apikey + "): acquiring condition"

            self.condition.acquire()
            self.condition.notify()
            self.condition.release()
            self._lock.release()
