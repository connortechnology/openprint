# Copyright (C) 2007 Isaac Connor <isaac@connortechnology.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA

package openprint::Estimating::Folding;
use strict;

require openprint::service;
require sql;

use vars qw( %fold_types );

my $debug = 0;

my @equipment;
my @stitchers;

my @variables = (
		'txtPrice1', 'txtPrice2', 'txtPrice3',
		'MPrice1', 'MPrice2', 'MPrice3',
		'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
		'txtRunTime1', 'txtRunTime2', 'txtRunTime3',
		);

sub variables {
	my @v = @variables;
	my ( $p_id, $s_id, $specs ) = @_;

	my $Project = new openprint::Project( $p_id );
	foreach my $s_s_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $p_id, $s_s_id );
		foreach my $qty_index ( 1 .. 3 ) {
			push @v, "chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index";
			push @v, "ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index";
			push @v, "chkOverrideFoldType-$$sig_specs{'SignatureIndex'}-$qty_index";
			foreach my $fold_type ( keys %fold_types ) {
				push @v, "$fold_type-Qty-$$sig_specs{'SignatureIndex'}-$qty_index";
			} # end foreach
		} # end foreach
	} # end foreach

	return @v;
} # end sub variables


my @no_outputs = (
		'ProjectIndex','ServiceIndex',
		'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
		'ServiceType',
);

sub no_outputs {
	return @no_outputs;
} # end sub outputs

%fold_types = (
	'2PanelFold', '2 Panel Fold',
	'3PanelFold', '3 Panel Fold',
	'3PanelZFold', '3 Panel Z Fold',
	'4PanelFold', '4 Panel Fold',
	'4PanelZFold', '4 Panel Z Fold',
	'5PanelFold', '5 Panel Fold',
	'5PanelZFold', '5 Panel Z Fold',
	'6PanelFold', '6 Panel Fold',
	'6PanelZFold', '6 Panel Z Fold',
	'SingleGateFold', 'Single Gate Fold',
	'DoubleGateFold', 'Double Gate Fold',
	'4PageSignatureFold', '4PageSignatureFold',
	'8PageSignatureFold', '8PageSignatureFold',
	'12PageSignatureFold', '12PageSignatureFold',
	'16PageSignatureFold', '16PageSignatureFold',
	'20PageSignatureFold', '20PageSignatureFold',
	'24PageSignatureFold', '24PageSignatureFold',
	'28PageSignatureFold', '28PageSignatureFold',
	'32PageSignatureFold', '32PageSignatureFold',
	'36PageSignatureFold', '36PageSignatureFold',
	'40PageSignatureFold', '40PageSignatureFold',
	'44PageSignatureFold', '44PageSignatureFold',
	'48PageSignatureFold', '48PageSignatureFold',
	'PerpendicularSoftFold', 'PerpendicularSoftFold',
	'ParallelSoftFold', 'ParallelSoftFold',
	'2Panel1Pocket', 'Single Pocket Presentation Folder',
	'2Panel2Pocket', 'Double Pocket Presentation Folder',
	'2Panel2PocketGusset', 'Double Pocket Presentation Folder with Gussets',
	'3Panel2Pocket', '3 Panel Double Pocket Presentation Folder',
	'3Panel2PocketGusset', '3 Panel Double Pocket Presentation Folder with Gussets',
	'MapFold','Map Fold',
);

sub fold_types {
} # end sub fold_types

sub signature_needs {
	my ( $Project, $specs ) = @_;

	my $services = $Project->services();
	if ( $$services{'NoBindery'} ) {
		return 0;
	} # end if

	if ( $fold_types{$$specs{'rdbTemplateType'}} ) {
		return 1;
	} # end if

	if ( ($$specs{'txtFinalWidth'} != $$specs{'txtWidth'}) or ($$specs{'txtFinalHeight'} != $$specs{'txtHeight'}) ) {
		#$openprint::log->debug("FOLDING NEEDED dimensions do not match!");
		return 1;
	} # end if
	return 0;
} # end sub signature_needs

