use strict;
require openprint::Object_Type;
package openprint::Privacy;
our @ISA = qw(openprint::Object);
use vars qw( $debug $table $serial %fields %find_fields %defaults %transforms );

$debug = 1;
$table = 'privacy';
$serial = 'privacy_id_seq';
%fields = (
	'id'				=>	'id',
	'object_type_id'	=>	'object_type_id',
	'object_type'		=>	undef,
	'object_id'			=>	'object_id',
	'mode'				=>	'mode',
	'usergroup_id'		=>	'usergroup_id',# an array of group_id
	'relationship_type_id'	=>	'relationship_type_id',# an array of relationship_ids
	'users_id'				=>	'user_id', # an array
);
%find_fields = (
	'object_type'		=>	'(SELECT name FROM object_types WHERE id=object_type_id)',
);
%defaults = (
);
sub Object {
	$_ =  $_[0]->object_type()->new( $_[0]{'object_id'} );
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

1;
__END__
