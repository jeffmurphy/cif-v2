package CIF::Client::Query;
use base 'Class::Accessor';

use strict;
use warnings;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use Digest::SHA1 qw/sha1_hex/;
use CIF qw(is_uuid);
use CIF::Msg;
use Data::Dumper;
use Carp qw(cluck);

my @plugins = __PACKAGE__->plugins();

__PACKAGE__->follow_best_practice();
__PACKAGE__->mk_accessors(qw(
    apikey limit confidence
    guid description feed
));

sub new {
    my $class   = shift;
    my $args    = shift;
      
    my $self = {};
    bless($self,$class);
        
    my ($err,$ret);
    foreach my $p (@plugins){
        ($err,$ret) = $p->process($args);
        return($err) if($err);
        last if($ret);
    }   
   
    $ret = \%$args unless($ret);

    $ret = [$ret] unless(ref($ret) eq 'ARRAY');
      
    my $qRequest = {
		'query' => [],
		'feed' => 0
    };
    
    
    foreach my $qq (@{$ret}){
    print "query ". $qq->{query}."\n";
    	
        $qq->{'query'} = lc($qq->{'query'});
        # reworked in v3
        #$qq->{'query'} = sha1_hex($qq->{'query'}) unless($qq->{'query'} =~ /^[a-f0-9]{32,40}$/ || is_uuid($qq->{'query'}) );
        
        ## don't ask, its' all crap.
        $qRequest->{'limit'}        = $qq->{'limit'} if($qq->{'limit'});
        $qRequest->{'description'}  = $qq->{'description'} if($qq->{'description'});
        $qRequest->{'feed'}         = $qq->{'feed'} if($qq->{'feed'});
        $qRequest->{'confidence'}   = $qq->{'confidence'} if($qq->{'confidence'});
        
        push @{$qRequest->{'query'}}, { 'query' => $qq->{'query'}, 'nolog' => $qq->{'nolog'} };
    
    }

    return (undef, $qRequest);
}

# skel
sub process {}

1;