use strict;
package openprint::FoldSpecification;
our @ISA = qw( openprint::Object );
require openprint::Fold;

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 0;
$table = 'fold_specifications';
$serial = 'fold_specifications_id_seq';

%fields = (
	id			=>	'id',
	fold_id		=>	'fold_id',
	min_weight	=>	'min_weight',
	max_weight	=>	'max_weight',
	weight_units	=>	'weight_units',
	runspeed		=>	'runspeed',
	interpolate	=>	'interpolate',
);
%transforms = (
	min_weight	=> [ 's/[^\d\.]//g' ],
	max_weight	=> [ 's/[^\d\.]//g' ],
	runspeed	=> [ 's/\D//g' ],
);
%defaults = (
	min_weight		=>	undef,
	max_weight		=>	undef,
	weight_units	=>	q`'gsm'`,
	runspeed		=>	0,
	interpolate		=>	0,
);

sub Fold {
	return new openprint::Fold( $_[0]{fold_id} );
} # end sub Equipment

1;
__END__
