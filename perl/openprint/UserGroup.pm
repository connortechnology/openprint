package openprint::UserGroup;
@ISA = qw(openprint::Object);

use strict;
require openprint::User;

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 1;

$table = 'usergroups';
$serial= 'usergroups_id_seq';
%fields = (
    'id'    =>  'id',
    'name' =>  'name',
);
%transforms = (
    'name' => [ 's/^\s+//', 's/\s+$//' ],
);
%defaults = (
);

sub Users {
	my ( $self, %param ) = @_;
	if ( %param ) {
		$param{'usergroup_id'} = $$self{'id'};
		return openprint::User->find( %param );	
	} elsif ( ! $$self{'Users'} ) {
		$param{'usergroup_id'} = $$self{'id'};
		@{$$self{'Users'}} = openprint::User->find( %param );	
	} # end if
	return @{$$self{'Users'}};
} # end sub Users

1;
__END__