# A function that is smart enough to return true if the project needs folding, and false if it doesn't.
sub neccessary {
	my ( $log, $dbh, $project_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services( );

	if ( $$services{'NoBindery'} ) {
        $log->debug(" ** Project is marked as No bindery, Folding not needed ! ** ");
        return 0;
    } # end if
	if ( $$services{'MetalCoil'} ) {
        return 0;
    } # end if
	if ( $$services{'PlasticCoil'} ) {
        return 0;
	} # end if
	if ( $$services{'Cerlox'} ) {
        return 0;
    } # end if
	if ( $$services{'DoubleLoopWire'} ) {
        return 0;
    } # end if
	if ( $$services{'SaddleStitching'} ) {
        return 1;
    } # end if

	foreach my $signature_service_index ( $Project->signatures() ) {
		my $specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
		if ( signature_needs( $Project, $specs ) ) {
			return 1;
		} # end if
	} # end foreach
	$log->debug("FOLDING NOT NEEDED!");
	return 0;	
} # end sub neccessary

# Finds the different ways to run the job, and returns different impositions
sub impositions {
	my ( $Project, $Imposition, $specs, $sig_specs, $qty_index ) = @_;

	my @imps = ( $Imposition );

	if ( $Imposition->Press()->specification('Folding Capable') ne 'Y' ) {
		return @imps;
	} # end if
	my $Equipment = $Imposition->Press();

# Special case because we can't cut it in the middle of printing.  This case is basically for web presses
	my $foldtype = $Imposition->spread_columns().'x'.$Imposition->spread_rows().'-'.$Imposition->pages().'Page-'.$Imposition->image_orientation().'SignatureFold';

	if ( ! ( $Equipment->specification($foldtype .'RunSpeed', $$sig_specs{'txtStockGSM'} ) ) ) {
		$openprint::log->debug("No fold") if $debug;
		return @imps;
	} 
	if ( ( defined $Equipment->specification($foldtype.'MaximumImposition' ) and $Equipment->specification($foldtype.'MaximumImposition' ) > $Imposition->imposition() ) ) {
		$openprint::log->debug('No fold due to max impo ' . $Imposition->imposition() . '>' . $Equipment->specification($foldtype.'MaximumImposition' ) ) if $debug;
		return @imps;
	} 
	if ( ( defined $Equipment->specification($foldtype.'MaximumColumns' ) and $Equipment->specification($foldtype.'MaximumColumns' ) > $Imposition->columns() ) ) {
		$openprint::log->debug("No fold due to max columns") if $debug;
		return @imps;
	} 
	if ( $Equipment->specification($foldtype.'MaximumWidth' ) and ( $Equipment->specification($foldtype.'MaximumWidth' ) < ( $Imposition->image_orientation() eq 'Vertical' ? $Imposition->image_width() : $Imposition->image_height() ) ) ) {
		$openprint::log->debug("No fold due to max width") if $debug;
		return @imps;
	}
	if ( $Equipment->specification($foldtype.'MinimumHeight' ) and ( $Equipment->specification($foldtype.'MinimumHeight') > ( $Imposition->image_orientation() eq 'Vertical' ? $Imposition->image_width() : $Imposition->image_height() ) ) ) {
		$openprint::log->debug("No fold due to min height") if $debug;
		return @imps;
	}

	if ( $Equipment->specification($foldtype.'MinimumWidth' ) and ( $Equipment->specification($foldtype.'MinimumWidth' ) > ( $Imposition->image_orientation() eq 'Vertical' ? $Imposition->image_width() : $Imposition->image_height() ) ) ) {
		my $I = $Imposition->copy();

		if ( $I->image_orientation() eq 'Vertical' ) {
			my $space = $Equipment->specification($foldtype.'MinimumWidth' ) - $I->image_width();
			$I->cropmark_left(0) if $space >= $I->cropmark_left();
			$I->cropmark_right(0) if $space >= $I->cropmark_right();
			$I->gutters(0) if $space >= $I->gutters();
			$I->image_width( $Equipment->specification($foldtype.'MinimumWidth' ) );
		} else {
			my $space = $Equipment->specification($foldtype.'MinimumWidth' ) - $I->image_height();
			$I->cropmark_left(0) if $space >= $I->cropmark_left();
			$I->cropmark_right(0) if $space >= $I->cropmark_right();
			$I->gutters(0) if $space >= $I->gutters();
			$I->image_height( $Equipment->specification($foldtype.'MinimumWidth' ) );
		} # end if

		next if ( $I->paper()->start_width() and $I->paper()->start_width() < $I->used_width() );
		$I->paper()->width( $I->used_width() ) if ! $I->paper()->start_width();
		push @imps, $I;
	} # end if
	return @imps;

} # end sub impositions

sub test_fold {
	my ( $Equipment, $I, $sig_specs, $foldtype ) = @_;

	if ( ! $Equipment->specification($foldtype .'RunSpeed', $$sig_specs{'txtStockGSM'} ) ) {
		$openprint::log->debug("DId not Found $foldtype on " . $Equipment->name() ) if $debug;
		return 0;
	} else {
		$openprint::log->debug("Found $foldtype on " . $Equipment->name() ) if $debug;

		if ( ( defined $Equipment->specification($foldtype.'MaximumImposition' ) and $Equipment->specification($foldtype.'MaximumImposition' ) < $I->imposition() ) ) {
			$openprint::log->debug("Fold no good due to imposition ".$I->imposition()." > ".$Equipment->specification($foldtype.'MaximumImposition' ) ) if $debug;
			return 0;
		} # end if
		if ( ( defined $Equipment->specification($foldtype.'MaximumColumns' ) and $Equipment->specification($foldtype.'MaximumColumns' ) < $I->columns() ) ) {
			$openprint::log->debug("Fold no good due to imposition " . $I->columns() . "> ".$Equipment->specification($foldtype.'MaximumColumns' ) ) if $debug;
			return 0;
		} # end if
		if ( ( $Equipment->specification($foldtype.'MinimumWidth') and $Equipment->specification($foldtype.'MinimumWidth' ) > ( $I->image_orientation() eq 'Vertical' ? $I->image_width() : $I->image_height() ) ) ) {
			$openprint::log->debug("Fold no good due to Minimum Width " . ($I->image_orientation() eq 'Vertical' ? $I->image_width() : $I->image_height() ) . ' < ' . $Equipment->specification($foldtype.'MinimumWidth' ) ) if $debug;
			return 0;
		}
		if ( ( $Equipment->specification($foldtype.'MaximumWidth' ) and $Equipment->specification($foldtype.'MaximumWidth' ) < ( $I->image_orientation() eq 'Vertical' ? $I->image_width() : $I->image_height() ) ) ) {
			$openprint::log->debug("Fold no good due to Maximum Width " . ( $I->image_orientation() eq 'Vertical' ? $I->image_width() : $I->image_height() ) . ' > ' . $Equipment->specification($foldtype.'MaximumWidth' ) ) if $debug;
			return 0;
		} # end if
		if ( ( $Equipment->specification($foldtype.'MinimumHeight' ) and $Equipment->specification($foldtype.'MinimumHeight') > ( $I->image_orientation() eq 'Vertical' ? $I->image_height() : $I->image_width() ) ) ) {
			$openprint::log->debug("Fold no good due to Minimum height " . ($I->image_orieintation() eq 'Vertical' ? $I->image_height() : $I->image_width() ) . ' < ' . $Equipment->specification($foldtype.'MinimumWidth' ) ) if $debug;
			return 0;
		} # end if
		if ( ( $Equipment->specification($foldtype.'MaximumHeight' ) and $Equipment->specification($foldtype.'MaximumHeight') < ( $I->image_orientation() eq 'Vertical' ? $I->image_height() : $I->image_width() ) ) ) {
			$openprint::log->debug("Fold no good due to Maximum height " . ($I->image_orieintation() eq 'Vertical' ? $I->image_height() : $I->image_width() ) . ' > ' . $Equipment->specification($foldtype.'MaximumHeight' ) ) if $debug;
			return 0;
		#} else {
			#$openprint::log->debug("Fold good due to Maximum height " . ($I->image_orieintation() eq 'Vertical' ? $I->image_height() : $I->image_width() ) . ' > ' . $Equipment->specification($foldtype.'MaximumHeight' ) ) if $debug;
		} # end if
	} # end if
	return 1;
} # end sub test_fold

sub signature_calc {
	my ( $Project, $signature_service_index, $sig_specs, $specs, $qty_index, $Paper, $Imposition ) = @_;
	$$specs{"txtQuantity$qty_index"} = int $$specs{"txtQuantity$qty_index"};
	$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};

	if ( ! $Imposition ) {
		$Imposition = new openprint::Imposition;
		$Imposition->paper( $Paper );
		$Imposition->load( $sig_specs, $qty_index );
	} # end if

	$$specs{'hdnBreakdown'.$qty_index} .= "Signature: $$sig_specs{'txtServiceDescription'}:<br/>" if $$sig_specs{'txtServiceDescription'};
	if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
		$$specs{'hdnBreakdown'.$qty_index} .= "No imposition.<br/>";
		return;
	} # endif
	if ( ! $$sig_specs{'txtSpreadSize'} ) {
		$$sig_specs{'txtSpreadSize'} = 2;
	} # end if

	my $bestPrice;
	my $bestRunPrice = 0;
	my $bestRunTime = 0;
	my $bestSetupPrice = 0;
	my $bestEquipment;
	my $bestFolds;

	if ( $$specs{'txtPressSheetComboItems'} ) {
		$$specs{"txtQuantity$qty_index"} *= $$specs{'txtPressSheetComboItems'};
	} # end if

	@equipment = openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Folding Capable'=>'Y'}, 'order'=>'lower(strname)' ) if ! @equipment;
	@stitchers = openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Stitching Capable'=>'Y'}, 'order'=>'lower(strname)' ) if ! @stitchers;
	
	my @my_equipment;

	if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		$openprint::log->debug("Overriding Equipment! " . $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"});
		if ( $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} ) {
			push @my_equipment, new openprint::Equipment( $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
		} # end if
		push @no_outputs, "ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index";
	} else {
		@my_equipment = @equipment;

		if ( my @Press = openprint::Equipment::find( 'strid'=>$$sig_specs{'ddmPress'.$qty_index} ) ) {
			my $Press = shift @Press;
			if ( $Press->specification('Folding Capable') ) {
				unshift @my_equipment, $Press;
			} # end if
		} # end if
	} # end if
	
	# If the stitching is happening on a piece of equipment that can't handle large signatures, then we need to cut them down instead of folding them.
	# Something like a duplo can do 4pg signatures only, so the cutting service will cut everything down, and we will show the 4pg sigs being folded on the duplo

	# First step, find out if we are stitching, then find out which equipment is being used for stitching
	my $services = $Project->services();
	#my $stitching_specs;
	if ( ! ( $$services{'SaddleStitching'} or $$services{'LoopStitching'} ) ) {
		@my_equipment = sets::exclude( \@stitchers, \@my_equipment );
	} # end if

	if ( ! @my_equipment ) {
		$$specs{'alert'} .= 'There is no Folding capable equipment.';
		return;
	} # end if

	#$openprint::log->debug("Makereadies...");
	my %makereadies;

	foreach my $ss_id ( $Project->signatures() ) {
		next if $Paper and $signature_service_index and ($ss_id > $signature_service_index);
		next if $ss_id >= $signature_service_index;
		my $s_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		foreach my $fold_type ( keys %fold_types ) {
			if ( $$specs{$fold_type."-Qty-$$s_specs{'SignatureIndex'}-$qty_index"} > 0 ) {
				push @{$makereadies{$$specs{"ddmEquipment-$$s_specs{'SignatureIndex'}-$qty_index"}}}, $fold_type;
			} # end if
		} # end foreach
	} # end foreach

	my $imposition;
	if ( $Imposition->StitchingImposition() ) {
		$imposition = $Imposition->StitchingImposition();
#$openprint::log->debug("Got impo from StitchingImposition $qty_index: $imposition out") if $debug;
	} elsif ( $$services{'SaddleStitching'} ) {
		my $stitching_specs = openprint::service::get_specs_ref( $Project, $$services{'SaddleStitching'}[0] );
		$imposition = $$stitching_specs{'Imposition'.$qty_index};
#$openprint::log->debug("Got impo from SaddleStitching: $imposition out") if $debug;
	} elsif ( $$services{'LoopStitching'} ) {
		my $stitching_specs = openprint::service::get_specs_ref( $Project, $$services{'LoopStitching'}[0] );
		$imposition = $$stitching_specs{'Imposition'.$qty_index};
#$openprint::log->debug("Got impo from LoopStitching: $imposition out") if $debug;
	} # end if
	$imposition = 1 if ! $imposition;

	my $pages = $Imposition->pages();
	$openprint::log->debug(sprintf('Sign info: %dx%d*%d,%dout %dout', $Imposition->spread_columns(), $Imposition->spread_rows(), $Imposition->spread_size(), $Imposition->imposition(), $imposition ) ) if $debug;

	# Foreach equipment, figure out which folds are required.
	foreach my $Equipment ( @my_equipment ) {
		my %folds;
		$$specs{'hdnBreakdown'.$qty_index} .= 'Equipment '.$Equipment->name().': ';

# Each piece of equipment can do different folds.  So we have to calculate what we can do as well.
		if ( $$specs{"chkOverrideFoldType-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
			foreach ( keys %fold_types ) {
				$$specs{$_."-Qty-$$sig_specs{'SignatureIndex'}-$qty_index"} = int $$specs{$_."-Qty-$$sig_specs{'SignatureIndex'}-$qty_index"};
				$folds{$_} = $$specs{$_."-Qty-$$sig_specs{'SignatureIndex'}-$qty_index"};
			} # end foreach
		} elsif ( $Equipment->strid() eq $$sig_specs{'ddmPress'.$qty_index} ) {
# Special case because we can't cut it in the middle of printing.  This case is basically for web presses

			my $foldtype = $Imposition->spread_columns().'x'.$Imposition->spread_rows().'-'.$pages.'Page-'.$Imposition->image_orientation().'SignatureFold';

			if ( test_fold( $Equipment, $Imposition, $sig_specs, $foldtype, $imposition ) ) {
				$folds{$pages.'PageSignatureFold'} += 1;
			} # end if
		} else {

			# FIgure out the fold.  Because this isn't the press, we have to figure out how it cuts...
			if ( $$sig_specs{'rdbTemplateType'} and $fold_types{$$sig_specs{'rdbTemplateType'}} ) {
#$openprint::log->debug("Templatetype: $$sig_specs{'rdbTemplateType'}");
				$_ = $Equipment->fits( $Imposition->image_width(), $Imposition->image_height(), $$sig_specs{'txtSpecificStockCalliper'} );
				if ( $_ ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "Doesn't fit: $_<br/>";
				} else {
					$folds{$$sig_specs{'rdbTemplateType'}} = 1;
				}

			} else {
#if ( $$sig_specs{"txtSignatureSpreadQuantity$qty_index"} ) {

				# A book
$openprint::log->debug("Starting spreads:" . $Imposition->spreads() . ' on ' . $Equipment->name()) if $debug;

				my @folds = ( $Imposition->copy() );
				my @good_folds;
				while ( @folds ) {
					my $I = shift @folds;
					last if ! $I->spreads();
					
					$_ = $Equipment->fits( $I->image_orientation() eq 'Vertical' ? ( $I->image_width() * $imposition, $I->image_height() ) : ( $I->image_width(), $I->image_height() * $imposition ), $$sig_specs{'txtSpecificStockCalliper'} );
					if ( ! $_ )  {
						my $fold_type = $I->pages().'PageSignatureFold';
						if ( test_fold( $Equipment, $I, $sig_specs, $fold_type ) ) {
							push @good_folds, $I;
							next;
						} # end if
						$fold_type= $I->spread_columns().'x'.$I->spread_rows().'-'.$I->pages().'PageSignatureFold';
						if ( test_fold( $Equipment, $I, $sig_specs, $fold_type ) ) {
							push @good_folds, $I;
							next;
						} # end if
					} else {
						$$specs{'hdnBreakdown'.$qty_index} .= 'Spreads ' . $I->spreads() . ' : ' . $_ . '<br/>';
						#$openprint::log->debug($_);
						next;
					} # end if
					# This tells us whether it's a book or not
					last if ! $$sig_specs{'txtSignatureSpreadQuantity'.$qty_index};

# If we have to cut it down
					if ( $I->spread_rows() > $I->spread_columns() ) {
						if ( $I->spread_rows() % 2 ) {
							my $i2 = $I->copy();
							$i2->spread_rows(1);
							push @folds, $i2;
							$I->spread_rows( $I->spread_rows() - 1 );
							push @folds, $I;
						} else {
							$I->spread_rows( $I->spread_rows()/2 );
							push @folds, $I;
							my $i2 = $I->copy();
							push @folds, $i2;
						} # end if
					} else {
						if ( $I->spread_columns() % 2 ) {
							my $i2 = $I->copy();
							$i2->spread_columns(1);
							push @folds, $i2;
							$I->spread_columns( $I->spread_columns() - 1 );
							push @folds, $I;
						} else {
							$I->spread_columns( $I->spread_columns()/2 );
							push @folds, $I;
							push @folds, $I->copy();
						} # end if
					} # end if
				} # end while spreads
				if ( @folds ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "Unable to fold all pages.<br/>";
					next;
				} else {
					foreach my $I ( @good_folds ) {
						$folds{$I->spreads()*$$sig_specs{'txtSpreadSize'}.'PageSignatureFold'} += 1;
					}
				} # end if
			} # end if
		} # end if

		next if ! %folds;
		my $totalTime = $Equipment->specification('Station Make Ready') * 60;

		my $totalPrice;
		foreach my $fold ( keys %folds ) {
			next if ! $folds{$fold};
		
			$openprint::log->debug("Pricing fold $fold : $folds{$fold}") if $debug;

			my $runSpeed = $Equipment->specification($fold.'RunSpeed');
			if ( ! $runSpeed ) {
				$$specs{'hdnBreakdown'.$qty_index} .= "No runspeed for $fold on " . $Equipment->name() ." : $runSpeed<br/>";
				next;
			} # end if

			# We are assumin at this point, that all these folds are posible on this equipment, so any errors are soft errors
			my %servicePrice = openprint::service::get_price_object( $openprint::log, $openprint::dbh, $openprint::variable, $fold, $folds{$fold} * $$specs{"txtQuantity$qty_index"}/$imposition, $Equipment );
			if ( ! %servicePrice ) {
				$$specs{'hdnBreakdown'.$qty_index} .= "No price assigned for $fold on ".$Equipment->name().". <br/>";
				next;
			} # end if

			my %setupPrice = openprint::service::get_price_object( $openprint::log, $openprint::dbh, $openprint::variable, $fold.'MakeReady', undef, $Equipment );
			if ( $setupPrice{'units'} eq 'Per Form' ) {
				$totalPrice += $setupPrice{'Price'};
			} elsif ( ! sets::isin( $fold, $makereadies{$Equipment->id()} ) ) {
				$totalPrice += $setupPrice{'Price'};
			} # end if

			my $runTime = sprintf( '%.4f', ($$specs{"txtQuantity$qty_index"}/$imposition) / $runSpeed );
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Folds: %d, QTY: %d, %dout Runspeed: %d/Hr = %.2f hours', $folds{$fold}, $$specs{'txtQuantity'.$qty_index}, $imposition, $runSpeed, $runTime) . "<br/>";

			if ( defined $bestPrice and $totalPrice > $bestPrice ) {
				last;
			} # end if

			# In hours
			if ( lc $servicePrice{'units'} eq 'per hour' ) {
				$servicePrice{'Total'} = $servicePrice{'Price'} * $runTime * $folds{$fold};
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('%s %s: Setup: %.2f, Run: $%.2f%s * %.2d:%.2d:%.2d = $%.2f', $folds{$fold}, $fold, $setupPrice{'Price'}, @servicePrice{'Price','units'}, misc::seconds_to_interval(int $runTime*3600), $servicePrice{'Total'} ) . "<br/>";
			} elsif ( sets::isin( lc $servicePrice{'units'}, ['per m', 'per 1000'] ) ) {
				$servicePrice{'Total'} = $servicePrice{'Price'} * ( $folds{$fold}*($$specs{"txtQuantity$qty_index"}/$imposition) / 1000 );
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('%s %s: Setup: %.2f, Run: $%.2f%s * %d = $%.2f', $folds{$fold}, $fold, $setupPrice{'Price'}, @servicePrice{'Price','units'}, $folds{$fold}*$$specs{"txtQuantity$qty_index"}, $servicePrice{'Total'} ) . "<br/>";
			} else {
				$$specs{'hdnBreakdown'.$qty_index} .= qq`No Units ($servicePrice{'units'}) given for $fold on `.$Equipment->name().",<br/>";
				next;
			} # end if
			
			$totalPrice += $servicePrice{'Total'};
			$totalTime += $runTime * 3600;
			if ( defined $bestPrice and $totalPrice > $bestPrice ) {
				last;
			} # end if
		
		} # end foreach fold
		$$specs{'hdnBreakdown'.$qty_index} .= 'Total: ' . sprintf($openprint::config{'ProjectMoneyFormat'}, $totalPrice ) . '<br/>';

		if ( ( $totalPrice < $bestPrice ) or ( ! defined $bestPrice ) ) {
			$bestPrice = $totalPrice;
			$bestEquipment = $Equipment;
			$bestRunTime = int($totalTime);
			$bestFolds = \%folds;
		} # end if
		last if ( $Equipment->strid() eq $$sig_specs{'ddmPress'.$qty_index} );
	} # end foreach Equipment
	my %results = (
		'Price'			=> $bestPrice,
		'MPrice'		=> $$specs{'txtQuantity'.$qty_index} ? ($bestPrice/$$specs{'txtQuantity'.$qty_index})*1000 : 0,
		'Equipment'		=> $bestEquipment,
		'Imposition'	=> $imposition,
		'Status'		=> $bestEquipment ? 'calculated' : 'uncalculated',
		'BestFolds'		=>	$bestFolds,
		);
	$$specs{'Status'} = $bestEquipment ? 'calculated' : 'uncalculated';
	return %results;
} # end sub signature_calc

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	if ( ! $project_index or ! $service_index ) {
		$log->debug("calc_folding called with ProjectIndex or ServiceIndex!");
		return;
	} # end if

	$log->debug(" Start FOLDING!!!!!!!!!!!!!!!!!!");
	# sig_calc overwrites $$specs{Status}, so we keep our own copy
	my $status = 'calculated';

	my $Project = new openprint::Project( $project_index );
	#my @signature_service_indices = openprint::print::get_signature_indices( $log, $dbh, $project_index );
	my $printing_specs = openprint::service::get_specs_ref( $project_index, openprint::project::get_project_type_service_index( $log, $dbh, $project_index ) );
	@equipment = openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Folding Capable'=>'Y'}, 'order'=>'lower(strname)' );
	@stitchers = openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Stitching Capable'=>'Y'}, 'order'=>'lower(strname)' );

	foreach my $qty_index ( 1 .. 3 ) {
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		next if ! int $$specs{"txtQuantity$qty_index"};
		$$specs{'hdnBreakdown'.$qty_index} = '';

		my $price;
		my $mprice;

		foreach my $signature_service_index ( sort $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
			$$sig_specs{'txtSpreadSize'} = $$printing_specs{'txtSpreadSize'} if ! $$sig_specs{'txtSpreadSize'};
			$$sig_specs{'txtSpreadSize'} = 2 if ! $$sig_specs{'txtSpreadSize'};

			if ( ( ! exists $$sig_specs{'txtSignatureSpreadQuantity'.$qty_index} ) or $$sig_specs{'txtSignatureSpreadQuantity'.$qty_index} ) {
				my %results = signature_calc( $Project, $signature_service_index, $sig_specs, $specs, $qty_index );
				$price += $results{'Price'};
				$mprice += $results{'MPrice'};
				if ( $results{'Equipment'} ) {
					$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = $results{'Equipment'}->id();
				} else {
					if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
						$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = '';
					} # end if
					$status = 'uncalculated';
				} # end if
				foreach ( keys %fold_types ) {
					$$specs{$_."-Qty-$$sig_specs{'SignatureIndex'}-$qty_index"} = $results{'BestFolds'}{$_};
				} # end foreach
			}# # end if
		} # end foreach signature

		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price );
		$$specs{"MPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $mprice );
$log->debug($$specs{'hdnBreakdown'.$qty_index});
	} # end foreach qty
	$log->debug(" END FOLDING!!!!!!!!!!!!!!!!!! $status");
	return $$specs{'Status'} = $status;
} # end sub calc

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my @equipment = openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Folding Capable'=>'Y'}, 'order'=>'lower(strname)' );
	push @equipment, openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Folding Capable'=>'When Printing'}, 'order'=>'lower(strname)' );

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();
	if ( ! ( $$services{'SaddleStitching'} or $$services{'LoopStitching'} ) ) {
		@equipment = sets::exclude( [ openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Stitching Capable'=>'Y'}, 'order'=>'lower(strname)' ) ], \@equipment );
	} # end if
	@{$$variable{'EquipmentArray'}} = map { $_->id(), $_->name() } @equipment;

	@{$$variable{'Signatures'}} = ();

	foreach my $signature_service_index ( $Project->signatures() ) {
		my $specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );
		push @{$$variable{'Signatures'}}, @$specs{'SignatureIndex','txtServiceDescription'};
	} # end foreach
	if ( @{$$variable{'Signatures'}} == 0 ) {
# this will display the first group of cutting fields for projects that dont' have a printing service.
		push @{$$variable{'Signatures'}}, 1;
	} # end if

} # end sub display

sub summary {
	return '';
} # end sub summary

sub runtime {
    my ( $p_id, $s_id, $specs, $qty_index ) = @_;
    return 0 if ! $$specs{'ddmEquipment'.$qty_index};
	my @Equipment = openprint::Equipment::find('strid'=>$$specs{'ddmEquipment'.$qty_index});
	return 0 if @Equipment != 1; 

    my $runTime = $Equipment[0]->specification( 'Station Make Ready' ) * 60;
    foreach my $name ( keys %$specs ) {
        if ( $name =~ /^txt(\w*)Qty$/ ) {
            my $type = $1;
            my $quantity = $$specs{$name} * $$specs{'txtQuantity'.$qty_index};
            if ( $quantity > 0 ) {
                my $runSpeed = $Equipment[0]->specification( $type.'RunSpeed' );
                if ( $runSpeed ) {
                    $runTime += $quantity * 3600 / $runSpeed; # Convert to seconds
                } # end if
            } # end if
        } # end if
    } # end foreach
    return $runTime;
} # end sub runtime

1;

__END__
