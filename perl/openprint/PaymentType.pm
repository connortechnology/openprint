package openprint::PaymentType;
@ISA = qw(openprint::Object);

use strict;

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 1;
$table = 'paymenttypes';
$serial = 'paymenttypes_id_seq';

%fields = (
	'id'			=>	'id',
	'name'			=>	'name',
	'description'	=>	'description',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
);

1;
__END__
