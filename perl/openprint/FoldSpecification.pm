package openprint::FoldSpecification;
@ISA = qw( openprint::Object );
use strict;
use openprint ();
use openprint::Fold;
require sql;

my %fields = (
	'id'			=>	'id',
	'fold_id'		=>	'fold_id',
	'min_weight'	=>	'min_weight',
	'max_weight'	=>	'max_weight',
	'weight_units'	=>	'weight_units',
	'runspeed'		=>	'runspeed',
	'interpolate'	=>	'interpolate',
);
my %transforms = (
	'min_weight'	=> [ 's/\D//g' ],
	'max_weight'	=> [ 's/\D//g' ],
	'runspeed'		=> [ 's/\D//g' ],
);
my %defaults = (
	'min_weight'	=>	0,
	'max_weight'	=>	0,
	'weight_units'	=>	'gsm',
	'runspeed'		=>	0,
	'interpolate'	=>	0,
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
		my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
		if ( ! $data ) {
			$openprint::log->error( "Error loading Fold Specification ($sql) (@values) :" . $openprint::dbh->errstr );
		} elsif ( $debug ) {
			$openprint::log->debug( $sql . join(',',@values). ' Number of results: ' . @$data );
		} # end if
		
		return map { new openprint::FoldSpecification( $_->{id}, $_ ) } @$data;
	} # end if
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( q{SELECT * FROM Fold_Specifications WHERE id=?}, {}, $$self{'id'} );
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
		@$self{id} = sql::execute( undef, undef, q{SELECT nextval('FoldSpecification_id_seq')} );
		$sql{id} = $$self{id};

		if ( ( my $error = sql::insert( undef, undef, 'Fold_Specifications', \%sql ) ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
	} else {
		if ( ( my $error = sql::update( undef, undef, 'Fold_Specifications', ['id=?',$$self{id}], \%sql ) ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
	} # end if
	sql::end_transaction( $openprint::dbh, $ac );
	$self->load();
	return;
} # end sub save

sub delete {
	my ( $self ) = @_;
	sql::execute( undef, undef, q{DELETE FROM Fold_Specifications WHERE id=?}, $$self{id} );
} # end sub delete

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
