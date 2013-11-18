# Copyright (C) 2007 Isaac Connor <isaac@connortechnology.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA	02110-1301, USA
use strict;

package openprint::Estimating::Scoring;

require sql;
require openprint::service;
require openprint::Material;
require openprint::imposition;
require openprint::Paper;

require openprint::Estimating::Folding;
require openprint::Equipment;

use constant DEBUG => 0;

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

sub outputs {
} # end sub outputs

sub has_overrides {
    my ( $Project, $service_id, $specs ) = @_;
    $specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;

    my @v;
    foreach my $s_s_id ( $Project->signatures() ) {
        my $sig_specs = openprint::service::get_specs_ref( $Project, $s_s_id );
        foreach my $qty_index ( $Project->quantity_indexes() ) {
            push @v, "chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index" if $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"};
            push @v, "chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index" if $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"};
        } # end foreach
    } # end foreach

    return @v;

} # end sub has_overrides
sub signature_needs {
	my ( $Project, $specs, $sig_specs, $Paper ) = @_;

#$openprint::log->debug("Scoring::need $$sig_specs{SignatureIndex} : " .$$specs{"chkOverrideQty-$$sig_specs{'SignatureIndex'}"});
	if ( $specs ) {
	# This is because for non-books, the specs hash doesn't have the SignatureIndex filledin.
		my $sig_index = $$sig_specs{"SignatureIndex"} * 1;
		if ( ( $$specs{"chkOverrideQty-$sig_index"} eq 'Y' ) and
				( $$specs{"txtVerticalQty-$sig_index"} or $$specs{"txtHorizontalQty-$sig_index"} ) ) {
			return 1;
		} # end if
	} # end if

# If it's not needing folding, then it doesn't need to be scored!!
	if ( ! openprint::Estimating::Folding::signature_needs( $Project, $sig_specs) ) {
#$openprint::log->debug("NeedFolding is not true $$specs{'txtWidth'}x$$specs{'txtHeight'} : $$specs{'txtFinalWidth'}x$$specs{'txtFinalHeight'}");
		return 0;
	} # end if
	if ( ( $$sig_specs{'txtSignatureType'} eq '' ) or ( $$sig_specs{'txtSignatureType'} eq 'Cover Pages' ) or ( $$sig_specs{'txtSignatureType'} and ( $$sig_specs{'SignatureIndex'} == 1 ) ) ) {
		$Paper = openprint::Paper::load_from_signature( $Project, $sig_specs ) if ! $Paper;
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

	my $services = $Project->services( );
	if ( $$services{'NoBindery'} ) {
		#$log->debug(" ** Project is marked as No bindery, Scoring not needed ! ** ");
		return 0;
	} # end if

	# Only need scoring if it's being folded.
	if ( $$services{'Folding'} and @{$$services{'Folding'}} ) {
		my $specs = openprint::service::get_specs_ref( $Project, $$services{'Scoring'}[0] ) if $$services{'Scoring'};
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

	foreach my $qty_index ( $Project->quantity_indexes() ) {
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
			$qty = $$specs{"txtQuantity$qty_index"};
			if ( $$sig_specs{'Versions'} ) {
				$qty *= $$sig_specs{'Versions'};
			} # end if
			$$specs{'hdnBreakdown'.$qty_index} .= "Signature: $$sig_specs{'txtServiceDescription'}, " if $$sig_specs{'txtServiceDescription'} ne '';
			if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
				$$specs{'hdnBreakdown'.$qty_index} .= "No imposition for signature $$sig_specs{'SignatureIndex'}";
				next;
			} # end if
			my $Imposition = new openprint::Imposition();
			$Imposition->load( $sig_specs, $qty_index );

			my %Price = signature_calc( $Project, $service_index, $specs, $signature_service_index, $sig_specs, $qty_index, $Imposition );
			$status = $Price{'Status'} if $Price{'Status'} eq 'uncalculated';
			if ( $Price{'Equipment'} ) {
				$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = $Price{'Equipment'}->id();
				$$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} = $Price{'Imposition'}->imposition();
				$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = $Price{'Imposition'}->layout_width();
				$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = $Price{'Imposition'}->layout_height();
			} else {
				$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = '' if $$specs{"chkOverrideEquipment-$$sig_specs{SignatureIndex}-$qty_index"} ne 'Y';
				$$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
				$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
				$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
				if ( $Price{'Status'} eq 'uncalculated' ) {
					if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
						$$specs{'alert'} = "The selected equipment can not handle your project.	This may be because the stock is too heavy, or too large.";
					} else {
						$$specs{'alert'} = "No suitable equipment could be found for your project.	This may be because the stock is too heavy, or too large.";
					} # end if
				} # end if
			} # end if
			$$specs{'hdnBreakdown'.$qty_index} .= $Price{'Breakdown'};
			$$specs{'alert'} .= $Price{alert};

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
			$unitPrice = $price / $qty if $qty;
		} # end if
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $unitPrice * (1+$Project->markup()/100) );

		if ( $$specs{"OverridePrice$qty_index"} ne 'Y' ) {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price*(1+$$specs{"Markup$qty_index"}/100) * (1+$Project->markup()/100) );
		} else {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{"txtPrice$qty_index"} );
		} # end if
	} # end foreach

	$log->debug("END SCORING!!!!!!!!!!!!!!!!!!");
	return $$specs{'Status'} = $status;
} # end sub calc

