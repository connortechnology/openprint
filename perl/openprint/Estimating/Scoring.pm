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
#use warnings;

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
	'alert',
);

my @all_equipment;

my $folding_service_index;

sub variables {
	my @v = @variables;
	my $p_id = shift;

	my $Project = new openprint::Project( $p_id );
	foreach my $s_s_id ( $Project->signatures() ) {
		my $specs = openprint::service::get_specs_ref( $Project, $s_s_id );
		my $form = $$specs{SignatureIndex};
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			push @v, ( "txtWidth-$form", "txtHeight-$form",
				"ddmEquipment-$form-$qty_index", "chkOverrideEquipment-$form-$qty_index",
				"txtImposition-$form-$qty_index", "chkOverrideImposition-$form-$qty_index",
				"txtLayoutWidth-$form-$qty_index", "txtLayoutHeight-$form-$qty_index",
				"txtVerticalQty-$form", "txtHorizontalQty-$form", "chkOverrideQty-$form", 
			);
			foreach my $score_index ( 1 .. 4 ) {
                push @v, "ScoreQty-$form-$qty_index-$score_index";
                push @v, "ScoreImposition-$form-$qty_index-$score_index";
                push @v, "ScoreRunspeed-$form-$qty_index-$score_index";
            } # end foreach
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
		my $form = $$sig_specs{SignatureIndex};
        foreach my $qty_index ( $Project->quantity_indexes() ) {
            push @v, "chkOverrideEquipment-$form-$qty_index" if $$specs{"chkOverrideEquipment-$form-$qty_index"};
            push @v, "chkOverrideImposition-$form-$qty_index" if $$specs{"chkOverrideImposition-$form-$qty_index"};
        } # end foreach
    } # end foreach

    return @v;

} # end sub has_overrides
sub signature_needs {
	my ( $Project, $specs, $sig_specs, $Paper ) = @_;

	my $form = $$sig_specs{SignatureIndex};
#$openprint::log->debug("Scoring::need $$sig_specs{SignatureIndex} : " .$$specs{"chkOverrideQty-$form"});
	if ( $specs ) {
	# This is because for non-books, the specs hash doesn't have the SignatureIndex filledin.
		if ( ( (defined $$specs{"chkOverrideQty-$form"} ) and ( $$specs{"chkOverrideQty-$form"} eq 'Y' ) ) and
				( $$specs{"txtVerticalQty-$form"} or $$specs{"txtHorizontalQty-$form"} ) ) {
			return 1;
		} # end if
	} # end if

# If it's not needing folding, then it doesn't need to be scored!!
	if ( ! openprint::Estimating::Folding::signature_needs( $Project, $sig_specs ) ) {
#$openprint::log->debug("NeedFolding is not true $$specs{'txtWidth'}x$$specs{'txtHeight'} : $$specs{'txtFinalWidth'}x$$specs{'txtFinalHeight'}");
		return 0;
	} # end if
	if ( 
		( $$sig_specs{txtSignatureType} eq '' ) 
		or ( $$sig_specs{txtSignatureType} eq 'Cover Pages' ) 
		or ( $$sig_specs{'txtSignatureType'} and ( ! $Project->signatures({type=>'Cover Pages'}) ) and ( $form == 1 ) ) 
	) {
		$Paper = openprint::Paper::load_from_signature( $Project, $sig_specs ) if ! $Paper;
#$openprint::log->debug( "Score Required!: " . $Paper->score_required() );
		if ( $Paper->score_required() ) {
			return 1;
		} # end if
	} # end if
#$log->debug("Scoringn is not needed! ($$specs{'txtSignatureType'}) ($form)");
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
	$$specs{alert} = '';

	my $Project = new openprint::Project( $project_index );

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$specs{'txtPrice'.$qty_index} =~ s/[^\d\.]//g;
		$$specs{'Markup'.$qty_index} =~ s/[^\d\.\-]//g;
		$$specs{"txtQuantity$qty_index"} =~ s/[^\d\.\-]//g if $$specs{"txtQuantity$qty_index"};
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		if ( ! ( $$specs{"txtQuantity$qty_index"} > 0 ) ) {
			next;
		} # end if
		my $qty = $$specs{"txtQuantity$qty_index"};

		$$specs{'hdnBreakdown'.$qty_index} = "QTY: $qty:";

		my $qtyTotal = 0;
		my $price = 0;

		foreach my $signature_service_index ( $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
			my $form = $$sig_specs{SignatureIndex};
			$qty = $$specs{"txtQuantity$qty_index"};
			if ( $$sig_specs{'Versions'} ) {
				$qty *= $$sig_specs{'Versions'};
			} # end if
			$$specs{'hdnBreakdown'.$qty_index} .= "Signature: $$sig_specs{'txtServiceDescription'}, " if $$sig_specs{'txtServiceDescription'} ne '';
			if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
				$$specs{'hdnBreakdown'.$qty_index} .= "No imposition for signature $form";
				next;
			} # end if
			my $Imposition = new openprint::Imposition();
			$Imposition->load( $sig_specs, $qty_index );

           if ( $$specs{"OverrideScore-$form-$qty_index"} ne 'Y' ) {
                foreach my $index ( 1 .. 4 ) {
                    $$specs{"ScoreQty-$form-$qty_index-$index"} = 0;
                    $$specs{"ScoreImposition-$form-$qty_index-$index"} = '';
                    $$specs{"ScoreRunspeed-$form-$qty_index-$index"} = '';
                } # end for
            } # end if

			my %Price = signature_calc( $Project, $service_index, $specs, $signature_service_index, $sig_specs, $qty_index, $Imposition );
			$status = $Price{'Status'} if $Price{'Status'} eq 'uncalculated';
			if ( $Price{'Equipment'} ) {
				$$specs{"ddmEquipment-$form-$qty_index"} = $Price{'Equipment'}->id();
			} else {
				$$specs{"ddmEquipment-$form-$qty_index"} = '' if $$specs{"chkOverrideEquipment-$$sig_specs{SignatureIndex}-$qty_index"} ne 'Y';
				if ( $Price{'Status'} eq 'uncalculated' ) {
					if ( $$specs{"chkOverrideEquipment-$form-$qty_index"} eq 'Y' ) {
						$$specs{'alert'} = "QTY $qty_index: The selected equipment can not handle your project.	This may be because the stock is too heavy, or too large.";
					} else {
						$$specs{'alert'} = "QTY $qty_index: No suitable equipment could be found for your project.	This may be because the stock is too heavy, or too large.";
					} # end if
				} # end if
			} # end if
			my $score_index = 1;
			foreach my $I ( @{$Price{Impositions}} ) {
				$$specs{"ScoreQty-$form-$qty_index-$score_index"} = $I->quantity();
				$$specs{"ScoreImposition-$form-$qty_index-$score_index"} = $I->imposition();
				$$specs{"ScoreRunspeed-$form-$qty_index-$score_index"} = $I->runspeed();
				$score_index += 1;
			} # endd
			$$specs{'hdnBreakdown'.$qty_index} .= $Price{'Breakdown'};
			$$specs{'alert'} .= $Price{alert};

			$qtyTotal += $$specs{"txtVerticalQty-$form"};
			$qtyTotal += $$specs{"txtHorizontalQty-$form"};
			if ( $$specs{"txtVerticalQty-$form"} eq '' and $$specs{"txtHorizontalQty-$form"} eq '' ) {
				$$specs{'alert'} .= 'Please specify # of scores for form ' . $form;
				$status = 'uncalculated';
			} # end if
			$price += $Price{Price} if $Price{Price};
			$status = 'uncalculated' if $Price{'Status'} eq 'uncalculated';
		} # end foreach qty_index

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
	my ( $Project, $service_index, $specs, $signature_service_index, $sig_specs, $qty_index, $SignatureImposition ) = @_;
	my %Results = (
		Status		=> 'calculated',
		Breakdown	=> '',
	);
	my $form = $$sig_specs{SignatureIndex};

	if ( (!defined $$specs{"chkOverrideQty-$form"}) or ( $$specs{"chkOverrideQty-$form"} ne 'Y' ) ) {
		get_scores( $Project, $specs, $sig_specs, $SignatureImposition->Paper() );
	} # end if

	my $score_qty = $$specs{"txtVerticalQty-$form"} + $$specs{"txtHorizontalQty-$form"};
	@$specs{"txtWidth-$form", "txtHeight-$form"} = @$sig_specs{'txtWidth','txtHeight'};
	$Results{'Breakdown'} .= "# of Scores: $score_qty<br/>";
	return %Results if ! $score_qty;

	$Results{Status} = 'uncalculated';
	my $services = $Project->services();
	my $qty = $$specs{"txtQuantity$qty_index"};
	if ( $$specs{txtPressSheetComboItems} ) {
		$qty *= $$specs{txtPressSheetComboItems};
	} # end if
	if ( $$sig_specs{Versions} ) {
		$qty *= $$sig_specs{Versions};
	} # end if


	# Can only use the stitcher for scoring if we are stitching.	There are also thickness constraints
	my $stitching_service_index = $$services{'SaddleStitching'} ? $$services{'SaddleStitching'}[0] : undef;
	# Can only use the stitcher for scoring if we are stitching.	There are also thickness constraints
	$stitching_service_index = ( $$services{'LoopStitching'} ? $$services{'LoopStitching'}[0] : undef ) if ! $stitching_service_index;
	my $stitching_specs = openprint::service::get_specs_ref( $Project, $stitching_service_index ) if $stitching_service_index;
	# juts for efficeincy
	my $cutting_service_index = $$services{'Cutting'} ? $$services{'Cutting'}[0] : undef;
	$folding_service_index = ( ( $$services{Folding} and @{$$services{Folding}} ) ? $$services{'Folding'}[0] : undef );
	my ( $folding_specs, @Folds );
	if ( $$SignatureImposition{Folds} ) {
		@Folds = @{$$SignatureImposition{Folds}};
	} elsif ( $folding_service_index ) {
		$folding_specs = openprint::service::get_specs_ref( $Project, $folding_service_index );
		@Folds = openprint::Estimating::Folding::get_Folds( $folding_specs, $sig_specs, $qty_index );
	} # end if

	$Results{'Status'} = 'uncalculated';
	my @equipment;	
	if ( $$specs{"chkOverrideEquipment-$form-$qty_index"} eq 'Y' ) {
		@equipment = openprint::Equipment->find( 'id'=>$$specs{"ddmEquipment-$form-$qty_index"} );
		$openprint::log->debug("Overriding Equipment to: " . $$specs{"ddmEquipment-$form-$qty_index"} );
	} else {
		my @capabilities = ('Y','When Printing');
		push @capabilities, 'For Pocket Folders' if $Project->Type()->name() eq 'PresentationFolders';
		push @capabilities, 'When Folding' if $folding_specs;
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
	if ( ! $SignatureImposition->imposition() ) {
		$Results{alert} .= "Unable to load the imposition.  This likely is because printing has not finished calculating.<br/>";
		return $Results{Status} = 'uncalculated';
	} # end if

	#if ( $$specs{"chkOverrideImposition-$form-$qty_index"} eq 'Y' ) {
		#if ( $$specs{"txtImposition-$form-$qty_index"} > $imposition->imposition() or $$specs{"txtImposition-$form-$qty_index"} <= 0 ) {
			#$$specs{'alert'} = "The specified imposition is not possible.";
			#return %Results;
		##} # end if
	#} # end if

   # What we do is build a set of pieces of the imposition, all of which can be folded. We don't worry about optimality, just possibility.
    my @Set_Of_Impositions;

	$$SignatureImposition{impressions} = $qty / $$SignatureImposition{imposition};

    # IF it's a W&T, we have to cut in half first, so just do it.
    if ( $$SignatureImposition{runstyle} eq 'Work & Turn' ) {
        my $i = $SignatureImposition->copy();
        $i->runstyle('Sheet Work');
        $i->start_columns( $i->columns() );
        $i->columns( $i->columns()/2 );
        $$i{quantity} = 2;
        push @Set_Of_Impositions, $i;
    } elsif ( $$SignatureImposition{runstyle} eq 'Work & Tumble' ) {
        my $i = $SignatureImposition->copy();
        $i->runstyle('Sheet Work');
        $i->start_rows( $i->rows() );
        $i->rows( $i->rows()/2 );
        $$i{quantity} = 2;
        push @Set_Of_Impositions, $i;
    } else {
        my $i = $SignatureImposition->copy();
        $$i{quantity} = 1;
        push @Set_Of_Impositions, $i;
    } # end if

# Get rid of dutches
	if ( $SignatureImposition->dutch_columns() ) {
		my @Impositions = ();
		my $modified = 0;
		foreach my $I ( @Set_Of_Impositions ) {
			if ( $I->dutch_columns() ) {
				{
					my $i = $I->copy();
					$i->dutch_columns(0);
					$i->dutch_rows(0);
					$i->quantity(1);
					push @Impositions, $i;
				}
				{
					my $i = $I->copy();
					$i->columns( $i->dutch_columns() );
					$i->rows( $i->dutch_rows() );
					$i->dutch_columns(0);
					$i->dutch_rows(0);
					$i->quantity(1);
					$i->image_orientation($I->image_orientation() eq 'Vertical' ? 'Horizontal' : 'Vertical');
					push @Impositions, $i;
				}
				$modified = 1;
			} else {
				push @Impositions, $I;
			} # end if
		} # end foreach

		@Set_Of_Impositions = @Impositions if $modified;
		if ( DEBUG ) {
			foreach my $I ( @Impositions ) {
				$I->display('Results from dutch cuts');
			} # end foreach
		} # end if
	} # end if dutch

	my @Initial_Impositions = openprint::Estimating::Folding::reduce_impositions( \@Set_Of_Impositions );
	my @All_Impositions = @Initial_Impositions;

    for ( my $set_index = 0; $set_index < @All_Impositions; $set_index += 1 ) {
        my $Set_Of_Impositions = $All_Impositions[$set_index];
        for ( my $imp_index = 0; $imp_index < @$Set_Of_Impositions; $imp_index += 1 ) {
            my $Imposition = $$Set_Of_Impositions[$imp_index];
            if ( $$Imposition{imposition} > 1 ) {
                foreach my $cuts ( openprint::Estimating::Folding::cut_imposition( $Imposition ) ) {
                    my @new_impositions = @$Set_Of_Impositions;
                    splice @new_impositions, $imp_index, 1, @$cuts;
                    @new_impositions = openprint::Estimating::Folding::compact_impositions( @new_impositions ) if @new_impositions > 1;
                    push @All_Impositions, \@new_impositions;
                } # end foreach cuts
            }
        } # end foreach Impo
    } # end foreach Set of

	if ( DEBUG ) {
		$openprint::log->debug("Sets of Maximum Impositions: " . @All_Impositions);
		foreach my $Set ( @All_Impositions ) {
			$openprint::log->debug("Impositions in set: " . @$Set);
			foreach my $I ( @$Set ) {
				$I->display('quantity '.$I->quantity() );
			} # end foreach I
		} # end foreach set
		$openprint::log->debug(sprintf('Original Sign info: %dx%d*%d,%dout', $SignatureImposition->spread_columns(), $SignatureImposition->spread_rows(), $SignatureImposition->spread_size(), $SignatureImposition->imposition() ) );
	} # end if debug

	foreach my $Equipment ( @equipment ) {
		$Results{Breakdown} .= "<br/>Equipment: $$Equipment{name}, ";
		my $type = $Equipment->specification('Type');
		if ( $Equipment->specification('Scoring Capable') eq 'When Folding' ) {
			if ( ! ( $$services{'Folding'} and @{$$services{'Folding'}} ) ) {
				$Results{'Breakdown'} .= 'Not being folded.<br/>';
				if ( $$specs{"chkOverrideEquipment-$form-$qty_index"} eq 'Y' ) {
					$Results{alert} .= 'Not being folded.<br/>';;
				} # end if
				next;
			} 
			if ( $$folding_specs{"ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index"} != $Equipment->id() ) {
				$Results{'Breakdown'} .= 'Not being folded on this.<br/>';
				if ( $$specs{"chkOverrideEquipment-$form-$qty_index"} eq 'Y' ) {
					$Results{alert} .= 'Not being folded on this.<br/>';
				} # end if
				next;
			} # end if
		} # end if
		if ( $type eq 'Stitcher' ) {
			if ( ! $stitching_service_index ) {
				$Results{'Breakdown'} .= 'Not being stitched.<br/>';
				next;
			} # end if
			if ( $$stitching_specs{"ddmEquipment$qty_index"} and $$stitching_specs{"ddmEquipment$qty_index"} != $Equipment->id() ) {
				$Results{'Breakdown'} .= 'Not stitching on this.<br/>';
				next;
			} # end if
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
		} # end if
		if ( $$services{'NoOfflineBindery'} and ( $$sig_specs{'ddmPress'.$qty_index} ne $Equipment->strid() ) ) {
			$Results{'Breakdown'} .= "No Offline bindery and not printing on $$Equipment{name}.<br/>";
			next;
		} # end if

		my $totalPrice;

		if ( ( $type eq 'Folder' ) and @Folds ) {
			my $impressions;
			my $parts = 0;
			foreach my $Fold ( @Folds ) {
				$parts += $Fold->imposition() * $Fold->quantity();
			} # end if
			$Results{Breakdown} .= ' # of parts: ' . $parts . '<br/>';
			if ( $parts != $SignatureImposition->imposition() ) {
				$Results{alert} .= 'Folded parts does not match signature imposition.<br/>';
			} # eneid

			foreach my $Fold ( @Folds ) {
				$$Fold{impressions} = ( $qty / $SignatureImposition->imposition() ) * $$Fold{quantity};
				#$$Fold{impressions} /= $Fold->imposition();
                my $Price = get_price( $Equipment, $$specs{"txtVerticalQty-$$sig_specs{SignatureIndex}"}, $$specs{"txtHorizontalQty-$$sig_specs{SignatureIndex}"}, $$Fold{impressions}, $Fold );
                $totalPrice += $$Price{setup} + $$Price{Vertical}{Total} + $$Price{Horizontal}{Total} + $$Price{Service}{Total};
                $Results{Breakdown} .= $$Price{Breakdown};
			} # end foreach my $Fold
#$Results{'Imposition'} = $Fold;
			$Results{'Breakdown'} .= sprintf('Total: $%.2f<br/>', $totalPrice );

			if ( $totalPrice < $Results{'Price'} or ! exists $Results{'Price'} ) {
				$Results{Price} = $totalPrice;
				$Results{Equipment} = $Equipment;
				$Results{Runspeed} = $Equipment->specification('Scoring Runspeed');
				$Results{Impositions} = \@Folds;
			} # end if
		} else {
			my @My_All_Impositions;
			my $type = $Equipment->specification('Type');
			if ( $type eq 'Press' ) {
				@My_All_Impositions = @Initial_Impositions;
			} elsif ( $type eq 'Folder' ) {
				@My_All_Impositions = @All_Impositions;
			} elsif ( $type eq 'Stitcher' ) {
				@My_All_Impositions = @All_Impositions;
				my $max_imposition = $Equipment->specification('Maximum Imposition');
				if ( DEBUG and 0 ) {
					$openprint::log->debug("Impositions before max comparison: $max_imposition" );
					for ( my $set_index = 0; $set_index < @My_All_Impositions; $set_index += 1 ) {
						my $Set_Of_Impositions = $My_All_Impositions[$set_index];
						$openprint::log->debug("Impositions before max comparison in this set: " . @$Set_Of_Impositions );
						for ( my $imp_index = 0; $imp_index < @$Set_Of_Impositions; $imp_index += 1 ) {
							my $Imposition = $$Set_Of_Impositions[$imp_index];
							$Imposition->display();
						} #end for
					} #end for
				} # end if
				if ( $max_imposition ) {
					for ( my $set_index = 0; $set_index < @My_All_Impositions; $set_index += 1 ) {
						my $Set_Of_Impositions = $My_All_Impositions[$set_index];
						for ( my $imp_index = 0; $imp_index < @$Set_Of_Impositions; $imp_index += 1 ) {
							my $Imposition = $$Set_Of_Impositions[$imp_index];
							if ( $$Imposition{imposition} > $max_imposition ) {
								splice @My_All_Impositions, $set_index, 1;
								$set_index -= 1;
								last;
							} # end if
						} # end for
					} # end foreach set
				} # end if
			} # end if equipment type
			$openprint::log->debug("Impositions sets before filtering: " . @My_All_Impositions );

			# Remove duplicate sets
			my %sets;
			for ( my $set_index = 0; $set_index < @My_All_Impositions; $set_index += 1 ) {
				my $Set_Of_Impositions = $My_All_Impositions[$set_index];
				my $id = join(',', sort{ $a cmp $b } map { $$_{quantity}.'x'.$$_{imposition}.'='.$$_{columns} } @$Set_Of_Impositions );
				if ( $sets{$id} ) {
					splice @My_All_Impositions, $set_index, 1;
					$set_index -= 1;
					next;
				}
				$sets{$id} = 1;
			} # end foreach
			if ( ! @My_All_Impositions ) {
				$openprint::log->debug("No imposition sets for $$Equipment{strid}");
				next;
			} # end if

			foreach my $Set_Of_Impositions ( @My_All_Impositions ) {
				my @impositions = @{$Set_Of_Impositions};
				if ( $type eq 'Press' ) {
					next if @impositions > 1;
				} # end if

				my $totalPrice;
				my $complete = 1;

				foreach my $I ( @impositions ) {
					$Results{'Breakdown'} .= '<br/>Imp: '.$I->to_string().'<br/>';

					if ( $_ = fits_on_equipment( $Equipment, $I, $sig_specs, $$specs{"txtVerticalQty-$form"}, $$specs{"txtHorizontalQty-$form"} ) ) {
						$Results{'Breakdown'} .= "Doesn't fit. $_<br/>";
						$complete = 0;
						last;
					} # end if

					$Results{'Breakdown'} .= '<br/>';

					my $Price = get_price( $Equipment, $$specs{"txtVerticalQty-$form"}, $$specs{"txtHorizontalQty-$form"}, $$I{impressions} * $$I{quantity}, $I );

					$totalPrice += $$Price{setup} + $$Price{Vertical}{Total} + $$Price{Horizontal}{Total} + $$Price{Service}{Total};
					$Results{Breakdown} .= $$Price{Breakdown};
				} # end foreach imposition I
				next if ! $complete;
				$Results{'Breakdown'} .= sprintf('Total: $%.2f<br/>', $totalPrice );

				if ( $totalPrice < $Results{'Price'} or ! exists $Results{'Price'} ) {
					$Results{'Price'} = $totalPrice;
					$Results{'Equipment'} = $Equipment;
					$Results{'Runspeed'} = $Equipment->specification('Scoring Runspeed');
					$Results{Impositions} = $Set_Of_Impositions;
				} # end if
			} # end foreach imposition I
		} # end if folding
	} # end foreach equipment

	if ( $Results{'Equipment'} ) {
		$Results{'Status'} = 'calculated';
	} else {
		$Results{'Status'} = 'uncalculated';
	} # end if
	return %Results;
} # end sub signature_calc

