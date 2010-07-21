package openprint::Whitelist;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use openprint ();
use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 1;

$table = 'whitelist';
$serial = '';

%fields = (
	'id'			=>	'ip',
	'ip'			=>	'ip',
	'created_on'	=>	'created_on',
	'description'	=>	'description',
);

%transforms = (
);

%defaults = (
);

1;
__END__
