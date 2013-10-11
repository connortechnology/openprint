use strict;
require openprint::Material;
require openprint::Service;
package openprint::Ink;
our @ISA = qw( openprint::Object );

use openprint ();

use vars qw( $table $debug $serial %fields %transforms %defaults );
$debug = 0;

$table = 'inks';
$serial = 'inks_id_seq';

%fields = (
	id			=>	'id',
	pmsid		=>	'pmsid',
	name		=>	'name',
	service_id	=>	'service_id',
	material_id	=>	'material_id',
	washups		=>	'washups',
	grades		=>	'grades',
	mix			=>	'mix',
);

%defaults = (
	mix			=>	0,
	washups		=>	undef,
	service_id	=>	undef,
	material_id	=>	undef,
	grades		=>	undef,
);

%transforms = (
	washups	=> [ 's/\D//g' ],
);

sub Material {
	if ( ! $_[0]{Material} ) {
		$_[0]{Material} = new openprint::Material( $_[0]{material_id} );
	}
	return $_[0]{Material};
} # end sub Material
sub Service {
	if ( ! $_[0]{Service} ) {
		$_[0]{Service} = new openprint::Service( $_[0]{service_id} );
	} # end if
	return $_[0]{Service};	
} # end sub Service
1;
__END__
