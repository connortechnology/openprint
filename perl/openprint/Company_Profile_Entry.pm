use strict;
package openprint::Company_Profile_Entry;
our @ISA = qw( openprint::Object );

use vars qw( $table @identified_by %fields %transforms %defaults $debug );
$debug = 0;

$table = 'company_profiles';
@identified_by = ( 'company_id', 'field_id' );
%fields = (
	'company_id'	=>	'company_id',
	'field_id'	=>	'field_id',
	'value'		=>	'value',
);
%defaults = (
	'required'	=>	0,
);

sub field {
	if ( ! $_[0]{'Field'} ) {
		$_[0]{'Field'} = new openprint::Company_Profile_Field( $_[0]{'field_id'} );
	} # end if
	return $_[0]{'Field'}->name();
} # end sub field

1;
__END__
