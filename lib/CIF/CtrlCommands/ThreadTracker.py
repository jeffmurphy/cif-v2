import datetime
import time
import os
import msg_pb2
import control_pb2
import cifsupport
import threading
import hashlib
import struct
import sys


"""
Routines that support thread tracking
as well as the PB THREADS_* command processing

     ID, User, Host, Command, Time, State, Info
"""
    

class ThreadTracker:
    def __init__ (self, _debug):
        self.track = {}
        self.debug = _debug
        self.lock = threading.RLock()
        
    def add(self, id=None, user=None, host=None, command=None, state=None, info=None):
        self.lock.acquire()
        self.track[id] = { 'user': user, 'host': host, 'command': command, 'state': state, 'info': info, 'time': time.time() }
        self.lock.release()
    
    def update(self, id=None, state=None, info=None):
        self.lock.acquire()
        if id in self.track:
            self.track[id]['state'] = state
            self.track[id]['info'] = info
        self.lock.release()
        
    def remove(self, _id):
        self.lock.acquire()
        del self.track[_id]
        self.lock.release()
    
    def list(self):
        self.lock.acquire()
        rv = []
        for _id in self.track:
            rv.append(_id)
        self.lock.release()
        return rv
    
    def get(self, _id):
        self.lock.acquire()
        rv = None
        if _id in self.track:
            rv = self.track[_id]
        self.lock.release()
        return rv
    
    def user(self, _id):
        self.lock.acquire()
        rv = ""
        if 'user' in self.track[_id] and self.track[_id]['user'] != None:
            rv = self.track[_id]['user']
        self.lock.release()
        return rv
    
    def runtime(self, _id):
        self.lock.acquire()
        rv = 0
        if 'time' in self.track[_id] and self.track[_id]['time'] != None:
            rv = int(time.time() - self.track[_id]['time'])
        self.lock.release()
        return rv    
    
    def host(self, _id):
        self.lock.acquire()
        rv = ""
        if 'host' in self.track[_id] and self.track[_id]['host'] != None:
            rv = self.track[_id]['host']
        self.lock.release()
        return rv
    
    def command(self, _id):
        self.lock.acquire()
        rv = ""
        if 'command' in self.track[_id] and self.track[_id]['command'] != None:
            rv = self.track[_id]['command']
        self.lock.release()
        return rv
    
    def state(self, _id):
        self.lock.acquire()
        rv = ""
        if 'state' in self.track[_id] and self.track[_id]['state'] != None:
            rv = self.track[_id]['state']
        self.lock.release()
        return rv
    
    def info(self, _id):
        self.lock.acquire()
        rv = ""
        if 'info' in self.track[_id] and self.track[_id]['info'] != None:
            rv = self.track[_id]['info']
        self.lock.release()
        return rv
        
    @classmethod
    def makecontrolmsg(cls, src, dst, apikey):
        msg = control_pb2.ControlType()
        msg.version = msg.version # required
        msg.type = control_pb2.ControlType.COMMAND
        msg.command = control_pb2.ControlType.THREADS_LIST
        msg.dst = dst
        msg.src = src
        msg.apikey = apikey
        _md5 = hashlib.md5()
        _md5.update(msg.SerializeToString())
        msg.seq = _md5.digest()
        
        return msg
    
    def asmessage(self, ltr):
        """
        Return the threads list as a Control message
        message ListThreadsResponse {
    repeated string id = 1;
    repeated string user = 2;
    repeated string host = 3;
    repeated string command = 4;
    repeated int32 runtime = 5; 
    repeated string state = 6; 
    repeated string info = 7;
        }

        """
        #m = control_pb2.ListThreadsResponse()
        m = ltr
        for k in self.track.keys():
            m.id.extend([str(k)])
            m.user.extend([self.user(k)])
            m.host.extend([self.host(k)])
            m.command.extend([self.command(k)])
            m.state.extend([self.state(k)])
            m.info.extend([self.info(k)])

            m.runtime.extend([int(time.time() - self.track[k]['time'])])
        return m
    
    def __str__(self):
        l = "| ID | User | Host | Time | Command | State | Info |\n"
        for k in self.track.keys():
            
            l = l + "| %(id)s | %(user)s | %(host)s | %(time)d | %(command)s | %(state)s | %(info)s |\n" % \
                { 'id' : k, 
                  'user' : self.user(k), 
                  'host' : self.host(k), 
                  'time' : self.runtime(k),
                  'command' : self.command(k), 
                  'state' : self.state(k), 
                  'info' : self.info(k),
                  }
        return l
    
    def __repr__(self):
        return "CIF.CtrlCommands.ThreadTracker()"

    
