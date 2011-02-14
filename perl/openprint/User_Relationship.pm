use strict;
require openprint::Object;
require openprint::User;
package openprint::User_Relationship_Type;
our @ISA = qw(openprint::Object);
use vars qw( $debug $table $serial %fields %defaults %transforms );
$debug = 1;
$table = 'user_relationship_types';
$serial = 'user_relationship_types_id_seq';
%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
);

package openprint::User_Relationship;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table @identified_by %fields %find_fields %defaults %transforms );
$debug = 1;
$table = 'user_relationships';
@identified_by = ( 'user_id1', 'type_id', 'user_id2' );

%fields = (
	'user_id1'	=>	'user_id1',
	'user_id2'	=>	'user_id2',
	'type_id'	=>	'type_id',
);
%find_fields = (
	'type'		=>	'(SELECT name from user_relationship_types WHERE id=type_id)',
);

sub User {
	return new openprint::User( $_[0]{'user_id1'} );
}
sub type {
	if ( @_ > 1 ) {
		my $Type = openprint::User_Relationship_Type->find_one('name_lc'=>lc $_[1]);
		if ( ! $Type->id() ) {
			$Type->save('name'=>$_[1]);
		} # end if
		$_[0]{'type_id'} = $Type;
		return $Type->name();
	} # end if
	return new openprint::User_Relationship_Type( $_[0]{'type_id'} );
} # end sub type
1;
__END__
