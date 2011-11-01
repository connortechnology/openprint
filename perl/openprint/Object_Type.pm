use strict;
package openprint::Object_Type;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table %fields %transforms %defaults $serial );

$debug = 1;
$table = 'object_types';
$serial = 'object_types_id_seq';
%fields = (
	'id'		=>	'id',
	'name'		=>	'name',
	'human'		=>	'human',
);
%defaults = (
);

1;
__END__
