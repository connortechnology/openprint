use strict;
package openprint::Inventory_Check;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 0;
$table = 'inventory_checks';
$serial= 'inventory_checks_id_seq';
%fields = (
	id		=>	'id',
	name	=>	'name',
	created_on	=>	'created_on',
	started_on	=>	'started_on',
	ended_on	=>	'ended_on',
);
%transforms = (
	name	=> [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%defaults = (
	created_on	=>	q`'NOW()'`,
	started_on	=>	q`'NOW()'`,
);

1;
__END__
