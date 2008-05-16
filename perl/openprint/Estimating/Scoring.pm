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
	'OverridePrice1', 'OverridePrice2', 'OverridePrice3',
	'Markup1', 'Markup2', 'Markup3',
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
				"txtVerticalQty-$$specs{'SignatureIndex'}", "txtHorizontalQty-$$specs{'SignatureIndex'}", "chkOverrideQty-$$specs{'SignatureIndex'}", 
		} # end foreach
	} # end foreach
    return @v;
} # end sub variables

my @no_outputs = (
);

sub signature_needs {
	my ( $Project, $specs, $sig_specs ) = @_;

	if ( $specs ) {
		if ( ( $$specs{"chkOverrideQty-$$sig_specs{'SignatureIndex'}"} eq 'Y' ) and
				( $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} or $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} ) ) {
			return 1;
		} # end if
	} # end if

# If it's not needing folding, then it doesn't need to be scored!!
	if ( ! openprint::Estimating::Folding::signature_needs( $Project, $sig_specs) ) {
#$openprint::log->debug("NeedFolding is not true $$specs{'txtWidth'}x$$specs{'txtHeight'} : $$specs{'txtFinalWidth'}x$$specs{'txtFinalHeight'}");
		return 0;
	} # end if
	if ( ( $$sig_specs{'txtSignatureType'} eq '' ) or ( $$sig_specs{'txtSignatureType'} eq 'Cover Pages' ) or ( $$sig_specs{'txtSignatureType'} and ( $$sig_specs{'SignatureIndex'} == 1 ) ) ) {
		my $Paper = openprint::Paper::load_from_signature( $Project, $sig_specs );
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

	my $specs = openprint::service::get_specs_ref( $Project, $$services{'Scoring'}[0] );

	# Only need scoring if it's being folded.
	if ( $$services{'Folding'} ) {
		foreach my $signature_service_index ( $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );

			if ( signature_needs( $Project, $specs, $sig_specs ) ) {
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

	foreach my $qty_index ( 1 .. 3 ) {
		$$specs{'txtPrice'.$qty_index} =~ s/[^\d\.]//g;
		$$specs{'Markup'.$qty_index} =~ s/[^\d\.\-]//g;
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		if ( ! $$specs{"txtQuantity$qty_index"} > 0 ) {
			next;
		} # end if
		my $qty = $$specs{"txtQuantity$qty_index"};
		$$specs{'hdnBreakdown'.$qty_index} = "QTY: $qty:";

		my $qtyTotal = 0;
		my $price = 0;

		foreach my $signature_service_index ( $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
			$$specs{'hdnBreakdown'.$qty_index} .= "Signature: $$sig_specs{'txtServiceDescription'}, " if $$sig_specs{'txtServiceDescription'} ne '';
			if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
				$$specs{'hdnBreakdown'.$qty_index} .= "No imposition for signature $$sig_specs{'SignatureIndex'}";
				next;
			} # end if

			my %Price = signature_calc( $Project, $service_index, $specs, $signature_service_index, $sig_specs, $qty_index );
			if ( $Price{'Equipment'} ) {
                $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = $Price{'Equipment'}->id();
                $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} = $Price{'Imposition'}->imposition();
                $$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = $Price{'Imposition'}->layout_width();
                $$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = $Price{'Imposition'}->layout_height();
                $status = $Price{'Status'};
            } else {
                $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = '' if $$specs{"chkOverrideEquipment-$$sig_specs{SignatureIndex}-$qty_index"} ne 'Y';
                $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
                $$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
                $$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
                $status = $Price{'Status'};
                if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
                    $$specs{'alert'} = "The selected equipment can not handle your project.  This may be because the stock is too heavy, or too large.";
                } else {
                    $$specs{'alert'} = "No suitable equipment could be found for your project.  This may be because the stock is too heavy, or too large.";
                } # end if
            } # end if
			$$specs{'hdnBreakdown'.$qty_index} .= $Price{'Breakdown'};


			$qtyTotal += $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"};
			$qtyTotal += $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"};
			if ( $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} eq '' and $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} eq '' ) {
				$$specs{'alert'} .= 'Please specify # of scores for form ' . $$sig_specs{'SignatureIndex'};
				$status = 'uncalculated';
			} # end if
			$price += $Price{'Price'};
			$status = 'uncalculated' if $Price{'Status'} eq 'uncalculated';
		} # end foreach

		my $unitPrice = 0;

		if ( $qtyTotal ) {
			$unitPrice = $price / $qty;
		} # end if
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $unitPrice );

		if ( $$specs{"OverridePrice$qty_index"} ne 'Y' ) {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price*(1+$$specs{"Markup$qty_index"}/100) );
		} else {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{"txtPrice$qty_index"} );
		} # end if
	} # end foreach

	$log->debug("END SCORING!!!!!!!!!!!!!!!!!!");
	return $status;
} # end sub calc

