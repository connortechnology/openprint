use strict;
package openprint::Like;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table %fields %transforms %defaults @identified_by );

$debug = 1;
$table = 'likes';
%fields = (
	'user_id'		=>	'user_id',
	'object_type'	=>	'object_type',
	'object_id'		=>	'object_id',
	'created_on'	=>	'created_on',
);
@identified_by = ( 'user_id', 'object_type', 'object_id' );
%defaults = (
	'created_on'	=>	q`'NOW()'`,
);


sub Object {
	if ( ! $_[0]{'Object'} ) {
#$openprint::log->debug("Like: new object openprint::$_[0]{'object_type'}");
		if ( ('openprint::'.$_[0]{'object_type'})->can('new') ) {
			$_[0]{'Object'} = ('openprint::'.$_[0]{'object_type'})->new( $_[0]{'object_id'} );
#$openprint::log->debug("lLike: new object type: " . (ref $_[0]{'Object'}) . ' id: ' . $_[0]{'Object'}->id() );
		} else {
			$openprint::log->warn("Unable to create an openprint::$_[0]{object_type}");
		} # end if
	} 
	if ( ! $_[0]{'Object'} ) {
		return new openprint::Object();
	} 
	return $_[0]{'Object'};
} # end sub Object

1;
__END__
