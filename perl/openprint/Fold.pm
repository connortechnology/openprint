use strict;
package openprint::Fold;
our @ISA = qw( openprint::Object );
require openprint;
require openprint::Equipment;
require openprint::FoldSpecification;
require sql;

use Memoize;
memoize('Specification');

use vars qw( $debug $table $serial $log $dbh %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$debug = 0;
$table = 'folds';
$serial= 'folds_id_seq';

%fields = (
	'id'					=>	'id',
	'equipment_id'			=>	'equipment_id',
	'type'					=>	'type',
	'name'					=>	'name',
	'min_width'				=>	'min_width',
	'max_width'				=>	'max_width',
	'min_height'			=>	'min_height',
	'max_height'			=>	'max_height',
	'min_calliper'			=>	'min_calliper',
	'max_calliper'			=>	'max_calliper',
	'min_gsm'				=>	'min_gsm',
	'max_gsm'				=>	'max_gsm',
	'pages'					=>	'pages',
	'page_columns'			=>	'page_columns',
	'page_rows'				=>	'page_rows',
	'min_imposition'		=>	'min_imposition',
	'max_imposition'		=>	'max_imposition',
	'cutting'				=>	'cutting',
	'stitching'				=>	'stitching',
	'perfectbind'			=>	'perfectbind',
	'spinepaste'			=>	'spinepaste',
	'spine_direction'		=>	'spine_direction',
	'makeready_time'		=>	'makeready_time',
	'makeready_overs'		=>	'makeready_overs',
	'makeready_overs_units'	=>	'makeready_overs_units',
	'run_overs_units'		=>	'run_overs_units',
	'run_overs'				=>	'run_overs',
	'folds'					=>	'folds',
	'angles'				=>	'angles',
	'printing_type'			=>	'printing_type',
);
%transforms = (
	'min_width' => [ 's/[^\d\.]//g' ],
	'max_width' => [ 's/[^\d\.]//g' ],
	'min_height' => [ 's/[^\d\.]//g' ],
	'max_height' => [ 's/[^\d\.]//g' ],
	'min_calliper' => [ 's/[^\d\.]//g' ],
	'max_calliper' => [ 's/[^\d\.]//g' ],
	'min_imposition' => [ 's/\D//g' ],
	'max_imposition' => [ 's/\D//g' ],
	'pages' => [ 's/\D//g' ],
	'page_columns' => [ 's/\D//g' ],
	'page_rows' => [ 's/\D//g' ],
	'makeready_time' => [ 's/[^\d\.]//g' ],
	'makeready_overs' => [ 's/[^\d\.]//g' ],
	'run_overs' => [ 's/[^\d\.]//g' ],
	'folds' => [ 's/\D//g' ],
	'angles' => [ 's/\D//g' ],
);
%defaults = (
	'min_width'			=>	undef,
	'max_width'			=>	undef,
	'min_height'		=>	undef,
	'max_height'		=>	undef,
	'min_calliper'		=>	undef,
	'max_calliper'		=>	undef,
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
	'folds'			=> undef,
	'angles'		=> undef,
	'printing_type'	=>	undef,
);

sub to_string {
	if ( ! $_[0]{'to_string'} ) {
		$_[0]{'to_string'} = sprintf('%s %dx%d=%d pages min:%d max:%d impo', 
				@{$_[0]}{'name','page_columns','page_rows','pages', 'min_imposition','max_imposition'} );
	} # end if
	return $_[0]{'to_string'};
} # end sub to_string

sub delete {
	my ( $self ) = @_;
	my $ac = sql::start_transaction( $dbh );
	sql::execute( undef, undef, q{DELETE FROM Fold_Specifications WHERE fold_id=?}, $$self{id} );
	if ( ! sql::execute( undef, undef, q{DELETE FROM Folds WHERE id=?}, $$self{id} ) ) {
		delete $openprint::Object::cache{ref $self}{$$self{id}};
	} # end if
	sql::end_transaction( $dbh, $ac );
} # end sub delete

sub copy {
	my $self = $_[0];
	my $new = new openprint::Fold();
	@$new{keys %fields} =  @$self{ keys %fields};
	@{$$new{'Specifications'}} = map { $_->copy() } $_[0]->Specifications();
	delete $$new{id};
	return $new;
} # end sub copy

sub Equipment {
	return new openprint::Equipment( $_[0]{equipment_id} );
} # end sub Equipment

sub Specifications {
	if ( ! $_[0]{'Specifications'} ) {
		@{$_[0]{'Specifications'}} = openprint::FoldSpecification->find( 'fold_id'=>$_[0]{'id'},'order'=>'min_weight NULLS FIRST,max_weight NULLS FIRST' );
	} # end if
	return @{$_[0]{'Specifications'}};
} # end sub Equipment

sub Specification {
	my ( $self, $range ) = @_;

    if ( ! $$self{'Specifications'} ) {
		@{$$self{'Specifications'}} = openprint::FoldSpecification->find( 'fold_id'=>$$self{'id'},'order'=>'min_weight NULLS FIRST,max_weight NULLS FIRST' );
    } # end if

    if ( ! @{$$self{'Specifications'}} ) {
		return;
	} # end if

	if ( $$self{'Specifications'}[0]{weight_units} eq 'lbs' )  {
$log->debug("Converting $range gsm to " . openprint::Paper::gsm_to_weight( $range ) ) if $debug;
		$range = openprint::Paper::gsm_to_weight( $range );
	} # end if

	$range = 1*$range;
	my $i = 0;
	my $x;
	my $y;
	for ( ; $i < @{$$self{'Specifications'}}; $i += 1 ) {
		my $Spec = $$self{'Specifications'}[$i];
$log->debug("Examining: ".$Spec->Fold()->Equipment()->name() . ' ' . $Spec->Fold()->name() . " MIN(" . $Spec->min_weight() .     ') MAX(' . $Spec->max_weight() . $Spec->weight_units(). ') RUNSPEED(' . $Spec->runspeed() .') INTERPOLATE('.$Spec->interpolate() .') for range: ' . $range ) if $debug;
		#return $Spec if ( 1*$$Spec{min_weight} == $range ) or ( 1*$$Spec{max_weight} == $range );

		return $Spec if ( ( $$Spec{min_weight} <= $range ) and ( $$Spec{max_weight} >= $range ) );
		return $Spec if (
				( ! $$Spec{interpolate} ) and 
				(( ! $$Spec{min_weight} ) or ($$Spec{min_weight} <= $range)) and
				(( ! $$Spec{max_weight} ) or ($$Spec{max_weight} >= $range))
				);

# first step, find one less than the min
		last if 1*$$Spec{min_weight} > $range;
		last if ( $Spec->max_weight() eq '' and ! $Spec->interpolate() );
	} # end if

   if ( $i and $i <= @{$$self{'Specifications'}} ) {
        $i -= 1;
        # back up
		$x = $$self{'Specifications'}[$i];
$log->debug("Found spec for $range:" . $x->min_weight() . ' ' . $x->max_weight() . ' : ' . $x->runspeed() ) if $debug;
		return if ( (1*$$x{max_weight}) and ( $$x{max_weight} < $range ) and ! $$x{interpolate} );
   } else {
	   $log->debug("Couldn't find monimum for $range ") if $debug;
	   return;
   } # end if

   for ( ; $i < @{$$self{'Specifications'}}; $i += 1 ) {
	   my $Spec = $$self{'Specifications'}[$i];
		# Don't need to check for equality, as we do that above
	   return $Spec if ( !(1*$$Spec{max_weight}) and ! $$Spec{interpolate} );

$log->debug("Examining MAX spec for $range:" . $Spec->min_weight() . ' ' . $Spec->max_weight() . ' : ' . $Spec->runspeed() ) if $debug;
# first step, find one less than the min
		if ( ( 1*$$Spec{max_weight} > 1*$range ) or ( $$Spec{max_weight} eq '' ) ) {
			#$log->debug("Foudn Max at $i " . @{$$self{'Specifications'}} );
			last;
		} # end if
   } # end foreach
   if ( $i and $i < @{$$self{'Specifications'}} ) {
# back up
	   $y = $$self{'Specifications'}[$i];
$log->debug("Found spec max " . $y->min_weight() . ' ' . $y->max_weight() . ' : ' . $y->runspeed() ) if $debug;
   } else {
$log->debug("Couldn't find maximum") if $debug;
	   return;
   } # end if

    if ( $$x{id} == $$y{id} ) {
        return $x;
    } elsif ( $$x{interpolate} ) {
        my $S = $x->copy();
        $$S{min_weight} = $$S{max_weight} = $range;
        $$S{runspeed} = $$x{runspeed} + ($range - $$x{min_weight})*($$y{runspeed}-$$x{runspeed})/($$y{min_weight}-$$x{min_weight});
        return $S;
    } # end if

} # end sub Specification

sub RunSpeed {
	my ( $self, $gsm ) = @_;
	if ( ! exists $$self{runspeed_cache} ) {
		$$self{runspeed_cache} = {};
	} # end if
	if ( ! defined $gsm ) {
		my ( $caller, undef, $line ) = caller;
		$openprint::log->warn("No gsm in Fold->RunSpeed from $caller line $line");
	} # end if
	if ( ! exists $$self{runspeed_cache}{$gsm} ) {
		$$self{runspeed_cache}{$gsm} = $self->Specification( $gsm );
	} # end if
	return $$self{runspeed_cache}{$gsm};
} # end sub RunSpeed

sub runspeed {
	if ( $_[0]{runspeed} ) {
		return $_[0]{runspeed};
	} else {
	if ( ! $_[1] ) {
		my ( $caller, undef, $line ) = caller;
		$openprint::log->warn("No gsm in Fold->runspeed from $caller line $line");
	} # end if
	my $RunSpeed = $_[0]->RunSpeed($_[1]);
	return $RunSpeed ? $$RunSpeed{'runspeed'} : undef;
	} # end if
} # end sub runspeed

sub Imposition {
	if ( @_ > 1 ) {
		$_[0]{'Imposition'} = $_[1];
	} # end if
	return $_[0]{'Imposition'};
} # end sub Imposition

sub imposition {
	if ( @_ > 1 ) {
		$_[0]{'imposition'} = $_[1];
	} # end if
	return $_[0]{'imposition'};
} # end sub imposition
1;
__END__
