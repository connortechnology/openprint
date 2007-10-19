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

package openprint::Estimating::Scoring;
use strict;

require sql;
require openprint::service;
require openprint::Material;
require openprint::imposition;
require openprint::Paper;

require openprint::Estimating::Folding;
require openprint::Equipment;

my $debug = 0;

my @variables = (
	'txtQuantity',
	'txtQuantity1','txtQuantity2','txtQuantity3',
	'txtPrice1','txtPrice2','txtPrice3',
);

my @all_equipment;

sub variables {
	my @v = @variables;
	my $p_id = shift;

	my $Project = new openprint::Project( $p_id );
	foreach my $s_s_id ( $Project->signatures() ) {
		my $specs = openprint::service::get_specs_ref( $p_id, $s_s_id );
		foreach my $qty_index ( 1 .. 3 ) {
			next if ! $Project->quantity( $qty_index );
			push @v, "txtWidth-$$specs{'SignatureIndex'}", "txtHeight-$$specs{'SignatureIndex'}",
				"ddmEquipment-$$specs{'SignatureIndex'}-$qty_index", "chkOverrideEquipment-$$specs{'SignatureIndex'}-$qty_index",
				"txtImposition-$$specs{'SignatureIndex'}-$qty_index", "chkOverrideImposition-$$specs{'SignatureIndex'}-$qty_index",
				"txtLayoutWidth-$$specs{'SignatureIndex'}-$qty_index", "txtLayoutHeight-$$specs{'SignatureIndex'}-$qty_index",
				"txtQty-$$specs{'SignatureIndex'}", "chkOverrideQty-$$specs{'SignatureIndex'}", 
				"rdbDirection-$$specs{'SignatureIndex'}","chkOverrideDirection-$$specs{'SignatureIndex'}",
		} # end foreach
	} # end foreach
    return @v;
} # end sub variables

my @no_outputs = (
);

sub signature_needs {
	my ( $Project, $specs ) = @_;
# If it's not needing folding, then it doesn't need to be scored!!
	if ( ! openprint::Estimating::Folding::signature_needs($specs) ) {
#$log->debug("NeedFolding is not true");
		return 0;
	} # end if
	if ( ( $$specs{'txtSignatureType'} eq '' ) or ( $$specs{'txtSignatureType'} eq 'Cover Spreads' ) or ( $$specs{'txtSignatureType'} and ( $$specs{'SignatureIndex'} == 1 ) ) ) {
		my $Paper = openprint::Paper::load_from_signature( $Project, $specs );
$openprint::log->debug( "Score Required!: " . $Paper->score_required() );
		if ( $Paper->score_required() ) {
			return 1;
		} # end if
	} # end if
#$log->debug("Scoringn is not needed! ($$specs{'txtSignatureType'}) ($$specs{'SignatureIndex'})");
	return 0;
} # end sub signature_needs

