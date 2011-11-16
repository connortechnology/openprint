use strict;
package openprint::Wall;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 1;
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

sub can_edit {
	return 1 if $openprint::session{'user_type'} eq 'A';
	return 1 if $openprint::session{'user_id'} == $_[0]{'author_id'};
	return 0;
} # end sub can_edit

1;
__END__
