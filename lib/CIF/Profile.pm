package CIF::Profile;
use base 'Class::Accessor';
use Carp qw(cluck croak);
use Data::Dumper;

use strict;
use warnings;

use CIF::APIKey;

use CIF qw/is_uuid generate_uuid_random generate_uuid_ns/;
use Digest::SHA1 qw/sha1_hex/;

__PACKAGE__->follow_best_practice();
__PACKAGE__->mk_accessors(qw(config db_config));

=pod

 new('cf' => $foundation)

=cut

sub new {
    my $class   = shift;
    my $args    = shift;
    
    my $self = {};
    bless($self,$class);
    
    $self->init($args);
    return($self);
}

sub init {
    my $self = shift;
    my $args = shift;
    
  	$self->{cf} = $args->{cf};
}




sub key_add {
    my $self    = shift;
    my $args    = shift;
    
    my $uuid = generate_uuid_random();

    my $r = CIF::APIKey->insert({
        uuid                => $uuid,
        uuid_alias          => $args->{'uuid_alias'} || $args->{'userid'},
        description         => $args->{'description'},
        restricted_access   => $args->{'restricted_access'},
        parentid            => $args->{'parentid'},
        write               => $args->{'write'},
        revoked             => $args->{'revoked'},
        expires             => $args->{'expires'},
    });
    

    return($r);
}

sub key_remove {
    my $self = shift;
    my $args = shift;
    
    my @recs = CIF::APIKey->search(uuid => $args->{'key'});
    $_->delete() foreach(@recs);
}

sub key_toggle_write {
    my $self = shift;
    my $args = shift;
    
    my $k = CIF::APIKey->retrieve(uuid => $args->{'key'});
    return unless($k);
    
    my $val = 0;
    $val = 1 unless($k->write());
    $k->write($val);
    return $k->update();
}

sub key_toggle_revoke {
    my $self = shift;
    my $args = shift;
    
    my $k = CIF::APIKey->retrieve(uuid => $args->{'key'});
    return unless($k);
    
    my $val = 0;
    $val = 1 unless($k->revoked());
    $k->revoked($val);
    return $k->update();
}

sub key_set_expires {
    my $self = shift;
    my $args = shift;
    
    my $k = CIF::APIKey->retrieve(uuid => $args->{'key'});
    return unless($k);
    
    $k->expires($args->{'expires'});
    return $k->update();
}

sub user_add {
    my $self = shift;
    my $args = shift;
    
    my $group           = $args->{'groups'}         || 'everyone';
    my $default_group   = $args->{'default_group'}  || 'everyone';
    my $isRestricted    = ($args->{'restricted_access'}) ? 1 : 0;
    
    my $r = $self->key_add({
        uuid_alias          => $args->{'uuid_alias'}    || $args->{'userid'},
        description         => $args->{'description'},
        write               => $args->{'write'},
        parentid            => $args->{'parentid'},
        expires             => $args->{'expires'},
        restricted_access   => $isRestricted,
    });
    $self->group_add({
        key     => $r->uuid(),
        group   => $group,
        default => $default_group,
    });
    $self->restriction_add({
        restriction => $args->{'restricted_access'},
        key         => $r->uuid(),
    }) if($isRestricted);
    return $r;
}

