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
	return $_[0]{name}->new( $_[1] );
} # end sub Object

sub human {
	if ( @_ > 1 ) {
		$_[0]{human} = $_[1];
	}
	if ( ! $_[0]{human} ) {
		$_[0]{human} = $_[0]{name};
		$_[0]{human} =~ s/^openprint:://;
	}
	return $_[0]{human};
}
1;
__END__
