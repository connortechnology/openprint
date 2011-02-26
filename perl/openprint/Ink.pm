use strict;
require openprint::Material;
require openprint::Service;
package openprint::Ink;
our @ISA = qw( openprint::Object );

use openprint ();

use vars qw( $table $serial %fields %transforms %defaults );

$table = 'inks';
$serial = 'inks_id_seq';

%fields = (
	'id'		=>	'id',
	'pmsid'		=>	'pmsid',
	'name'		=>	'strcolourname',
	'service_id'=>	'service_id',
	'material_id'	=>	'material_id',
	'washups'	=>	'washups',
);

%defaults = (
	'washups'	=>	undef,
);

%transforms = (
	'washups'	=> [ 's/\D//g' ],
);

sub Material {
	return new openprint::Material( $_[0]{'material_id'} );
} # end sub Material
sub Service {
	return new openprint::Service( $_[0]{'service_id'} );
} # end sub Service
1;
__END__
