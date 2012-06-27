import msg_pb2
import feed_pb2

"""
Compare the received object's version to the version available
in our local installation. If the integer portion of the version does 
not match, throw an exception. The minor (fractional) portion of the
version is allowed to mismatch.

This will work for both Message and Feed type objects.
"""


def versionCheck(rcvdMsg):
    m = msg_pb2.MessageType()
    if rcvdMsg.__class__ == "<class 'feed_pb2.FeedType'>":
        m = feed_pb2.FeedType()
        
    if type(rcvdMsg) != type(m):
        raise Exception("Object type mismatch: Recvd=" + str(type(rcvdMsg)) + " != Expected=" + str(type(m)))
    else:
        if int(m.version) != int(rcvdMsg.version):
            raise Exception("Version mismatch: Recvd=" + str(int(rcvdMsg.version)) + " != OurIDL=" + str(int(m.version)))
