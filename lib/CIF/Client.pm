package CIF::Client;
use base 'Class::Accessor';

use strict;
use warnings;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use Try::Tiny;
use Config::Simple;
use Digest::SHA1 qw/sha1_hex/;
use Compress::Snappy;
use MIME::Base64;
use Iodef::Pb::Simple qw/iodef_addresses iodef_confidence iodef_impacts/;
use Regexp::Common qw/net/;
use Regexp::Common::net::CIDR;
use Net::Patricia;
use URI::Escape;
use Digest::SHA qw/sha1_hex/;
use Digest::MD5 qw/md5_hex/;
use Encode qw(encode_utf8);
use Data::Dumper;

use CIF qw(generate_uuid_ns is_uuid debug);
use CIF::Msg;
use CIF::Msg::Feed;

__PACKAGE__->follow_best_practice();
__PACKAGE__->mk_accessors(qw(
    config driver_config global_config driver apikey 
    nolog limit guid filter_me no_maprestrictions
    table_nowarning related
));

our @queries = __PACKAGE__->plugins();
@queries = map { $_ =~ /::Query::/ } @queries;

sub new {
    my $class = shift;
    my $args = shift;
    
    return(undef,'missing config file') unless($args->{'config'});
    
    $args->{'config'} = Config::Simple->new($args->{'config'}) || return(undef,'missing config file');
    
    my $self = {};
    bless($self,$class);
        
    $self->set_global_config(   $args->{'config'});
    $self->set_config(          $args->{'config'}->param(-block => 'client'));
    $self->set_driver(          $self->get_config->{'driver'} || 'HTTP');
    $self->set_driver_config(   $args->{'config'}->param(-block => 'client_'.lc($self->get_driver())));
    $self->set_apikey(          $args->{'apikey'} || $self->get_config->{'apikey'});
    
    $self->{'guid'}             = $args->{'guid'}               || $self->get_config->{'default_guid'};
    $self->{'limit'}            = $args->{'limit'}              || $self->get_config->{'limit'};
    $self->{'compress_address'} = $args->{'compress_address'}   || $self->get_config->{'compress_address'};
    $self->{'round_confidence'} = $args->{'round_confidence'}   || $self->get_config->{'round_confidence'};
    $self->{'table_nowarning'}  = $args->{'table_nowarning'}    || $self->get_config->{'table_nowarning'};
    
    $self->{'group_map'}        = (defined($args->{'group_map'})) ? $args->{'group_map'} : $self->get_config->{'group_map'};
    
    $self->set_no_maprestrictions(  $args->{'no_maprestrictions'}   || $self->get_config->{'no_maprestrictions'});
    $self->set_filter_me(           $args->{'filter_me'}            || $self->get_config->{'filter_me'});
    $self->set_nolog(               $args->{'nolog'}                || $self->get_config->{'nolog'});
    $self->set_related(             $args->{'related'}              || $self->get_config->{'related'});
    
    my $nolog = (defined($args->{'nolog'})) ? $args->{'nolog'} : $self->get_config->{'nolog'};
    
    if($args->{'fields'}){
        @{$self->{'fields'}} = split(/,/,$args->{'fields'}); 
    } 
    
    my $driver     = 'CIF::Client::Transport::'.$self->get_driver();
    my $err;
    try {
        $driver     = $driver->new({
            config  => $self->get_driver_config()
        });
    } catch {
        $err = shift;
    };
    if($err){
        debug($err) if($::debug);
        return($err);
    }
    
    $self->set_driver($driver);
    return (undef,$self);
}

