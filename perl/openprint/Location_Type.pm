use strict;
use openprint ();
require openprint::Object;
package openprint::Location_Type;
our @ISA = qw(openprint::Object);

use vars qw($debug $table $serial %fields %transforms %defaults );

$debug = 1;

$table = 'location_types';
$serial = 'location_types_id_seq';
%fields = (
	'id'			=>	'id',
	'name'		=>	'name',
);

%transforms = (
);

%defaults = (
);

1;
__END__
