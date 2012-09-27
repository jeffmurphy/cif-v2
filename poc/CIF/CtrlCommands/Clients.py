import datetime
import time
import os
import msg_pb2
import control_pb2
import cifsupport
import threading
import hashlib

"""
Routines that support client tracking (used by cif-router)
as well as the PB ListClients command processing
"""

class Clients:
    def __init__ (self):
        self._clients = {} #  clientname => connecttimestamp
        self._lock = threading.RLock()
        
    def register(self, client_name):
        """
        zmq doesnt have a disconnect, so if we xsub.connect() multiple times
        to the same client, we'll start recving duplicates of that clients
        messages. to avoid this, we track who we've connected to and if we
        see the same client more than once, we dont call connect() again.
        """
        with self._lock:
            self._clients[client_name] = time.time()
    
    def unregister(self, client_name):
        return
    
    def isregistered(self, client_name):
        if client_name in self._clients:
            return True
        return False
    
    @classmethod
    def makecontrolmsg(cls, src, dst):
        msg = control_pb2.ControlType()
        msg.version = msg.version # required
        msg.type = control_pb2.ControlType.COMMAND
        msg.command = control_pb2.ControlType.LISTCLIENTS
        msg.dst = dst
        msg.src = src
        _md5 = hashlib.md5()
        _md5.update(msg.SerializeToString())
        msg.seq = _md5.digest()
        
        return msg
    
    def asmessage(self):
        """
        Return the clients list as a Control message
        """
        m = control_pb2.ListClientsResponse()
        for k in self._clients.keys():
            m.client.extend([k])
            m.connectTimestamp.extend([int(self._clients[k])])
        return m
    
    def __str__(self):
        l = ''
        for k in self._clients.keys():
            l = l + "%{client}s %{time}d\n" % { 'client' : k, 'time' : self._clients[k] }
        return l
    
    def __repr__(self):
        return "CIF.CtrlCommands.Clients()"

    