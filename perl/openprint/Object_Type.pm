use strict;
package openprint::Object_Type;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table %fields %transforms %defaults $serial );

$debug = 0;
$table = 'object_types';
$serial = 'object_types_id_seq';
%fields = (
	'id'		=>	'id',
	'name'		=>	'name',
	'human'		=>	'human',
);
%defaults = (
);

sub Object {
	return $_[0]{'name'}->new( $_[1] );
} # end sub Object
1;
__END__
