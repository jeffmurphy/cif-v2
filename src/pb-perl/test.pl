#!/usr/bin/perl -w
use strict;
use lib './lib';
use CIF::Msg;
use CIF::Msg::Control;
use CIF::Msg::Support;
use RFC5070_IODEF_v1_pb2;
use MAEC_v2_pb2;
use Data::Dumper;

print "CIF::Msg demo.\n";
print "  Message IDL version: ". CIF::Msg::Support::getOurVersion("Message") . "\n";
print "  Control IDL version: ". CIF::Msg::Support::getOurVersion("Control") . "\n";
print "     Feed IDL version: ". CIF::Msg::Support::getOurVersion("Feed") . "\n";

# construct a simple inner message, we'll use MAEC

my $maec = CIF::MAEC::MaecPlaceholder->encode({
	msg => 'A Test Message',
	i => 24681357
});



# construct the submission message

my $m = CIF::Msg::MessageType->encode({
	type => CIF::Msg::MessageType::MsgType::SUBMISSION(),
	version => CIF::Msg::Support::getOurVersion("Message"),   # _always_ include this when making a message. set to '1' to test version checking code
	submissionRequest => [ 
		{
			baseObjectType => 'MAEC_v2_pb2',
			data => $maec
		}
	]
});

my $c = CIF::Msg::ControlType->encode({
	type => CIF::Msg::ControlType::MsgType::COMMAND(),
	command => CIF::Msg::ControlType::CommandType::REGISTER(),
	src => 'me',
	dst => 'you',
	version => 20120727, 
	#version => CIF::Msg::Support::getOurVersion("Control"), # _required_
});

my $dc = CIF::Msg::ControlType->decode($c);

print $dc->get_version . " \n";
#
#if (!CIF::Msg::Support::versionCheck($dc)) {
#	die "Sorry, version of received message is incompatible. We can not process it.\n" .
#		"\tOur compiled in version is: " . CIF::Msg::Support::getOurVersion("Control") . "\n" .
#		"\tRecvd message is version: " . $dc->get_version;
#}

my $x = CIF::Msg::MessageType->decode($m);

if (!CIF::Msg::Support::versionCheck($x)) {
	die "Sorry, version of received message is incompatible. We can not process it.\n" .
		"\tOur compiled in version is: " . CIF::Msg::Support::getOurVersion("Message") . "\n" .
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
