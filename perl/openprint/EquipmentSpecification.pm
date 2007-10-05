package openprint::EquipmentSpecification;
@ISA = qw( openprint::Object );
use strict;
use openprint ();
use openprint::Equipment;
require sql;

my %fields = (
	'id'			=>	'lngindex',
	'equipment_id'	=>	'lngequipmentindex',
	'min'			=>	'dblmin',
	'max'			=>	'dblmax',
	'units'			=>	'strunits',
	'name'			=>	'strname',
	'value'			=>	'strvalue',
	'interpolate'	=>	'interpolate',
);

my $debug = 0;
# Returns a paper object specified by the parameters
sub find {
	my %params = @_;

	if ( $params{'id'} ) {
		return new openprint::EquipmentSpecification( $params{'id'} );
	} else {
		my $sql;
		my @values;
		$sql = q{SELECT * FROM tbl_Equipment_Specifications WHERE 1>0};
		if ( $params{'Equipment'} and $params{'Equipment'}->id() ) {
			$sql .= q{ AND lngEquipmentIndex=?};
			push @values, $params{'Equipment'}->id();
		} # end if
		if ( $params{'equipment_id'} ) {
			$sql .= q{ AND lngEquipmentIndex=?};
			push @values, $params{'equipment_id'};
		} # end if

		if ( $params{'name'} ) {
			$sql .= q{ AND strName=?};
			push @values, $params{'name'};
		} # end if

		$sql .= " OR $params{'or'}" if $params{'or'};
		$sql .= " ORDER BY $params{'order'}" if ( $params{'order'} );
		my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
		if ( ! $data ) {
			$openprint::log->error( "Error loading Equipment Specification ($sql) (@values) :" . $openprint::dbh->errstr );
		} elsif ( $debug ) {
		#$openprint::log->debug( 'Number of results: ' . @$data );
			$openprint::log->debug( $sql . join(',',@values) );
		} # end if
		
		return map { new openprint::EquipmentSpecification( $_->{lngindex}, $_ ) } @$data;
	} # end if
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( q{SELECT * FROM tbl_Equipment_Specifications WHERE lngIndex=?}, {}, $$self{'id'} );
	} # end if
	@$self{keys %fields} = @$data{@fields{keys %fields}};
} # end sub load

sub Equipment {
	my $self = shift;
	return new openprint::Equipment( $$self{equipment_id} );
} # end sub Equipment


1;
__END__