sub get_price {
	my ( $Equipment, $vertical, $horizontal, $qty, $I ) = @_;

	my $type = $Equipment->specification('Type');
	my %Results;
	my $horizontal_rule = 0;
	my $horizontal_length = 0;
	my %horizontal_price;

	my $vertical_rule = 0;
	my $vertical_length = 0;
	my %vertical_price;

	if ( $I->image_orientation() eq 'Vertical' ) {
		if ( $vertical ) {
			$vertical_rule = $vertical * $I->columns();
			$vertical_length = $vertical_rule * $I->layout_height();
		}
		if ( $horizontal ) {
			$horizontal_rule = $horizontal * $I->rows();
			$horizontal_length = $horizontal_rule * $I->layout_width();
		} # end if
	} elsif ( $I->image_orientation() eq 'Horizontal' ) {
		if ( $horizontal ) {
			$vertical_rule = $horizontal * $I->rows();
			$vertical_length = $vertical_rule * $I->layout_width();
		} # end if
		if ( $vertical ) {
			$horizontal_rule = $vertical * $I->columns();
			$horizontal_length = $horizontal_rule * $I->layout_height();
		} # end if
	} # end if
	my $score_qty = $horizontal_rule + $vertical_rule;
	my $setupPrice;
	if ( ( $type eq 'Folder' ) and ! $folding_service_index ) {
		$setupPrice = openprint::service::get_price( 'ScoringMakeReadyWithoutFolding', $score_qty, $Equipment );
		$setupPrice = openprint::service::get_price( 'ScoringMakeReady', $score_qty, $Equipment ) if ! $setupPrice;
	} else {
		$setupPrice = openprint::service::get_price( 'ScoringMakeReady', $score_qty, $Equipment );
	} # end if

	$Results{'Breakdown'} .= sprintf( 'MakeReady: for %d scores = $%.2f<br/>', $score_qty, $setupPrice );
	$Results{'Breakdown'} .= "Imposition: " . $I->to_string() . '<br/>';

	my $Overs = $Equipment->Specification( 'Scoring Overs', $qty );
	if ( $$Overs{'units'} eq 'Sheets' ) {
		my $overs = $$Overs{'value'};
		$qty += $overs;
		$Results{'Overs'} = $overs;
		$Results{'Breakdown'} .= 'Overs: ' . $overs . '<br/>';
	} # end if

	my %servicePrice;
	if ( ( $type eq 'Folder' ) and ! $folding_service_index ) {
		%servicePrice = openprint::service::get_price_object( 'ScoringWithoutFolding', $qty, $Equipment );
		%servicePrice = openprint::service::get_price_object( 'Scoring', $qty, $Equipment ) if ! %servicePrice;
	} else {
		%servicePrice = openprint::service::get_price_object( 'Scoring', $qty, $Equipment );
	} # end if

	if ( $servicePrice{units} eq 'per m' ) {
		$servicePrice{Total} = Math::Round::nearest( 0.01, $servicePrice{Price} * $qty / 1000 );
		$Results{'Breakdown'} .= sprintf('Service: $%.2f%s * %d * %d scores=$%.2f<br/>', @servicePrice{'Price','units'}, $qty, $score_qty, $servicePrice{Total} );
	} elsif ( $servicePrice{units} eq 'per hour' ) {
		my $runspeed = $Equipment->specification('PerfScoreRunSpeed');
		if ( $runspeed ) {
			if ( int($runspeed) ) {
				my $hours = $qty / $runspeed;
				$servicePrice{Total} = Math::Round::nearest( 0.01, $servicePrice{'Price'} * $hours );
				$Results{Breakdown} .= sprintf('Service: $%.2f%s * %d @ %d%s = $%.2f<br/>', @servicePrice{'Price','units'}, $qty, $runspeed, 'Per Hour', $servicePrice{Total} );
			} else {
				$openprint::log->error("Bogus runspeed ($runspeed) on $$Equipment{strid}");
			} # end if
		} # end if
	} elsif ( $servicePrice{'Price'} ) {
		$Results{'Breakdown'} .= "Unknown units set on service price ($score_qty) ($servicePrice{'units'}) <br/>";
	} # end if


#$openprint::log->debug("Horizontal: $horizontal_rule");
	if ( $horizontal_rule ) {
		if ( my @Materials = openprint::Material->find(name=>'ScoringRule') ) {
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


#$openprint::log->debug("Vertical: $vertical_rule");
	if ( $vertical_rule ) {
		if ( my $Material = openprint::Material->find_one( name=>'ScoringWheel') ) {
			%vertical_price = $Material->get_price( $vertical_rule, $Equipment );
			if ( sets::isin( $vertical_price{'units'},['per rule','each'] ) ) {
				$vertical_price{'Total'} = $vertical_price{'Price'} * $vertical_rule;
				$Results{'Breakdown'} .= sprintf('Wheel: $%1$.2f%2$s * %4$d wheels=$%3$.2f<br/>', @vertical_price{'Price','units','Total'}, $vertical_rule );
			} elsif ( $vertical_price{'units'} eq 'per inch' ) {
				$vertical_price{'Total'} = $vertical_price{'Price'} * $vertical_length;
				$Results{'Breakdown'} .= sprintf('Wheel: $%1$.2f%2$s * %4$.2finches=$%3$.2f<br/>', @vertical_price{'Price','units','Total'}, $vertical_length );
			} elsif ( $vertical_price{units} eq 'per foot' ) {
				$vertical_price{Total} = $vertical_price{'Price'} * $vertical_length/12;
				$Results{Breakdown} .= sprintf('Wheel: $%1$.2f%2$s * %4$.2finches=$%3$.2f<br/>', @vertical_price{'Price','units','Total'}, $vertical_length/12 );
			} else {
				$Results{Breakdown} .= "Unknown units set on vertical material price ($vertical_price{'units'})<br/>";
			} # end if
		} else {
			$Results{Breakdown} .= "No material found for ScoringWheel<br/>";
		} # end if
	} # end if vertical_rule

	$Results{setup} = $setupPrice;
	$Results{Service} = \%servicePrice;
	$Results{Vertical} = \%vertical_price;
	$Results{Horizontal} = \%horizontal_price;
	return \%Results;

} # end sub get_price

# figures ou the number of scores needed. May return 0 if signature doesn't need it.
sub get_scores {
	my ( $Project, $specs, $sig_specs, $Paper ) = @_;

	my $form = $$sig_specs{SignatureIndex};
	if ( ! signature_needs( $Project, $specs, $sig_specs, $Paper ) ) {
# Default to 1 score, because we assume that if we have scoring, then we must want at least 1
		$$specs{"txtVerticalQty-$form"} = 0;
		$$specs{"txtHorizontalQty-$form"} = 0;
		$openprint::log->debug("SIgnature $form doesn't need scoring in get_scores") if DEBUG;
		return;
	} # end if
	if ( $$sig_specs{'txtSignatureType'} eq 'Cover Pages' ) {
		if ( openprint::print::get_book_type( $Project ) eq 'PerfectBound' ) {
			$$specs{"txtVerticalQty-$form"} = 4;
			$$specs{"txtHorizontalQty-$form"} = 0;
		} elsif ( $$sig_specs{txtWidth}/$$sig_specs{txtFinalWidth} != 2 ) {
			$$specs{"txtVerticalQty-$form"} = 2;
			$$specs{"txtHorizontalQty-$form"} = 0;
		} elsif ( $$sig_specs{txtSpreadSize} > 2 ) {
			$$specs{"txtVerticalQty-$form"} = 1;
			$$specs{"txtHorizontalQty-$form"} = 0;
		} # end if
	} elsif ( $$sig_specs{'txtSignatureType'} eq 'Interior Pages' ) {
		if ( $form == 1 ) {
			$$specs{"txtVerticalQty-$form"} = 1;
			$$specs{"txtHorizontalQty-$form"} = 0;
		} # end if
	} elsif ( $$sig_specs{'txtSignatureType'} eq 'Gate Folded Pages' ) {
	} else { # normal printing
		my $width_folds = sprintf('%.0f', ($$sig_specs{'txtWidth'}/$$sig_specs{'txtFinalWidth'})-1 ) if $$sig_specs{'txtFinalWidth'};
		my $height_folds = sprintf('%.0f', ($$sig_specs{'txtHeight'}/$$sig_specs{'txtFinalHeight'}) -1 ) if $$sig_specs{'txtFinalHeight'};
		$openprint::log->debug("Width folds: $width_folds height folds: $height_folds template $$sig_specs{'rdbTemplateType'} $$sig_specs{'txtWidth'}/$$sig_specs{'txtFinalWidth'} $$sig_specs{'txtHeight'}/$$sig_specs{'txtFinalHeight'}") if DEBUG;
		if ( sets::isin( $$sig_specs{'rdbTemplateType'}, 'Portrait', 'Landscape' ) ) {
# needs no folding
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, ['4PageSignatureFold','2PanelFold','BusCardLandscapeFold','BusCardPortraitFold']) ) {
			$$specs{"txtVerticalQty-$form"} = 1;
			$$specs{"txtHorizontalQty-$form"} = 0;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, '3PanelFold', '3PanelZFold' ) ) {
			$$specs{"txtVerticalQty-$form"} = $width_folds;
			$$specs{"txtHorizontalQty-$form"} = $height_folds;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, 'AccordianFold') ) {
			$$specs{"txtVerticalQty-$form"} = $width_folds;
			$$specs{"txtHorizontalQty-$form"} = $height_folds;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, '4PanelFold','4PanelZFold', 'AccordianFold4Panel') ) {
			if ( $width_folds ) {
				$$specs{"txtVerticalQty-$form"} = 3;
			} else {
				$$specs{"txtHorizontalQty-$form"} = 3;
			} # end if
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, '5PanelFold', '5PanelZFold') ) {
			$$specs{"txtVerticalQty-$form"} = $width_folds;
			$$specs{"txtHorizontalQty-$form"} = $height_folds;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, '6PanelFold', '6PanelZFold' ) ) {
			$$specs{"txtVerticalQty-$form"} = $width_folds;
			$$specs{"txtHorizontalQty-$form"} = $height_folds;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, 'SingleGateFold' ) ) {
			$$specs{"txtVerticalQty-$form"} = 2;
			$$specs{"txtHorizontalQty-$form"} = 0;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, 'DoubleGateFold' ) ) {
			$$specs{"txtVerticalQty-$form"} = 3;
			$$specs{"txtHorizontalQty-$form"} = 0;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, 'PF1Pocket', 'PF2Pocket' ) ) {
			$$specs{"txtVerticalQty-$form"} = 2;
			$$specs{"txtHorizontalQty-$form"} = 0;
		} elsif ( sets::isin( $$sig_specs{'rdbTemplateType'}, '2Panel2Pocket', '2Panel1Pocket' ) ) {
			$$specs{"txtVerticalQty-$form"} = 1;
			$$specs{"txtHorizontalQty-$form"} = 1;
		} else {
			if ( $$specs{'txtFinalWidth'} ) {
				my $cols = $$sig_specs{'txtWidth'} / $$specs{'txtFinalWidth'};
				my $mod_cols = $$sig_specs{'txtWidth'} % $$specs{'txtFinalWidth'};
				if ( $cols and ! $mod_cols ) {
					$$specs{"txtVerticalQty-$form"} = 2;
				} elsif ( $$specs{'txtFinalHeight'} ) {
					my $rows = $$sig_specs{'txtHeight'} / $$specs{'txtFinalHeight'};
					my $mod_rows = $$sig_specs{'txtHeight'} % $$specs{'txtFinalHeight'};
					if ( $rows and ! $mod_rows ) {
						$$specs{"txtHorizontalQty-$form"} = 0;
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
		if ( $$specs{"ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index"} ) {
			my $Equipment = new openprint::Equipment( $$specs{"ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index"} );
			return ' on ' . $Equipment->name();
		} # end if
	} # end if
	return;
} # end sub signature_summary

sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;

	if ( $qty_index ) {
		my $html;
		foreach my $s_s_id ( $Project->signatures( { sort=>1 } ) ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $s_s_id );
			my $Paper = openprint::Paper::load_from_signature( $Project, $sig_specs, $qty_index );
			if ( signature_needs( $Project, $specs, $sig_specs, $Paper ) ) {
				$html .= 'Form ' . $$sig_specs{SignatureIndex} . ' ' . $$sig_specs{txtServiceDescription} . ' scored ' ."\n".signature_summary( $Project, $service_id, undef, $qty_index, $s_s_id, undef ) . "\n";
			} # end if
		} # end foreach
		return $html;

	} else {
	} # end if
} # end sub summary