sub signature_calc {
	my ( $Project, $service_index, $specs, $signature_service_index, $sig_specs, $qty_index, $imposition ) = @_;

	my %Results = (
		'Status' => 'calculated',
		'Breakdown'	=>	'',
	);

	if ( $$specs{"chkOverrideQty-$$sig_specs{'SignatureIndex'}"} ne 'Y' ) {
		get_scores( $Project, $specs, $sig_specs );
	} else {
		$openprint::log->debug('Override Scores');
	} # end if

	my $score_qty = $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} + $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"};
	@$specs{"txtWidth-$$sig_specs{'SignatureIndex'}", "txtHeight-$$sig_specs{'SignatureIndex'}"} = @$sig_specs{'txtWidth','txtHeight'};
	$Results{'Breakdown'} .= "# of Scores: $score_qty<br/>";
	return %Results if ! $score_qty;

	$Results{'Status'} = 'uncalculated';
	my $services = $Project->services();
	my $qty = $$specs{"txtQuantity$qty_index"};
	if ( $$specs{'txtPressSheetComboItems'} ) {
		$qty *= $$specs{'txtPressSheetComboItems'};
	} # end if

	# Can only use the stitcher for scoring if we are stitching.  There are also thickness constraints
	my $stitching_service_index = $$services{'SaddleStitching'} ? $$services{'SaddleStitching'}[0] : undef;
	# Can only use the stitcher for scoring if we are stitching.  There are also thickness constraints
	$stitching_service_index = ( $$services{'LoopStitching'} ? $$services{'LoopStitching'}[0] : undef ) if ! $stitching_service_index;
	# juts for efficeincy
	my $cutting_service_index = $$services{'Cutting'} ? $$services{'Cutting'}[0] : undef;
