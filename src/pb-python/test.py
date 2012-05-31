#!/usr/bin/python

# adjust to match your $PREFIX if you specified one
# default PREFIX = /usr/local
sys.path.append('/usr/local/lib/cif-protocol/pb-python/gen-py')
import msg_pb2
import feed_pb2
import RFC5070_IODEF_v1_pb2

msg = msg_pb2.MessageType()
msg.MsgType = msg_pb2.MessageType.MsgType.QUERY;
