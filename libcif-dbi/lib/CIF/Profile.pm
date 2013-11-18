package CIF::Profile;
use base 'Class::Accessor';
use Carp qw(cluck croak);
use Data::Dumper;

use strict;
use warnings;

use CIF::APIKey;

use CIF qw/is_uuid generate_uuid_random generate_uuid_ns/;
use Digest::SHA qw/sha1_hex/;

__PACKAGE__->follow_best_practice();
__PACKAGE__->mk_accessors(qw(config db_config));

=pod

 new('cf' => $foundation)

=cut

sub new {
	my $class = shift;
	my $args  = shift;

	my $self = {};
	bless( $self, $class );

	$self->init($args);
	return ($self);
}

sub init {
	my $self = shift;
	my $args = shift;

	$self->{cf} = $args->{cf};
}

sub key_add {
	my $self = shift;
	my $args = shift;

	my $msg = $self->{cf}->make_control_message(
		"cif-db",
		CIF::Msg::ControlType::MsgType::COMMAND(),
		CIF::Msg::ControlType::CommandType::APIKEY_ADD(),
	);

	my $uuid = generate_uuid_random();

	$msg->{'apiKeyRequest'} = {
		'apikey'           => $uuid,
		'alias'            => $args->{'uuid_alias'} || $args->{'userid'},
		'description'      => $args->{'description'} || "",
		'restrictedAccess' => $args->{'restricted_access'},
		'writeAccess'      => $args->{'write'} || 0,
		'parent'           => $args->{'parentid'} || "",
		'revoked'          => 0, #$args->{'revoked'},
		'expires'          => $args->{'expires'} || 0
	};

	$msg = $self->{cf}->add_seq($msg);

	$self->{cf}->send_multipart( [ $msg->encode() ] );
	my $_reply = $self->{cf}->recv_multipart();
	my $reply  = CIF::Msg::ControlType->decode( $_reply->[0] );

	my $r = undef;

	if ( $reply->get_status != CIF::Msg::ControlType::StatusType::SUCCESS() ) {
		cluck("APIKEYS_ADD failed: " . $reply->{statusMsg});
	}
	else {
		my $akr = $msg->{'apiKeyRequest'};

		$r = new CIF::APIKey(
			{
				'uuid'              => $akr->{apikey},
				'uuid_alias'        => $akr->{alias},
				'description'       => $akr->{description},
				'parentid'          => $akr->{parent},
				'revoked'           => $akr->{revoked},
				'write'             => $akr->{writeAccess},
				'restricted_access' => $akr->{restrictedAccess},
				'expires'           => $akr->{expires},
				'created'           => time(),
			}
		);
	}

	return ($r);
}

sub key_remove {
	my $self = shift;
	my $args = shift;

	my $msg = $self->{cf}->make_control_message(
		"cif-db",
		CIF::Msg::ControlType::MsgType::COMMAND(),
		CIF::Msg::ControlType::CommandType::APIKEY_DEL(),
	);


	$msg->{'apiKeyRequest'} = {
		'apikey'           => $args->{'key'},
		'alias'            => '',
		'description'      => '',
		'restrictedAccess' => '',
		'writeAccess'      => 0,
		'parent'           => "",
		'revoked'          => 0,
		'expires'          => 0
	};

	$msg = $self->{cf}->add_seq($msg);

	$self->{cf}->send_multipart( [ $msg->encode() ] );
	my $_reply = $self->{cf}->recv_multipart();
	my $reply  = CIF::Msg::ControlType->decode( $_reply->[0] );

	if ( $reply->get_status != CIF::Msg::ControlType::StatusType::SUCCESS() ) {
		cluck("APIKEYS_DEL failed");
	}
	
}

sub user_rename {
	croak("not implemented");
}

sub key_toggle_write {
	my $self = shift;
	my $args = shift;

	my $kr = $self->key_get($args);
		
	if (defined($kr)) {
		my $msg = $self->{cf}->make_control_message(
			"cif-db",
			CIF::Msg::ControlType::MsgType::COMMAND(),
			CIF::Msg::ControlType::CommandType::APIKEY_UPDATE(),
		);
	
		if ( $kr->{'apiKeyResponseList'}->[0]->{'writeAccess'} == 1 ) {
			$msg->{'apiKeyRequest'}->{'writeAccess'} = 0;
		}
		else {
			$msg->{'apiKeyRequest'}->{'writeAccess'} = 1;
		}
		$msg->{'apiKeyRequest'}->{'apikey'} = $kr->{'apiKeyRequest'}->{'apikey'};
		
		$msg = $self->{cf}->add_seq($msg);		
		
		$self->{cf}->send_multipart( [ $msg->encode() ] );
		my $_reply = $self->{cf}->recv_multipart();
		my $reply  = CIF::Msg::ControlType->decode( $_reply->[0] );
	
		if ( $reply->get_status != CIF::Msg::ControlType::StatusType::SUCCESS() ) {
			cluck("APIKEYS_UPDATE failed");
			return -1;
		} 
		return 1;
	}

	return -1;
}

