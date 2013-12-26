import sys, time, zmq
import datetime
import threading

sys.path.append('/opt/cif/lib/cif-protocol/pb-python/gen-py')
import msg_pb2
import control_pb2
import cifsupport

class PubSubMgr(object):
    
    def __init__(self, pubport, thread_tracker, clients, stats):
        self.context = zmq.Context()

        self.publishers = {}
        self.clients = clients
        self.stats_tracker = stats
        
        self.L("Create XSUB socket")
        self.xsub = self.context.socket(zmq.SUB)
        self.xsub.setsockopt(zmq.SUBSCRIBE, '')
        
        self.L("Create XPUB socket on " + str(pubport))
        self.xpub = self.context.socket(zmq.PUB)
        self.xpub.bind("tcp://*:" + str(pubport))
        
        self.L("Spawning PubSub Manager thread")
        self.thread = threading.Thread(target=self.myrelay, args=())
        self.thread.start()
        while not self.thread.isAlive():
            self.L("waiting for pubsub relay thread to become alive")
            time.sleep(1)
        self.thread_tracker = thread_tracker
        self.thread_tracker.add(id=self.thread.ident, user='Router', host='localhost', state='Running', info="PUBSUB Mgr")


        
    def L(self, msg):
        caller =  ".".join([str(__name__), sys._getframe(1).f_code.co_name])
        print caller + ": " + msg

            
    def dosubscribe(self, client, m):
        client = m.src
        if client in self.publishers:
            print "dosubscribe: we've seen this client before. re-using old connection."
            return control_pb2.ControlType.SUCCESS
        elif self.clients.isregistered(client) == True:
            if self.clients.apikey(client) == m.apikey:
                print "dosubscribe: New publisher to connect to " + client
                self.publishers[client] = time.time()
                addr = m.iPublishRequest.ipaddress
                port = m.iPublishRequest.port
                print "dosubscribe: connect our xsub -> xpub on " + addr + ":" + str(port)
                self.xsub.connect("tcp://" + addr + ":" + str(port))
                return control_pb2.ControlType.SUCCESS
            print "dosubscribe: iPublish from a registered client with a bad apikey: " + client + " " + m.apikey
        print "dosubscribe: iPublish from a client who isnt registered: \"" + client + "\""
        return control_pb2.ControlType.FAILED

    def myrelay(self):
        relaycount = 0
        
        self.L("PubSubMgr thread started")
        
        while True:
            try:
                relaycount = relaycount + 1
                m = self.xsub.recv()
                
                _m = msg_pb2.MessageType()
                _m.ParseFromString(m)
                
                if _m.type == msg_pb2.MessageType.QUERY:
                    self.stats_tracker.setrelayed(1, 'QUERY')
                elif _m.type == msg_pb2.MessageType.REPLY:
                    self.stats_tracker.setrelayed(1, 'REPLY')
                elif _m.type == msg_pb2.MessageType.SUBMISSION:
                    self.stats_tracker.setrelayed(1, 'SUBMISSION')
                    
                    for bmt in _m.submissionRequest:
                        self.stats_tracker.setrelayed(1, bmt.baseObjectType)
                        
        
                print "[myrelay] total:%d got:%d bytes" % (relaycount, len(m)) 
                #print "[myrelay] got msg on our xsub socket: " , m
                self.xpub.send(m)
    
            except Exception as e:
                print "[myrelay] invalid message received: ", e