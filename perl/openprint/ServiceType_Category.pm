use strict;
package openprint::ServiceType_Category;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 0;
$table = 'ServiceType_Categories';
$serial = 'ServiceType_Categories_id_seq';

%fields = (
	'id'				=>	'id',
	'name'				=> 'name',
	'sorting'			=> 'sorting',
);
%transforms = (
);
%defaults = (
	'sorting'	=>	undef,
);


1;
__END__
