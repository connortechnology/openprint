use strict;
package openprint::Bookmark;
our @ISA = qw(openprint::Object);
use vars qw( $debug $table $serial %fields %defaults %transforms );

$debug = 1;
$table = 'bookmarks';
$serial = 'bookmarks_id_seq';
%fields = (
	'id'			=>	'id',
	'user_id'		=>	'user_id',
	'object_type'	=>	'object_type',
	'object_id'		=>	'object_id',
	'created_on'	=>	'created_on',
	'deleted'		=>	'deleted',
	'text'			=>	'text',
);
%defaults = (
	'created_on'	=>	q`'NOW()'`,
	'deleted'		=>	0,
	'approved'		=>	0,
	'user_id'		=> q`$openprint::session{user_id}`,
	'approved'		=>	0,
);
sub Object {
	$_ =  $_[0]{'object_type'}->new( $_[0]{'object_id'} );
$openprint::log->debug( "Returning object of type " . ref $_ );
	return $_;
} # end sub Object

1;
__END__
