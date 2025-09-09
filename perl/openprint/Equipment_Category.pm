use strict;
package openprint::Equipment_Category;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %transforms %defaults $default_sort);
$debug = 0;
$table = 'equipment_categories';
$serial= 'equipment_categories_id_seq';
$default_sort = 'lower(name)';
%fields = (
	id		=>	'id',
	name		=>	'name',
);
%transforms = (
    name => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%defaults = (
);

1;
__END__
