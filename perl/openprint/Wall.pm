use strict;
package openprint::Wall;
our @ISA = qw( openprint::Object );

use vars qw( $table $serial %fields %transforms %defaults );

$table = 'wall';
$serial = 'wall_id_seq';

%fields = (
	'id'			=>	'id',
	'created_on'	=>	'created_on',
	'user_id'		=>	'user_id',
	'author_id'		=>	'author_id',
	'message'		=>	'message',
);

%defaults = (
	'created_on'	=>	q`'NOW()'`,
	'user_id'		=>	q`$openprint::session{'user_id'}`,
);

sub Author {
	return new openprint::User( $_[0]{'author_id'} );
} # end sub Author

1;
__END__
