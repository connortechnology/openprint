use strict;
package openprint::PaymentType;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 0;
$table = 'paymenttypes';
$serial = 'paymenttypes_id_seq';

%fields = (
	id			=>	'id',
	name		=>	'name',
	description	=>	'description',
	created_on	=>	'created_on',
	updated_on	=>	'updated_on',
);
%defaults = (
	created_on	=>	q`'NOW()'`,
);

1;
__END__
