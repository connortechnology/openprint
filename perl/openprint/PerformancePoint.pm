use strict;
require openprint::Equipment;
use openprint ();

package openprint::PerformancePoint_Type;
our @ISA = qw( openprint::Object );
use vars qw( $table $serial %fields %transforms %defaults );
$table = 'performancepoint_types';
$serial = 'performancepoint_types_id_seq';
%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
	'category'	=>	'category',
);

sub delete {
	my $error;
	my $ac = sql::start_transaction( $openprint::dbh );
	foreach my $Point ( openprint::PerformancePoint->find('type_id'=>$_[0]{'id'}) ) {
		last if $error .= $Point->delete();
	} # end foreach Point
	$error .=  $_[0]->SUPER::delete() if ! $error;
	sql::end_transaction( $openprint::dbh, $ac );
	return $error;
} # end sub delete

package openprint::PerformancePoint_Record;
our @ISA = qw( openprint::Object );
use vars qw( $table $serial %fields %transforms %defaults );
$table = 'performancepoint_records';
$serial = 'performancepoint_records_id_seq';
%fields = (
	'type_id'	=>	'type_id',
	'shift_id'		=>	'shift_id',
	'operator_id'	=>	'operator_id',
	'total'		=>	'total',
	'quantity'	=>	'quantity',
);

sub Shift {
	return new openprint::Shift( $_[0]{'shift_id'} );
} # end sub Shift;
sub Type {
	return new openprint::PerformancePoint_Type( $_[0]{'type_id'} );
} # end sub Type

package openprint::PerformancePoint;
our @ISA = qw( openprint::Object );

use vars qw( $table $serial %fields %transforms %defaults @identified_by );

$table = 'performancepoints';
$serial = 'performancepoints_id_seq';

@identified_by = ('type_id','equipment_id');

%fields = (
	'type_id'		=>	'type_id',
	'type'			=>	undef,
	'units'			=>	'units',
	'equipment_id'	=>	'equipment_id',
	'value'			=>	'value',
	'max_value'		=>	'max_value',
);

%defaults = (
	'value'		=>	undef,
	'max_value'		=>	undef,
	'type_id'	=>	undef,
);

%transforms = (
);

sub Type {
	return new openprint::PerformancePoint_Type( $_[0]{'type_id'} );
} # end sub Type

sub Equipment {
	return new openprint::Equipmetn( $_[0]{'equipment_id'} );
} # end sub Equipment

1;
__END__
