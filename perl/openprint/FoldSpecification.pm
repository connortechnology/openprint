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

my $debug = 1;
# Returns a paper object specified by the parameters
sub find {
	my %params = @_;

	if ( $params{'id'} ) {
		return new openprint::EquipmentSpecification( $params{'id'} );
	} else {
		my $sql;
		my @values;
		$sql = q{SELECT * FROM Fold_Specifications WHERE 1>0};
		if ( $params{'Fold'} and $params{'Fold'}->id() ) {
			$sql .= q{ AND fold_id=?};
			push @values, $params{'Fold'}->id();
		} # end if
		if ( $params{'fold_id'} ) {
			$sql .= q{ AND fold_id=?};
			push @values, $params{'fold_id'};
		} # end if

		$sql .= " OR $params{'or'}" if $params{'or'};
		$sql .= " ORDER BY $params{'order'}" if ( $params{'order'} );
		my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
		if ( ! $data ) {
			$log->error( "Error loading Fold Specification ($sql) (@values) :" . $dbh->errstr );
		} elsif ( $debug ) {
			$log->debug( $sql . join(',',@values). ' Number of results: ' . @$data );
		} # end if
		
		return map { new openprint::FoldSpecification( $_->{id}, $_ ) } @$data;
	} # end if
} # end sub find

sub copy {
	my ( $self ) = @_;
	my $new = new openprint::FoldSpecification();
	@$new{keys %fields} = @$self{keys %fields};
	delete $$new{id};
	return $new;
} # end sub copy

sub Fold {
	my $self = shift;
	return new openprint::Fold( $$self{fold_id} );
} # end sub Equipment


1;
__END__
