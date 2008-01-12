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
my %transforms = (
	'min' => [ 's/[^\d\.]//g' ],
	'max' => [ 's/[^\d\.]//g' ],
);
my %defaults = (
	'min'	=>	undef,
	'max'	=>	undef,
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

sub save {
	my ( $self, $param ) = @_;

	my %sql;
    foreach my $k ( keys %fields ) {
		if ( $param and exists $$param{$k} ) {
			$$self{$k} = $$param{$k};
		} # end if

        my @transforms = @{$transforms{$k}} if $transforms{$k};
        foreach my $transform ( @transforms ) {
            eval '$$self{$k} =~ ' . $transform;
        } # end foreach

        if ( ( ( ! defined $$self{$k} ) or ( $$self{$k} eq '' ) ) and exists $defaults{$k} ) {
            $openprint::log->debug("Setting default for $k $defaults{$k}");
            $sql{$fields{$k}} = $defaults{$k};
        } else {
            $sql{$fields{$k}} = $$self{$k};
        } # end if
    } # end foreach

	my $ac = sql::start_transaction( $openprint::dbh );

	if ( ! $$self{id} ) {
		@$self{id} = sql::execute( undef, undef, q{SELECT nextval('EquipmentSpecification_seq')} );
		$sql{lngindex} = $$self{id};
		delete $sql{id};

		if ( ( my $error = sql::insert( undef, undef, 'tbl_Equipment_Specifications', \%sql ) ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
	} else {
		if ( ( my $error = sql::update( undef, undef, 'tbl_Equipment_Specifications', ['lngindex=?',$$self{id}], \%sql ) ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
	} # end if
	sql::end_transaction( $openprint::dbh, $ac );
	$self->load();
} # end sub save

sub delete {
	my ( $self ) = @_;
	sql::execute( undef, undef, q{DELETE FROM tbl_Equipment_Specifications WHERE lngindex=?}, $$self{id} );
} # end sub delete

sub copy {
	my ( $self ) = @_;
	my $new = new openprint::EquipmentSpecification();
	@$new{keys %fields} = @$self{keys %fields};
	delete $$new{id};
	return $new;
} # end sub copy

sub Equipment {
	my $self = shift;
	return new openprint::Equipment( $$self{equipment_id} );
} # end sub Equipment


1;
__END__
