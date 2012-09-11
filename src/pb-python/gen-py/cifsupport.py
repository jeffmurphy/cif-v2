import msg_pb2
import feed_pb2
import control_pb2

"""
Compare the received object's version to the version available
in our local installation. If the integer portion of the version does 
not match, throw an exception. The minor (fractional) portion of the
version is allowed to mismatch.

This will work for both Message and Feed type objects.
"""


def versionCheck(rcvdMsg):
    
    m = msg_pb2.MessageType()
    if isMessage(rcvdMsg):
        m = msg_pb2.MessageType()
    elif isFeed(rcvdMsg):
        m = feed_pb2.FeedType()
    elif isControl(rcvdMsg):
        m = control_pb2.ControlType()
    else:
        raise Exception("Unknown object type. Expected Message/Feed/Control got: " + str(type(m)))
    
    if int(m.version) != int(rcvdMsg.version):
        raise Exception("Version mismatch: Recvd=" + str(int(rcvdMsg.version)) + " != OurIDL=" + str(int(m.version)))

def isMessage(m):
    if str(m.__class__) == "<class 'msg_pb2.MessageType'>":
        return 1
    return 0

def isFeed(m):
    if str(m.__class__) == "<class 'feed_pb2.FeedType'>":
        return 1
    return 0

def isControl(m):
    if str(m.__class__) == "<class 'control_pb2.ControlType'>":
        return 1
    return 0