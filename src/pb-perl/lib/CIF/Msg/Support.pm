package CIF::Msg::Support;
use CIF::Msg;
use 5.008008;
use strict;
use warnings;



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

1;
