use strict;
package openprint::Link;
@ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 1;
%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
	'href'	=>	'href',
	'count'	=>	'count',
	'sorting'	=>	'sorting',
);
1;
__END__