sub restriction_add {
    my $self = shift;
    my $args = shift;
    
    my $restriction = (ref($args->{'restriction'}) eq 'ARRAY') ? $args->{'restriction'} : [ split(/,/,$args->{'restriction'}) ];
    
    my @ids;
    foreach (@$restriction){
        my @bits = split(/\//);
        my $feed = join(' ',reverse(@bits)).' feed';
        $feed = sha1_hex($feed) unless(/^[a-z0-9]{40}$/);
        my $id = CIF::APIKeyRestrictions->insert({
            uuid    => $args->{'key'},
            access  => $feed,
        });
        push(@ids,$id);
    }
    return(\@ids);
}

sub restriction_list {
    my $self = shift;
    my $args = shift;
    
    return CIF::APIKey::Restriction->search(uuid => $args->{'uuid'});
}

sub user_list {
    my $self = shift;
    my $args = shift;
    
    my $msg = $self->{cf}->make_control_message(
    	"cif-db",
		CIF::Msg::ControlType::MsgType::COMMAND(),
		CIF::Msg::ControlType::CommandType::APIKEY_LIST(),
	);
	
	$msg->{'apiKeyRequest'}->{'apikey'} =  ".*";
	
    $self->{cf}->send_multipart([$msg->encode()]);
    my $_reply = $self->{cf}->recv_multipart();
   	my $reply = CIF::Msg::ControlType->decode($_reply->[0]);
    
    if ($reply->get_status != CIF::Msg::ControlType::StatusType::SUCCESS()) {
		cluck("APIKEYS_LIST failed");
	}
	
	my @rv;
	
	my $akr_list = $reply->{apiKeyResponseList};
	
	if ($#$akr_list > -1) {
		foreach my $akr (@$akr_list) {
			my $groupsList = {};
			
			if (exists $akr->{groupsList}) {
				foreach my $akg (@{$akr->{groupsList}}) {
					$groupsList->{$akg->{groupid}} = $akg->{groupname};
				}
			}
			
			my $k = CIF::APIKey->new(
				{
					'uuid' => $akr->{apikey},
					'uuid_alias' => $akr->{alias},
					'description' => $akr->{description},
					'parentid' => $akr->{parent},
					'revoked' => $akr->{revoked},
					'write' => $akr->{writeAccess},
					'restricted_access' => $akr->{restrictedAccess},
					'expires' => $akr->{expires},
					'created' => $akr->{created},
					'groupsMap' => $groupsList
				}
			);
			push @rv, $k;
		}
	}
	return @rv;    
}

sub user_from_key {
    my $self = shift;
    my $args = shift;
    
    my @r = CIF::APIKey->search(uuid => $args);
    return unless($#r > -1);
    return $r[0]->uuid_alias();
}

sub remove {
    my $self = shift;
    my $arg = shift;
    
    return $self->user_remove({ user => $arg }) unless(is_uuid($arg));
    return $self->key_remove({ key => $arg });
}
    

sub user_remove {
    my $self = shift;
    my $args = shift;
    
    my @recs = CIF::APIKey->search(uuid_alias => $args->{'user'});
    $_->delete() foreach(@recs);
}

sub group_remove {
    my $self = shift;
    my $args = shift;
    
    my $k = CIF::APIKey->retrieve(uuid => $args->{'key'});
    my $g = generate_uuid_ns($args->{'group'});
    my $ret;
    foreach ($k->groups()){
        if($g eq $_->guid()){
            $ret = $_->delete();
        }
    }
    return $ret;
}

sub group_add {
    my $self = shift;
    my $args = shift;
       
    my $group           = $args->{'group'};
    my $default_group   = $args->{'default'};
    
    my @ids;
    foreach (split(',',$group)){
        my $isDefault = 1 if($default_group && ($_ eq $default_group));
        $_ = generate_uuid_ns($_) unless(is_uuid($_));
        my $id = CIF::APIKeyGroups->insert({
            uuid    => $args->{'key'},
            guid    => $_,
            default_guid    => $isDefault,
        });
        push(@ids,$id);
    }
    return(\@ids);
}

sub group_set_default {
    my $self = shift;
    my $args = shift;
    
    my $group = $args->{'group'};
    $group = generate_uuid_ns($group) unless(is_uuid($group));
    
    my $key = CIF::APIKey->retrieve(uuid => $args->{'key'});
    foreach ($key->groups()){
        next unless($_->default_guid());
        $_->default_guid(undef);
        $_->update();
    }
    foreach ($key->groups()){
        next unless($_->guid eq $group);
        $_->default_guid('true');
        $_->update();
    }
}

sub group_default {
    my $self    = shift;
    my $args    = shift;
    
    my $id = CIF::APIKey->retrieve(uuid => $args);
    return unless($id);
    
    my $groups = $id->groups();
    
    while(my $g = $groups->next()){
        return($g->guid()) if($g->default_guid());
    }
}

sub groups {
    my $self = shift;
    my $args = shift;
    
    my $id = CIF::APIKey->retrieve(uuid => $args);
    return unless($id);
    
    my @groups = $id->groups();
    return unless($#groups > -1);
    
    @groups = map { $_->guid() } @groups;
    return(\@groups);
}

sub expired {
    my $self = shift;
    my $args = shift;
    
    my $id = CIF::APIKey->retrieve(uuid => $args);
    return 0 unless($id->expires());
    
    my $time = DateTime::Format::DateParse->parse_datetime($id->expires());
    return 1 if(time() > $time);
    return 0;
}
    
1;
