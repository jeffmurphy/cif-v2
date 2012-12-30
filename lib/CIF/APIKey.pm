package CIF::APIKey;
use Moose;


has 'uuid' => ( isa => 'Str', is => 'rw' ); 
has 'uuid_alias' => ( isa => 'Str', is => 'rw' ); 
has 'description' => ( isa => 'Str', is => 'rw' ); 
has 'parentid' => ( isa => 'Str', is => 'rw' ); 
has 'revoked' => ( isa => 'Str', is => 'rw' ); 
has 'write' => ( isa => 'Bool', is => 'rw' ); 
has 'restricted_access' => ( isa => 'Bool', is => 'rw' ); 
has 'expires' => ( isa => 'Int', is => 'rw' ); 
has 'created' => ( isa => 'Int', is => 'rw' ); 
has 'groupsMap' => ( isa => 'HashRef[Str]', is => 'rw' );
has 'default' => ( isa => 'Str', is => 'rw');


use Carp qw(cluck);

use CIF qw/is_uuid generate_uuid_random generate_uuid_url generate_uuid_ns/;

sub Xnew {
	my $class = shift;
    my $self = {};
    bless $self, $class;
    
    my $p = shift;

	for my $k (keys %$p) {
		$self->set($k, $p->{$k});
	}
	
    return $self;
}


sub groups {
	my $self = shift;
	if (exists $self->{groupsMap}) {
		return keys %{$self->{groupsMap}};
	}
	return ();
}

=pod

retrieve ('uuid' => $uuid)

__PACKAGE__->columns(Primary => 'uuid');
__PACKAGE__->columns(All => qw/uuid uuid_alias description parentid revoked write restricted_access expires created/);

=cut

sub retrieve {
    my $class = shift;
    my %keys = @_;

    cluck "CIF::APIKey::retrieve()";

    return;
}

=pod

add_groups($default_guid, [group list])

=cut

sub add_groups {
    my ($self,$default_guid,$groups) = @_;
    
    if ($default_guid){
        $default_guid = generate_uuid_url($default_guid) unless(is_uuid($default_guid));
    }

    foreach (@$groups){
        $_ = generate_uuid_url($_) unless(is_uuid($_));
        my $isDefault = 1 if($default_guid && ($_ eq $default_guid));
        my $id = eval {
            CIF::APIKeyGroups->insert({
                uuid            => $self->uuid(),
                guid            => $_,
                default_guid    => $isDefault,
            });
        };
        if($@){
            die($@) unless($@ =~ /unique constraint/);
        }
    }
}

sub default_guid {
    my $self = shift;
    my @groups = $self->groups();
    foreach (@groups){
        return($_->guid()) if($_->default_guid());
    }
    # this shouldn't happen... in theory.
    return(0);
}

sub inGroup {
    return in_group(@_);
}

sub in_group {
    my $self = shift;
    my $grp = shift;
    
    return unless($grp);
    $grp = lc($grp);
    $grp = generate_uuid_ns($grp) unless(is_uuid($grp));

    my @groups = $self->groups();
    foreach (@groups){
        return(1) if($grp eq $_->guid());
    }
    return(0);
}

sub mygroups {
    return groups(\@_);
}

sub my_groups {
    my $self = shift;
    
    my @groups = $self->groups();
    return unless($#groups > -1);
    my $g = '';
    foreach (@groups){
        $g .= $_->guid().',';
    }
    $g =~ s/,$//;
    return $g;
}

## TODO -- move this to PROFILE
sub expired {
    my $self = shift;
    my $args = shift;

    return 0 unless($self->expires());
    
    my $time = DateTime::Format::DateParse->parse_datetime($self->expires());
    return 1 if(time() > $time);
    return 0;
}

1;