# A function that is smart enough to return true if the project needs perfing/scoring, and false if it doesn't.
sub neccessary {
	my ( $Project ) = @_;

	$Project = new openprint::Project( $Project ) if ref $Project ne 'openprint::Project';

	my %services = $Project->get_services( );
	if ( $services{'NoBindery'} ) {
        #$log->debug(" ** Project is marked as No bindery, Scoring not needed ! ** ");
        return 0;
    } # end if

	# Only need scoring if it's being folded.
	if ( $services{'Folding'} ) {
		foreach my $signature_service_index ( $Project->signatures() ) {
			my $specs = openprint::service::get_specs_ref( $Project->id(), $signature_service_index );

			if ( signature_needs( $specs ) ) {
				return 1;
			} # end if
		} # end foreach
	} else {
		$openprint::log->debug("No Folding");
	} # end if

	return 0;
} # end sub neccessary

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();

	# Can only use the stitcher for scoring if we are stitching.  There are also thickness constraints
	my $stitching_service_index = $$services{'SaddleStitching'} ? $$services{'SaddleStitching'}[0] : undef;
	# Can only use the stitcher for scoring if we are stitching.  There are also thickness constraints
	$stitching_service_index = ( $$services{'LoopStitching'} ? $$services{'LoopStitching'}[0] : undef ) if ! $stitching_service_index;
	# Can only use the folder for scoring if we are folding.  There are also thickness constraints

	# juts for efficeincy
	my $cutting_service_index = $$services{'Cutting'};

	if ( ! @all_equipment ) {
		@all_equipment = openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Scoring Capable'=>'Y'} );
		if ( $stitching_service_index and $$services{'Folding'} ) {

			push @all_equipment, openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Scoring Capable'=>'When Folding'} );
		} # end if

		my @stitchers = openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Stitching Capable'=>'Y'} );
		if ( ! $stitching_service_index ) {
			@all_equipment = sets::exclude( \@stitchers, \@all_equipment );
		} # end if
	} # end if

	foreach my $qty_index ( 1 .. 3 ) {
		$$specs{'txtPrice'.$qty_index} = '';
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		if ( ! $$specs{"txtQuantity$qty_index"} > 0 ) {
			next;
		} # end if
		my $qty = $$specs{"txtQuantity$qty_index"};
		$$specs{'hdnBreakdown'.$qty_index} = "QTY: $qty:";

		my $totalServicePrice = 0;
		my $totalSetupPrice = 0;
		my $totalMaterialPrice = 0;
		my $qtyTotal = 0;

		foreach my $signature_service_index ( $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
			my %Price = signature_calc( $Project, $service_index, $specs, $signature_service_index, $sig_specs, $qty_index );
			$qtyTotal += $$specs{"txtQty-$$sig_specs{'SignatureIndex'}"};
			$totalSetupPrice += $Price{'SetupPrice'};
			$totalServicePrice += $Price{'ServicePrice'};
			$totalMaterialPrice += $Price{'MaterialPrice'};
		} # end foreach

		my $price = 0;
		my $additionalPrice = 0;
		my $unitPrice = 0;

		if ( $qtyTotal ) {
			$price = $totalSetupPrice + $qty * $totalServicePrice + $totalMaterialPrice;
			$unitPrice = $price / $qty;
		} # end if
		$$specs{"txtUnitPrice$qty_index"} = sprintf( '%.2f', $unitPrice );

		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price );
	} # end foreach

	$log->debug("END SCORING!!!!!!!!!!!!!!!!!!");
	return $status;
} # end sub calc

sub signature_calc {
	my ( $Project, $service_index, $specs, $signature_service_index, $sig_specs, $qty_index ) = @_;
$openprint::log->debug("sign calc");

	my $qty = $$specs{"txtQuantity$qty_index"};
	if ( $$specs{'txtPressSheetComboItems'} ) {
		$qty *= $$specs{'txtPressSheetComboItems'};
	} # end if
	$specs = openprint::service::get_specs_ref( $Project, $service_index ) if ! $specs;
	$sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index ) if ! $sig_specs;

	my %Results = (
		'Status' => 'uncalculated',
	);
	my $services = $Project->services();
	# Can only use the stitcher for scoring if we are stitching.  There are also thickness constraints
	my $stitching_service_index = $$services{'SaddleStitching'} ? $$services{'SaddleStitching'}[0] : undef;
	# Can only use the stitcher for scoring if we are stitching.  There are also thickness constraints
	$stitching_service_index = ( $$services{'LoopStitching'} ? $$services{'LoopStitching'}[0] : undef ) if ! $stitching_service_index;
	# juts for efficeincy
	my $cutting_service_index = $$services{'Cutting'} ? $$services{'Cutting'}[0] : undef;

	if ( ( $$sig_specs{'SignatureIndex'} == 1 ) and sets::isin( $$sig_specs{'txtSignatureType'}, ['Cover Spreads','Interior Spreads'] ) ) {
		my $proj_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );
		@$sig_specs{'txtFinalWidth','txtFinalHeight'} = @$proj_specs{'txtFinalWidth','txtFinalHeight'};
	} # end if

	$$specs{'hdnBreakdown'.$qty_index} .= "Signature: $$sig_specs{'txtServiceDescription'}, " if $$sig_specs{'txtServiceDescription'} ne '';

	if ( $$specs{"chkOverrideQty-$$sig_specs{'SignatureIndex'}"} ne 'Y' ) {
		get_scores( $Project, $specs, $sig_specs );
	} else {
		$openprint::log->debug('Override Scores');
	} # end if

	if ( $$specs{"chkOverrideDirection-$$sig_specs{'SignatureIndex'}"} ne 'Y' ) {
		if ( $$sig_specs{'txtWidth'} != $$sig_specs{'txtFinalWidth'} ) {
			$$specs{"rdbDirection-$$sig_specs{'SignatureIndex'}"} = 'Height';
		} else {
			$$specs{"rdbDirection-$$sig_specs{'SignatureIndex'}"} = 'Width';
		} # end if
	} # end if
	if ( $$specs{"rdbDirection-$$sig_specs{'SignatureIndex'}"} eq 'Width' ) {
		$$specs{"txtLength-$$sig_specs{'SignatureIndex'}"} = $$sig_specs{'txtFinalWidth'};
	} else {
		$$specs{"txtLength-$$sig_specs{'SignatureIndex'}"} = $$sig_specs{'txtFinalHeight'};
	} # end if
	@$specs{"txtWidth-$$sig_specs{'SignatureIndex'}", "txtHeight-$$sig_specs{'SignatureIndex'}"} = @$sig_specs{'txtWidth','txtHeight'};
	$$specs{'hdnBreakdown'.$qty_index} .= "# of Scores: ". $$specs{"txtQty-$$sig_specs{'SignatureIndex'}"} . "<br/>";
	return %Results if ! $$specs{"txtQty-$$sig_specs{'SignatureIndex'}"};

