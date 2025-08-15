use strict;
package openprint::Product_Filter;
our @ISA = qw( openprint::Object );
use vars qw( $debug $table %fields %transforms %defaults $serial );

$debug = 0;
$serial = 'product_filter_seq';
$table = 'product_filter';

%fields = (
		id				=>	'id',
		category_id		=>	'category',
		name				=>	'name',
		sortorder				=>	'sortorder',
);
%transforms = (
    name => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);

%defaults = (
);

1;
__END__
