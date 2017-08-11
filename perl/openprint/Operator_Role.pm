use strict;
package openprint::Operator_Role;
our @ISA = qw(openprint::Object);

use vars qw( $debug %fields %find_fields %transforms %defaults $table $serial );

$table = 'operator_roles';
$serial = 'operator_roles_id_seq';
$debug = 1;
%fields = (
	id							=>	'id',
	servicetype_id	=>	'servicetype_id',
	name						=>	'name',
);
%find_fields = (
);
%transforms = (
);
%defaults = (
	servicetype_id	=>	undef,
);

1;
__END__
