package CIF::Smrt::Fetcher::Plugin::Uri;

use strict;
use warnings;
use namespace::autoclean;

# moose stuff
use Moose;
use MooseX::FollowPBP;
use MooseX::Aliases;
use MooseX::NonMoose;

extends 'LWP::UserAgent';
with 'CIF::Smrt::Fetcher::Plugin';

use constant DEFAULT_AGENT => 'cif-smrt/'.$CIF::VERSION.' (csirtgadgets.org)';

has 'capacity' => (
    is      => 'ro',
    isa     => 'Int',
    default => 5,
);

has 'uri' => (
    is  => 'ro',
    isa => 'Str',
);

#has 'agent' => (
#    is      => 'rw',
#    isa     => 'Str',
#    default => sub { DEFAULT_AGENT() },
#);

has 'token' => (
    is      => 'ro',
    isa     => 'Str',
    alias   =>  ['password','pass','apikey','key'],
);

sub understands {
    my $self = shift;
    my $args = shift;
    
    return 1 if($args->{'feed'} =~ /^http/);
}

sub process {
    my $self = shift;
    my $args = shift;
    
}

sub BUILD {
    my $self    = shift;
    my $args    = shift;
  
    # setup custom stuff
    $self->agent(DEFAULT_AGENT());
    $self->conn_cache({ total_capacity  => $self->get_capacity() });
    
    unless($self->get_TLS_verify_mode()){
        $self->ssl_opts(SSL_verify_mode => 'SSL_VERIFY_NONE');
        $self->ssl_opts(verify_hostname => 0);
    }
    if($args->{'proxy'}){
        $self->proxy(['http','https'],$args->{'proxy'});
    } else {
        $self->env_proxy();
    }
    die ::Dumper($self);
}

__PACKAGE__->meta->make_immutable();

1;