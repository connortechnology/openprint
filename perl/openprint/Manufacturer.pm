use strict;
package openprint::Manufacturer;
our @ISA = qw(openprint::Object);

use vars qw( $table $serial %fields %transforms %defaults $cache_field $default_sort );

$cache_field = 'name';

$table = 'manufacturers';
$default_sort = 'lower(name)';
$serial= 'manufacturers_id_seq';
%fields = (
		id		=>  'id',
		name	=>  'name',
    approved  =>  'approved',
);
%transforms = (
		name	=> [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%defaults = (
  approved => '1',
);

1;
__END__