sub signature_calc {
	my ( $Project, $service_index, $specs, $signature_service_index, $sig_specs, $qty_index, $imposition ) = @_;
	my %Results = (
		'Status' => 'calculated',
		'Breakdown'	=>	'',
	);
	$$sig_specs{'SignatureIndex'} *= 1;
	if ( $$specs{"chkOverrideQty-$$sig_specs{'SignatureIndex'}"} ne 'Y' ) {
		get_scores( $Project, $specs, $sig_specs, $imposition->Paper() );
	#} else {
		#$openprint::log->debug('Override Scores');
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
	if ( $$sig_specs{'Versions'} ) {
		$qty *= $$sig_specs{'Versions'};
	} # end if

	# Can only use the stitcher for scoring if we are stitching.	There are also thickness constraints
	my $stitching_service_index = $$services{'SaddleStitching'} ? $$services{'SaddleStitching'}[0] : undef;
	# Can only use the stitcher for scoring if we are stitching.	There are also thickness constraints
	$stitching_service_index = ( $$services{'LoopStitching'} ? $$services{'LoopStitching'}[0] : undef ) if ! $stitching_service_index;
	# juts for efficeincy
	my $cutting_service_index = $$services{'Cutting'} ? $$services{'Cutting'}[0] : undef;

	$Results{'Status'} = 'uncalculated';
	my @equipment;	
	if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		@equipment = openprint::Equipment->find( 'id'=>$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
		$openprint::log->debug("Overriding Equipment to: " . $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
	} else {
		my @capabilities = ('Y','When Printing');
		push @capabilities, 'For Pocket Folders' if $Project->Type()->name() eq 'PresentationFolders';
		push @capabilities, 'When Folding' if $$services{'Folding'} and @{$$services{'Folding'}};
		push @capabilities, 'When PerfectBinding' if $$services{'PerfectBound'} and @{$$services{'PerfectBound'}};
		push @capabilities, 'When Stitching' if $stitching_service_index;
		
		@equipment = openprint::Equipment->find( 'Specifications' => {'Scoring Capable'=>\@capabilities}, 'useinestimating'=>1,'order'=>'strName');
	} # endif
	if ( DEBUG ) {
	foreach my $E ( @equipment ) {
		#$openprint::log->debug( "Equipment: " . $E->strid() );
	}
	}

# Get the impositions to consider
	if ( ! $imposition ) {
		$imposition = new openprint::Imposition();
		$imposition->load( $sig_specs, $qty_index );
	} else {
		$imposition = $imposition->copy();
	} # end if
	if ( ! $imposition->imposition() ) {
		$Results{alert} .= "Unable to load the imposition.  This likely is because printing has not finished calculating.<br/>";
		return $Results{Status} = 'uncalculated';
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
			$imps[$i]->display() if DEBUG;
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
		my $type = $Equipment->specification('Type');
		if ( ( $type eq 'Folder' ) and ( $Equipment->specification('Scoring Capable') eq 'When Folding' ) and ! ( $$services{'Folding'} and @{$$services{'Folding'}} ) ) {
			$Results{'Breakdown'} .= 'Not being folded.<br/>';
			if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
				$Results{alert} .= 'Not being folded.<br/>';;
			} # end if
			next;
		} # end if
		if ( ( $type eq 'Stitcher' ) and ! $stitching_service_index ) {
			$Results{'Breakdown'} .= 'Not being stitched.<br/>';
			next;
		} # end if
		next if ( $type eq 'PerfectBinder' ) and ! $$services{'PerfectBound'};
		if ( $Equipment->specification('Scoring Capable') eq 'When Printing' and $Equipment->strid() ne $$sig_specs{'ddmPress'.$qty_index} ) {
			$Results{'Breakdown'} .= "Not printing on $$Equipment{name}.<br/>";
			next;
		} # end if
		my @impositions = ();
		if ( $type eq 'Press' ) {
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
		my $max_feed_width = $Equipment->specification('Maximum Feed Width');
		$Results{'Breakdown'} .= "Maximum Feed Width: $max_feed_width<br/>" if $max_feed_width;
		my $orientation = $Equipment->specification('Orientation');

		foreach my $I ( @impositions ) {
			next if ! $I->imposition();
			if ( ! int($I->imposition()) ) {
				$openprint::log->error("Bad imposition in Scoring: $$I{imposition}");
				next;
			} # end if
			next if ( $imposition->imposition() % $I->imposition() );
			$Results{'Breakdown'} .= $I->to_string().'<br/>';
			if ( $type ne 'Press' ) {
				$score_qty = ($$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"}*$I->columns()) + ($$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} * $I->rows() );
			} # end if

			my $width = $I->layout_width();
			my $height = $I->layout_height();

			if ( $_ = fits_on_equipment( $Equipment, $width, $height, $$sig_specs{'txtSpecificStockCalliper'}, $sig_specs ) ) {
				$Results{'Breakdown'} .= "Doesn't fit. $_<br/>";
				next;
			} # end if
			if ( $max_feed_width ) {
				if ( $orientation ) {
					$Results{'Breakdown'} .= "Has orientation setting.<br/>";
					if (
							( $orientation eq 'Portrait' and $I->layout_width() <= $I->layout_height() ) or
							( $orientation eq 'Landscape' and $I->layout_width() >= $I->layout_height() )
					   ) {
						if ( $I->layout_width() >= $max_feed_width ) {
							$Results{'Breakdown'} .= "Score no good due to max feed width($max_feed_width) on width ($$sig_specs{txtWidth}).<br/>";
							next;
						} # end if
					} else {
						if ( $I->layout_height() >= $max_feed_width ) {
							$Results{'Breakdown'} .= "Score no good due to max feed width($max_feed_width) on width ($$sig_specs{txtHeight}).<br/>";
							next;
						} # end if
					} # end if
				} else {
					if ( $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} and $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} ) {
# Do nothing, we already know it fits on the machine, and it has to go one way or another.
						$Results{'Breakdown'} .= 'Running either way because scores both ways.<br/>';
					} elsif ( $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} ) {
						if ( $I->image_orientation() eq 'Vertical' ) {
							$Results{'Breakdown'} .= 'Running ' . $I->layout_width() . ' ' . $I->image_orientation() . ' on feed of ' . $max_feed_width . '<br/>';
							if ( $I->layout_width() >= $max_feed_width ) {
								$Results{'Breakdown'} .= "Score no good due to max feed width($max_feed_width) on width (".$I->layout_width().").<br/>";
								next;
							} # end if
						} else {
							$Results{'Breakdown'} .= 'Running ' . $I->layout_height() . ' on feed of ' . $max_feed_width . '<br/>';
						} # end if
					} elsif ( $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} ) {
						if ( $I->image_orientation() eq 'Horizontal' ) {
							$Results{'Breakdown'} .= 'Running ' . $I->layout_height() . ' on feed of ' . $max_feed_width . '<br/>';
							if ( $I->layout_height() >= $max_feed_width ) {
								$Results{'Breakdown'} .= "Score no good due to max feed width($max_feed_width) on width (".$I->layout_height().").<br/>";
								next;
							} # end if
						} else {
							$Results{'Breakdown'} .= 'Running ' . $I->layout_width() . ' on feed of ' . $max_feed_width . '<br/>';
						} # end if
					} else {
						$Results{'Breakdown'} .= 'Running ' . $I->layout_height() . ' on feed of ' . $max_feed_width . '<br/>';
					} # end if
				} # end if orientation or not
			} # end if max_feed)wudetg
			if ( ( $_ = $Equipment->specification('Maximum Imposition') ) and ( $_ < $I->imposition() ) ) {
				$Results{'Breakdown'} .= "Imposition $$I{imposition}out too high. Maximum: $_<br/>";
				next;
			} # end if

			if ( $type eq 'Press' ) {
				if ( $_ = $Equipment->fits( $I->Paper()->width(), $I->Paper()->height(), $$sig_specs{'txtSpecificStockCalliper'} ) ) {
					$Results{'Breakdown'} .= "Doesn't fit. $_<br/>";
					next;
				} # end if
			} else {
				if ( $_ = $Equipment->fits( $width, $height ) ) {
					$Results{'Breakdown'} .= "Doesn't fit. $_<br/>";
					next;
				} # end if
			} # end if
			$Results{'Breakdown'} .= '<br/>';
			my $setupPrice;
			if ( ( $type eq 'Folder' ) and ! ( $$services{Folding} and @{$$services{Folding}} ) ) {
				$setupPrice = openprint::service::get_price( 'ScoringMakeReadyWithoutFolding', $score_qty, $Equipment );
				$setupPrice = openprint::service::get_price( 'ScoringMakeReady', $score_qty, $Equipment ) if ! $setupPrice;
			} else {
				$setupPrice = openprint::service::get_price( 'ScoringMakeReady', $score_qty, $Equipment );
			} # end if
		
			$Results{'Breakdown'} .= sprintf( 'MakeReady: for %d scores = $%.2f<br/>', $score_qty, $setupPrice );
			$Results{'Breakdown'} .= "Imposition: $$I{columns}x$$I{rows}=$$I{'imposition'}: ";

			my $use_qty = ($qty /$imposition->imposition()) * ( $imposition->imposition() / $I->imposition() );
			my $Overs = $Equipment->Specification( 'Scoring Overs', $use_qty );
			if ( $$Overs{'units'} eq 'Sheets' ) {
				my $overs = $$Overs{'value'};
				$use_qty += $overs;
				$Results{'Overs'} = $overs;
				$Results{'Breakdown'} .= 'Overs: ' . $overs . '<br/>';
			} # end if

			my $servicePrice;
			my %servicePrice;
			if ( ( $type eq 'Folder' ) and ! ( $$services{Folding} and @{$$services{Folding}} ) ) {
				%servicePrice = openprint::service::get_price_object( 'ScoringWithoutFolding', $use_qty, $Equipment );
				%servicePrice = openprint::service::get_price_object( 'Scoring', $use_qty, $Equipment ) if ! %servicePrice;
			} else {
				%servicePrice = openprint::service::get_price_object( 'Scoring', $use_qty, $Equipment );
			} # end if

			if ( $servicePrice{'units'} eq 'per m' ) {
				$servicePrice = Math::Round::nearest( 0.01, $servicePrice{'Price'} * $use_qty / 1000 );
				$Results{'Breakdown'} .= sprintf('Service: $%.2f%s * %d * %d scores=$%.2f<br/>', @servicePrice{'Price','units'}, $use_qty, $score_qty, $servicePrice );
			} elsif ( $servicePrice{'units'} eq 'per hour' ) {
				my $hours = $use_qty / $Equipment->specification('PerfScoreRunSpeed') if $Equipment->specification('PerfScoreRunSpeed');
				$servicePrice = Math::Round::nearest( 0.01, $servicePrice{'Price'} * $hours );
				$Results{'Breakdown'} .= sprintf('Service: $%.2f%s @ %d%s =%.2f', @servicePrice{'Price','units'}, $Equipment->specification('PerfScoreRunSpeed'), 'Per Hour', $servicePrice );
			} elsif ( $servicePrice{'Price'} ) {
				$Results{'Breakdown'} .= "Unknown units set on service price ($score_qty) ($servicePrice{'units'}) <br/>";
			} # end if

			my $horizontal_rule = 0;
			my $horizontal_length = 0;
			my %horizontal_price;

			if ( $I->image_orientation() eq 'Vertical' and	$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} ) {
				$horizontal_rule = $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} * $I->rows();
				$horizontal_length = $horizontal_rule * $$sig_specs{'txtWidth'};
			} elsif ( $I->image_orientation() eq 'Horizontal' and	$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} ) {
				$horizontal_rule = $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} * $I->columns();
				$horizontal_length = $horizontal_rule * $$sig_specs{'txtHeight'};
			} # end if
		#$openprint::log->debug("Horizontal: $horizontal_rule");
			if ( $horizontal_rule ) {
				if ( my @Materials = openprint::Material->find('name'=>'ScoringRule') ) {
					%horizontal_price = $Materials[0]->get_price( $horizontal_rule, $Equipment );
					if ( sets::isin( $horizontal_price{'units'},['per rule','each','per score'] ) ) {
						$horizontal_price{'Total'} = $horizontal_price{'Price'} * $horizontal_rule;
						$Results{'Breakdown'} .= sprintf('Rule: $%1$.2f%2$s * %4$d rule=$%3$.2f<br/>', @horizontal_price{'Price','units','Total'}, $horizontal_rule );
					} elsif ( $horizontal_price{'units'} eq 'per inch' ) {
						$horizontal_price{'Total'} = $horizontal_price{'Price'} * $horizontal_length;
						$Results{'Breakdown'} .= sprintf('Rule: $%1$.2f%2$s * %4$.2finches=$%3$.2f<br/>', @horizontal_price{'Price','units','Total'}, $horizontal_length );
					} elsif ( $horizontal_price{'units'} eq 'per foot' ) {
						$horizontal_price{'Total'} = $horizontal_price{'Price'} * $horizontal_length/12;
						$Results{'Breakdown'} .= sprintf('Rule: $%1$.2f%2$s * %4$.2finches=$%3$.2f<br/>', @horizontal_price{'Price','units','Total'}, $horizontal_length/12 );
					} else {
						$Results{'Breakdown'} .= "Unknown units set on horizontal material price ($horizontal_price{'units'})<br/>";
					} # end if
				} # end if
			} # end if

			my $vertical_rule = 0;
			my $vertical_length = 0;
			my %vertical_price;

			if ( $I->image_orientation() eq 'Vertical' and	$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} ) {
				$vertical_rule = $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} * $I->columns();
				$vertical_length = $vertical_rule * $$sig_specs{'txtHeight'};
			} elsif ( $I->image_orientation() eq 'Horizontal' and	$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} ) {
				$vertical_rule = $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} * $I->rows();
				$vertical_length = $vertical_rule * $$sig_specs{'txtWidth'};
			} # end if

			#$openprint::log->debug("Vertical: $vertical_rule");
			if ( $vertical_rule ) {
				if ( my @Materials = openprint::Material->find('name'=>'ScoringWheel') ) {
					%vertical_price = $Materials[0]->get_price( $vertical_rule, $Equipment );
					if ( sets::isin( $vertical_price{'units'},['per rule','each'] ) ) {
						$vertical_price{'Total'} = $vertical_price{'Price'} * $vertical_rule;
						$Results{'Breakdown'} .= sprintf('Wheel: $%1$.2f%2$s * %4$d wheels=$%3$.2f<br/>', @vertical_price{'Price','units','Total'}, $vertical_rule );
					} elsif ( $vertical_price{'units'} eq 'per inch' ) {
						$vertical_price{'Total'} = $vertical_price{'Price'} * $vertical_length;
						$Results{'Breakdown'} .= sprintf('Wheel: $%1$.2f%2$s * %4$.2finches=$%3$.2f<br/>', @vertical_price{'Price','units','Total'}, $vertical_length );
					} elsif ( $vertical_price{'units'} eq 'per foot' ) {
						$vertical_price{'Total'} = $vertical_price{'Price'} * $vertical_length/12;
						$Results{'Breakdown'} .= sprintf('Wheel: $%1$.2f%2$s * %4$.2finches=$%3$.2f<br/>', @vertical_price{'Price','units','Total'}, $vertical_length/12 );
					} else {
						$Results{'Breakdown'} .= "Unknown units set on vertical material price ($vertical_price{'units'})<br/>";
					} # end if
				} else {
					$Results{'Breakdown'} .= "No material found for ScoringWheel<br/>";
				} # end if
			} # end if

