package CIF::Foundation;
use base 'Class::Accessor';
 
use strict;
use warnings;

use threads;
use threads::shared;
use Thread::Semaphore;

use lib "/usr/local/lib/cif-protocol/pb-perl/lib";

use CIF::Msg;
use CIF::Msg::Control;
use CIF::Msg::Support;

use ZeroMQ qw(ZMQ_PUB ZMQ_REQ ZMQ_IDENTITY ZMQ_SUB ZMQ_SUBSCRIBE ZMQ_REP ZMQ_DEALER ZMQ_SNDMORE ZMQ_RCVMORE ZMQ_NOBLOCK);
use ZeroMQ::Raw;
use Data::Dumper;
use Carp qw(cluck confess);
use Sys::Hostname;
use Socket qw(inet_ntoa);



use Digest::MD5;
                  
=pod

=head1 Overview

Foundation provides routines for configuring ZMQ from a client
perspective: registering, unregistering, etc.

It also provides the primary event loop for handling ZMQ replies.

=cut

sub new {
	my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    $self->initialize(@_);
    return $self;	
}

=pod

initialize( { apikey => , myip => , cifrouter => , controlport => , publisherport => , myid => , routerid => })

private method called by new()

=cut 

sub initialize {
	my $self = shift;
	my $p = shift;
	$self->{p} = $p;
	
	foreach my $_p (qw{apikey myip cifrouter controlport publisherport myid routerid}) {
		$self->{$_p} = $self->param($_p);
	}

	my @x = split(':', $self->{cifrouter});
	$self->{router_hname} = $x[0];
	$self->{routerport} = $x[1];
	
	$self->{routerpubport} = undef; # set by 'register'

	my $debug :shared = 0;
	$self->{debug} = \$debug;
	
	# context is shared, but does not require locking per ZMQ doc
	my $context :shared = new ZeroMQ::Context();
	$self->{context} = \$context; 
	
	my $callback_registry :shared = {};
	$self->{callback_registry} = \$callback_registry;
	
	# access to these must be lock()ed
	
	my $subscriber :shared = undef;
	$self->{subscriber} = \$subscriber;
	
	my $publisher :shared = undef;
	$self->{publisher} = \$publisher;
	
	my $rep :shared = undef;
	$self->{rep} = \$rep;
	
	my $req :shared = undef;
	$self->{req} = \$req;
	
        # we want the register, unregister and ipublish commands to be
        # synchronous. the following (semaphores) helps achieve that
    
    my $register_synchronizer :shared = undef;
	$self->{register_synchronizer} = \$register_synchronizer;
	my $register_reply :shared = undef;
	$self->{register_reply} = \$register_reply;
	
	my $unregister_synchronizer :shared = undef;
	$self->{unregister_synchronizer} = \$unregister_synchronizer;
	my $unregister_reply :shared = undef;
	$self->{unregister_reply} = \$unregister_reply;
	
	my $ipublish_synchronizer :shared = undef;
	$self->{ipublish_synchronizer} = \$ipublish_synchronizer;
	my $ipublish_reply :shared = undef;
	$self->{ipublish_reply} = \$ipublish_reply;
}

sub param {
	my $self = shift;
	my $k = shift;
	return $self->{p}->{$k} if (exists $self->{p}->{$k});
	return undef;
}
        

sub md5 {
	my $self = shift;
	my $s = shift;
	return Digest::MD5::md5_hex($s);
}

sub setdebug {
	my $self = shift;
	my $_d = shift;
	lock ${$self->{debug}};
	my $pd = ${$self->{debug}};
	${$self->{debug}} = $_d;
	return $pd;
}

sub getdebug {
	my $self = shift;
	lock ${$self->{debug}};
	
	return ${$self->{debug}};
}


sub requestsocket {
	my $self = shift;
    
    print "Connecting to ". $self->{cifrouter} . " as " . $self->{myid} ."\n" if $self->getdebug();
    lock(${$self->{req}});
    
	${$self->{req}} = zmq_socket($self->{context}, ZMQ_DEALER);
	my $myname = $self->{myip} . ":" . $self->{controlport} . "|" . $self->{myid};
	zmq_setsockopt(${$self->{req}}, ZMQ_IDENTITY, $myname);
	zmq_connect(${$self->{req}}, "tcp://" . $self->{cifrouter});
	
	$self->{evthread} = threads->create(\$self->eventloop());
	$self->{evthread}->detach();
	return ${$self->{req}};
}
    
