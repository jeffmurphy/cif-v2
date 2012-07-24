#!/usr/bin/perl -w
use strict;
use lib './lib';
use CIF::Msg;
use RFC5070_IODEF_v1_pb2;
use MAEC_v2_pb2;
use Data::Dumper;

print "CIF::Msg demo. IDL version: ". getOurVersion() . "\n";

# construct a simple inner message, we'll use MAEC

my $maec = CIF::MAEC::MaecPlaceholder->encode({
	msg => 'A Test Message',
	i => 24681357
});



# construct the submission message

my $m = CIF::Msg::MessageType->encode({
	type => CIF::Msg::MessageType::MsgType::SUBMISSION(),
	submissionRequest => [ 
		{
			baseObjectType => 'MAEC_v2_pb2',
			data => $maec
		}
	]
});



my $x = CIF::Msg::MessageType->decode($m);

print "decoded type: ", $x->get_type , "\n";
print "decoded version: " . $x->get_version . "\n";
print "decoded buffer: ". Dumper($x) . "\n";
print "our message contains the following inner messages:\n";
for (my $i = 0 ; $i <= $#{$x->get_submissionRequest} ; $i++) {
	print "\t#$i: " . $x->get_submissionRequest->[0]->get_baseObjectType . "\n";
}

my $x2 = CIF::MAEC::MaecPlaceholder->decode($x->get_submissionRequest->[0]->get_data);

print "\ndecoded first inner message: " . Dumper($x2) . "\n";


exit 0;

# Find the version of our 'compiled in' protocol buffer IDL

sub getOurVersion {
	return CIF::Msg::MessageType->decode(
		CIF::Msg::MessageType->encode({
			type => CIF::Msg::MessageType::MsgType::SUBMISSION(),
		})
	)->get_version;
}