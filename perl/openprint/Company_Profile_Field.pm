use strict;
package openprint::Company_Profile_Field;
our @ISA = qw( openprint::Object );

use vars qw( $table $serial %fields %transforms %defaults );
$table = 'user_profile_fields';
$serial = 'user_profile_fields_id_seq';
%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
	'required'	=>	'required',
	'description'	=>	'description',
	'type'			=>	'type',	
	'sort'			=>	'sort',
	'values'		=>	'values',
	'deleted'		=>	'deleted',
);
%transforms = (
	'sort'	=> [ 's/\D//g' ],
);
%defaults = (
	'required'	=>	0,
	'sort'		=>	'undef',
	'deleted'	=>	0,
);

sub destroy {
	my $error;
	my $ac = sql::start_transaction( $openprint::dbh );
	foreach ( openprint::Company_Profile_Entry( 'field_id'=>$_[0]{'id'} ) ) {
		$error .= $_->destroy();
		if ( $error ) {
			$openprint::dbh->rollback();
			return $error;
		} # end if
	} # end foreach
	$error .= $_[0]->SUPER::destroy();
	sql::end_transaction( $openprint::dbh, $ac );
	return $error;
} # end sub destroy

1;
__END__
