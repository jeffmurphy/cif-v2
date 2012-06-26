#!/usr/bin/python

import sys

# adjust to match your $PREFIX if you specified one
# default PREFIX = /usr/local
sys.path.append('./gen-py')

import msg_pb2
import feed_pb2
import RFC5070_IODEF_v1_pb2
import MAEC_v2_pb2
import cifsupport


print "Constructing a CIF.msg object"

msg = msg_pb2.MessageType()
msg.version = msg.version # delicious hackery
msg.apikey = '12345'
msg.guid = '123456-abcdef'

print "Object's IDL version: " , msg.version


# example query object

msg.type = msg_pb2.MessageType.QUERY

query = msg.queryRequest.add() 
query.limit = 100

subquery = msg.QueryStruct()
subquery.query = 'foobar.com'
query.query.extend([subquery])

subquery.query = '1.2.3.0/24'
query.query.extend([subquery])

another_query = msg_pb2.MessageType.QueryRequest()
another_query.limit = 10

subquery.query = '2001:468:902:400:20c:29ff:fe53:beef/64'
another_query.query.extend([subquery])

msg.queryRequest.extend([another_query])

# or a submission object. note that since 
# we are changing msg.type to SUBMISSION, even tho
# the above query fields will persist, the receiver of 
# the message will/should ignore them because the type 
# is not 'QUERY'

# comment out to test deserialization of QUERY messages
msg.type = msg_pb2.MessageType.SUBMISSION

# construct the opaque inner message
maec = MAEC_v2_pb2.maecPlaceholder()
maec.msg = "test maec message"

sr = msg.submissionRequest.add()
sr.baseObjectType = 'MAEC_v2'
sr.data = maec.SerializeToString()

# construct another opaque inner message

iodef = RFC5070_IODEF_v1_pb2.IODEF_DocumentType()
iodef.lang = 'en'
iodef.version = 'test'

sr2 = msg.submissionRequest.add()
sr2.baseObjectType = 'RFC5070_IODEF_v1'
sr2.data = iodef.SerializeToString()

print "Message contains:\n", msg

# uncomment to simulate a version mis-match
#msg.version = 1


# At this point, we'd serialize it and send it off somewhere.
#     msg.SerializeToString()   -> send somewhere
# 
# The receiver would read it in and deserialize it back into 
# and object. 
#     rawmsg <- read from somewhere
#     msg.ParseFromString(rawmsg)
#
# and then do a version check to ensure the received object
# matches the IDL installed locally for the receiver

print "Serializing the message"

serialized = msg.SerializeToString()

print "\nSerialized message size: ", len(serialized)
print "'Sending' it to a 'remote' receiver"

# we are now the receiver

msg2 = msg_pb2.MessageType()

print "Deserializing"
msg2.ParseFromString(serialized)

print "Version checking against our IDL"
try:
    cifsupport.versionCheck(msg2)
except Exception as e:
    print "Received message was bad: ", e
else:
    print "\nDeserialized message contains:\n", msg2

    if msg2.type == msg_pb2.MessageType.QUERY:
        print "Received a QUERY"
        print "\tMessage contains: " + str(len(msg2.queryRequest)) + " queries"
        for i in range(len(msg2.queryRequest)):
            print "\t\t #" + str(i) + " is: " + msg2.queryRequest[i].query
            
    elif msg2.type == msg_pb2.MessageType.SUBMISSION:
        print "Received a SUBMISSION"
        print "\tSubmission contains: " + str(len(msg2.submissionRequest)) + " submission objects"
        for i in range(len(msg2.submissionRequest)):
            print "\t\t #" + str(i) + " is type: " + msg2.submissionRequest[i].baseObjectType
            # now deserialize the .data field into an MAEC, IODEF, etc, object based on the baseObjectType

print "Done."
