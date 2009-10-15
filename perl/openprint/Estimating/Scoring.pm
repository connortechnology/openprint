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

my $debug = 1;

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
		my $specs = openprint::service::get_specs_ref( $Project, $s_s_id );
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			push @v, "txtWidth-$$specs{'SignatureIndex'}", "txtHeight-$$specs{'SignatureIndex'}",
				"ddmEquipment-$$specs{'SignatureIndex'}-$qty_index", "chkOverrideEquipment-$$specs{'SignatureIndex'}-$qty_index",
				"txtImposition-$$specs{'SignatureIndex'}-$qty_index", "chkOverrideImposition-$$specs{'SignatureIndex'}-$qty_index",
				"txtLayoutWidth-$$specs{'SignatureIndex'}-$qty_index", "txtLayoutHeight-$$specs{'SignatureIndex'}-$qty_index",
				"txtVerticalQty-$$specs{'SignatureIndex'}", "txtHorizontalQty-$$specs{'SignatureIndex'}", "chkOverrideQty-$$specs{'SignatureIndex'}", 
		} # end foreach
	} # end foreach
    return @v;
} # end sub variables

my @no_outputs = (
);

sub signature_needs {
	my ( $Project, $specs ) = @_;
# If it's not needing folding, then it doesn't need to be scored!!
	if ( ! openprint::Estimating::Folding::signature_needs( $Project, $specs) ) {
#$openprint::log->debug("NeedFolding is not true $$specs{'txtWidth'}x$$specs{'txtHeight'} : $$specs{'txtFinalWidth'}x$$specs{'txtFinalHeight'}");
		return 0;
	} # end if
	if ( ( $$specs{'txtSignatureType'} eq '' ) or ( $$specs{'txtSignatureType'} eq 'Cover Spreads' ) or ( $$specs{'txtSignatureType'} and ( $$specs{'SignatureIndex'} == 1 ) ) ) {
		my $Paper = openprint::Paper::load_from_signature( $Project, $specs );
#$openprint::log->debug( "Score Required!: " . $Paper->score_required() );
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

	my $services = $Project->services( );
	if ( $$services{'NoBindery'} ) {
        #$log->debug(" ** Project is marked as No bindery, Scoring not needed ! ** ");
        return 0;
    } # end if

	# Only need scoring if it's being folded.
	if ( $$services{'Folding'} ) {
		foreach my $signature_service_index ( $Project->signatures() ) {
			my $specs = openprint::service::get_specs_ref( $Project->id(), $signature_service_index );

			if ( signature_needs( $Project, $specs ) ) {
				return 1;
			} # end if
		} # end foreach
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

	my @capabilities = 'Y';
	push @capabilities, 'For Pocket Folders' if $Project->Type()->name() eq 'Presentation Folders';
	push @capabilities, 'When Folding' if $$services{'Folding'};

	@all_equipment = openprint::Equipment::find( 'Specifications' => {'Scoring Capable'=>\@capabilities}, 'UseInEstimating'=>'Y','order'=>'strName');

	my @stitchers = openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Stitching Capable'=>'Y'} );
	if ( ! $stitching_service_index ) {
		@all_equipment = sets::exclude( \@stitchers, \@all_equipment );
	} # end if

	foreach my $qty_index ( $Project->quantity_indexes() ) {
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
			$qtyTotal += $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"};
			$qtyTotal += $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"};
			$totalSetupPrice += $Price{'SetupPrice'};
			$totalServicePrice += $Price{'ServicePrice'};
			$totalMaterialPrice += $Price{'MaterialPrice'};
			$status = 'uncalculated' if $Price{'Status'} eq 'uncalculated';
		} # end foreach

		my $price = 0;
		my $additionalPrice = 0;
		my $unitPrice = 0;

		if ( $qtyTotal ) {
			$price = $totalSetupPrice + $totalServicePrice + $totalMaterialPrice;
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
$openprint::log->debug("Scoring sign calc");

	my $qty = $$specs{"txtQuantity$qty_index"};
	if ( $$specs{'txtPressSheetComboItems'} ) {
		$qty *= $$specs{'txtPressSheetComboItems'};
	} # end if
	$specs = openprint::service::get_specs_ref( $Project, $service_index ) if ! $specs;
	$sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index ) if ! $sig_specs;

	my %Results = (
		'Status' => 'calculated',
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

	my $score_qty = $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} + $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"};
$openprint::log->debug("Scores: $score_qty");
	@$specs{"txtWidth-$$sig_specs{'SignatureIndex'}", "txtHeight-$$sig_specs{'SignatureIndex'}"} = @$sig_specs{'txtWidth','txtHeight'};
	$$specs{'hdnBreakdown'.$qty_index} .= "# of Scores: $score_qty<br/>";
	return %Results if ! $score_qty;

# If any of the signatures doesn't have an imposition, then we are in an incomplete state.
	if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
		$$specs{'alert'} .= "No imposition for signature $$sig_specs{'SignatureIndex'}";
		return %Results;
	} # end if

	$Results{'Status'} = 'uncalculated';

	my $bestPrice = -1;
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
		#if ( ! @all_equipment ) {
			my @capabilities = 'Y';
			push @capabilities, 'For Pocket Folders' if $Project->Type()->name() eq 'Presentation Folders';
			push @capabilities, 'When Folding' if $$services{'Folding'};
			
			@all_equipment = openprint::Equipment::find( 'Specifications' => {'Scoring Capable'=>\@capabilities}, 'UseInEstimating'=>'Y','order'=>'strName');

			my @stitchers = openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Stitching Capable'=>'Y'} );
			if ( ! $stitching_service_index ) {
				@all_equipment = sets::exclude( \@stitchers, \@all_equipment );
			} # end if
		#} # end if
		@equipment = @all_equipment;
	} # endif
	foreach my $E ( @equipment ) {
		$openprint::log->debug( "Equipment: " . $E->strid() );
	}

# Get the impositions to consider
	my $imposition = new openprint::Imposition();
	$imposition->load( $sig_specs, $qty_index );

	if ( 1 ) {
		# IF it's a W&T, we have to cut in half first, so just do it.
		if ( $imposition->runstyle() eq 'Work & Turn' ) {
			$imposition->columns( $imposition->columns()/2 );
		} elsif ( $imposition->runstyle() eq 'Work & Tumble' ) {
			$imposition->rows( $imposition->rows()/2 );
		} # end if
	} # end if

	if ( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		if ( $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} > $imposition->imposition() or $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} <= 0 ) {
			$$specs{'alert'} = "The specified imposition is not possible.";
			return %Results;
		} # end if
	} # end if

	my @cut_impositions = ();
	if ( $cutting_service_index ) {
		#$imposition->display();
		my @imps = openprint::imposition::get_all_impositions( $imposition );
		for ( my $i = 0; $i < @imps; $i += 1 ) {
			#$imps[$i]->display();
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
		$$specs{'hdnBreakdown'.$qty_index} .= '<br/>Equipment: '.$Equipment->name().', ';
		if ( ( $Equipment->specification('Type') eq 'Folder' ) and ! $$services{'Folding'} ) {
			$$specs{'hdnBreakdown'.$qty_index} .= 'Not being folded.<br/>';
			next;
		} # end if
		if ( ( $Equipment->specification('Type') eq 'Stitcher' ) and ! $stitching_service_index ) {
			$$specs{'hdnBreakdown'.$qty_index} .= 'Not being stitched.<br/>';
			next;
		} # end if
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
			if ( $Equipment->specification('Type') ne 'Press' ) {
				$score_qty = ($$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"}*$imposition->columns()) + ($$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} * $imposition->rows() );
			} # end if

			my $width = $imposition->layout_width();
			my $height = $imposition->layout_height();

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
			$$specs{'hdnBreakdown'.$qty_index} .= '<br/>';
			my $setupPrice = openprint::service::get_price( $openprint::log, $openprint::dbh, $openprint::variable, 'ScoringMakeReady', $score_qty, $Equipment );
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf( 'MakeReady: for %d scores = $%.2f<br/>', $score_qty, $setupPrice);
			$$specs{'hdnBreakdown'.$qty_index} .= "\t\tImposition: $$imposition{'imposition'}: ";

			my $servicePrice;
			my $materialPrice = 0;

			my %servicePrice = openprint::service::get_price_object( $openprint::log, $openprint::dbh, $openprint::variable, 'Scoring', $qty, $Equipment );

			if ( lc $servicePrice{'units'} eq 'per m' ) {
				$servicePrice = $servicePrice{'Price'} * $qty / 1000;
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service: $%.2f%s * %d=%.2f<br/>', @servicePrice{'Price','units'}, $qty, $servicePrice );
			} elsif ( lc $servicePrice{'units'} eq 'per hour' ) {
				my $hours = $qty / $Equipment->specification('PerfScoreRunSpeed') if $Equipment->specification('PerfScoreRunSpeed');
				$servicePrice = $servicePrice{'Price'} * $hours;
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service: $%.2f%s @ %d%s =%.2f', @servicePrice{'Price','units'}, $Equipment->specification('PerfScoreRunSpeed'), 'Per Hour', $servicePrice );
			} elsif ( $servicePrice{'Price'} ) {
				$$specs{'hdnBreakdown'.$qty_index} .= "Unknown units set on service price ($score_qty) ($servicePrice{'units'}) <br/>";
			} # end if

			if ( my @Materials = openprint::Material::find('name'=>'ScoringRule') ) {
				my %materialPrice = $Materials[0]->get_price( $score_qty, $Equipment );
				if ( %materialPrice ) {
					if ( sets::isin( lc $materialPrice{'units'},['per rule','per score'] ) ) {
						$materialPrice = $materialPrice{'Price'} * $score_qty;
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Material: $%1$.2f%2$s * %4$dscores = $%3$.2f', @materialPrice{'Price','units'}, $materialPrice, $score_qty );
					} elsif ( sets::isin( lc $materialPrice{'units'},['per item'] ) ) {
						$materialPrice = $materialPrice{'Price'} * $imposition->imposition();
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Material: $%1$.2f%2$s * %4$dscores = $%3$.2f', @materialPrice{'Price','units'}, $materialPrice, $imposition->imposition() );
					} elsif ( lc $materialPrice{'units'} eq 'per inch' ) {
						$materialPrice = $materialPrice{'Price'} * $score_qty;
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Material: $%1$.2f%2$s * %4$dscores = $%3$.2f', @materialPrice{'Price','units'}, $materialPrice, $score_qty );
					} elsif ( $materialPrice{'units'} eq 'per foot' ) {
						$materialPrice = $materialPrice{'Price'} * $score_qty * $$specs{"txtLength-$$sig_specs{'SignatureIndex'}"} / 12;
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Material: $%1$.2f%2$s * %4$dscores = $%3$.2f', @materialPrice{'Price','units'}, $materialPrice, $score_qty );
					} else {
						$$specs{'hdnBreakdown'.$qty_index} .= "Unknown units set on material price ($materialPrice{'units'})<br/>";
					} # end if
				} # end if
			} # end if

# Div by imposition
			$servicePrice /= $imposition->imposition() if $imposition->imposition();

			my $totalPrice = $setupPrice + $materialPrice + $servicePrice;
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Total: $%.2f<br/>', $totalPrice );

			if ( $totalPrice < $bestPrice or $bestPrice == -1 ) {
$openprint::log->debug(sprintf('Choosing %dout on %s : $%.2f', $imposition->imposition(), $Equipment->name(), $totalPrice ) );
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
	$Results{'Price'} = $bestSetupPrice + $bestServicePrice + $bestMaterialPrice;

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
$openprint::log->debug("ALert: $$specs{'alert'}");
$openprint::log->debug("Break: ".$$specs{'hdnBreakdown'.$qty_index});
	return %Results;
} # end sub signature_calc

# figures ou the number of scores needed. May return 0 if signature doesn't need it.
sub get_scores {
	my ( $Project, $specs, $sig_specs ) = @_;

	if ( ! signature_needs( $Project, $sig_specs ) ) {
		# Default to 1 score, because we assume that if we have scoring, then we must want at least 1
		$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		$openprint::log->debug("SIgnature $$sig_specs{'SignatureIndex'} doesn't need scoring in get_scores") if $debug;
		return;
	} # end if
	if ( $$sig_specs{'txtSignatureType'} eq 'Cover Spreads' ) {
		if ( openprint::print::get_book_type( $Project ) eq 'PerfectBound' ) {
			$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = 4;
			$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		} else {
			$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = 1;
			$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		} # end if
	} elsif ( $$sig_specs{'txtSignatureType'} eq 'Interior Spreads' ) {
		if ( $$sig_specs{'SignatureIndex'} == 1 ) {
			$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = 1;
			$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		} # end if
	} elsif ( $$sig_specs{'txtSignatureType'} eq 'Gate Fold Spreads' ) {
	} else { # normal printing
		if ( sets::isin( $$sig_specs{'rdbTemplateType'}, 'Portrait', 'Landscape' ) ) {
# needs no folding
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, ['4PageSignatureFold','2PanelFold','BusCardLandscapeFold','BusCardPortraitFold']) ) {
			$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = 1;
			$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, '3PanelFold', '3PanelZFold' ) ) {
			$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = 2;
			$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, '4PanelFold','4PanelZFold', 'AccordianFold', 'AccordianFold4Panel') ) {
			$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = 3;
			$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, '5PanelFold', '5PanelZFold') ) {
			$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = 4;
			$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, '6PanelFold', '6PanelZFold' ) ) {
			$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = 5;
			$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, 'SingleGateFold' ) ) {
			$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = 2;
			$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, 'DoubleGateFold' ) ) {
			$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = 3;
			$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, 'PF1Pocket', 'PF2Pocket' ) ) {
			$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = 2;
			$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, '2Panel2Pocket' ) ) {
			$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = 1;
			$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = 1;
		} else {
			if ( $$specs{'txtFinalWidth'} ) {
				my $cols = $$sig_specs{'txtWidth'} / $$specs{'txtFinalWidth'};
				my $mod_cols = $$sig_specs{'txtWidth'} % $$specs{'txtFinalWidth'};
				if ( $cols and ! $mod_cols ) {
					$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = 2;
				} elsif ( $$specs{'txtFinalHeight'} ) {
					my $rows = $$sig_specs{'txtHeight'} / $$specs{'txtFinalHeight'};
					my $mod_rows = $$sig_specs{'txtHeight'} % $$specs{'txtFinalHeight'};
					if ( $rows and ! $mod_rows ) {
						$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = 0;
					} # end if
				} # end if
			} # end if

		} # end if

	} # end if

} # end sub get_scores

sub get_specs {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;
	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();

	@{$$variable{'SignatureGroups'}} = ();

	my @capabilities = 'Y';
	push @capabilities, 'For Pocket Folders' if $Project->Type()->name() eq 'Presentation Folders';
	push @capabilities, 'When Folding' if $$services{'Folding'};
	
	@{$$variable{'EquipmentArray'}} = map{ $_->id() } openprint::Equipment::find( 'Specifications' => {'Scoring Capable'=>\@capabilities}, 'UseInEstimating'=>'Y','order'=>'strName');

	foreach my $signature_service_index ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
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