# If any of the signatures doesn't have an imposition, then we are in an incomplete state.

	$Results{'Status'} = 'uncalculated';
	my @equipment;	
	if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		@equipment = openprint::Equipment::find( 'id'=>$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
		$openprint::log->debug("Overriding Equipment to: " . $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
	} else {
		if ( ! @all_equipment ) {
			@all_equipment = openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Scoring Capable'=>['Y','When Printing']} );
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
	if ( ! $imposition ) {
		$imposition = new openprint::Imposition();
		$imposition->load( $sig_specs, $qty_index );
	} else {
		$imposition = $imposition->copy();
	} # end if

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
		$Results{'Breakdown'} .= "<br/>Equipment: ".$Equipment->name().', ';
		next if ( $Equipment->specification('Type') eq 'Folder' ) and ! $$services{'Folding'};
		next if ( $Equipment->specification('Type') eq 'Stitcher' ) and ! $stitching_service_index;
		if ( $Equipment->specification('Scoring Capable') eq 'When Printing' and $Equipment->strid() ne $$sig_specs{'ddmPress'.$qty_index} ) {
			$Results{'Breakdown'} .= "Not printing on $$Equipment{name}.<br/>";
			next;
		} # end if
		my @impositions = ();
		if ( $Equipment->specification('Type') eq 'Press' ) {
			if ( sets::isin( $$sig_specs{'ddmRunStyle'.$qty_index}, ['Work & Turn','Work & Tumble'] ) ) {
				$Results{'Breakdown'} .= 'Cant do an inline score when W&T.<br/>';
				next;
			} # end if
			@impositions = ($imposition);
		} else {
			@impositions = @cut_impositions;
		} # end if
		if ( $$services{'NoOfflineBindery'} and ( $$sig_specs{'ddmPress'.$qty_index} ne $Equipment->strid() ) ) {
			$Results{'Breakdown'} .= "No Offline bindery and not printing on $$Equipment{name}.<br/>";
			next;
		} # end if
		foreach my $imposition ( @impositions ) {
			if ( $Equipment->specification('Type') ne 'Press' ) {
				$score_qty = ($$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"}*$imposition->columns()) + ($$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} * $imposition->rows() );
			} # end if

			my $width = $imposition->layout_width();
			my $height = $imposition->layout_height();

			if ( $_ = fits_on_equipment( $Equipment, $width, $height, $$sig_specs{'txtSpecificStockCalliper'} ) ) {
				$Results{'Breakdown'} .= "Doesn't fit. $_<br/>";
				next;
			} # end if

			if ( $Equipment->specification('Type') eq 'Press' ) {
				if ( $_ = $Equipment->fits( $imposition->Paper()->width(), $imposition->Paper()->height(), $$sig_specs{'txtSpecificStockCalliper'} ) ) {
					$Results{'Breakdown'} .= "Doesn't fit. $_<br/>";
					next;
				} # end if
			} else {
				if ( $_ = $Equipment->fits( $width, $height, $$sig_specs{'txtSpecificStockCalliper'} ) ) {
					$Results{'Breakdown'} .= "Doesn't fit. $_<br/>";
					next;
				} # end if
			} # end if
			$Results{'Breakdown'} .= '<br/>';
			my $setupPrice = openprint::service::get_price( 'ScoringMakeReady', $score_qty, $Equipment );
			$Results{'Breakdown'} .= sprintf( 'Setup: %d scores $%.2f<br/>', $score_qty, $setupPrice);
			$Results{'Breakdown'} .= "\t\tImposition: $$imposition{'imposition'}: ";

			my $servicePrice;
			my %servicePrice = openprint::service::get_price_object( 'Scoring', $score_qty, $Equipment );

			if ( lc $servicePrice{'units'} eq 'per m' ) {
				$servicePrice = $servicePrice{'Price'} * $qty / 1000;
				$Results{'Breakdown'} .= sprintf('Service: $%.2f%s * %d=%.2f<br/>', @servicePrice{'Price','units'}, $qty, $servicePrice );
			} elsif ( lc $servicePrice{'units'} eq 'per hour' ) {
				my $hours = $qty / $Equipment->specification('PerfScoreRunSpeed') if $Equipment->specification('PerfScoreRunSpeed');
				$servicePrice = $servicePrice{'Price'} * $hours;
				$Results{'Breakdown'} .= sprintf('Service: $%.2f%s @ %d%s =%.2f', @servicePrice{'Price','units'}, $Equipment->specification('PerfScoreRunSpeed'), 'Per Hour', $servicePrice );
			} elsif ( $servicePrice{'Price'} ) {
				$Results{'Breakdown'} .= "Unknown units set on service price ($score_qty) ($servicePrice{'units'}) <br/>";
			} # end if

            my $horizontal_rule = 0;
            my $horizontal_length = 0;
            my %horizontal_price;

            if ( $imposition->image_orientation() eq 'Vertical' and  $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} ) {
                $horizontal_rule = $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} * $imposition->rows();
                $horizontal_length = $horizontal_rule * $$sig_specs{'txtWidth'};
            } elsif ( $imposition->image_orientation() eq 'Horizontal' and  $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} ) {
                $horizontal_rule = $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} * $imposition->columns();
                $horizontal_length = $horizontal_rule * $$sig_specs{'txtHeight'};
            } # end if
        #$openprint::log->debug("Horizontal: $horizontal_rule");
            if ( $horizontal_rule ) {
                if ( my @Materials = openprint::Material::find('name'=>'ScoringRule') ) {
                    %horizontal_price = $Materials[0]->get_price( $horizontal_rule, $Equipment );
                    if ( sets::isin( lc $horizontal_price{'units'},['per rule','each','per score'] ) ) {
                        $horizontal_price{'Total'} = $horizontal_price{'Price'} * $horizontal_rule;
                        $Results{'Breakdown'} .= sprintf('Rule: $%1$.2f%2$s * %4$d rule=%3$.2f', @horizontal_price{'Price','units','Total'}, $horizontal_rule );
                    } elsif ( lc $horizontal_price{'units'} eq 'per inch' ) {
                        $horizontal_price{'Total'} = $horizontal_price{'Price'} * $horizontal_length;
                        $Results{'Breakdown'} .= sprintf('Rule: $%1$.2f%2$s * %4$.2finches=%3$.2f', @horizontal_price{'Price','units','Total'}, $horizontal_length );
                    } elsif ( $horizontal_price{'units'} eq 'per foot' ) {
                        $horizontal_price{'Total'} = $horizontal_price{'Price'} * $horizontal_length/12;
                        $Results{'Breakdown'} .= sprintf('Rule: $%1$.2f%2$s * %4$.2finches=%3$.2f', @horizontal_price{'Price','units','Total'}, $horizontal_length/12 );
                    } else {
                        $Results{'Breakdown'} .= "Unknown units set on material price ($horizontal_price{'units'})<br/>";
                    } # end if
                } # end if
            } # end if

          my $vertical_rule = 0;
            my $vertical_length = 0;
            my %vertical_price;

            if ( $imposition->image_orientation() eq 'Vertical' and  $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} ) {
                $vertical_rule = $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} * $imposition->columns();
                $vertical_length = $vertical_rule * $$sig_specs{'txtHeight'};
            } elsif ( $imposition->image_orientation() eq 'Horizontal' and  $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} ) {
                $vertical_rule = $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} * $imposition->rows();
                $vertical_length = $vertical_rule * $$sig_specs{'txtWidth'};
            } # end if

        #$openprint::log->debug("Vertical: $vertical_rule");
            if ( $vertical_rule ) {
                if ( my @Materials = openprint::Material::find('name'=>'PerforatingWheel') ) {
                    %vertical_price = $Materials[0]->get_price( $vertical_rule, $Equipment );
                    if ( sets::isin( lc $horizontal_price{'units'},['per rule','each'] ) ) {
                        $vertical_price{'Total'} = $vertical_price{'Price'} * $vertical_rule;
                        $Results{'Breakdown'} .= sprintf('Wheel: $%1$.2f2$%s * %4$d wheels=%3$.2f', @vertical_price{'Price','units','Total'}, $vertical_rule );
                    } elsif ( lc $vertical_price{'units'} eq 'per inch' ) {
                        $vertical_price{'Total'} = $vertical_price{'Price'} * $vertical_length;
                        $Results{'Breakdown'} .= sprintf('Wheel: $%1$.2f2$%s * %4$.2finches=%3$.2f', @vertical_price{'Price','units','Total'}, $vertical_length );
                    } elsif ( $vertical_price{'units'} eq 'per foot' ) {
                        $vertical_price{'Total'} = $vertical_price{'Price'} * $vertical_length/12;
                        $Results{'Breakdown'} .= sprintf('Wheel: $%1$.2f2$%s * %4$.2finches=%3$.2f', @vertical_price{'Price','units','Total'}, $vertical_length/12 );
                    } else {
                        $Results{'Breakdown'} .= "Unknown units set on material price ($vertical_price{'units'})<br/>";
                    } # end if
                } # end if
            } # end if

