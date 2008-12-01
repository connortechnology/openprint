package openprint::MaterialSpecification;
@ISA = qw( openprint::Object );
use strict;
use openprint ();
use openprint::Material;
require sql;

use vars qw( $log $dbh $table $serial %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
$table = 'Material_Specifications';
$serial = 'materialspecification_id_seq';

%fields = (
	'id'			=>	'id',
	'material_id'	=>	'material_id',
	'min'			=>	'min',
	'max'			=>	'max',
	'units'			=>	'units',
	'name'			=>	'name',
	'value'			=>	'value',
	'interpolate'	=>	'interpolate',
);

%transforms = (
);
%defaults = (
);

my $debug = 0;
# Returns a paper object specified by the parameters
sub find {
	my %params = @_;

	if ( $params{'id'} ) {
		return new openprint::MaterialSpecification( $params{'id'} );
	} else {
		my $sql;
		my @values;
		$sql = q{SELECT * FROM Material_Specifications WHERE 1>0};
		if ( $params{'Material'} ) {
			$sql .= q{ AND material_id=?};
			push @values, $params{'Material'}->id();
		} # end if
		if ( $params{'material_id'} ) {
			$sql .= q{ AND material_id=?};
			push @values, $params{'material_id'};
		} # end if

		if ( $params{'name'} ) {
			$sql .= q{ AND name=?};
			push @values, $params{'name'};
		} # end if

		$sql .= " OR $params{'or'}" if $params{'or'};
		$sql .= " ORDER BY $params{'order'}" if ( $params{'order'} );
		my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
		if ( ! $data ) {
			$log->error( "Error loading Material Specification ($sql) (@values) :" . $dbh->errstr );
		} elsif ( $debug ) {
		#$log->debug( 'Number of results: ' . @$data );
			$log->debug( $sql . join(',',@values) . ':' . @$data );
		} # end if
		
		return map { new openprint::MaterialSpecification( $_->{id}, $_ ) } @$data;
	} # end if
} # end sub find

1;
__END__
