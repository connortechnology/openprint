package openprint::Usergroup;
@ISA = qw( openprint::Object );
use strict;
require sql;

use vars qw( %fields %transforms %defaults );

my $debug = 1;

%fields = (
	'id'			=>	'id',
	'name'			=>	'name',
);

%transforms = (
);

%defaults = ( 
);

# Similar to Ruby style.... takes an optional hash ref to determine filters
# Currently returns an array of id/name pairs maybe someday should return an array of objects...
sub find {
	my %params = @_;

	my $sql;
	my @values;
	$sql = q{SELECT * FROM UserGroups WHERE 1>0};
	if ( $params{'name'} ) {
		$sql .= q{ AND name=?};
		push @values, $params{'name'};
	} # end if
	if ( $params{'user_id'} ) {
		$sql .= ' AND id IN (SELECT usergroup_id FROM users_in_usergroups WHERE user_id=?)';
		push @values, $params{'user_id'};
	} # end if
	$sql .= " OR $params{'or'}" if $params{'or'};
	$sql .= " ORDER BY $params{'order'}" if ( $params{'order'} );
	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->error( "Error loading UserGroup ($sql) (@values) :" . $openprint::dbh->errstr );
	} elsif ( $debug ) {
		$openprint::log->debug( $sql . join(',',@values). ' Number of results: ' . @$data );
	} # end if

	return map { new openprint::Usergroup( $_->{id}, $_ ) } @$data;
} # end if

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( q{SELECT * FROM Usergroups WHERE id=?}, {}, $$self{'id'} );
	} # end if
	@$self{keys %fields} = @$data{@fields{keys %fields}};
} # end sub load

1;
__END__
