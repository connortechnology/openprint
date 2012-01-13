use strict;
package openprint::Opinion_Availability;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table %fields %transforms %defaults @identified_by);

$debug = 1;
$table = 'opinion_availability';
@identified_by = ( 'opinion_type_id', 'object_type_id', 'object_id' );
%fields = (
	'opinion_type_id'	=>	'opinion_type_id',
	'object_type_id'	=>	'object_type_id',
	'object_type'		=>	undef,
	'object_id'			=>	'object_id',	
);
%transforms = (
);
%defaults = (
);

sub Object {
	return $_[0]->object_type()->new( $_[0]{'object_id'} );
} # end sub Object
1;
__END__
