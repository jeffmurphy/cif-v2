package CIF::Smrt::Fetcher::Plugin;

use strict;
use warnings;
use namespace::autoclean;

use Moose::Role;
use MooseX::Aliases;
use MooseX::FollowPBP;

# http://stackoverflow.com/questions/10954827/perl-moose-how-can-i-dynamically-choose-a-specific-implementation-of-a-metho
requires qw(understands process);

has 'TLS_verify_mode' => (
    is      => 'ro',
    isa     => 'Str',
    alias   => ['tls_verify', 'SSL_verify_mode']
);

1;