sub fits_on_equipment {
	my ( $Equipment, $I, $sig_specs, $vertical_scores, $horizontal_scores ) = @_;

	my $type = $Equipment->specification('Type');
	my $Paper = $I->Paper();
	my $calliper = $Paper->calliper();
	my $max_feed_width = $Equipment->specification('Maximum Feed Width');
	my $orientation = $Equipment->specification('Orientation');
	my $width = $I->layout_width();
	my $height = $I->layout_height();

	my $minimum_score_size = $Equipment->specification('Minimum Score Size');
	if ( $minimum_score_size ) {
		if ( $vertical_scores and $height < $minimum_score_size ) {
			return "Doesn't fit minimum Score Size Height $height < $minimum_score_size";
		} elsif ( $horizontal_scores and $width < $minimum_score_size ) {
			return "Doesn't fit minimum Score Size Width $width < $minimum_score_size";
		} # end if
	} # end if
	my $maximum_score_size = $Equipment->specification('Maximum Score Size');
	if ( $maximum_score_size ) {
		if ( $vertical_scores and $height > $maximum_score_size ) {
			return "Doesn't fit maximum Score Size Height $height > $maximum_score_size";
		} elsif ( $horizontal_scores and $width > $maximum_score_size ) {
			return "Doesn't fit maximum Score Size Width $width > $maximum_score_size";
		} # end if
	} # end if

	if ( $Equipment->specification('Minimum Score Calliper') and 1*$calliper < 1*$Equipment->specification('Minimum Score Calliper') ) {
		return "Calliper too small: ($calliper), Min: " . $Equipment->specification('Minimum Score Calliper');
	} # end if
	if ( $Equipment->specification('Maximum Score Calliper') and 1*$calliper > 1*$Equipment->specification('Maximum Score Calliper') ) {
		return 'Calliper too big';
	} # end if

	if ( $max_feed_width ) {
		if ( $orientation ) {
			if (
					( $orientation eq 'Portrait' and $I->layout_width() <= $I->layout_height() ) or
					( $orientation eq 'Landscape' and $I->layout_width() >= $I->layout_height() )
			   ) {
				if ( $width >= $max_feed_width ) {
					return "Score no good due to max feed width($max_feed_width) on width ($width).<br/>";
				} # end if
			} else {
				if ( $height >= $max_feed_width ) {
					return "Score no good due to max feed width($max_feed_width) on width ($height).<br/>";
				} # end if
			} # end if
		} else {
			if ( $vertical_scores and $horizontal_scores ) {
# Do nothing, we already know it fits on the machine, and it has to go one way or another.
			} elsif ( $vertical_scores ) {
				if ( $I->image_orientation() eq 'Vertical' ) {
					if ( $height >= $max_feed_width ) {
						return "Perf no good due to max feed width($max_feed_width) on height (".$height.").<br/>";
					} # end if
				} else {
					if ( $width >= $max_feed_width ) {
						return "Perf no good due to max feed width($max_feed_width) on width (".$width.").<br/>";
					} # end if
				} # end if
			} elsif ( $horizontal_scores ) {
				if ( $I->image_orientation() eq 'Vertical' ) {
					if ( $width >= $max_feed_width ) {
						return "Perf no good due to max feed width($max_feed_width) on width (".$width.").<br/>";
					} # end if
				} else {
					if ( $height >= $max_feed_width ) {
						return "Perf no good due to max feed width($max_feed_width) on height (".$height.").<br/>";
					} # end if
				} # end if
			} else {
				return 'Running ' . $height . ' on feed of ' . $max_feed_width . '<br/>';
			} # end if
		} # end if orientation or not
	} # end if max_feed)wudetg
	if ( ( $_ = $Equipment->specification('Maximum Imposition') ) and ( $_ < $I->imposition() ) ) {
		return "Imposition $$I{imposition}out too high. Maximum: $_<br/>";
	} # end if
	if ( $type eq 'Press' ) {
		if ( $_ = $Equipment->fits( $Paper->width(), $Paper->height(), $Paper->calliper() ) ) {
			return "Doesn't fit. $_<br/>";
		} # end if
	} else {
		if ( $_ = $Equipment->fits( $width, $height ) ) {
			return "Doesn't fit. $_<br/>";
		} # end if
	} # end if
	return '';
} # end sub fits_on_equipment

sub save {
} # end sub save

1;
__END__