sub subscribersocket {
	my $self = shift;
	
	my $remote_publisher = "tcp://" . $self->{router_hname} . ":" . $self->{routerpubport};
	print "Creating subscriber socket and connecting to " . $self->{remote_publisher} if $self->getdebug();
	
	lock (${$self->{subscriber}});
	
	${$self->{subscriber}} = zmq_socket($self->{context}, ZMQ_SUB);
	zmq_connect(${$self->{subscriber}}, $remote_publisher);
	zmq_setsockopt(${$self->{subscriber}}, ZMQ_SUBSCRIBE, '');
	return ${$self->{subscriber}};
}
    
sub publishersocket {
	my $self = shift;
	
	lock (${$self->{publisher}});
	
	${$self->{publisher}} = zmq_socket($self->{context}, ZMQ_PUB);
	zmq_bind(${$self->{publisher}}, "tcp://*:" . $self->{publisherport});
	return ${$self->{publisher}};
}
    
sub registerFinished {
	my $self = shift;
	my $decoded_message = shift;
	${$self->{register_synchronizer}}->up();
}

sub unregisterFinished {
	my $self = shift;
	my $decoded_message = shift;
	${$self->{unregister_synchronizer}}->up();
}

sub ipublishFinished {
	my $self = shift;
	my $decoded_message = shift;
	${$self->{ipublish_synchronizer}}->up();
}

sub unregister {
	my $self = shift;
	
	my $cm = CIF::Msg::ControlType->encode({
		type => CIF::Msg::ControlType::MsgType::COMMAND(),
		command => CIF::Msg::ControlType::CommandType::UNREGISTER(),
		src => $self->{myid},
		dst => $self->{routerid},
		apikey => $self->{apikey},
		version => CIF::Msg::Support::getOurVersion("Control"), # _required_
	});
    
    $cm->{seq} = $self->md5($cm->encode());
    
    ${$self->{unregister_synchronizer}} = Thread::Semaphore->new(0);
	$self->sendmsg($cm, \$self->unregisterFinished);
	${$self->{unregister_synchronizer}}->down();

	my $reply = ${$self->{unregister_reply}};
	$cm = CIF::Msg::ControlType->decode($reply->[0]);
	
	if ($cm->get_status != CIF::Msg::ControlType::StatusType::SUCCESS()) {
		cluck("Failed to UNREGISTER");
	}
}

