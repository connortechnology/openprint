package openprint::MaterialSpecification;
@ISA = qw( openprint::Object );
use strict;
use openprint ();
use openprint::Material;
require sql;

my %fields = (
	'id'			=>	'id',
	'material_id'	=>	'material_id',
	'min'			=>	'min',
	'max'			=>	'max',
	'units'			=>	'units',
	'name'			=>	'name',
	'value'			=>	'value',
	'interpolate'	=>	'interpolate',
);

my $debug = 1;
# Returns a paper object specified by the parameters
sub find {
	my %params = @_;

	if ( $params{'id'} ) {
		return new openprint::MaterialSpecification( $params{'id'} );
	} else {
		my $sql;
		my @values;
		$sql = q{SELECT * FROM Material_Specifications WHERE 1>0};
		if ( $params{'Material'} ) {
			$sql .= q{ AND material_id=?};
			push @values, $params{'Material'}->id();
		} # end if
		if ( $params{'material_id'} ) {
			$sql .= q{ AND material_id=?};
			push @values, $params{'material_id'};
		} # end if

		if ( $params{'name'} ) {
			$sql .= q{ AND name=?};
			push @values, $params{'name'};
		} # end if

		$sql .= " OR $params{'or'}" if $params{'or'};
		$sql .= " ORDER BY $params{'order'}" if ( $params{'order'} );
		my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
		if ( ! $data ) {
			$openprint::log->error( "Error loading Material Specification ($sql) (@values) :" . $openprint::dbh->errstr );
		} elsif ( $debug ) {
		#$openprint::log->debug( 'Number of results: ' . @$data );
			$openprint::log->debug( $sql . join(',',@values) . ':' . @$data );
		} # end if
		
		return map { new openprint::MaterialSpecification( $_->{lngindex}, $_ ) } @$data;
	} # end if
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( q{SELECT * FROM Material_Specifications WHERE id=?}, {}, $$self{'id'} );
	} # end if
	@$self{keys %fields} = @$data{@fields{keys %fields}};
} # end sub load


1;
__END__
