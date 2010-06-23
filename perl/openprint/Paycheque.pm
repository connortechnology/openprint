package openprint::Paycheque;
@ISA = qw(openprint::Object);

use vars qw( %config $log $dbh %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
use MIME::QuotedPrint;
use MIME::Base64;

my $debug = 1;

use strict;
use vars qw( $table $serial %fields %defaults %transforms );

require sql;

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

sub Currency {
	return new openprint::Currency( $_[0]{currency_id} );
} # end sub Currency

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
~       
