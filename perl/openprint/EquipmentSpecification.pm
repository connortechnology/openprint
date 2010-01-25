package openprint::EquipmentSpecification;
@ISA = qw( openprint::Object );
use strict;
use openprint ();
use openprint::Equipment;
require sql;

use vars qw( $log $dbh $table $serial %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

my $debug = 0;
$table = 'tbl_Equipment_Specifications';
$serial = 'tbl_equipment_specifications_id_seq';

%fields = (
	'id'			=>	'id',
	'equipment_id'	=>	'lngequipmentindex',
	'min'			=>	'dblmin',
	'max'			=>	'dblmax',
	'units'			=>	'strunits',
	'name'			=>	'strname',
	'value'			=>	'strvalue',
	'interpolate'	=>	'interpolate',
);
%transforms = (
	'min' => [ 's/[^\d\.]//g' ],
	'max' => [ 's/[^\d\.]//g' ],
);
%defaults = (
	'min'	=>	undef,
	'max'	=>	undef,
);


sub find {
	my %params = @_;

	if ( $params{'id'} ) {
		return new openprint::EquipmentSpecification( $params{'id'} );
	} else {
		my $sql;
		my @values;
		$sql = q{SELECT * FROM tbl_Equipment_Specifications WHERE 1>0};
		if ( $params{'Equipment'} and $params{'Equipment'}->id() ) {
			$sql .= q{ AND lngEquipmentIndex=?};
			push @values, $params{'Equipment'}->id();
		} # end if
		if ( $params{'equipment_id'} ) {
			$sql .= q{ AND lngEquipmentIndex=?};
			push @values, $params{'equipment_id'};
		} # end if

		if ( $params{'name'} ) {
			$sql .= q{ AND strName=?};
			push @values, $params{'name'};
		} # end if

		$sql .= " OR $params{'or'}" if $params{'or'};
		$sql .= " ORDER BY $params{'order'}" if ( $params{'order'} );
		my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
		if ( ! $data ) {
			$log->error( "Error loading Equipment Specification ($sql) (@values) :" . $dbh->errstr );
			return;
		} elsif ( $debug ) {
			$log->debug( 'EquipemetnSpecifications::find: ' . $sql . join(',',@values) . " # results: " . @$data );
		} # end if
		
		return map { new openprint::EquipmentSpecification( $_->{id}, $_ ) } @$data;
	} # end if
} # end sub find

sub Equipment {
	my $self = shift;
	return new openprint::Equipment( $$self{equipment_id} );
} # end sub Equipment


1;
__END__
