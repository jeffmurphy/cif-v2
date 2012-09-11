package CIF::Msg::Support;
use CIF::Msg;
use CIF::Msg::Feed;
use CIF::Msg::Control;

use 5.008008;
use strict;
use warnings;

use Carp qw(confess cluck);

sub versionCheck {
	my $m = shift;
	
	if (ref($m) eq "CIF::Msg::MessageType") {
		my $ourV = getOurVersion("Message");
		return 0 if (int($m->get_version) != int($ourV));
	}
	
	elsif (ref($m) eq "CIF::Msg::ControlType") {
		my $ourV = getOurVersion("Control");
		return 0 if (int($m->get_version) != int($ourV));
	}
	
	elsif (ref($m) eq "CIF::Msg::FeedType") {
		my $ourV = getOurVersion("Feed");
		return 0 if (int($m->get_version) != int($ourV));
	}
	
	else {
		cluck("versionCheck expected CIF::Msg::MessageType, ::ControlType or ::FeedType but got: ". 
			ref($m). "\n");
		return 0;
	}
		
	return 1;
}

# Find the version of our 'compiled in' protocol buffer IDL

sub getOurVersion {
	my $t = shift;
	confess ("getOurVersion(type) where type is Message, Control or Feed") unless defined($t);
	
	return CIF::Msg::MessageType->decode(
		CIF::Msg::MessageType->encode({
			type => CIF::Msg::MessageType::MsgType::SUBMISSION(),
		})
	)->get_version  if ($t eq "Message");
	
	return CIF::Msg::ControlType->decode(
		CIF::Msg::ControlType->encode({
			type => CIF::Msg::ControlType::MsgType::COMMAND(),
		})
	)->get_version if ($t eq "Control");
	
	return CIF::Msg::FeedType->decode(
		CIF::Msg::FeedType->encode({
			description => 'x',
			ReportTime => 'x'
		})
	)->get_version if ($t eq "Feed");
}

1;
