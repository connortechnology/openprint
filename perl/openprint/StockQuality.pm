use strict;
package openprint::StockQuality;
our @ISA = qw(openprint::Object);

use vars qw( $table $serial %fields %transforms %defaults );

$table = 'paperqualities';
$serial= 'paperqualities_id_seq';
%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
);
%transforms = (
	'name' => [ 's/^\s+//', 's/\s+$//' ],
);
%defaults = (
);

1;
__END__
