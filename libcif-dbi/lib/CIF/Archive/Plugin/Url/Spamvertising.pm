package CIF::Archive::Plugin::Url::Spamvertising;
use base 'CIF::Archive::Plugin::Url';

use strict;
use warnings;

use Iodef::Pb::Simple qw(iodef_impacts);

__PACKAGE__->table('url_spamvertising');

sub prepare {
    my $class = shift;
    my $data = shift;
    
    my $impacts = iodef_impacts($data->{'data'});
    foreach (@$impacts){
        return 1 if($_->get_content->get_content() =~ /^spamvertising$/);
    }
    return(0);
}

1;
