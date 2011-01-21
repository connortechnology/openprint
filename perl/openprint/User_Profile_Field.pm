use strict;
package openprint::User_Profile_Field;
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
);
%transforms = (
	'sort'	=> [ 's/\D//g' ],
);
%defaults = (
	'required'	=>	0,
	'sort'		=>	'undef',
);

1;
__END__
