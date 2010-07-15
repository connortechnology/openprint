package openprint::StockPurpose;
@ISA = qw(openprint::Object);

use strict;

use vars qw( $table $serial %fields %transforms %defaults );
$table = 'stockpurposes';
$serial='stockpurposes_id_seq';
%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
);

1;

__END__
