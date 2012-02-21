use strict;
package openprint::PurchaseOrder_Department;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 1;

$table = 'PurchaseOrder_Departments';
$serial = 'PurchaseOrder_Departments_id';
%fields = (
	'id'		=>	'id',
	'name'		=>	'name',
);

%transforms = (
    'name' => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);

%defaults = (
);

1;
__END__
