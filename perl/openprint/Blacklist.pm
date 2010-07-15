package openprint::Blacklist;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use openprint ();
use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 1;

$table = 'blacklist';
$serial = '';

%fields = (
	'id'			=>	'ip',
	'ip'			=>	'ip',
	'count'			=>	'count',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
);

%transforms = (
);

%defaults = (
);

1;
__END__
