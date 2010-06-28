package openprint::InvoiceLog;
@ISA = qw(openprint::Object);

my $debug = 1;

use strict;
use vars qw( $table $serial %fields %defaults %transforms );

require sql;

$table = 'invoice_logs';
$serial = 'invoice_logs_id_seq';

%fields = (
	'id'				=>	'id',
	'invoice_id'		=>	'invoice_id',
	'user_id'			=>	'user_id',
	'created_on'		=>	'created_on',
	'description'		=>	'description',
);

%transforms = (
);
%defaults = (
	'created_on'	=> 'NOW()',
);

1;
__END__
