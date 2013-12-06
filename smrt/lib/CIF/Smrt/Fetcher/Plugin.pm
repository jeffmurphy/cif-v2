package CIF::Smrt::Fetcher::Plugin;

use strict;
use warnings;
use namespace::autoclean;

use Moose::Role;
use MooseX::Aliases;
use MooseX::FollowPBP;

# http://stackoverflow.com/questions/10954827/perl-moose-how-can-i-dynamically-choose-a-specific-implementation-of-a-metho
requires qw(understands process);

use constant DEFAULT_AGENT => 'cif-smrt/'.$CIF::Smrt::VERSION.' (csirtgadgets.org)';

has 'token'     => (
    is      => 'ro',
    isa     => 'Str',
    alias   =>  ['password','pass','apikey','key'],
);

has 'timeout'   => (
    is      => 'ro',
    isa     => 'Int',
    default => 180,
);

has 'agent'     => (
    is      => 'ro',
    isa     => 'Str',
    default => DEFAULT_AGENT(),
);

1;