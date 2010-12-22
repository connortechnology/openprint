package openprint::PurchaseOrder_ContentType;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 1;

$table = 'PurchaseOrder_ContentTypes';
$serial = 'PurchaseOrder_ContentTypes_id_seq';
%fields = (
	'id'		=>	'id',
	'name'		=>	'name',
);

%transforms = (
);

%defaults = (
);

1;
__END__
