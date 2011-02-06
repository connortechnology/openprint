use strict;
package openprint::Event;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table $serial %fields %transforms %defaults );
$table = 'events';
$serial = 'events_id_seq';

%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
	'occuring_on'	=>	'occuring_on',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
	'deleted'		=>	'deleted',
);

%defaults = (
	'created_on'	=>	q`'NOW()'`,
);

1;
__END__
