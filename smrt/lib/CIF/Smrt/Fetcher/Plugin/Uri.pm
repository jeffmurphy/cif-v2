package CIF::Smrt::Fetcher::Plugin::Uri;

use strict;
use warnings;
use namespace::autoclean;

# moose stuff
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::FollowPBP;
use MooseX::Aliases;
use MooseX::NonMoose;

# cif stuff
use CIF::Type;

extends 'LWP::UserAgent';
with 'CIF::Smrt::Fetcher::Plugin';

has 'capacity' => (
    is      => 'ro',
    isa     => 'Int',
    default => 5,
);

has 'uri' => (
    is          => 'ro',
    isa         => 'CIF::Type::Uri',
    alias       => ['feed','url'],
    required    => 1,
    coerce      => 1,
);

has 'TLS_verify_mode' => (
    is      => 'ro',
    isa     => 'Str',
    alias   => ['tls_verify', 'SSL_verify_mode']
);

sub understands {
    my $self = shift;
    my $args = shift;
    
    return 0 unless($args->{'feed'});
    return 1 if($args->{'feed'} =~ /^(http|ftp|scp)/);
}

sub process {
    my $self = shift;
    my $args = shift;
    
    #die ::Dumper($self);
}

around BUILDARGS => sub {
    my $orig = shift;
    my $self = shift;
    my %args = @_;
  
    #$args{'feed'} = URI->new($args{'feed'});

    return $self->$orig(%args);
};

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
}

__PACKAGE__->meta->make_immutable();

1;