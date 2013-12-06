use Test::More;

use strict;
use warnings;
use 5.011;

BEGIN { 
    use_ok('CIF');
    use_ok('CIF::Smrt');
    use_ok('CIF::Smrt::FetcherFactory');
};

use Data::Dumper;

my $ret = CIF::Smrt::FetcherFactory->new_plugin({
    config  => {
        feed    => 'https://example.com:8443/myfeed.json',
    }
});

$ret = CIF::Smrt->new({
    config  => $ENV{'HOME'}.'/.cif',
    rule    => {
        feed        => 'https://example.com:8443/myfeed.json',
        confidence  => 50,
        assessment  => 'botnet',
    }
});

warn ::Dumper($ret);

done_testing();