# Div by imposition # Not needed, done in the use_qty stuff
			#$servicePrice /= $imposition->imposition() if $imposition->imposition();

			my $totalPrice = $setupPrice + $vertical_price{'Total'} + $horizontal_price{'Total'} + $servicePrice;
			$Results{'Breakdown'} .= sprintf('Total: $%.2f<br/>', $totalPrice );

			if ( $totalPrice < $Results{'Price'} or ! exists $Results{'Price'} ) {
				$Results{'Price'} = $totalPrice;
				$Results{'SetupPrice'} = $setupPrice;
				$Results{'ServicePrice'} = $servicePrice;
				$Results{'HorizontalPrice'} = \%horizontal_price;
				$Results{'VerticalPrice'} = \%vertical_price;
				$Results{'Equipment'} = $Equipment;
				$Results{'Imposition'} = $I;
				$Results{'Runspeed'} = $Equipment->specification('Scoring Runspeed');
			} # end if
		} # end foreach equipment
	} # end foreach imposition I

	if ( $Results{'Equipment'} ) {
		$Results{'Status'} = 'calculated';
	} else {
		$Results{'Status'} = 'uncalculated';
	} # end if
	return %Results;
} # end sub signature_calc

# figures ou the number of scores needed. May return 0 if signature doesn't need it.
sub get_scores {
	my ( $Project, $specs, $sig_specs, $Paper ) = @_;

	if ( ! signature_needs( $Project, $specs, $sig_specs, $Paper ) ) {
		# Default to 1 score, because we assume that if we have scoring, then we must want at least 1
		$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		$openprint::log->debug("SIgnature $$sig_specs{'SignatureIndex'} doesn't need scoring in get_scores") if DEBUG;
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
	} elsif ( $$sig_specs{'txtSignatureType'} eq 'Gate Folded Pages' ) {
	} else { # normal printing
		my $width_folds = sprintf('%.0f', ($$sig_specs{'txtWidth'}/$$sig_specs{'txtFinalWidth'})-1 ) if $$sig_specs{'txtFinalWidth'};
		my $height_folds = sprintf('%.0f', ($$sig_specs{'txtHeight'}/$$sig_specs{'txtFinalHeight'}) -1 ) if $$sig_specs{'txtFinalHeight'};
$openprint::log->debug("Width folds: $width_folds height folds: $height_folds template $$sig_specs{'rdbTemplateType'} $$sig_specs{'txtWidth'}/$$sig_specs{'txtFinalWidth'} $$sig_specs{'txtHeight'}/$$sig_specs{'txtFinalHeight'}");
		if ( sets::isin( $$sig_specs{'rdbTemplateType'}, 'Portrait', 'Landscape' ) ) {
# needs no folding
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, ['4PageSignatureFold','2PanelFold','BusCardLandscapeFold','BusCardPortraitFold']) ) {
			$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = 1;
			$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, '3PanelFold', '3PanelZFold' ) ) {
			$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = $width_folds;
			$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = $height_folds;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, '4PanelFold','4PanelZFold', 'AccordianFold', 'AccordianFold4Panel') ) {
			$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = $width_folds;
			$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = $height_folds;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, '5PanelFold', '5PanelZFold') ) {
			$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = $width_folds;
			$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = $height_folds;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, '6PanelFold', '6PanelZFold' ) ) {
			$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = $width_folds;
			$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = $height_folds;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, 'SingleGateFold' ) ) {
			$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = 2;
			$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, 'DoubleGateFold' ) ) {
			$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = 3;
			$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, 'PF1Pocket', 'PF2Pocket' ) ) {
			$$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} = 2;
			$$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} = 0;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, '2Panel2Pocket', '2Panel1Pocket' ) ) {
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

	my @capabilities = ( 'Y', 'When Printing' );
	push @capabilities, 'For Pocket Folders' if $Project->Type()->name() eq 'PresentationFolders';
	push @capabilities, 'When Folding' if $$services{'Folding'};
	push @capabilities, 'When PerfectBinding' if $$services{'PerfectBound'};
	push @capabilities, 'When Stitching' if $$services{'SaddleStitching'} or $$services{'LoopStitching'};
	
	@{$$variable{'Equipment'}} = openprint::Equipment->find( 'Specifications' => {'Scoring Capable'=>\@capabilities}, 'useinestimating'=>1,'order'=>'strName');

	foreach my $signature_service_index ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
		push @{$$variable{'SignatureGroups'}}, @$sig_specs{'SignatureIndex','txtServiceDescription'};
	} # end foreach
} # end sub get_specs