# If any of the signatures doesn't have an imposition, then we are in an incomplete state.
	if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
		$$specs{'alert'} .= "No imposition for signature $$sig_specs{'SignatureIndex'}";
		return %Results;
	} # end if

	my $bestPrice = 0;
	my $bestEquipment = '';
	my $bestSetupPrice = 0;
	my $bestMaterialPrice = 0;
	my $bestServicePrice = 0;
	my $bestImposition = 0;

	my @equipment;	
	if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		@equipment = openprint::Equipment::find( 'strid'=>$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
		$openprint::log->debug("Overriding Equipment to: " . $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
	} else {
		if ( ! @all_equipment ) {
			@all_equipment = openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Scoring Capable'=>'Y'} );
			if ( $stitching_service_index and $$services{'Folding'} ) {

				push @all_equipment, openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Scoring Capable'=>'When Folding'} );
			} # end if

			my @stitchers = openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Stitching Capable'=>'Y'} );
			if ( ! $stitching_service_index ) {
				@all_equipment = sets::exclude( \@stitchers, \@all_equipment );
			} # end if
		} # end if
		@equipment = @all_equipment;
	} # endif

# Get the impositions to consider
	my $imposition = new openprint::Imposition();
	$imposition->load( $sig_specs, $qty_index );

	if ( $imposition->runstyle() eq 'Work & Turn' ) {
		$imposition->columns( $imposition->columns()/2 );
	} elsif ( $imposition->runstyle() eq 'Work & Tumble' ) {
		$imposition->rows( $imposition->rows()/2 );
	} # end if

	if ( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		if ( $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} > $imposition->imposition() or $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} <= 0 ) {
			$$specs{'alert'} = "The specified imposition is not possible.";
			return %Results;
		} # end if
	} # end if

	my @cut_impositions = ();
	if ( $cutting_service_index ) {
		$imposition->display();
		my @imps = openprint::imposition::get_all_impositions( $imposition );
		$imposition->display();
		for ( my $i = 0; $i < @imps; $i += 1 ) {
			$imps[$i]->display();
			if ( ( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' )
					or ( $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} == $imps[$i]->imposition() )
			   ) {
				push @cut_impositions, $imps[$i];
			} # end if

# Remove any other impositions that have th same setup
			for ( my $j = $i + 1; $j < @imps; $j += 1 ) {
				if ( $imps[$i]->imposition() == $imps[$j]->imposition() and $imps[$i]->rows() == $imps[$j]->rows() ) {
					splice @imps, $j, 1;
					$j -= 1;
				} # end if
			} # end for
		} # end for
	} else {
		@cut_impositions = ( $imposition );
	} # end if

	foreach my $Equipment ( @equipment ) {
		$$specs{'hdnBreakdown'.$qty_index} .= "<br/>Equipment: ".$Equipment->name().', ';
		next if ( $Equipment->specification('Type') eq 'Folder' ) and ! $$services{'Folding'};
		my @impositions = ();
		if ( $Equipment->specification('Type') eq 'Press' ) {
			if ( $Equipment->strid() ne $$sig_specs{'ddmPress'.$qty_index} ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'Must be printed on same press.<br/>';
				next;
			} else {
				@impositions = ($imposition);
			} # end if
			if ( sets::isin( $$sig_specs{'ddmRunStyle'.$qty_index}, ['Work & Turn','Work & Tumble'] ) ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'Cant do an inline score when W&T.<br/>';
				next;
			} # end if
		} else {
			@impositions = @cut_impositions;
		} # end if
		foreach my $imposition ( @impositions ) {
			my $score_qty;
			if ( $Equipment->specification('Type') eq 'Press' ) {
				$score_qty = $$specs{"txtQty-$$sig_specs{'SignatureIndex'}"};
			} else {
				$score_qty = $$specs{"txtQty-$$sig_specs{'SignatureIndex'}"}*($$specs{"rdbDirection-$$sig_specs{'SignatureIndex'}"} eq 'Width' ? $imposition->rows() : $imposition->columns());
			} # end if

			
			my $setupPrice = openprint::service::get_price( $openprint::log, $openprint::dbh, $openprint::variable, 'ScoringMakeReady', $score_qty, $Equipment );
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf( 'Setup: %d scores $%.2f<br/>', $score_qty, $setupPrice);
			$$specs{'hdnBreakdown'.$qty_index} .= "\t\tImposition: $$imposition{'imposition'}: ";
			my $width = $$specs{"txtWidth-$$sig_specs{'SignatureIndex'}"} * ( $imposition->image_orientation() eq 'Vertical' ? $imposition->columns() : $imposition->rows() );
			my $height = $$specs{"txtHeight-$$sig_specs{'SignatureIndex'}"} * ( $imposition->image_orientation() eq 'Vertical' ? $imposition->rows() : $imposition->columns() );

			if ( $_ = fits_on_equipment( $Equipment, $width, $height, $$sig_specs{'txtSpecificStockCalliper'} ) ) {
				$$specs{'hdnBreakdown'.$qty_index} .= "Doesn't fit. $_<br/>";
				next;
			} # end if

			if ( $Equipment->specification('Type') eq 'Press' ) {
				if ( $_ = $Equipment->fits( $imposition->Paper()->width(), $imposition->Paper()->height(), $$sig_specs{'txtSpecificStockCalliper'} ) ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "Doesn't fit. $_<br/>";
					next;
				} # end if
			} else {
				if ( $_ = $Equipment->fits( $width, $height, $$sig_specs{'txtSpecificStockCalliper'} ) ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "Doesn't fit. $_<br/>";
					next;
				} # end if
			} # end if
			$$specs{'hdnBreakdown'.$qty_index} .= "<br/>";

			my $servicePrice;
			my $materialPrice = 0;

			my %servicePrice = openprint::service::get_price_object( $openprint::log, $openprint::dbh, $openprint::variable, 'Scoring', $score_qty, $Equipment );

			if ( lc $servicePrice{'units'} eq 'per m' ) {
				$servicePrice = $servicePrice{'Price'} / 1000;
			} elsif ( lc $servicePrice{'units'} eq 'per hour' ) {
				$servicePrice = $servicePrice{'Price'} / $Equipment->specification('PerfScoreRunSpeed') if $Equipment->specification('PerfScoreRunSpeed');
			} else {
				$$specs{'hdnBreakdown'.$qty_index} .= "Unknown units set on service price ($score_qty) ($servicePrice{'units'}) <br/>";
			} # end if
			$$specs{'hdnBreakdown'.$qty_index} .= "Service: \$ $servicePrice{'Price'} $servicePrice{'units'}, ";

			if ( my @Materials = openprint::Material::find('name'=>'ScoringRule') ) {
				my %materialPrice = $Materials[0]->get_price( $score_qty, $Equipment );
				if ( %materialPrice ) {
					if ( sets::isin( lc $materialPrice{'units'},['per rule','per score'] ) ) {
						$materialPrice = $materialPrice{'Price'} * $score_qty;
					} elsif ( lc $materialPrice{'units'} eq 'per inch' ) {
						$materialPrice = $materialPrice{'Price'} * $score_qty;
					} elsif ( $materialPrice{'units'} eq 'per foot' ) {
						$materialPrice = $materialPrice{'Price'} * $score_qty * $$specs{"txtLength-$$sig_specs{'SignatureIndex'}"} / 12;
					} else {
						$$specs{'hdnBreakdown'.$qty_index} .= "Unknown units set on material price ($materialPrice{'units'})<br/>";
					} # end if
				} # end if
				$$specs{'hdnBreakdown'.$qty_index} .= "Material: \$ $materialPrice{'Price'} $materialPrice{'units'}, ";
			} # end if

# Div by imposition
			$servicePrice /= $imposition->imposition() if $imposition->imposition();

			my $totalPrice = $setupPrice + $materialPrice + ( $qty * $servicePrice );
			$$specs{'hdnBreakdown'.$qty_index} .= "\t\tTotal: \$".sprintf('%.2f', int($totalPrice) )."<br/>";

			if ( $totalPrice < $bestPrice or $bestPrice == 0 ) {
				$bestPrice = $totalPrice;
				$bestSetupPrice = $setupPrice;
				$bestMaterialPrice = $materialPrice;
				$bestServicePrice = $servicePrice;
				$bestEquipment = $Equipment;
				$bestImposition = $imposition;
			} # end if
		} # end foreach equipment
	} # end foreach imposition

	$Results{'SetupPrice'} = $bestSetupPrice;
	$Results{'ServicePrice'} = $bestServicePrice;
	$Results{'MaterialPrice'} = $bestMaterialPrice;
	$Results{'Price'} = $bestSetupPrice + $qty * $bestServicePrice + $bestMaterialPrice;

	if ( $bestImposition ) {
		$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = $bestEquipment->strid();
		$$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} = $bestImposition->imposition();
		if ( $bestImposition->image_orientation() eq 'Vertical' ) {
			$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = $$specs{"txtWidth-$$sig_specs{'SignatureIndex'}"} * $bestImposition->columns();
			$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = $$specs{"txtHeight-$$sig_specs{'SignatureIndex'}"} * $bestImposition->rows();
		} else {
			$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = $$specs{"txtWidth-$$sig_specs{'SignatureIndex'}"} * $bestImposition->rows();
			$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = $$specs{"txtHeight-$$sig_specs{'SignatureIndex'}"} * $bestImposition->columns();
		} # end if
	} else {
		$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = '' if $$specs{"chkOverrideEquipment-$$sig_specs{SignatureIndex}-$qty_index"} ne 'Y';
		$$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
		$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
		$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
	} # end if

	if ( ! $bestEquipment ) {
		if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
			$$specs{'alert'} = "The selected equipment can not handle your project.  This may be because the stock is too heavy, or too large.";
		} else {
			$$specs{'alert'} = "No suitable equipment could be found for your project.  This may be because the stock is too heavy, or too large.";
		} # end if
	} else {
		$Results{'Status'} = 'calculated';
	} # end if
	return %Results;
} # end sub signature_calc

