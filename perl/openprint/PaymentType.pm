package openprint::PaymentType;
@ISA = qw(openprint::Object);

use strict;

require sql;
use openprint ();
use vars qw( $log $dbh $table $serial %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$table = 'paymenttypes';
$serial = 'paymenttypes_id_seq';

%fields = (
	'id'			=>	'id',
	'name'			=>	'name',
	'description'	=>	'description',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
);
my $debug = 1;


1;

__END__
~       