sub key_toggle_revoke {
	my $self = shift;
	my $args = shift;

	my $kr = $self->key_get($args);
	
	if (defined($kr)) {
		my $msg = $self->{cf}->make_control_message(
			"cif-db",
			CIF::Msg::ControlType::MsgType::COMMAND(),
			CIF::Msg::ControlType::CommandType::APIKEY_UPDATE(),
		);
	
		if ( $kr->{'apiKeyResponseList'}->[0]->{'revoked'} == 1 ) {
			$msg->{'apiKeyRequest'}->{'revoked'} = 0;
		}
		else {
			$msg->{'apiKeyRequest'}->{'revoked'} = 1;
		}
		
		$msg->{'apiKeyRequest'}->{'apikey'} = $kr->{'apiKeyRequest'}->{'apikey'};
		
		$msg = $self->{cf}->add_seq($msg);
		
		$self->{cf}->send_multipart( [ $msg->encode() ] );
		my $_reply = $self->{cf}->recv_multipart();
		my $reply  = CIF::Msg::ControlType->decode( $_reply->[0] );
	
		if ( $reply->get_status != CIF::Msg::ControlType::StatusType::SUCCESS() ) {
			cluck("APIKEYS_UPDATE failed");
			return -1;
		} 
		return 1;
	}

	return -1;
}

sub key_set_expires {
	my $self = shift;
	my $args = shift;


	my $msg = $self->{cf}->make_control_message(
		"cif-db",
		CIF::Msg::ControlType::MsgType::COMMAND(),
		CIF::Msg::ControlType::CommandType::APIKEY_UPDATE(),
	);

	$msg->{'apiKeyRequest'}->{'apikey'} = $args->{'key'};
	$msg->{'apiKeyRequest'}->{'expires'} = $args->{'expires'};
	$msg = $self->{cf}->add_seq($msg);

	$self->{cf}->send_multipart( [ $msg->encode() ] );
	my $_reply = $self->{cf}->recv_multipart();
	my $reply  = CIF::Msg::ControlType->decode( $_reply->[0] );

	if ( $reply->get_status != CIF::Msg::ControlType::StatusType::SUCCESS() ) {
		cluck("APIKEYS_UPDATE failed");
		return -1;
	} 
	return 1;
}

sub user_add {
	my $self = shift;
	my $args = shift;

	my $group         = $args->{'groups'}        || 'everyone';
	my $default_group = $args->{'default_group'} || 'everyone';
	my $isRestricted = ( $args->{'restricted_access'} ) ? 1 : 0;

	my $r = $self->key_add(
		{
			uuid_alias => $args->{'uuid_alias'} || $args->{'userid'},
			description       => $args->{'description'},
			write             => $args->{'write'},
			parentid          => $args->{'parentid'},
			expires           => $args->{'expires'},
			restricted_access => $isRestricted,
		}
	);

	$self->group_add(
		{
			key     => $r->uuid(),
			group   => $group,
			default => $default_group,
		}
	);

	$self->restriction_add(
		{
			restriction => $args->{'restricted_access'},
			key         => $r->uuid(),
		}
	) if ($isRestricted);

	return $r;
}

