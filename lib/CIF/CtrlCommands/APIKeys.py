import datetime
import time
import os
import msg_pb2
import control_pb2
import cifsupport
import threading
import hashlib

"""
Routines that support talking to the DB about apikeys 
"""

class APIKeys:
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
        p.command = msg.command
        p.status = control_pb2.ControlType.SUCCESS
        p.apikey = msg.apikey        

        return p
        
    @classmethod
    def makeseq(self, p):
        _md5 = hashlib.md5()
        _md5.update(p.SerializeToString())
        return _md5.digest()
    
    """
        APIKEY_ADD     = 11;
        APIKEY_UPDATE  = 12;
        APIKEY_DEL     = 13;
        APIKEY_REVOKE  = 14;
        APIKEY_LIST    = 15;
        APIKEY_GET     = 16;
    """
    
    @classmethod
    def makerequest(cls, src, dst, apikey, cmd):
        p = control_pb2.ControlType()
        p.src = src
        p.dst = dst
        p.version = p.version
        p.type = control_pb2.ControlType.COMMAND
        p.command = cmd
        p.status = control_pb2.ControlType.SUCCESS
        p.apiKeyRequest.apikey = apikey

        return p
    
    def __repr__(self):
        return "CIF.CtrlCommands.Ping()"

    