# figures ou the number of scores needed. May return 0 if signature doesn't need it.
sub get_scores {
	my ( $Project, $specs, $sig_specs ) = @_;

	if ( ! signature_needs( $Project, $sig_specs ) ) {
		$$specs{"txtQty-$$sig_specs{'SignatureIndex'}"} = 0;
		$openprint::log->debug("SIgnature $$sig_specs{'SignatureIndex'} doesn't need scoring in get_scores") if $debug;
		return;
	} # end if
	if ( $$sig_specs{'txtSignatureType'} eq 'Cover Spreads' ) {
		$$specs{"txtQty-$$sig_specs{'SignatureIndex'}"} = 1;
	} elsif ( $$sig_specs{'txtSignatureType'} eq 'Interior Spreads' ) {
		if ( $$sig_specs{'SignatureIndex'} == 1 ) {
			$$specs{"txtQty-$$sig_specs{'SignatureIndex'}"} = 1;
		} # end if
	} elsif ( $$sig_specs{'txtSignatureType'} eq 'Gate Fold Spreads' ) {
	} else { # normal printing
		if ( sets::isin( $$sig_specs{'rdbTemplateType'}, 'Portrait', 'Landscape' ) ) {
# needs no folding
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, ['4PageSignatureFold','2PanelFold','BusCardLandscapeFold','BusCardPortraitFold']) ) {
			$$specs{"txtQty-$$sig_specs{'SignatureIndex'}"} = 1;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, '3PanelFold', '3PanelZFold' ) ) {
			$$specs{"txtQty-$$sig_specs{'SignatureIndex'}"} = 2;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, '4PanelFold','4PanelZFold', 'AccordianFold', 'AccordianFold4Panel') ) {
			$$specs{"txtQty-$$sig_specs{'SignatureIndex'}"} = 3;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, '5PanelFold', '5PanelZFold') ) {
			$$specs{"txtQty-$$sig_specs{'SignatureIndex'}"} = 4;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, '6PanelFold', '6PanelZFold' ) ) {
			$$specs{"txtQty-$$sig_specs{'SignatureIndex'}"} = 5;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, 'SingleGateFold' ) ) {
			$$specs{"txtQty-$$sig_specs{'SignatureIndex'}"} = 2;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, 'DoubleGateFold' ) ) {
			$$specs{"txtQty-$$sig_specs{'SignatureIndex'}"} = 3;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, 'PF1Pocket', 'PF2Pocket' ) ) {
			$$specs{"txtQty-$$sig_specs{'SignatureIndex'}"} = 2;
		} else {
			if ( $$specs{'txtFinalWidth'} ) {
				my $cols = $$sig_specs{'txtWidth'} / $$specs{'txtFinalWidth'};
				my $mod_cols = $$sig_specs{'txtWidth'} % $$specs{'txtFinalWidth'};
				if ( $cols and ! $mod_cols ) {
					$$specs{"txtQty-$$sig_specs{'SignatureIndex'}"} = $cols;
				} elsif ( $$specs{'txtFinalHeight'} ) {
					my $rows = $$sig_specs{'txtHeight'} / $$specs{'txtFinalHeight'};
					my $mod_rows = $$sig_specs{'txtHeight'} % $$specs{'txtFinalHeight'};
					if ( $rows and ! $mod_rows ) {
						$$specs{"txtQty-$$sig_specs{'SignatureIndex'}"} = $rows;
					} # end if
				} # end if
			} # end if

		} # end if

	} # end if

	$openprint::log->debug(qq`Get_Scores:  $$specs{"txtQty-$$sig_specs{'SignatureIndex'}"}`) if $debug;

} # end sub get_scores