sub restriction_add {
	my $self = shift;
	my $args = shift;

	my $restriction =
	  ( ref( $args->{'restriction'} ) eq 'ARRAY' )
	  ? $args->{'restriction'}
	  : [ split( /,/, $args->{'restriction'} ) ];

	my @ids;
	foreach (@$restriction) {
		my @bits = split(/\//);
		my $feed = join( ' ', reverse(@bits) ) . ' feed';
		$feed = sha1_hex($feed) unless (/^[a-z0-9]{40}$/);
		my $id = CIF::APIKeyRestrictions->insert(
			{
				uuid   => $args->{'key'},
				access => $feed,
			}
		);
		push( @ids, $id );
	}
	return ( \@ids );
}

sub restriction_list {
	my $self = shift;
	my $args = shift;

	return CIF::APIKey::Restriction->search( uuid => $args->{'uuid'} );
}

sub user_list {
	my $self = shift;
	my $args = shift;

	my $msg = $self->{cf}->make_control_message(
		"cif-db",
		CIF::Msg::ControlType::MsgType::COMMAND(),
		CIF::Msg::ControlType::CommandType::APIKEY_LIST(),
	);

	$msg->{'apiKeyRequest'}->{'apikey'} = ".*";
	$msg = $self->{cf}->add_seq($msg);

	$self->{cf}->send_multipart( [ $msg->encode() ] );
	my $_reply = $self->{cf}->recv_multipart();
	my $reply  = CIF::Msg::ControlType->decode( $_reply->[0] );

	if ( $reply->get_status != CIF::Msg::ControlType::StatusType::SUCCESS() ) {
		cluck("APIKEYS_LIST failed");
	} 
	else {
		my @rv;
	
		my $akr_list = $reply->{apiKeyResponseList};
	
		if ( $#$akr_list > -1 ) {
			foreach my $akr (@$akr_list) {
				my $groupsList = {};
	
				if ( exists $akr->{groupsList} ) {
					foreach my $akg ( @{ $akr->{groupsList} } ) {
						$groupsList->{ $akg->{groupid} } = $akg->{groupname};
					}
				}
	
				my $k = CIF::APIKey->new(
					{
						'uuid'              => $akr->{apikey},
						'uuid_alias'        => $akr->{alias},
						'description'       => $akr->{description},
						'parentid'          => $akr->{parent},
						'revoked'           => $akr->{revoked},
						'write'             => $akr->{writeAccess},
						'restricted_access' => $akr->{restrictedAccess},
						'expires'           => $akr->{expires},
						'created'           => $akr->{created},
						'groupsMap'         => $groupsList
					}
				);
				
				push @rv, $k;
			}
		}
		
		return @rv;
	}
}

sub key_get {
	my $self = shift;
	my $args = shift;

	my $msg = $self->{cf}->make_control_message(
		"cif-db",
		CIF::Msg::ControlType::MsgType::COMMAND(),
		CIF::Msg::ControlType::CommandType::APIKEY_GET(),
	);

	$msg->{'apiKeyRequest'}->{'apikey'} = $args->{'key'};
	$msg = $self->{cf}->add_seq($msg);

	$self->{cf}->send_multipart( [ $msg->encode() ] );
	my $_reply = $self->{cf}->recv_multipart();
	my $reply  = CIF::Msg::ControlType->decode( $_reply->[0] );

	if ( $reply->get_status != CIF::Msg::ControlType::StatusType::SUCCESS() ) {
		cluck("APIKEYS_GET failed");
		return undef;
	} 
	

	my $akr_list = $reply->{apiKeyResponseList};

	if ( $#$akr_list == 0 ) {
		return $reply;
	}
	
	cluck ("Didnt get back exactly 1 apiKeyResponseList object: " . ($#$akr_list + 1));
	return undef;
}


sub user_from_key {
	my $self = shift;
	my $args = shift;

	my $msg = $self->{cf}->make_control_message(
		"cif-db",
		CIF::Msg::ControlType::MsgType::COMMAND(),
		CIF::Msg::ControlType::CommandType::APIKEY_GET(),
	);


	$msg->{'apiKeyRequest'} = {
		'apikey'           => $args,
		'alias'            => '',
		'description'      => '',
		'restrictedAccess' => '',
		'writeAccess'      => 0,
		'parent'           => "",
		'revoked'          => 0,
		'expires'          => 0
	};

	$msg = $self->{cf}->add_seq($msg);

	$self->{cf}->send_multipart( [ $msg->encode() ] );
	my $_reply = $self->{cf}->recv_multipart();
	my $reply  = CIF::Msg::ControlType->decode( $_reply->[0] );

	if ( $reply->get_status != CIF::Msg::ControlType::StatusType::SUCCESS() ) {
		return;
	}
	
	return $reply->{apiKeyResponse}->{apikey};
}

sub remove {
	my $self = shift;
	my $arg  = shift;

	return $self->user_remove( { user => $arg } ) unless ( is_uuid($arg) );
	return $self->key_remove( { key => $arg } );
}

sub user_remove {
	my $self = shift;
	my $args = shift;

	my $msg = $self->{cf}->make_control_message(
		"cif-db",
		CIF::Msg::ControlType::MsgType::COMMAND(),
		CIF::Msg::ControlType::CommandType::APIKEY_DEL(),
	);


	$msg->{'apiKeyRequest'} = {
		'apikey'           => '',
		'alias'            => $args->{'user'},
		'description'      => '',
		'restrictedAccess' => '',
		'writeAccess'      => 0,
		'parent'           => "",
		'revoked'          => 0,
		'expires'          => 0
	};

	$msg = $self->{cf}->add_seq($msg);

	$self->{cf}->send_multipart( [ $msg->encode() ] );
	my $_reply = $self->{cf}->recv_multipart();
	my $reply  = CIF::Msg::ControlType->decode( $_reply->[0] );

	my $r = undef;

	if ( $reply->get_status != CIF::Msg::ControlType::StatusType::SUCCESS() ) {
		cluck("APIKEYS_ADD failed");
	}
	
}

sub group_remove {
	my $self = shift;
	my $args = shift;

	my $k = CIF::APIKey->retrieve( uuid => $args->{'key'} );
	my $g = generate_uuid_ns( $args->{'group'} );
	my $ret;
	foreach ( $k->groups() ) {
		if ( $g eq $_->guid() ) {
			$ret = $_->delete();
		}
	}
	return $ret;
}

sub group_add {
	my $self = shift;
	my $args = shift;

	my $group         = $args->{'group'};
	my $default_group = $args->{'default'};


	
	my $msg = $self->{cf}->make_control_message(
		"cif-db",
		CIF::Msg::ControlType::MsgType::COMMAND(),
		CIF::Msg::ControlType::CommandType::APIKEY_UPDATE(),
	);

	$msg->{'apiKeyRequest'} = {
		'apikey'           => $args->{'key'},
	};
	
	
	
	my @ids;
	my $groupsList;
	$msg->{apiKeyRequest}->{groupsList} = [];
		
	foreach my $gname ( split( ',', $group ) ) {
		my $isDefault = 1 if ( $default_group && ( $gname eq $default_group ) );
		my $gid = $gname;
		$gid = generate_uuid_ns($gname) unless ( is_uuid($gname) );
		$groupsList->{$gid} = $gname;
		push( @ids, $gid );
		push @{$msg->{apiKeyRequest}->{groupsList}}, {groupname => $gname, groupid => $gid, 'default' => $isDefault };
	}

	
	$msg = $self->{cf}->add_seq($msg);

	$self->{cf}->send_multipart( [ $msg->encode() ] );
	my $_reply = $self->{cf}->recv_multipart();
	my $reply  = CIF::Msg::ControlType->decode( $_reply->[0] );

	my $r = undef;

	if ($reply->get_status != CIF::Msg::ControlType::StatusType::SUCCESS() )
	{
		cluck("APIKEYS_UPDATE failed: " . $reply->{statusMsg});
	}


	return ( \@ids );
}

sub group_set_default {
	my $self = shift;
	my $args = shift;

	my $group = $args->{'group'};
	$group = generate_uuid_ns($group) unless ( is_uuid($group) );

	my $key = CIF::APIKey->retrieve( uuid => $args->{'key'} );
	foreach ( $key->groups() ) {
		next unless ( $_->default_guid() );
		$_->default_guid(undef);
		$_->update();
	}
	foreach ( $key->groups() ) {
		next unless ( $_->guid eq $group );
		$_->default_guid('true');
		$_->update();
	}
}

sub group_default {
	my $self = shift;
	my $args = shift;

	my $id = CIF::APIKey->retrieve( uuid => $args );
	return unless ($id);

	my $groups = $id->groups();

	while ( my $g = $groups->next() ) {
		return ( $g->guid() ) if ( $g->default_guid() );
	}
}

sub groups {
	my $self = shift;
	my $args = shift;

	my $id = CIF::APIKey->retrieve( uuid => $args );
	return unless ($id);

	my @groups = $id->groups();
	return unless ( $#groups > -1 );

	@groups = map { $_->guid() } @groups;
	return ( \@groups );
}

sub expired {
	my $self = shift;
	my $args = shift;

	my $id = CIF::APIKey->retrieve( uuid => $args );
	return 0 unless ( $id->expires() );

	my $time = DateTime::Format::DateParse->parse_datetime( $id->expires() );
	return 1 if ( time() > $time );
	return 0;
}

1;
