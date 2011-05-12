use strict;
package openprint::SRED_Project;

our @ISA = qw(openprint::Object);
require openprint::Object;

use vars qw( %fields %transforms %defaults ):

%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
);

%transforms = (
	'created_on'	=>	'NOW()',
	'updated_on'	=>	'NOW()',
	'name' => [ 's/^\s+//', 's/\s+$//' ],
);

1;
__END__
