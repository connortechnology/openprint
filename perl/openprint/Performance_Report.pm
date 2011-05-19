use strict;
use openprint ();
require openprint::Shift;
require openprint::User;
require openprint::Performance_Record;

package openprint::Performance_Report;
our @ISA = qw( openprint::Object );


# A performanceReport appliedsto a shift + operator
# It is a collection of PerformanceRecords

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 1;
$table = 'performance_reports';
$serial = 'performance_reports_id_seq';
%fields = (
	'id'	=>	'id',
	'shift_id'	=>	'shift_id',
	'operator_id'	=>	'operator_id',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
	'deleted'		=>	'deleted',
);

%transforms = (
);
%defaults = (
	'deleted'	=>	0,
);

sub Shift {
	return new openprint::Shift( $_[0]{'shift_id'} );
} # end sub Shift;
sub Operator {
	return new openprint::User( $_[0]{'operator_id'} );
}
sub Records {
	my $self = shift;
	my %param = @_;
	$param{'record_id'} = $$self{'id'};
	return openprint::Performance_Record->find(%param);
} # end sub Records
1;
__END__