sub signature_summary {
	my ( $Project, $service_index, $specs, $qty_index, $s_id, $sig_specs ) = @_;
	$specs = openprint::service::get_specs_ref( $Project, $service_index ) if ! $specs;
	$sig_specs = openprint::service::get_specs_ref( $Project, $s_id ) if ! $sig_specs;
	if ( $qty_index ) {
		my @folds;
		my $Equipment = new openprint::Equipment( $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
		return ' on ' . $Equipment->name();
	} # end if
} # end sub signature_summary

sub summary {
	my ( $Project, $service_index, $specs, $qty_index ) = @_;
	my $services = $Project->services();

	if ( $qty_index ) {

	} else {
	} # end if
} # end sub summary

sub fits_on_equipment {
	my ( $Equipment, $width, $height, $calliper, $sig_specs ) = @_;

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
	if ( $Equipment->specification('Minimum Score Calliper') and 1*$calliper < 1*$Equipment->specification('Minimum Score Calliper') ) {
		return "Calliper too small: ($calliper), Min: " . $Equipment->specification('Minimum Score Calliper');
	} # end if
	if ( $Equipment->specification('Maximum Score Calliper') and 1*$calliper > 1*$Equipment->specification('Maximum Score Calliper') ) {
		return 'Calliper too big';
	} # end if
	if ( my $max_feed_width = $Equipment->specification('Maximum Feed Width') ) {
		my $width_folds = sprintf('%.0f', ($$sig_specs{'txtWidth'}/$$sig_specs{'txtFinalWidth'})-1 ) if $$sig_specs{'txtFinalWidth'};
		my $height_folds = sprintf('%.0f', ($$sig_specs{'txtHeight'}/$$sig_specs{'txtFinalHeight'}) -1 ) if $$sig_specs{'txtFinalHeight'};
		if ( $width_folds and $$sig_specs{'txtWidth'} > $max_feed_width ) {
			return "Width ($$sig_specs{'txtWidth'}) too large for feed width ($max_feed_width).";
		} elsif ( $height_folds and $$sig_specs{'txtHeight'} > $max_feed_width ) {
			return "Height ($$sig_specs{'txtHeight'}) too large for feed width ($max_feed_width).";
		} # end if
	} # end if	
	return '';
} # end sub fits_on_equipment

sub save {
} # end sub save

1;

__END__
