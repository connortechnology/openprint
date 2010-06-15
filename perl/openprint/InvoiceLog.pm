package openprint::InvoiceLog;
@ISA = qw(openprint::Object);

use vars qw( %config $log $dbh %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

my $debug = 1;

use strict;
use vars qw( $table $serial %fields %defaults %transforms );

require sql;

$table = 'invoice_logs';
$serial = 'invoice_logs_id_seq';

%fields = (
	'id'				=>	'id',
	'invoice_id'		=>	'invoicer_id',
	'user_id'			=>	'user_id',
	'created_on'		=>	'created_on',
	'description'		=>	'description',
);

%transforms = (
);
%defaults = (
	'created_on'	=> 'NOW()',
);

sub User {
	return new openprint::User( $_[0]->user_id() );
} # end sub User

1;

__END__
~       
