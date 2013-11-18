import datetime
import time
import os
import msg_pb2
import control_pb2
import cifsupport
import threading
import hashlib

"""
Routines that support client pinging 
"""

class Ping:
    def __init__ (self):
        self._lock = threading.RLock()
    
    @classmethod    
    def makereply(cls, msg):
        p = control_pb2.ControlType()
        p.src = msg.dst
        p.dst = msg.src
        p.seq = msg.seq
        p.version = p.version
        p.type = control_pb2.ControlType.REPLY
        p.command = control_pb2.ControlType.PING
        p.status = control_pb2.ControlType.SUCCESS
        p.apikey = msg.apikey        
        p.pingRequest.ts = msg.pingRequest.ts
        p.pingRequest.pingseq = msg.pingRequest.pingseq
        
        return p
        
    @classmethod
    def makeseq(self, p):
        _md5 = hashlib.md5()
        _md5.update(p.SerializeToString())
        return _md5.digest()
    
    @classmethod
    def makerequest(cls, src, dst, apikey, pingseq):
        p = control_pb2.ControlType()
        p.src = src
        p.dst = dst
        p.version = p.version
        p.type = control_pb2.ControlType.COMMAND
        p.command = control_pb2.ControlType.PING
        p.status = control_pb2.ControlType.SUCCESS
        p.apikey = apikey        
        p.pingRequest.ts = time.time()
        p.pingRequest.pingseq = pingseq
        
        p.seq = Ping.makeseq(p)
        
        return p
    
    def __repr__(self):
        return "CIF.CtrlCommands.Ping()"

    
