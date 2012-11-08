use strict;
package openprint::StockGroup;
our @ISA = qw(openprint::Object);

use vars qw( $table $serial %fields %transforms %defaults );
$table = 'stockgroups';
$serial = 'stockgroups_id_seq';

%fields = ( 
	id	=>	'id',
	name=>	'name',
);
%transforms = (
    name => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%defaults = ();

1;
__END__
