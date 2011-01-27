use strict;
package openprint::User_Profile_Entry;
our @ISA = qw( openprint::Object );

use vars qw( $table @identified_by %fields %transforms %defaults );
$table = 'user_profiles';
@identified_by = ( 'user_id', 'field_id' );
%fields = (
	'user_id'	=>	'user_id',
	'field_id'	=>	'field_id',
	'value'		=>	'value',
);
%defaults = (
	'required'	=>	0,
);

sub field {
	if ( ! $_[0]{'Field'} ) {
		$_[0]{'Field'} = new openprint::User_Profile_Field( $_[0]{'field_id'} );
	} # end if
	return $_[0]{'Field'}->name();
} # end sub field

1;
__END__
