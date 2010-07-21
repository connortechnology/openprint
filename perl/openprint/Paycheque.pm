package openprint::Paycheque;
@ISA = qw(openprint::Object);

use strict;
use vars qw( $debug $table $serial %fields %defaults %transforms );

require sql;
$debug = 1;

$table = 'paycheques';
$serial = 'paycheque_id_seq';

%fields = (
	'id'				=>	'id',
	'employer_id'		=>	'employer_id',
	'employee_id'		=>	'employee_id',
	'total'				=>	'total',
	'created_on'		=>	'created_on',
	'updated_on'		=>	'updated_on',
	'currency_id'		=>	'currency_id',
	'internal_notes'	=>	'internal_notes',
	'external_notes'	=>	'external_notes',
	'paid_on'			=>	'paid_on',
	'deleted'			=>	'deleted',
);

%transforms = (
);
%defaults = (
	'deleted'		=>	0,
	'created_on'	=> 'NOW()',
	'updated_on'	=> 'NOW()',
	'paid_on'		=> 'NOW()',
	'total'			=>	undef,
);


sub Employer {
	return new openprint::Company( $_[0]{employer_id} );
} # end sub Payor

sub Employee {
	return new openprint::User( $_[0]{employee_id} );
} # end sub Recipient

sub add_Timetrack {
	my ( $self, $Timetrack ) = @_;
	sql::insert( undef, undef, 'paycheques_timetracks', 'timetrack_id', $Timetrack->id(), 'paycheque_id', $$self{id} );
} # end sub add_Timetrack

sub del_Timetrack {
	my ( $self, $Timetrack ) = @_;

	sql::execute( undef, undef, 'DELETE FROM paycheques_timetracks WHERE paycheque_id=? AND timetrack_id=?', $$self{id}, $$Timetrack{'id'} );
} # end sub del_Timetrack

1;
__END__
