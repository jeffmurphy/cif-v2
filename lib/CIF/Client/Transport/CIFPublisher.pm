package CIF::Client::Transport::CIFPublisher;
use base 'Class::Accessor';

use strict;
use warnings;

use CIF::Msg;
use CIF::Msg::Control;
use ZMQ::Constants qw(ZMQ_PUB ZMQ_REQ ZMQ_IDENTITY ZMQ_SNDMORE ZMQ_RCVMORE ZMQ_NOBLOCK);
use ZMQ::LibZMQ3;
use ZMQ;
use Data::Dumper;
use Carp qw(cluck confess);
use Sys::Hostname;
use Socket qw(inet_ntoa);

use CIF::Foundation;

__PACKAGE__->follow_best_practice();
__PACKAGE__->mk_accessors(qw(config));

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
    
    print "Connecting to ". $self->{cifrouter} . " as " . $self->{myid} ."\n" if $self->{D};
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
		src => $self->{'myid'},
		dst => 'cif-router',
		apikey => $self->{apikey},
		version => CIF::Msg::Support::getOurVersion("Control"), # _required_
	});
    
    print "Sending REGISTER command\n" if $self->{D};
	
	$self->send_multipart([$self->add_seq($cm)->encode()]);

	print "Waiting for reply\n" if $self->{D};
	
	my $reply = $self->recv_multipart();
	$cm = CIF::Msg::ControlType->decode($reply->[0]);
	#print "got reply: ". Dumper($cm). "\n" if $self->{D};
	
	if ($cm->get_status == CIF::Msg::ControlType::StatusType::DUPLICATE()) {
		cluck("Already registered with cif-router?") if $self->{D};
		$self->{error} = "Connection/ID conflict";
	}
	elsif ($cm->get_status == CIF::Msg::ControlType::StatusType::UNAUTHORIZED()) {
		$self->{error} = "Not authorized";
	}
	else {
		# tell the router that we're a publisher so it will subscribe to us
	
		print "Send IPUBISH to cif-router\n" if $self->{D};
		my $tmp = $cm->{'src'};
		$cm->{'src'} = $cm->{'dst'};
		$cm->{'dst'} = $tmp;
		$cm->set_command(CIF::Msg::ControlType::CommandType::IPUBLISH());
		$cm->set_type(CIF::Msg::ControlType::MsgType::COMMAND());
		$cm->{'iPublishRequest'}->{'ipaddress'} = $self->myip();
		$cm->{'iPublishRequest'}->{'port'} = $self->{'publisherport'};
		
		$self->send_multipart([$self->add_seq($cm)->encode()]);
		$reply = $self->recv_multipart();
		$cm = CIF::Msg::ControlType->decode($reply->[0]);
		
		#print "got reply: ". Dumper($cm). "\n" if $self->{D};
	
		if ($cm->get_status eq CIF::Msg::ControlType::StatusType::SUCCESS()) {
			# success, cif-router should connect to our PUB socket (zmq won't tell us)
			print "Registered successfully.\n" if $self->{D};
		}
		elsif ($cm->get_status ne CIF::Msg::ControlType::StatusType::SUCCESS()) {
			confess("Failed to notify cif-router that we have information to publish");
		}
	}        
}

sub unregister {
	my $self = shift;
	
	my $cm = CIF::Msg::ControlType->new({
		type => CIF::Msg::ControlType::MsgType::COMMAND(),
		command => CIF::Msg::ControlType::CommandType::UNREGISTER(),
		src => $self->{'myid'},
		dst => 'cif-router',
		apikey => $self->{apikey},
		version => CIF::Msg::Support::getOurVersion("Control"), # _required_
	});
    
	$self->send_multipart([$self->add_seq($cm)->encode(), '']);

	my $reply = $self->recv_multipart();
	$cm = CIF::Msg::ControlType->decode($reply->[0]);
	
	if ($cm->get_status != CIF::Msg::ControlType::StatusType::SUCCESS()) {
		cluck("Failed to UNREGISTER");
	}
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

sub new {
    my $class = shift;
    my $args = shift;
 
    my $self = {};
    bless($self,$class);
    
    $self->{D} = 0;
		
    $self->{'controlport'} = $args->{config}->{'zmq_controlport'};
    $self->{'publisherport'} = $args->{config}->{'zmq_publisherport'};
    $self->{'cifrouter'} = $args->{config}->{'zmq_cifrouter'};
    $self->{'myid'} = $args->{config}->{'zmq_myid'};
    $self->{'myname'} = $self->myip() . ":" . $self->{publisherport} . "|" . $self->{myid};
    $self->{'apikey'} = $args->{config}->{apikey};
    
    #print "apikey " . $self->{'apikey'};
    
    # $self->{cf} = new CIF::Foundation(
	# {
		# apikey => $self->{apikey},
		# myip => $self->myip(),
		# cifrouter => $self->{cifrouter},
		# controlport => 15556,  # FIX
		# publisherport => 15557, # FIX get from config
		# myid => $self->{myid},
		# routerid => 'cif-router',
		# debug => 10
	# }
	# );
	
    $self->{'cntx'} = zmq_init();
    $self->requestsocket();
    $self->publishersocket();
    $self->register();
	
    return($self);
}

sub __DESTROY__ {
	my $self = shift;
	$self->unregister();
	zmq_term($self->{cntx});
}

# config parameters required:
#   controlport = "5656"
#   publisherport = "5657"
#   cifrouter = "sdev.nickelsoft.com:5555"
#   myid = "poc-publisher"

sub send {
    my $self = shift;
    my $msg = shift;
    return unless(defined($msg));

    my $rv = zmq_send($self->{publisher}, 
    				  $self->add_seq($msg)->encode());

    confess("failed to zmq_send the message") if $rv;
    
    my $rm = CIF::Msg::MessageType->encode({
    	type => CIF::Msg::MessageType::MsgType::SUBMISSION(),
    	status => 	CIF::Msg::MessageType::StatusType::SUCCESS()
    });
    return (undef, $rm);
}

sub send_direct {
	my $self = shift;
	my $msg  = shift;
	return unless defined($msg);
		
	my $rv = 
		$self->send_multipart([$self->add_seq($msg)->encode()]);

	print "send_direct: Waiting for reply\n" if $self->{D};
	
	my $reply = $self->recv_multipart();

	return (undef, $reply->[0]);
#	$cm = CIF::Msg::ControlType->decode($reply->[0]);
}

=pod 

 eg. 
 
 make_control_message(
   		"cif-db",
  		CIF::Msg::ControlType::MsgType::COMMAND(), 
  		CIF::Msg::ControlType::CommandType::CIF_QUERY_REQUEST()
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
		src => $self->{'myid'},
		dst => $dst || $self->{'cifrouter_id'},
		apikey => $self->{apikey},
		version => CIF::Msg::Support::getOurVersion("Control"), # _required_
	});
	
}

use Digest::MD5 qw(md5 md5_hex md5_base64);

sub add_seq {
	my $self = shift;
	my $cm = shift;
	$cm->{seq} = md5($cm->encode());
	return $cm;	
}


1;