sub send_multipart {
	my $self = shift;
	my $parts = shift;
	die "invalid argument: parts is not an array ref" unless ref($parts) eq "ARRAY";
	my $rv = 0;

	lock(${$self->{req}});
	
	for (my $i = 0; $i < $#$parts ; $i++) {
		$rv = zmq_send(${$self->{req}}, $parts->[$i], ZMQ_SNDMORE);
		die "zmq_send failed with $rv" if ($rv == -1);
	}
	$rv = zmq_send(${$self->{req}}, $parts->[$#$parts]);
	die "zmq_send failed with $rv" if ($rv == -1);
}

sub recv_multipart {
	my $self = shift;
	my $parts = [];
	my $done = 0;
	my $rv = 0;

	lock (${$self->{req}});
	
	while($rv = zmq_recv(${$self->{req}})) {
			push @$parts, zmq_msg_data($rv);
			#my $hasmore = zmq_getsockopt($self->{req}, ZMQ_RCVMORE);
			#print "hasmore: $hasmore\n";sleep(1);
	}
	return $parts;
}

sub register {
	my $self = shift;
	
	print "Registering with cif-router\n" if $self->getdebug();
	
#	 msg = control_pb2.ControlType()
#    msg.version = msg.version # required
#    msg.apikey = apikey
#    msg.type = control_pb2.ControlType.COMMAND
#    msg.command = control_pb2.ControlType.REGISTER
#    msg.dst = 'cif-router'
#    msg.src = myid
    
    my $cm = CIF::Msg::ControlType->encode({
		type => CIF::Msg::ControlType::MsgType::COMMAND(),
		command => CIF::Msg::ControlType::CommandType::REGISTER(),
		src => $self->{myid},
		dst => $self->{routerid},
		apikey => $self->{apikey},
		version => CIF::Msg::Support::getOurVersion("Control"), # _required_
	});
    
    print "Sending REGISTER command\n" if $self->getdebug();

    $cm->{seq} = $self->md5($cm->encode());
    
    ${$self->{register_synchronizer}} = Thread::Semaphore->new(0);
	$self->sendmsg($cm, \$self->unregisterFinished);

	print "Waiting for reply\n" if $self->getdebug();

	${$self->{register_synchronizer}}->down();

	$cm = $self->{register_reply};	

	
	print "got reply: ". Dumper($cm). "\n" if $self->getdebug();
	
	if ($cm->get_status == CIF::Msg::ControlType::StatusType::DUPLICATE()) {
		cluck("Already registered with cif-router?") if $self->getdebug();
		$self->{error} = "Connection/ID conflict";
	}
	elsif ($cm->get_status == CIF::Msg::ControlType::StatusType::UNAUTHORIZED()) {
		$self->{error} = "Not authorized";
	}
	else {
        $self->{routerport} = $cm->{registerResponse}->{REQport};
        $self->{routerpubport} = $cm->{registerResponse}->{PUBport};
    }
    return ($self->{routerport}, $self->{routerpubport});
}

sub ipublish {
	my $self = shift;

    
    my $cm = CIF::Msg::ControlType->encode({
		type => CIF::Msg::ControlType::MsgType::COMMAND(),
		command => CIF::Msg::ControlType::CommandType::IPUBLISH(),
		src => $self->{myid},
		dst => $self->{routerid},
		apikey => $self->{apikey},
		version => CIF::Msg::Support::getOurVersion("Control"), # _required_
	});
    
    print "Sending IPUBLISH command\n" if $self->getdebug();

	$cm->{'iPublishRequest'}->{'ipaddress'} = $self->myip();
	$cm->{'iPublishRequest'}->{'port'} = $self->{'publisherport'};
    $cm->{seq} = $self->md5($cm->encode());
    
    ${$self->{ipublish_synchronizer}} = Thread::Semaphore->new(0);
	$self->sendmsg($cm, \$self->ipublishFinished);

	print "Waiting for reply\n" if $self->getdebug();

	${$self->{ipublish_synchronizer}}->down();

	$cm = $self->{ipublish_reply};
		
	print "got reply: ". Dumper($cm). "\n" if $self->getdebug();
	
	if ($cm->get_status eq CIF::Msg::ControlType::StatusType::SUCCESS()) {
		# success, cif-router should connect to our PUB socket (zmq won't tell us)
		print "Registered successfully.\n" if $self->getdebug();
	}
	elsif ($cm->get_status ne CIF::Msg::ControlType::StatusType::SUCCESS()) {
		confess("Failed to notify cif-router that we have information to publish");
	}
}        

sub ctrlc {
	my $self = shift;
	print "Shutting down.\n" if ($self->getdebug());
	$self->unregister();
}

sub ctrlsocket {
	my $self = shift;
	print "Creating control socket on: " . $self->{controlport} . "\n" if $self->getdebug();
	lock (${$self->{rep}});
	${$self->{rep}} = zmq_socket($self->{context}, ZMQ_REP);
	zmq_bind(${$self->{rep}}, "tcp://*:" . $self->{controlport});
}

=pod

        The eventloop runs in its own thread. It listens for inbound messages
        on the control socket (a DEALER socket). These messages are replies
        to outbound requests (control messages). When a reply is received,
        a thread is created and a user specified callback is called in that 
        thread.
        
=cut
        
sub eventloop {
	my $self = shift;
	
	while(1) {
		my $ti = threads->tid();
		print "$ti] eventloop: Waiting for a reply\n" if $self->getdebug() > 2;
		my $r = $self->recv_multipart();
		print "$ti] eventloop: Got reply: " if $self->getdebug() > 2;   # . Dumper($r) . "\n";
		if ($#$r > 0) {
			my $msg = $r->[1];
			my $decoded_message = CIF::Msg::ControlType->decode($msg);
			if (CIF::Msg::Support::versionCheck($decoded_message)) {
				my $msgid = $decoded_message->{seq};
				lock(${$self->{callback_registry}});
				if (exists ${$self->{callback_registry}}->{$msgid}) {
					my $cb = ${$self->{callback_registry}}->{$msgid};
					print "$ti] eventloop: Callback specified. Calling it.\n" if $self->getdebug() > 2;
					my $thr = threads->create($cb, $decoded_message);
					delete ${$self->{callback_registry}}->{$msgid};
				} 
				else {
					print "$ti] eventloop: Reply is bad (unexpected, no callback available). Discarding.\n" if $self->getdebug() > 2;
				}
			}
		}
	}
}

=pod

sendmsg($msg, $callback)

        Send a unicast message on a socket. Messages are always sent asynchronously.
        If a callback is specified, it will be called when a reply is received.
        
=cut 

sub sendmsg {
	my $self = shift;
	my $msg = shift;
	my $callback = shift;
	
	if (defined(${$self->{req}}) && defined($msg)) {
		if (defined($callback)) {
			lock(${$self->{callback_registry}});
			my $msgid = $msg->{seq};
			${$self->{callback_registry}}->{$msgid} = $callback;
		}
		$self->send_multipart($msg->encode());
	}
}

1; 
           