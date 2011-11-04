use strict;
package openprint::UserGroup;
our @ISA = qw(openprint::Object);

require openprint::User;

use vars qw( $debug $table $serial %fields %find_fields %transforms %defaults );
$debug = 1;

$table = 'usergroups';
$serial= 'usergroups_id_seq';
%fields = (
    'id'    =>  'id',
    'name' =>  'name',
);
%find_fields = (
    'user_id'       =>  '(SELECT user_id FROM users_in_usergroups WHERE usergroup_id=usergroups.id)',
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
