use strict;
package openprint::ProjectTypeCategory;
our @ISA = qw( openprint::Object );
require openprint::ProjectType;

use vars qw( $debug %fields %transforms %defaults $table $serial );

$debug = 1;
$table =  'ProjectType_Categories';
$serial = 'ProjectType_Categories_id_seq';
%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
	'sort'	=>	'sort',
);
%transforms = (
);
%defaults = (
	'sort'	=>	undef,
);

1;
__END__
