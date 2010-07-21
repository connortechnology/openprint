package openprint::FoldSpecification;
@ISA = qw( openprint::Object );
use strict;
use openprint ();
use openprint::Fold;
require sql;

use vars qw( $log $dbh $table $serial %fields %transforms %defaults );

$table = 'Fold_Specifications';
$serial = 'foldspecification_id_seq';

*log = \$openprint::log;
*dbh = \$openprint::dbh;

%fields = (
	'id'			=>	'id',
	'fold_id'		=>	'fold_id',
	'min_weight'	=>	'min_weight',
	'max_weight'	=>	'max_weight',
	'weight_units'	=>	'weight_units',
	'runspeed'		=>	'runspeed',
	'interpolate'	=>	'interpolate',
);
%transforms = (
	'min_weight'	=> [ 's/[^\d\.]//g' ],
	'max_weight'	=> [ 's/[^\d\.]//g' ],
	'runspeed'		=> [ 's/\D//g' ],
);
%defaults = (
	'min_weight'	=>	undef,
	'max_weight'	=>	undef,
	'weight_units'	=>	'gsm',
	'runspeed'		=>	0,
	'interpolate'	=>	0,
);

my $debug = 0;


sub Fold {
	my $self = shift;
	return new openprint::Fold( $$self{fold_id} );
} # end sub Equipment


1;
__END__
