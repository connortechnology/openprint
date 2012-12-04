use strict;
package openprint::Test_Result;
our @ISA = qw(openprint::Object);
require openprint::Test_Result_Result;

use vars qw( $table $serial %fields %transforms %defaults );
$table = 'test_results';
$serial = 'test_results_id_seq';

%fields = ( 
	id		=>	'id',
	employee_id	=>	'employee_id',
	workorder_id	=>	'workorder_id',
	technician_id	=>	'technician_id',
	rdate			=>	'rdate',
	tested_on		=>	'tested_on',
	result			=>	undef,
	result_id		=>	'result_id',
	remarks			=>	'remarks',	
	problem_level	=>	'problem_level',
	cost			=>	'cost',
);
%transforms = (
	remarks => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%defaults = ();

sub Result {
    return new openprint::Test_Result_Result( $_[0]{result_id} );
} # end sub Result

sub result {
    if ( @_ > 1 ) {
        my $Result = openprint::Test_Result_Result->find_one('name lc'=> lc $_[1] );
        if ( ! $Result ) {
            $Result = new openprint::Test_Result_Result();
            $Result->save({'name'=>$_[1]});
        } # end if
        $_[0]{'result_id'} = $Result->id();
        $_[0]{'result'} = $Result->name();
    }
    if ( ! $_[0]{'result'} ) {
        $_[0]{'result'} = new openprint::Test_Result_Result( $_[0]{'result_id'} )->name();
    } # end if
    return $_[0]{'result'};
} # end sub result

1;
__END__
