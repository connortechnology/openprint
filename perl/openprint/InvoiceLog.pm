package openprint::InvoiceLog;
@ISA = qw(openprint::Object);

use strict;
use vars qw( $debug $table $serial %fields %defaults %transforms );

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
