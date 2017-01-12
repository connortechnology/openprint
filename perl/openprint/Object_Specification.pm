use strict;
package openprint::Object_Specification;
our @ISA = qw( openprint::Object );
use vars qw( $debug $table %fields %find_fields %transforms %defaults $serial );

$debug = 1;
$serial = 'object_specifications_id_seq';
$table = 'object_specifications';

%fields = (
		id				=>	'id',
		object_id		=>	'object_id',
		object_type_id	=>	'object_type_id',
		name			=>	'name',
		value			=>	'value',
);
%find_fields = (
	object_type	=>	'(SELECT name FROM object_types WHERE id=object_type_id)',
);
%transforms = (
		name  => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
		value => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);

%defaults = (
);

1;
__END__
