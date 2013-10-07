import datetime
import time
import os
import threading
import json
import msg_pb2
import control_pb2
import cifsupport
import hashlib

"""
For proof-of-concept code, this is ok, but for production needs to be reconsidered.
Lock contention will slow everything down. Probably in production there should be
per-thread stats and then someone querying stats would have to sum when reporting.
"""

class RouterStats(object):
    def __init__ (self):
        self._uptime = time.time()
        self._controls = {}
        self._controls_total = 0
        self._bad_total = 0
        self._bad_version_total = 0
        self._bad_version = {}
        self._relayed = {}
        self._relayed_total = 0
        self._lock = threading.RLock()
    
    @classmethod
    def makecontrolmsg(cls, src, dst, apikey):
        msg = control_pb2.ControlType()
        msg.version = msg.version # required
        msg.type = control_pb2.ControlType.COMMAND
        msg.command = control_pb2.ControlType.STATS
        msg.dst = dst
        msg.src = src
        msg.apikey = apikey
        _md5 = hashlib.md5()
        _md5.update(msg.SerializeToString())
        msg.seq = _md5.digest()
        
        return msg
    
    def asmessage(self):
        """
        Return the stats as a Control message
        """
        m = control_pb2.StatsResponse()
        m.statsType = control_pb2.ControlType.ROUTER
        m.stats = self.asjson()
        return m
    
    def asjson(self):
        return json.dumps({'uptime':          self.getuptime(),
                           'relayed':         self._relayed_total,
                           'controls':        self._controls_total,
                           'bad':             self._bad_total,
                           'badversion':      self._bad_version_total,
                           'loadavg':         os.getloadavg(),
                           'per_controls':    self._controls,
                           'per_bad_version': self._bad_version,
                           'per_relayed':     self._relayed
                           })
        
    def getuptime(self):
        return time.time() - self._uptime
    
    
    def setrelayed(self, qty=1, type=''):
        """ 
        Increment the relayed-message count. Optionally increment it by amount
        'qty' (defaults to 1). Optionally increment the message-specific relay count
        at the same time as the global relayed-message count.
        
        eg stats.relayed() # incremement global count by 1
           stats.relayed(10) # incrememnet global count by 10
           stats.relayed(10, 'IODEF_v1') # inc global by 10, and also inc IODEF_v1 by 10
        """
        if qty < 1:
            qty = 1
        
        with self._lock:
            if type != '':
                if type in self._relayed:
                    self._relayed[type] = self._relayed[type] + qty
                else:
                    self._relayed[type] = qty
            self._relayed_total = self._relayed_total + qty
    
    def getrelayed(self):
        return [self._relayed_total, self._relayed[:]]
    
    def delrelayed(self):
        with self._lock:
            self._relayed_total = 0
            self._relayed = {}

    relayed = property(getrelayed, setrelayed, delrelayed, "Count of number of messages relayed through this router.")

    def setcontrols(self, qty, type):
        """
        Same as relayed() by for control messages received by the router. 'type' is an
        integer for this routine and corresponds to CIF.Msg.ControlType.CommandType
        in cif-protocol's control.proto
        """
        if qty < 1:
            qty = 1
        
        with self._lock:
            if type in self._controls:
                self._controls[type] = self._controls[type] + qty
            else:
                self._controls[type] = qty
            self._controls_total = self._controls_total + qty
    
    def getcontrols(self):
        return [self._controls_total, self._controls[:]]
    
    def delcontrols(self):
        with self._lock:
            self._controls_total = 0
            self._controls = {}
    
    controls = property(getcontrols, setcontrols, delcontrols, "Count of number of control messages sent to this router.")
    
    def setbad(self, qty=1):
        if qty < 1:
            qty = 1
        with self._lock:
            self._bad_total = self._bad_total + qty
    
    def getbad(self):
        return self._bad_total
    
    def delbad(self):
        with self._lock:
            self._bad_total = 0
    
    bad = property(getbad, setbad, delbad, "Count of number of invalid control messages this router has seen.")
    
    def setbadversion(self, qty=1, version=0):
        if qty < 1:
            qty = 1
        
        with self._lock:
            if version > 0:
                if version in self._bad_version:
                    self._bad_version[version] = self._bad_version[version] + qty
                else:
                    self._bad_version[version]= qty
            self._bad_version_total = self._bad_version_total + 1
        
    def getbadversion(self):
        return [self._bad_version_total, self._bad_version]
        
    def delbadversion(self):
        with self._lock:
            self._bad_version_total = 0
            self._bad_version = {}
    
    badversion = property(getbadversion, setbadversion, delbadversion, "Count of number of control messages with bad version numbers seen by this router.")
    
    @property
    def getloadavg(self):
        return os.getloadavg()
    
    

        