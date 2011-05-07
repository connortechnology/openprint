use strict;
package openprint::Comment;
our @ISA = qw(openprint::Object);
use vars qw( $debug $table $serial %fields %defaults %transforms );

$debug = 1;
$table = 'comments';
$serial = 'comments_id_seq';
%fields = (
	'id'			=>	'id',
	'user_id'		=>	'user_id',
	'object_type'	=>	'object_type',
	'object_id'		=>	'object_id',
	'created_on'	=>	'created_on',
	'deleted'		=>	'deleted',
	'approved'		=>	'approved',
	'text'			=>	'text',
	'approved'		=>	'approved',
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

sub can_delete {
	return 1 if $openprint::session{'user_type'} eq 'A';
	return 1 if $_[0]{'user_id'} == $openprint::session{'user_id'};
	return $_[0]->Object()->can_delete();
} # end sub can_delete

sub can_approve {
	return 1 if $openprint::session{'user_type'} eq 'A';
	return $_[0]->Object()->can_approve();
} # end sub can_approve
1;
__END__
