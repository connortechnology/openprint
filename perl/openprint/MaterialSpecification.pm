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

my $debug = 0;
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
		
		return map { new openprint::MaterialSpecification( $_->{id}, $_ ) } @$data;
	} # end if
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( q{SELECT * FROM Material_Specifications WHERE id=?}, {}, $$self{'id'} );
	} # end if
	@$self{keys %fields} = @$data{@fields{keys %fields}};
} # end sub load

sub save {
    my ( $self, $hash ) = @_;

    if ( $hash ) {
        $self->set( $hash );
    } # end if

    my $ac = sql::start_transaction( $openprint::dbh );
    if ( ! $$self{'id'} ) {
        @$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('materialspecification_id_seq')} );

        if ( my $error = sql::insert( undef, undef, 'Material_Specifications', [map { $_, $$self{$_} } keys %fields ] ) ) {
            $$self{'id'} = undef;
            sql::end_transaction( $openprint::dbh, $ac );
            return $error;
        } # end if

    } else {
        if ( my $error = sql::update( undef, undef, 'Material_Specifications', ['id=?', $$self{id}], [map { $_, $$self{$_} } keys %fields ] ) ) {
            sql::end_transaction( $openprint::dbh, $ac );
            return $error;
        } # end if
    } # end if

    sql::end_transaction( $openprint::dbh, $ac );
    $self->load();
    return;
} # end sub save


sub copy {
	my ( $self ) = @_;
	my $new = new openprint::MaterialSpecification();
	@$new{keys %fields} = @$self{keys %fields};
	delete $$new{id};
	return $new;
} # end sub copy

1;
__END__
