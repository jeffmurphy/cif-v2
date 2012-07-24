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
#	version => 1,   # uncomment to test version checking code
	submissionRequest => [ 
		{
			baseObjectType => 'MAEC_v2_pb2',
			data => $maec
		}
	]
});



my $x = CIF::Msg::MessageType->decode($m);

if (!versionCheck($x)) {
	die "Sorry, version of received message is incompatible. We can not process it.\n" .
		"\tOur compiled in version is: " . getOurVersion() . "\n" .
		"\tRecvd message is version: " . $x->get_version;
}

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

# returns 1 if integer portion of version of received message is 
# equivalent to our compiled in version

sub versionCheck {
	my $m = shift;
	if (ref($m) ne "CIF::Msg::MessageType") {
		warn "versionCheck expected CIF::Msg::MessageType but got: ". ref($m). "\n";
		return 0;
	}
	my $ourV = getOurVersion();
	return 0 if (int($m->get_version) != int($ourV));	
	return 1;
}

# Find the version of our 'compiled in' protocol buffer IDL

sub getOurVersion {
	return CIF::Msg::MessageType->decode(
		CIF::Msg::MessageType->encode({
			type => CIF::Msg::MessageType::MsgType::SUBMISSION(),
		})
	)->get_version;
}