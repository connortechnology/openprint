use strict;
use openprint ();

require openprint::Performance_Report;
require openprint::Performance_Point;

package openprint::Performance_Record;
our @ISA = qw( openprint::Object );
use vars qw( $table %fields %transforms %defaults @identified_by );
$table = 'performance_records';

%fields = (
    'type_id'   =>  'type_id',
    #'shift_id'     =>  'shift_id',
    #'operator_id'  =>  'operator_id',
    'total'     =>  'total',
    'quantity'  =>  'quantity',
    'record_id' =>  'record_id',
    'docket'    =>  'docket',
);

#sub Shift {
    #return new openprint::Shift( $_[0]{'shift_id'} );
#} # end sub Shift;

sub Type {
    return new openprint::Performance_Point_Type( $_[0]{'type_id'} );
} # end sub Type

1;
__END__
