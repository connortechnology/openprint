use strict;
require openprint::Object_Type;
package openprint::Comment;
our @ISA = qw(openprint::Object);
use vars qw( $debug $table $serial %fields %find_fields %defaults %transforms );

$debug = 1;
$table = 'comments';
$serial = 'comments_id_seq';
%fields = (
	'id'			=>	'id',
	'user_id'		=>	'user_id',
	'object_type_id'	=>	'object_type_id',
	'object_type'		=>	undef,
	'object_id'		=>	'object_id',
	'created_on'	=>	'created_on',
	'deleted'		=>	'deleted',
	'approved'		=>	'approved',
	'text'			=>	'text',
);
%find_fields = (
	'object_type'	=>	'(SELECT name FROM object_types WHERE id=object_type_id)',
);
%defaults = (
	'created_on'	=>	q`'NOW()'`,
	'deleted'		=>	0,
	'approved'		=>	0,
	'user_id'		=> q`$openprint::session{user_id}`,
	'approved'		=>	0,
);
sub Object {
	$_ =  $_[0]->object_type()->new( $_[0]{'object_id'} );
$openprint::log->debug( "Returning object of type " . ref $_ );
	return $_;
} # end sub Object
sub object_type {
	if ( @_ > 1 ) {
		my $Type = openprint::Object_Type->find_one('name lc'=> lc (openprint::Object_Type->transform( 'name', $_[1] ) ) );
		if ( ! $Type ) {
			$Type = new openprint::Object_Type();
			$Type->save({'name'=>$_[1], 'human'=>$_[1]});
		} # end if
		$_[0]{'object_type'} = $Type->name();
		$_[0]{'object_type_id'} = $Type->id();
	} # end if
	if ( ! $_[0]{'object_type'} ) {
		$_[0]{'object_type'} = new openprint::Object_Type( $_[0]{'object_type_id'} )->name();
	} # end if
	return $_[0]{'object_type'};
} # end sub object_type

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
