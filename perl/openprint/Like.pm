use strict;
require openprint::Object_Type;
package openprint::Like;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table %fields %find_fields %transforms %defaults @identified_by );

$debug = 1;
$table = 'likes';
%fields = (
	'user_id'		=>	'user_id',
	'object_type_id'	=>	'object_type_id',
	'object_type'	=>	undef,
	'object_id'		=>	'object_id',
	'created_on'	=>	'created_on',
	'value'			=>	'value',
);
%find_fields = (
	'object_type'	=>	'(SELECT name FROM object_types WHERE id=object_type_id)',
);
@identified_by = ( 'user_id', 'object_type_id', 'object_id' );
%defaults = (
	'created_on'	=>	q`'NOW()'`,
	'value'			=>	undef,
);

sub Object {
	if ( ! $_[0]{'Object'} ) {
#$openprint::log->debug("Like: new object ".$_[0]->object_type());
		my $type = $_[0]->object_type();
		if ( ! $type ) {
			$openprint::log->warn("No object_type $type");

		} elsif ( $type->can('new') ) {
			$_[0]{'Object'} = $type->new( $_[0]{'object_id'} );
#$openprint::log->debug("lLike: new object type: " . (ref $_[0]{'Object'}) . ' id: ' . $_[0]{'Object'}->id() );
		} else {
			$openprint::log->warn("Unable to create an $_[0]{object_type}");
		} # end if
	} 
	if ( ! $_[0]{'Object'} ) {
		return new openprint::Object();
	} # end if
	return $_[0]{'Object'};
} # end sub Object

1;
__END__