sub get_specs {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;
	my $Project = new openprint::Project( $project_index );
	my %services = $Project->get_services();

	@{$$variable{'SignatureGroups'}} = ();

	@{$$variable{'EquipmentArray'}} = map{ $_->id() } openprint::Equipment::find( 'Specifications' => {'Scoring Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'strName');

	if ( $services{'Folding'} ) {
		@{$$variable{'EquipmentArray'}} = sets::union( @{$$variable{'EquipmentArray'}}, 
				map{ $_->id() } openprint::Equipment::find( 'Specifications' => {'Scoring Capable'=>'When Folding'}, 'UseInEstimating'=>'Y','order'=>'strName'),
				);
	} # end if

	foreach my $signature_service_index ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );
		push @{$$variable{'SignatureGroups'}}, @$sig_specs{'SignatureIndex','txtServiceDescription'};
	} # end foreach
} # end sub get_specs

sub summary {
} # end sub summary

sub fits_on_equipment {
    my ( $Equipment, $width, $height, $calliper ) = @_;

    if ( $Equipment->specification('Minimum Score Size') and ( 1*$width < 1*$Equipment->specification('Minimum Score Size') ) ) {
        return "Doesn't fit minimum Score Size $width < " . $Equipment->specification('Minimum Score Size');
    } # end if

    if ( $Equipment->specification('Minimum Score Size') and ( 1*$height < 1*$Equipment->specification('Minimum Score Size') ) ) {
        return "Doesn't fit height minimum Score Size $height < " . $Equipment->specification('Minimum Score Size');
    } # end if
    if ( $Equipment->specification('Maximum Score Size') and ( 1*$width > 1*$Equipment->specification('Maximum Score Size') ) ) {
        return "Doesn't fit width maximum $width > " . $Equipment->specification('Maximum Score Size');
    } # end if

    if ( $Equipment->specification('Maximum Score Size') and ( 1*$height > 1*$Equipment->specification('Maximum Score Size') ) ) {
        return "Doesn't fit height max $height > " . $Equipment->specification('Maximum Score Size');
    } # end if
    if ( $Equipment->specification('Minimum Score Calliper') and 1*$calliper < 1*$Equipment->specifcation('Minimum Score Calliper') ) {
        return "Calliper too small: ($calliper), Min: " . $Equipment->specification('Minimum Score Calliper');
    } # end if
    if ( $Equipment->specification('Maximum Score Calliper') and 1*$calliper > 1*$Equipment->specification('Maximum Score Calliper') ) {
        return 'Calliper too big';
    } # end if
    return '';
} # end sub fits_on_equipment

1;

__END__