sub search {
    my $self = shift;
    my $args = shift;
    
    my $filter_me   = $args->{'filter_me'} || $self->get_filter_me();
    my $nolog       = (defined($args->{'nolog'})) ? $args->{'nolog'} : $self->get_nolog();
    my $no_decode   = $args->{'no_decode'};
    
    unless($args->{'apikey'}){
        $args->{'apikey'} = $self->get_apikey();
    }

    unless(ref($args->{'query'}) eq 'ARRAY'){
        my @a = split(/,/,$args->{'query'});
        $args->{'query'} = \@a;
    }
    
    my @queries;
    my @orig_queries = @{$args->{'query'}};
    
    # we have to pass this along so we can check it later in the code
    # for our original queries since the server will give us back more 
    # than we asked for
    my $ip_tree = Net::Patricia->new();
    debug('generating query') if($::debug);
    foreach my $q (@{$args->{'query'}}){
        my ($err,$ret) = CIF::Client::Query->new({
            query       => $q,
            apikey      => $args->{'apikey'},
            limit       => $args->{'limit'},
            confidence  => $args->{'confidence'},
            guid        => $args->{'guid'},
            nolog       => $args->{'nolog'},
            description => $args->{'description'} || 'search '.$q,
            pt          => $ip_tree,
            
            ## TODO -- not sure how else to do this atm
            ## needs to be passed to the IPv4 query so we
            ## can get back the tree and check it against the feed
        });
        return($err) if($err);
        push(@queries,$ret) if($ret);
    }        
        
    my $msg =  $self->get_driver->make_control_message(
  		"cif-db",
  		CIF::Msg::ControlType::MsgType::COMMAND(), 
  		CIF::Msg::ControlType::CommandType::CIF_QUERY_REQUEST()
  		);
  	
    $msg->{queryRequestList} = \@queries;

    
    debug('sending query') if($::debug);
    my ($err, $ret) = $self->get_driver->send_direct($msg);
    #my ($err,$ret) = $self->send($msg);
    
    return $err if($err);
    $ret = CIF::Msg::ControlType->decode($ret);
 
    unless($ret->get_status() == CIF::Msg::ControlType::StatusType::SUCCESS()){
        return('failed: '.@{$ret->get_data()}[0]) if($ret->get_status() == CIF::Msg::ControlType::StatusType::FAILED());
        return('unauthorized') if($ret->get_status() == CIF::Msg::ControlType::StatusType::UNAUTHORIZED());
    }
    
    return (undef,$ret->{'queryResponseList'});
}

sub send {
    my $self = shift;
    my $msg = shift;

    return $self->get_driver->send($msg);
}

sub submit {
    my $self = shift;
    my $data = shift;
    
    my $nitems = @$data;
    
    my $msg = CIF::Msg::MessageType->new({
    	version => CIF::Msg::Support::getOurVersion("Message"),
        type    => CIF::Msg::MessageType::MsgType::SUBMISSION(), 
        apikey  => $self->get_apikey(),
		submissionRequest => $data
    });
        
    my ($err,$ret) = $self->send($msg);
    
    return('ERROR: server failure, contact system administrator') unless($ret);
    
    $ret = CIF::Msg::MessageType->decode($ret);
    
    unless($ret->get_status() != CIF::Msg::MessageType::StatusType::SUCCESS()){
        return('ERROR: ' . $ret->{statusMsg}) if($ret->get_status() == CIF::Msg::MessageType::StatusType::FAILED());
        return('ERROR: unauthorized') if($ret->get_status() == CIF::Msg::MessageType::StatusType::UNAUTHORIZED());
    }
    
    # on success, pass the number of successfully submitted objects back to the
    # caller
    $ret->{statusMsg} = $nitems;
    
    return (undef,$ret);
}    

sub new_submission {
    my $self = shift;
    my $args = shift;

    my $data = (ref($args->{'data'}) eq 'ARRAY') ? $args->{'data'} : [$args->{'data'}];
 
	my @rv;
    foreach (@$data){
#TODO this decision should be in the driver, not at this layer
#v1        $_ = encode_base64(Compress::Snappy::compress($_));
		push @rv, {
#TODO we lose the 'type' along the way. at this pt we are iodef only
#TODO in the future, we'll need to have the type passed into us
			'baseObjectType' => 'RFC5070_IODEF_v1_pb2',
			'data' => $_
		};
    }
    
    return \@rv;
}
1;