# Div by imposition
			$servicePrice /= $imposition->imposition() if $imposition->imposition();

			my $totalPrice = $setupPrice + $vertical_price{'Total'} + $horizontal_price{'Total'} + $servicePrice;
			$Results{'Breakdown'} .= sprintf('Total: $%.2f<br/>', $totalPrice );

			if ( $totalPrice < $Results{'Price'} or ! exists $Results{'Price'} ) {
				$Results{'Price'} = $totalPrice;
                $Results{'SetupPrice'} = $setupPrice;
                $Results{'ServicePrice'} = $servicePrice;
                $Results{'HorizontalPrice'} = \%horizontal_price;
                $Results{'VerticalPrice'} = \%vertical_price;
                $Results{'Equipment'} = $Equipment;
                $Results{'Imposition'} = $imposition;
                $Results{'Runspeed'} = $Equipment->specification('Scoring Runspeed');
			} # end if
		} # end foreach equipment
	} # end foreach imposition

	if ( $Results{'Equipment'} ) {
		$Results{'Status'} = 'calculated';
	} else {
		$Results{'Status'} = 'uncalculated';
	} # end if
	return %Results;
} # end sub signature_calc

# figures ou the number of scores needed. May return 0 if signature doesn't need it.
sub get_scores {
	my ( $Project, $specs, $sig_specs ) = @_;

	if ( ! signature_needs( $Project, $specs, $sig_specs ) ) {
		# Default to 1 score, because we assume that if we have scoring, then we must want at least 1
		$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		$openprint::log->debug("SIgnature $$sig_specs{'SignatureIndex'} doesn't need scoring in get_scores") if $debug;
		return;
	} # end if
	if ( $$sig_specs{'txtSignatureType'} eq 'Cover Pages' ) {
		if ( openprint::print::get_book_type( $Project ) eq 'PerfectBound' ) {
			$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = 4;
			$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		} else {
			$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = 1;
			$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		} # end if
	} elsif ( $$sig_specs{'txtSignatureType'} eq 'Interior Pages' ) {
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

	@{$$variable{'Equipment'}} = openprint::Equipment::find( 'Specifications' => {'Scoring Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'strName');
	push @{$$variable{'Equipment'}}, openprint::Equipment::find( 'Specifications' => {'Scoring Capable'=>'When Printing'}, 'UseInEstimating'=>'Y','order'=>'strName');

	if ( $$services{'Folding'} ) {
		push @{$$variable{'Equipment'}}, openprint::Equipment::find( 'Specifications' => {'Scoring Capable'=>'When Folding'}, 'UseInEstimating'=>'Y','order'=>'strName');
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
