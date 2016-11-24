use strict;
package openprint::ZM_Server;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %defaults %transforms );
$debug = 0;
$table = 'Servers';

%fields = (
	id			=>	'Id',
	Name			=>	'Name',
	Hostname	=>	'Hostname',
);

1;
__END__
