use strict;
require openprint::Object;
require openprint::User;

package openprint::Blocklist;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table @identified_by %fields %find_fields %defaults %transforms );
$debug = 1;
$table = 'blocklist';
@identified_by = ( 'blockee', 'blocker' );

%fields = (
	blockee	=>	'blockee',
	blocker	=>	'blocker',
	created_on	=>	'created_on',	
);
%find_fields = (
	user_id	=>	[ 'blockee', 'blocoker' ],
);
%defaults = (
	created_on	=>	q`'NOW()'`,
);

sub Blockee {
	return new openprint::User( $_[0]{blockee} );
}
sub Blocker {
	return new openprint::User( $_[0]{blocker} );
}
1;
__END__
