package CIF::Foundation;
use base 'Class::Accessor';

use strict;
use warnings;

use CIF::Msg;
use CIF::Msg::Control;
use CIF::Msg::Support;
use ZMQ qw(ZMQ_PUB ZMQ_REQ ZMQ_IDENTITY ZMQ_SNDMORE ZMQ_RCVMORE ZMQ_NOBLOCK);
use ZMQ::LibZMQ3;
use ZMQ;
use Data::Dumper;
use Carp qw(cluck confess);
use Sys::Hostname;
use Socket qw(inet_ntoa);

use Digest::MD5 qw(md5 md5_hex md5_base64);

__PACKAGE__->follow_best_practice();
__PACKAGE__->mk_accessors(qw(config error));

sub setdebug {
	my $self = shift;
	$self->{D} = shift;
}

# CIFPublisher
#
#  1. Make the control socket
#  2. Make the publisher socket
#  3. Connect to the router and register
#  4. Router will connect to our publisher port 
#  5. Send the message 

sub requestsocket {
	my $self = shift;
	
	#req = context.socket(zmq.REQ)
    #req.setsockopt(zmq.IDENTITY, myname)
    #req.connect('tcp://' + cifrouter)	
    
    print "Connecting to ". $self->{cifrouter} . " as " . $self->{myname} ."\n" if $self->{D};
	$self->{req} = zmq_socket($self->{cntx}, ZMQ_REQ);
	zmq_setsockopt($self->{req}, ZMQ_IDENTITY, $self->{myname});
	zmq_connect($self->{req}, "tcp://" . $self->{cifrouter});
}

