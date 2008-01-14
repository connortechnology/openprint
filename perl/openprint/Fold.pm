package openprint::Fold;
@ISA = qw( openprint::Object );
use strict;
use openprint ();
use openprint::Equipment;
require sql;

my %fields = (
	'id'					=>	'id',
	'equipment_id'			=>	'equipment_id',
	'name'					=>	'name',
	'min_width'				=>	'min_width',
	'max_width'				=>	'max_width',
	'min_height'			=>	'min_height',
	'max_height'			=>	'max_height',
	'page_columns'			=>	'page_columns',
	'page_rows'				=>	'page_rows',
	'min_imposition'		=>	'min_imposition',
	'max_imposition'		=>	'max_imposition',
	'stitching'				=>	'stitching',
	'perfectbind'			=>	'perfectbind',
	'spinepaste'			=>	'spinepaste',
	'spine_direction'		=>	'spine_direction',
	'makeready_time'		=>	'makeready_time',
	'makeready_overs'		=>	'makeready_overs',
	'makeready_overs_units'	=>	'makeready_overs_units',
	'run_overs_units'		=>	'run_overs_units',
	'run_overs'				=>	'run_overs',
);
my %transforms = (
	'min_width' => [ 's/[^\d\.]//g' ],
	'max_width' => [ 's/[^\d\.]//g' ],
	'min_height' => [ 's/[^\d\.]//g' ],
	'max_height' => [ 's/[^\d\.]//g' ],
	'min_imposition' => [ 's/\D//g' ],
	'max_imposition' => [ 's/\D//g' ],
	'page_columns' => [ 's/\D//g' ],
	'page_rows' => [ 's/\D//g' ],
	'makeready_time' => [ 's/\D//g' ],
	'makeready_overs' => [ 's/\D//g' ],
	'run_overs' => [ 's/\D//g' ],
);
my %defaults = (
	'min_width'			=>	undef,
	'max_width'			=>	undef,
	'min_height'		=>	undef,
	'max_height'		=>	undef,
	'min_imposition'	=>	undef,
	'max_imposition'	=>	undef,
	'page_columns'		=>	undef,
	'page_rows'			=>	undef,
	'makeready_time' => undef,
	'makeready_overs' => undef,
	'run_overs' => undef,
);

my $debug = 1;

sub find {
	my %params = @_;

	if ( $params{'id'} ) {
		return new openprint::Fold( $params{'id'} );
	} else {
		my $sql;
		my @values;
		$sql = q{SELECT * FROM Folds WHERE 1>0};
		if ( $params{'Equipment'} and $params{'Equipment'}->id() ) {
			$sql .= q{ AND equipment_id=?};
			push @values, $params{'Equipment'}->id();
		} # end if
		if ( $params{'equipment_id'} ) {
			$sql .= q{ AND equipment_id=?};
			push @values, $params{'equipment_id'};
		} # end if

		if ( $params{'name'} ) {
			$sql .= q{ AND name=?};
			push @values, $params{'name'};
		} # end if

		$sql .= " OR $params{'or'}" if $params{'or'};
		$sql .= " ORDER BY $params{'order'}" if ( $params{'order'} );
		my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
		if ( ! $data ) {
			$openprint::log->error( "Error loading Fold ($sql) (@values) :" . $openprint::dbh->errstr );
		} elsif ( $debug ) {
			$openprint::log->debug( $sql . join(',',@values) . ' Number of results: ' . @$data );
		} # end if
		
		return map { new openprint::Fold( $_->{id}, $_ ) } @$data;
	} # end if
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( q{SELECT * FROM Folds WHERE id=?}, {}, $$self{'id'} );
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
		@$self{id} = sql::execute( undef, undef, q{SELECT nextval('Fold_id_seq')} );
		$sql{id} = $$self{id};

		if ( ( my $error = sql::insert( undef, undef, 'Folds', \%sql ) ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
	} else {
		if ( ( my $error = sql::update( undef, undef, 'Folds', ['id=?',$$self{id}], \%sql ) ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
	} # end if
	sql::end_transaction( $openprint::dbh, $ac );
	$self->load();
} # end sub save

sub delete {
	my ( $self ) = @_;
	sql::execute( undef, undef, q{DELETE FROM Folds WHERE id=?}, $$self{id} );
} # end sub delete

sub copy {
	my ( $self ) = @_;
	my $new = new openprint::Fold();
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
