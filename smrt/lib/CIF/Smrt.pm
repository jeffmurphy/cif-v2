package CIF::Smrt;

use 5.011;
use strict;
use warnings;
use threads;
use namespace::autoclean;

# version info
our $VERSION = '2.0000_01'; #2.00.00-alpha.1
$VERSION = eval $VERSION;  # see L<perlmodstyle>

# moose stuff
use Moose;
use MooseX::FollowPBP;
use MooseX::Aliases;

# cif support
use CIF qw/generate_uuid_url generate_uuid_random is_uuid debug normalize_timestamp/;
use CIF::Msg;
use CIF::Type;
use CIF::EventBuilder;
use CIF::Client;
#use CIF::Msg::Control;
#use CIF::Msg::Support;

# other
use Data::Dumper;
use Try::Tiny;
use Time::HiRes qw/nanosleep/;
use ZMQ;
use ZMQ::Constants ':all';
use Net::SSLeay;
Net::SSLeay::SSLeay_add_ssl_algorithms();
use Config::Simple;

# we're using ipc instead of inproc cause perl sucks
# at sharing context's with certain types of sockets (ZMQ_PUSH in particular)
use constant WORKER_CONNECTION      => 'ipc:///tmp/workers';
# this is used to return back the total sum of recs processed by the analytics
# i'm sure there's a better way to do this
use constant WORKER_SUM_CONNECTION  => 'ipc:///tmp/workers_sum';
use constant RETURN_CONNECTION      => 'ipc:///tmp/return';
use constant SENDER_CONNECTION      => 'ipc:///tmp/sender';
use constant CTRL_CONNECTION        => 'ipc:///tmp/ctrl';

# for figuring out throttle
use constant DEFAULT_THROTTLE_FACTOR => 4;

# the lower this is, the higher the chance of 
# threading collisions resulting in a seg fault.
# the higher the thread count, the higher this number needs to be
use constant NSECS_PER_MSEC     => 1_000_000;

use constant DEFAULT_CONFIG_PATH => $ENV{'HOME'}.'/.cif1';

has 'config'    => (
    is  => 'rw',
    isa => 'HashRef',
);

has 'threads'  => (
    is      => 'ro',
    isa     => 'Int',
    default     => 1,
);

has 'token'     => (
    is          => 'ro',
    isa         => 'CIF::Type::LowercaseUUID',
    alias       => 'apikey',
);

has 'goback'    => (
    is      => 'ro',
    isa     => 'Int',
    default => 3,
);

has 'eventbuilder' => (
    is      => 'ro',
    isa     => 'CIF::EventBuilder',
);

has 'fetcher'   => (
    is      => 'ro',
);

has 'max_batch' => (
    is      => 'ro',
    isa     => 'Int',
    default => '500',
);

has 'wait_for_server'   => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has 'name'  => (
    is  => 'ro',
    isa => 'Str',
    default => 'localhost',
);

has 'instance'  => (
    is      => 'ro',
    isa     => 'Str',
    default => 'localhost',
);

has 'client'   => (
    is      => 'ro',
    isa     => 'CIF::Client',
);

has 'parser'    => (
    is      => 'ro',
    isa     => 'Str',
);

has 'rule'      => (
    is      => 'ro',
    isa     => 'HashRef',
);

has 'feed'      => (
    is      => 'ro',
    isa     => 'Str',
);

around BUILDARGS => sub {
    my $origin  = shift;
    my $self    = shift;
    my $args    = shift;   

    $args->{'config'} = $CIF::DEFAULT_CONFIG_PATH unless($args->{'config'});
    $args->{'config'} = Config::Simple->new($args->{'config'}) unless(ref($args->{'config'}) eq 'Config::Simple');
    
    $args->{'client'} = CIF::Client->new({
        config  => $args->{'config'},
    });
    
    $args->{'config'} = $args->{'config'}->get_block('smrt');
    
    # override default config
    $args = { %{$args->{'config'}}, %$args };

    $args->{'fetcher'} = CIF::Smrt::FetcherFactory->new_plugin({ config => $args->{'rule'} });
    
    $args->{'parser'} = CIF::Smrt::ParserFactory->new_plugin({ config => $args->{'rule'} });
   
    return $self->$origin($args);
};

sub BUILD {
    my $self = shift;
    my $args = shift;
    
     
}

1;