sub send_multipart {
	my $self = shift;
	my $parts = shift;
	die "invalid argument: parts is not an array ref" unless ref($parts) eq "ARRAY";
	my $rv = 0;

	
	for (my $i = 0; $i < $#$parts ; $i++) {
		$rv = zmq_send($self->{req}, $parts->[$i], ZMQ_SNDMORE);
		die "zmq_send failed with $rv" if ($rv == -1);
	}
	$rv = zmq_send($self->{req}, $parts->[$#$parts]);
	die "zmq_send failed with $rv" if ($rv == -1);
}

sub recv_multipart {
	my $self = shift;
	my $parts = [];
	my $done = 0;
	my $rv = 0;

	while($rv = zmq_recv($self->{req})) {
			push @$parts, zmq_msg_data($rv);
			#my $hasmore = zmq_getsockopt($self->{req}, ZMQ_RCVMORE);
			#print "hasmore: $hasmore\n";sleep(1);
	}
	return $parts;
}

sub publishersocket {
	my $self = shift;
	
	print "Create publisher port on " . $self->{publisherport} . "\n" if $self->{D};
    #publisher = context.socket(zmq.PUB)
    #publisher.bind('tcp://*:' + publisherport)
    #return publisher
    
    $self->{publisher} = zmq_socket($self->{cntx}, ZMQ_PUB);
    zmq_bind($self->{publisher}, "tcp://*:" . $self->{publisherport});    
}

# returns 0 on sucess, 1 on failure and sets self->{error}

sub add_seq {
	my $self = shift;
	my $cm = shift;
	$cm->{seq} = md5($cm->encode());
	return $cm;	
}

sub register {
	my $self = shift;
	
	print "Registering with cif-router\n" if $self->{D};
	
#	 msg = control_pb2.ControlType()
#    msg.version = msg.version # required
#    msg.apikey = apikey
#    msg.type = control_pb2.ControlType.COMMAND
#    msg.command = control_pb2.ControlType.REGISTER
#    msg.dst = 'cif-router'
#    msg.src = myid
    
    my $cm = CIF::Msg::ControlType->new({
		type => CIF::Msg::ControlType::MsgType::COMMAND(),
		command => CIF::Msg::ControlType::CommandType::REGISTER(),
		src => $self->{'myname'},
		dst => $self->{'cifrouter_id'},
		apikey => $self->{apikey},
		version => CIF::Msg::Support::getOurVersion("Control"), # _required_
	});

    my $seq = md5($cm->encode());
    $cm->{seq} = $seq;
    
    
    print "Sending REGISTER command\n" if $self->{D};
	
	$self->send_multipart([$cm->encode()]);

	print "Waiting for reply\n" if $self->{D};
	
	my $reply = $self->recv_multipart();
	$cm = CIF::Msg::ControlType->decode($reply->[0]);
	#print "got reply: ". Dumper($cm). "\n" if $self->{D};
	
	if ($cm->get_status == CIF::Msg::ControlType::StatusType::DUPLICATE()) {
		cluck("Already registered with cif-router?") if $self->{D};
		$self->{error} = "Connection/ID conflict";
		return 1;
	}
	elsif ($cm->get_status != CIF::Msg::ControlType::StatusType::SUCCESS()) {
		$self->{error} = "Not authorized";
		return 1;
	}
	
	$self->{am_registered} = 1; 	
	
	return 0;
}

sub ipublish {
	my $self = shift;

	# tell the router that we're a publisher so it will subscribe to us

	print "Send IPUBISH to cif-router\n" if $self->{D};
	
	my $cm = CIF::Msg::ControlType->encode({
		type => CIF::Msg::ControlType::MsgType::COMMAND(),
		command => CIF::Msg::ControlType::CommandType::REGISTER(),
		src => $self->{'myname'},
		dst => $self->{'cifrouter_id'},
		apikey => $self->{apikey},
		version => CIF::Msg::Support::getOurVersion("Control"), # _required_
	});
	
	$cm->set_command(CIF::Msg::ControlType::CommandType::IPUBLISH());
	$cm->set_type(CIF::Msg::ControlType::MsgType::COMMAND());
	$cm->{'iPublishRequest'}->{'apikey'} = $self->myip();
	$cm->{'iPublishRequest'}->{'port'} = $self->{'publisherport'};
	
	$self->send_multipart([$cm->encode()]);
	my $reply = $self->recv_multipart();
	$cm = CIF::Msg::ControlType->decode($reply->[0]);
	
	#print "got reply: ". Dumper($cm). "\n" if $self->{D};

	if ($cm->get_status == CIF::Msg::ControlType::StatusType::SUCCESS()) {
		# success, cif-router should connect to our PUB socket (zmq won't tell us)
		print "Registered successfully.\n" if $self->{D};
	}
	elsif ($cm->get_status != CIF::Msg::ControlType::StatusType::SUCCESS()) {
		confess("Failed to notify cif-router that we have information to publish");
		return 1;
	}
	
	return 0;
}

sub unregister {
	my $self = shift;
	
	my $cm = CIF::Msg::ControlType->new({
		type => CIF::Msg::ControlType::MsgType::COMMAND(),
		command => CIF::Msg::ControlType::CommandType::UNREGISTER(),
		src => $self->{'myname'},
		dst => $self->{'cifrouter_id'},
		apikey => $self->{apikey},
		version => CIF::Msg::Support::getOurVersion("Control"), # _required_
	});
    my $seq = md5($cm->encode());
    $cm->{seq} = $seq;
    
	$self->send_multipart([$cm->encode(), '']);

	my $reply = $self->recv_multipart();
	$cm = CIF::Msg::ControlType->decode($reply->[0]);
	
	if ($cm->get_status != CIF::Msg::ControlType::StatusType::SUCCESS()) {
		cluck("Failed to UNREGISTER");
		return 1;
	}
	return 0;
}

sub myip {
	my $self = shift;
	
	my  ($name, $aliases, $addrtype, 
          $length, @addrs) = gethostbyname(hostname);
	return inet_ntoa($addrs[0]);
}

sub diiferr {
	my $self = shift;
	confess $self->{error} if ( exists $self->{'error'} && ($self->{'error'} ne "") );
}

=pod

 Usage:
 
 $cf = new CIF::Foundation( {
    'config' => { 
    	zmq_controlport => ...,
    	zmq_publisherport => ...,
    	zmq_cifrouter => ...,
    	zmq_myid => ...     
    },
    'basecfg' => {
    	apikey => ...
    }
 })

 $cf->requestsocket();
 $cf->register();

 $cf->publishersocket(); # optional, create a publisher socket
 $cf->ipubish(); # optional, tell the CIF router that we will be publishing (must come after ->publishersocket())
 
=cut

sub new {
    my $class = shift;
    my $args = shift;
 
    my $self = {};
    bless($self,$class);
    
    $self->{D} = 0;
	
    $self->{'controlport'} = $args->{config}->{'zmq_controlport'};
    $self->{'publisherport'} = $args->{config}->{'zmq_publisherport'} || "0";
    $self->{'cifrouter'} = $args->{config}->{'zmq_cifrouter'};
    $self->{'myid'} = $args->{config}->{'zmq_myid'};
    $self->{'myname'} = $self->myip() . ":" . $self->{publisherport} . "|" . $self->{myid};
    $self->{'apikey'} = $args->{basecfg}->{apikey};
	
    $self->{'cntx'} = zmq_init();

	$self->{cifrouter_id} = "cif-router";
	$self->{am_registered} = 0;
	
    return($self);
}

=pod 

 eg. 
 
 make_control_message(
  "cif-db",
  CIF::Msg::MessageType::COMMAND(), 
  CIF::Msg::MessageType::REGISTER()
  )
  
=cut

sub make_control_message {
	my $self = shift;
	my $dst = shift;
	my $t = shift;
	my $cmd = shift;
	
	return CIF::Msg::ControlType->new({
		type => $t,
		command => $cmd,
		src => $self->{'myname'},
		dst => $dst || $self->{'cifrouter_id'},
		apikey => $self->{apikey},
		version => CIF::Msg::Support::getOurVersion("Control"), # _required_
	});
	
}

sub DESTROY {
	my $self = shift;
	$self->unregister() if  $self->{am_registered} == 1;
	#https://zeromq.jira.com/browse/LIBZMQ-85
	zmq_close($self->{publisher}) if exists $self->{publisher};
	zmq_close($self->{req}) if exists $self->{req};
	zmq_term($self->{cntx});
}



1;