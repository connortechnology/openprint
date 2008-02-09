package openprint::Fold;
@ISA = qw( openprint::Object );
use strict;
use openprint ();
use openprint::Equipment;
use openprint::Fold;
use openprint::FoldSpecification;
require sql;

my %fields = (
	'id'					=>	'id',
	'equipment_id'			=>	'equipment_id',
	'type'					=>	'type',
	'name'					=>	'name',
	'min_width'				=>	'min_width',
	'max_width'				=>	'max_width',
	'min_height'			=>	'min_height',
	'max_height'			=>	'max_height',
	'pages'					=>	'pages',
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
	'pages' => [ 's/\D//g' ],
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
	'pages'		=>	undef,
	'page_columns'		=>	undef,
	'page_rows'			=>	undef,
	'makeready_time' => undef,
	'makeready_overs' => undef,
	'run_overs' => undef,
	'stitching'	=> undef,
	'perfectbind'	=> undef,
	'spinepaste'	=> undef,
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
		if ( defined $params{'pages'} ) {
			$sql .= q{ AND pages=?};
			
			push @values, $params{'pages'} ? $params{'pages'} : undef;
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
	return;
} # end sub save

sub delete {
	my ( $self ) = @_;
	my $ac = sql::start_transaction( $openprint::dbh );
	sql::execute( undef, undef, q{DELETE FROM Fold_Specifications WHERE fold_id=?}, $$self{id} );
	if ( ! sql::execute( undef, undef, q{DELETE FROM Folds WHERE id=?}, $$self{id} ) ) {
		delete $openprint::Object::cache{ref $self}{$$self{id}};
	} # end if
	sql::end_transaction( $openprint::dbh, $ac );
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
sub Specifications {
	my $self = shift;
	if ( ! $$self{'Specifications'} ) {
		@{$$self{'Specifications'}} = openprint::FoldSpecification::find( 'Fold'=>$self,'order'=>'min_weight,max_weight' );
	} # end if
	return @{$$self{'Specifications'}};
} # end sub Equipment

sub Specification {
	my ( $self, $range ) = @_;

    if ( ! $$self{'Specifications'} ) {
		@{$$self{'Specifications'}} = openprint::FoldSpecification::find( 'Fold'=>$self,'order'=>'min_weight,max_weight' );
    } # end if

    if ( ! @{$$self{'Specifications'}} ) {
		return;
	} # end if

	if ( $$self{'Specifications'}[0]{weight_units} eq 'lbs' )  {
$openprint::log->debug("Converting $range gsm to " . openprint::Paper::gsm_to_weight( $range ) );
		$range = openprint::Paper::gsm_to_weight( $range );
	} # end if

	$range = 1*$range;
	my $i = 0;
	my $x;
	my $y;
	for ( ; $i < @{$$self{'Specifications'}}; $i += 1 ) {
		my $Spec = $$self{'Specifications'}[$i];
#$openprint::log->debug("Examining: (" . $Spec->min() .     ') (' . $Spec->max() . ') (' . $Spec->value() . ') ('.$Spec->interpolate() ) if $debug;
		return $Spec if ( 1*$$Spec{min_weight} == $range ) or ( 1*$$Spec{max} == $range );

		return $Spec if (
				(! $$Spec{interpolate})
				and (($$Spec{min_weight} eq '') or ($$Spec{min_weight} <= $range))
				and (($$Spec{max_weight} eq '') or ($$Spec{max_weight} >= $range))
				);

# first step, find one less than the min
		last if 1*$$Spec{min_weight} > $range;
#last if ( $Spec->max() eq '' and ! $Spec->interpolate() );
	} # end if

   if ( $i and $i <= @{$$self{'Specifications'}} ) {
        $i -= 1;
        # back up
		$x = $$self{'Specifications'}[$i];
#$openprint::log->debug("Found spec for $range:" . $x->min() . ' ' . $x->max() . ' : ' . $x->value() ) if $debug;
		return if ( (1*$$x{max_weight}) and ( $$x{max_weight} < $range ) and ! $$x{interpolate} );
   } else {
	   $openprint::log->debug("Couldn't find monimum for $range ") if $debug;
	   return;
   } # end if

   for ( ; $i < @{$$self{'Specifications'}}; $i += 1 ) {
	   my $Spec = $$self{'Specifications'}[$i];
	   return $Spec if ( $$Spec{max_weight} == $range ) or ( !(1*$$Spec{max_weight}) and ! (1*$$Spec{interpolate}) );

# first step, find one less than the min
	   last if $$Spec{max_weight} > $range;
   } # end foreach
   if ( $i and $i < @{$$self{'Specifications'}} ) {
# back up
	   $y = $$self{'Specifications'}[$i];
#$openprint::log->debug("Found spec max " . $y->min() . ' ' . $y->max() . ' : ' . $y->value() ) if $debug;
   } else {
#$openprint::log->debug("Couldn't find maximum") if $debug;
	   return;
   } # end if

} # end sub Specification

1;
__END__
