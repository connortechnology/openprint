package openprint::PurchaseOrder_ContentType;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use openprint ();
use vars qw( $table $serial %fields %transforms %defaults );

my $debug = 1;

$table = 'PurchaseOrder_ContentTypes';
$serial = 'PurchaseOrder_ContentTypes_id';
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
