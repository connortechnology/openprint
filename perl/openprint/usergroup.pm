package openprint::usergroup;
use strict;
require sql;

use vars qw( %cache %groups_cache );

sub init_cache {
    %cache = ();
    %groups_cache = sql::execute( undef, undef, q{SELECT name, id FROM usergroups} );
}


# Similar to Ruby style.... takes an optional hash ref to determine filters
# Currently returns an array of id/name pairs maybe someday should return an array of objects...
sub find {
	my %params = @_;

	return sql::execute( undef, undef, q{SELECT id, name FROM UserGroups ORDER BY lower(name)} );
} # end if

sub names {
	my( $log, $dbh, @ids ) = @_;

	return if ! @ids;
	return sql::execute( $log, $dbh, "SELECT name FROM usergroups WHERE id IN (".join(',',@ids).")" );
} # end sub names

sub is_user_in {
	my ( $groups, $user_id ) = @_;

	if ( ! exists $cache{$user_id} ) {
        @{$cache{$user_id}} = sql::execute(undef, undef, 'SELECT usergroup_id FROM users_in_usergroups WHERE user_id=?', $user_id );
    } # end if
	if ( ! %groups_cache ) {
		%groups_cache = sql::execute( undef, undef, q{SELECT name, id FROM usergroups} );
	} # end if

	# If the groups don't exist, then default to true
	if ( ! @groups_cache{@$groups} ) {
		return @$groups;
	} # end if
	
    return sets::intersection( @{$cache{$user_id}}, @groups_cache{@$groups} );
} # end if

1;
__END__
