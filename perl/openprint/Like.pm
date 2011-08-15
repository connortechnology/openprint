use strict;
package openprint::Like;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table %fields %transforms %defaults @identified_by );

$debug = 1;
%fields = (
	'user_id'		=>	'user_id',
	'object_type'	=>	'object_type',
	'object_id'		=>	'object_id',
);
@identified_by = ( 'user_id', 'object_type', 'object_id' );


sub Object {
	return $_[0]{'object_type'}->new( $_[0]{'object_id'} );
} # end sub Object

1;
__END__
