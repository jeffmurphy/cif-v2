def versionCheck(rcvdMsg):
    m = msg_pb2.MessageType()
#m.version = m.version
    if type(rcvdMsg) != type(m):
        raise Exception("Object type mismatch: Recvd=" + str(type(rcvdMsg)) + " != Expected=" + str(type(m)))
    else:
        if int(m.version) != int(rcvdMsg.version):
            raise Exception("Version mismatch: Recvd=" + str(int(rcvdMsg.version)) + " != OurIDL=" + str(int(m.version)))
