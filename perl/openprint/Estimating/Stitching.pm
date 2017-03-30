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

package openprint::Estimating::Stitching;
use strict;
#use warnings;

use constant DEBUG => 0;

require openprint::Equipment;
require openprint::service;

my %specifications = (
	'Maximum Calliper'	=> {},
	'Units Per Hour'	=>	{},
	'Maximum Pieces'	=>	{},
	'Maximum Finished Width'	=>	{},
	'Maximum Finished Height'	=>	{},
	'Minimum Finished Width'	=>	{},
	'Minimum Finished Height'	=>	{},
);
my @possible_pages = ( 4, 6, 8, 12, 16, 20, 24, 32, 36, 40, 48, 64 );
# This is an array of all the variables that need to be saved to the database for this service.
my %variables = (
		'ProjectIndex'=>[],'ServiceIndex'=>[],
		'hdnBreakdown1'=>['output'],'hdnBreakdown2'=>['output'],'hdnBreakdown3'=>['output'],
		'txtQuantity1'=>['save'], 'txtQuantity2'=>['save'], 'txtQuantity3'=>['save'],
		'ServiceType'=>[],
		'alert'=>['save','output'],'Status'=>['output'],
		'txtInsertQuantity'=>['save','output'],'chkOverrideInsertQuantity'=>['save'],
		'txtCalliper'=>['save','output'],
		'OverrideImposition1'=>['save'], 'OverrideImposition2'=>['save'], 'OverrideImposition3'=>['save'],
		'Imposition1'=>['save','output'], 'Imposition2'=>['save','output'], 'Imposition3'=>['save','output'],
		'ddmEquipment1'=>['save','output'], 'ddmEquipment2'=>['save','output'], 'ddmEquipment3'=>['save','output'],
		'chkOverrideEquipment1'=>['save'], 'chkOverrideEquipment2'=>['save'], 'chkOverrideEquipment3'=>['save'],
		'OverridePockets1'=>['save'], 'OverridePockets2'=>['save'], 'OverridePockets3'=>['save'],
		'rdbGateFoldFit'=>['save'], 'CoverFit'=>['save'],
		'txtUnitPrice1'=>['output'], 'txtUnitPrice2'=>['output'], 'txtUnitPrice3'=>['output'],
		'OverridePrice1'=>['save'], 'OverridePrice2'=>['save'], 'OverridePrice3'=>['save'],
		'Markup1'=>['save'], 'Markup2'=>['save'], 'Markup3'=>['save'],
		'txtPrice1'=>['save','output'], 'txtPrice2'=>['save','output'], 'txtPrice3'=>['save','output'],
		'MPrice1'=>['save','output'], 'MPrice2'=>['save','output'], 'MPrice3'=>['save','output'],
		'txtRunTime1'=>['save'], 'txtRunTime2'=>['save'], 'txtRunTime3'=>['save'],
		'txtSignatureQty4Page-1'=>['save','output'], 'txtSignatureQty4Page-2'=>['save','output'], 'txtSignatureQty4Page-3'=>['save','output'],
		'txtSignatureQty6Page-1'=>['save','output'], 'txtSignatureQty6Page-2'=>['save','output'], 'txtSignatureQty6Page-3'=>['save','output'],
		'txtSignatureQty8Page-1'=>['save','output'], 'txtSignatureQty8Page-2'=>['save','output'], 'txtSignatureQty8Page-3'=>['save','output'],
		'txtSignatureQty12Page-1'=>['save','output'], 'txtSignatureQty12Page-2'=>['save','output'], 'txtSignatureQty12Page-3'=>['save','output'],
		'txtSignatureQty16Page-1'=>['save','output'], 'txtSignatureQty16Page-2'=>['save','output'], 'txtSignatureQty16Page-3'=>['save','output'],
		'txtSignatureQty20Page-1'=>['save','output'], 'txtSignatureQty20Page-2'=>['save','output'], 'txtSignatureQty20Page-3'=>['save','output'],
		'txtSignatureQty24Page-1'=>['save','output'], 'txtSignatureQty24Page-2'=>['save','output'], 'txtSignatureQty24Page-3'=>['save','output'],
		'txtSignatureQty32Page-1'=>['save','output'], 'txtSignatureQty32Page-2'=>['save','output'], 'txtSignatureQty32Page-3'=>['save','output'],
		'txtSignatureQty36Page-1'=>['save','output'], 'txtSignatureQty36Page-2'=>['save','output'], 'txtSignatureQty36Page-3'=>['save','output'],
		'txtSignatureQty40Page-1'=>['save','output'], 'txtSignatureQty40Page-2'=>['save','output'], 'txtSignatureQty40Page-3'=>['save','output'],
		'txtSignatureQty48Page-1'=>['save','output'], 'txtSignatureQty48Page-2'=>['save','output'], 'txtSignatureQty48Page-3'=>['save','output'],
		'txtSignatureQty64Page-1'=>['save','output'], 'txtSignatureQty64Page-2'=>['save','output'], 'txtSignatureQty64Page-3'=>['save','output'],
		);
sub variables {
	my ( $p_id, $s_id, $specs ) = @_;
	my @v;
	foreach my $k ( keys %variables ) {
		push @v, $k, if sets::isin( 'save', $variables{$k} );
	} # end foreach;
	if ( (defined $$specs{txtInsertQuantity} ) and int $$specs{txtInsertQuantity} ) {
		foreach my $insert_id ( 1 .. int $$specs{txtInsertQuantity} ) {
			push @v, 'txtInsertPage1-'.$insert_id, 'txtInsertPage2-'.$insert_id;
		} # end foreach
	} # end if

	return @v;
}

sub outputs {
	my @v;
	foreach my $k ( keys %variables ) {
		push @v, $k, if sets::isin( 'output', $variables{$k} );
	} # end foreach;
	return @v;
}
sub no_outputs {
	my ( $p_id, $s_id, $specs, $param ) = @_;
	my $Project = new openprint::Project( $p_id );
	my @v;
	foreach my $k ( keys %variables ) {
		push @v, $k, if ! sets::isin( 'output', $variables{$k} );
	} # end foreach;
	push @v, map { $$specs{"OverrideImposition$_"} ? "Imposition$_" : () } $Project->quantity_indexes();
	push @v, map { $$specs{"chkOverrideEquipment$_"} ? "ddmEquipment$_" : () } $Project->quantity_indexes();
	return @v;
}

sub has_overrides {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;
	$specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;

	my @v;
	if ( $qty_index ) {
		push @v, "chkOverrideEquipment$qty_index" if $$specs{"chkOverrideEquipment$qty_index"};
		push @v, "OverrideImposition$qty_index" if $$specs{"OverrideImposition$qty_index"};
		push @v, "OverridePockets$qty_index" if $$specs{"OverridePockets$qty_index"};
		push @v, "OverridePrice$qty_index" if $$specs{"OverridePrice$qty_index"};
	} # end if

	return @v;

} # end sub has_overrides

# A function that is smart enough to return true if the project needs folding, and false if it doesn't.
sub neccessary {
	my ( $Project ) = @_;

	my $services = $Project->services();

	if ( $$services{NoBindery} ) {
		$openprint::log->debug(" ** Project is marked as No bindery, Stitching not needed ! ** ");
		return 0;
	} # end if

	my $printing_service_index = $$services{''}[0] if $$services{''};
	my $specs = openprint::service::get_specs_ref( $Project, $printing_service_index );
	if ( sets::isin( $$specs{rdbTemplateType},[ 'SaddleStitching','LoopStitching'] ) ) {
		return 1;
	} # end if

	return 0;
} # end sub neccessary

sub get_imposition {
	my $imposition = 2;
	foreach my $I ( @_ ) {
		last if $imposition <= 1;

		$imposition = 1 if ( 
				($$I{imposition} % 2 ) or 
				($$I{image_orientation} == openprint::Imposition::Vertical and $$I{rows} % 2 ) or 
				($$I{image_orientation} == openprint::Imposition::Horizontal and $$I{columns} % 2 ) or
				( $$I{imposition}%4 and sets::isin( $$I{runstyle}, ['Work & Turn','Work & Tumble'] ) ) 
				);
	} # end foreach Imposition
	return $imposition;
} # end sub get_imposition

# Calculates the cost of stitching a signature... which is not realistic, but will hopefully help when deciding between 1up or 2up stitching
# includes teh cost of folding...
sub signature_calc {
	my ( $Project, $service_index, $specs, $qty_index, $Impositions, $calc_hash ) = @_;

	$openprint::log->debug("# of impositions in Stitching::signature_calc: " . @{$Impositions} ) if DEBUG;

	my %results = (
			alert	=>	'',
			);
	my $services = $Project->services();
	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );
	my $folding_specs = $$calc_hash{FoldingSpecs};
	my $ServiceType = $Project->ServiceType( $service_index );
	if ( ! $ServiceType->id() ) {
		$results{alert} .= 'Unable to determine stitching type!<br/>';
		$results{Status} = 'uncalculated';
		return \%results;
	} else {
		$$specs{ServiceTypeName} = $ServiceType->name();
	} # end if

	my $plusCover = $$printing_specs{rdbCover} eq 'Different' ? 1 : 0;

	if ( ! ( $Impositions and @{$Impositions} ) ) {
		Carp::cluck ('No Impositions');
		$results{alert} .= 'No impositions to stitch type!<br/>';
		$results{Status} = 'uncalculated';
		return \%results;
	} # end if

	if ( ! $printing_specs ) {
		Carp::cluck ('No printing_specs');
		$results{alert} .= 'No books specifications!<br/>';
		$results{Status} = 'uncalculated';
		return \%results;
	} # end if

# Need to figure out which dimension the spine bisects
	if ( $$printing_specs{spine} ) {
		if ( $$printing_specs{spine} eq 'width' ) {
			@$specs{'Width','Height'} = @$printing_specs{'txtFinalHeight','txtFinalWidth'};
		} else {
			@$specs{'Width','Height'} = @$printing_specs{'txtFinalWidth','txtFinalHeight'};
		} # end if
	} elsif ( ( $$printing_specs{txtFinalWidth} == $$printing_specs{txtWidth} ) and ( $$printing_specs{txtFinalHeight} != $$printing_specs{txtHeight} ) ) {
		@$specs{'Width','Height'} = @$printing_specs{'txtFinalHeight','txtFinalWidth'};
	} elsif ( ( $$printing_specs{txtFinalWidth} != $$printing_specs{txtWidth} ) and ( $$printing_specs{txtFinalHeight} == $$printing_specs{txtHeight} ) ) {
		@$specs{'Width','Height'} = @$printing_specs{'txtFinalWidth','txtFinalHeight'};
	} else {
		@$specs{'Width','Height'} = @$printing_specs{'txtFinalWidth','txtFinalHeight'};
		$$specs{alert} .= 'Unable to determine spine direction. Calculations may be invalid.';
	} # end if
	$$specs{txtCalliper} = $Project->calliper() if ! $$specs{txtCalliper};

# Start with 2 and try to figure it out
	my @printed_impositions;
	my $imposition = 2;
	my $pockets = $$specs{"txtPockets$qty_index"} = 0;

	my $override_pockets = 0;
	if ( ( defined $$specs{'OverridePockets'.$qty_index}) and ($$specs{'OverridePockets'.$qty_index} eq 'Y') ) {
		foreach my $pages ( @possible_pages ) {
			$pockets += $$specs{join('','txtSignatureQty',$pages,'Page-',$qty_index)};
		}
		$override_pockets = 1;
	} 

	foreach my $I ( @$Impositions ) {
		$I->display('In Stitching:') if DEBUG and 0;
		my $sig_specs = $$I{specs};
	#next if $$sig_specs{txtSignatureType} eq 'Cover Pages';
		if ( ! $sig_specs ) {
			my ( $caller, undef, $line ) = caller;
			$openprint::log->error("No specs from imposition $caller line $line @$Impositions");

			$I->display('This');
			foreach my $i ( @$Impositions ) {
				$i->display('all');
			}
			next;
		}
		my $form = $$sig_specs{SignatureIndex};
		push @printed_impositions, $$I{imposition};
		if ( ! $$I{Folds} ) {
			if ( DEBUG ) {
				$openprint::log->debug("Sitchign: No folds in imposition, generating") if DEBUG;
				$I->display("No Folds");
			}
			if ( $folding_specs ) {
				$$I{Folds} = [ openprint::Estimating::Folding::get_Folds( $folding_specs, $I, $qty_index ) ];
				if ( DEBUG ) {
					foreach my $F ( @{$$I{Folds}} ) {
						$F->display( 'pq:'.$$F{page_quantity} );
					} # end foreach F
				} # end if
			} # end if
		} # end if

		if ( ! ( $$I{Folds} and @{$$I{Folds}} ) ) {
			# Might not be folding.  
			if ( $$folding_specs{"chkOverrideEquipment-$form-$qty_index"} eq 'Y' and ! $$folding_specs{"ddmOverrideEquipment-$form-$qty_index"} ) {
			} else {
				if ( DEBUG ) {
					$openprint::log->error("No folds in imposition, guess 1");
					$I->display("No Folds");
				} # end if
				if ( ! $override_pockets ) {
					$$specs{join('','txtSignatureQty',$I->pages(),'Page-',$qty_index)} += 1;
					if ( $$sig_specs{Group} == 1 ) {
						$openprint::log->debug("Not counting pocket due to it being cover. $form") if DEBUG;
						next;
					}
					$pockets += 1;
				} # end if
			} # end if folding overriden to none or not
# This doesn't really make sense.  If we are doing printing estimation, then the folding probably isn't going to match.  
		} else {
			my $total_pages = 0;

			foreach my $FI ( @{$$I{Folds}} ) {
				$FI->display( 'Fold form '.$form ) if DEBUG;
				my $Fold = $$FI{Fold};
$openprint::log->debug("Fold pq($$FI{page_quantity}) pages($$FI{pages}) ($$Fold{name}) Pockets: $pockets") if DEBUG;
				if ( $$FI{imposition} < $imposition ) {
					$results{Breakdown} .= "Setting stitching imposition to $$FI{imposition} out because Folding imposition is $$FI{imposition}out<br/>";
					$imposition = $$FI{imposition};
				} elsif ( $$FI{imposition} % 2 ) {
					$imposition = 1;
				}
				if ( ! $$I{Folder} ) {
					$$I{Folder} = $Fold->Equipment();
					$openprint::log->debug("Setting folder to " . $$I{Folder}{strid} ) if DEBUG and 0;
					#} else {
					#$openprint::log->debug('Folder is ' . $$I{Folder}->strid() );
				}
				#$openprint::log->debug("Adding " . $Fold->pages() . 'x'.$Fold->quantity() );
				if ( ! $override_pockets ) {
					if ( $$sig_specs{Group} == 1 ) {
						$$specs{join('','txtSignatureQty',$$Fold{pages},'Page-',$qty_index)} += 1;
						$openprint::log->debug("Not counting pocket due to it being cover. $form") if DEBUG;
						next;
					} else {
						$total_pages += $$FI{pages};

						if ( $total_pages > $$I{pages} ) {
							$results{alert} .= "We are stitching too many pages.<br/>";
							$openprint::log->debug("Already have enough pages $total_pages + $$FI{pages} <= $$I{pages}") if DEBUG;
							#next;
						} 
							my $p = $$FI{page_quantity};
							$p *= $$FI{quantity} if ( $$FI{page_quantity} == 1 ) and $$FI{quantity} and ( $$FI{pages} < $$I{pages} );
							$$specs{join('','txtSignatureQty',$$Fold{pages},'Page-',$qty_index)} += $p;
							$pockets += $p;
					}
				}
$openprint::log->debug("Fold pq($$FI{quantity} * pq$$FI{page_quantity}) pages($$FI{pages}) ($$Fold{name}) Pockets: $pockets") if DEBUG;
			} # end foreach Fold
		}

		if ( $imposition > 1 ) {
#if ( ( ( $$folding_specs{"chkOverrideEquipment-$form-$qty_index"} ne 'Y' or $$folding_specs{"ddmEquipment-$form-$qty_index"} ) and $$I{FoldingImposition} and $$I{FoldingImposition} % 2 ) ) {
#$imposition = 1;
#$I->display("Setting imposition to 1 due to foldingositions") if DEBUG;
#$results{Breakdown} .= "Setting imposition to 1 due to foldingositions<br/>";
			if ($$I{imposition} % 2 ) {
				$I->display("Setting imposition to 1 due to odd impositions") if DEBUG;
				$results{Breakdown} .= "Setting imposition to 1 due to odd impositions<br/>";
				$imposition = 1;
			} elsif ($$I{image_orientation} == openprint::Imposition::Vertical and $$I{rows} % 2 ) {
				$I->display("Setting imposition to 1 due to Vertial and odd rows") if DEBUG;
				$results{Breakdown} .= "Setting imposition to 1 due to vertical and odd rows<br/>";
				$imposition = 1;
			} elsif ( ($$I{image_orientation} == openprint::Imposition::Horizontal ) and ( $$I{columns} % 2 ) ) {
				$I->display("Setting imposition to 1 due to Horizal and odd cols") if DEBUG or 1;
				$results{Breakdown} .= "Setting imposition to 1 due to Horizontal and odd cols on form $form".$I->to_string()."<br/>";
				$imposition = 1;
			} elsif (sets::isin( $$I{runstyle}, ['Work & Turn','Work & Tumble'] ) and ($$I{imposition}%4) ) {
				$I->display("Setting imposition to 1 due to W&T impo not % 4 ") if DEBUG;
				$imposition = 1;
			} # end if
			if ( $imposition > 1 ) {
				if ( $$printing_specs{spine} eq 'height' ) {
					if ( $$sig_specs{txtFinalHeight} < $$printing_specs{txtFinalHeight} ) {
						$imposition = 1;
						$results{Breakdown} .= "Setting imposition to 1 due to form $form having a smaller spine length<br/>";
					}
				} else {
					if ( $$sig_specs{txtFinalWidth} < $$printing_specs{txtFinalWidth} ) {
						$imposition = 1;
						$results{Breakdown} .= "Setting imposition to 1 due to form $form having a smaller spine length<br/>";
					}
				}
			}
		} # end if
		#if ( DEBUG ) {
			#if ( ! $$I{Folder} ) {
				#$openprint::log->warn("No folder!");
			#} else {
				#$openprint::log->debug('Folding is ' . $$I{Folder}->strid() );
			#}
		#}
	} # end foreach Imposition
	$results{Breakdown} .= qq`# of Pockets needed: $pockets`. ( $plusCover ? ' plus cover' : '' ) . '<br/>';
#$results{Breakdown} .= 'Initial pockets: 	' . $$specs{"txtPockets$qty_index"} . '<br/>';
#$openprint::log->debug("Imp: $imposition");

#$openprint::log->debug( "Stitching Impo: " . $imposition ) if DEBUG;
	if ( $$specs{'OverrideImposition'.$qty_index} ) {
		if ( $imposition < $$specs{'Imposition'.$qty_index} ) {
			$results{alert} .= "Can't stitch $$specs{'Imposition'.$qty_index} out";
			foreach my $I ( @$Impositions ) {
				if ( ($$I{FoldingImposition} and $$I{FoldingImposition} % 2 ) ) {
					$results{alert} .= ' Folding not multiple of 2out<br/>';
				} # end if
				if ( $$I{imposition} % 2 ) {
					$results{alert} .= ' imposition not multiple of 2out<br/>';
				} # end if
				if ( ($$I{image_orientation} == openprint::Imposition::Vertical and $$I{rows} % 2 ) ) {
					$results{alert} .= ' vertical and rows not multiple of 2out<br/>';
				} # end if
				if ( $$I{image_orientation} == openprint::Imposition::Horizontal and $$I{columns} % 2 ) {
					$results{alert} .= ' horizontal and cols not multiple of 2out<br/>';
				} # end if
			} # end foreach
			$results{Status} = 'uncalculated';
			return \%results;
		} else { 
			$imposition = $$specs{'Imposition'.$qty_index};
		} # end if
	} # end if
	$results{Breakdown} .= 'Imposition: ' . $imposition . 'out<br/>';

	@printed_impositions = sets::union( @printed_impositions );
	my %error;
	my @equipment = ();


	if ( ( defined $$specs{"chkOverrideEquipment$qty_index"} ) and ( $$specs{"chkOverrideEquipment$qty_index"} eq 'Y' ) ) {
		if ( ! $$specs{"ddmEquipment$qty_index"} ) {
			$results{alert} .= 'Please select a piece of equipment to stitch your job.<br/>';
		} else {
			@equipment = ( new openprint::Equipment( $$specs{"ddmEquipment$qty_index"} ) );
			if ( ! $equipment[0]->id() ) {
				$results{alert} .= 'Your selected equipment was not found. Please select another.<br/>';
			} elsif ( $_ = equipment_fits( $equipment[0], $specs ) ) {
				$results{alert} .= $_;
				$results{Status} = 'uncalculated';
				return \%results;
			} # end if
		} # end if
	} else {
	#$openprint::log->debug("Not Using overriden stitcher" . $$specs{"chkOverrideEquipment$qty_index"} );
		if ( $$calc_hash{'Stitching::signature_calc::equipment'} ) {
	#$results{Breakdown} .= 'Using cached equipment';
			@equipment = @{$$calc_hash{'Stitching::signature_calc::equipment'}};
		} else {
	#$results{Breakdown} .= 'getting freshequipment';
			@{$$calc_hash{'Stitching::signature_calc::equipment'}} = @equipment = get_equipment( $specs, \%error );
		} # end if
	#$openprint::log->debug("Using " . $equipment[0]->name() . " as overriden stitcher" );
	} # end if

	my $bestPrice;
	my $bestEquipment;
#$results{Breakdown} = 'Imposition: ' . $$specs{'Imposition'.$qty_index} .'<br/>';
	my $I = $$Impositions[0];
	my $Press = $I->Press();
	my $sig_specs = $$I{specs};
	my $form = $$sig_specs{SignatureIndex};

	while ( ! $bestPrice and $imposition ) {
		$$specs{'Imposition'.$qty_index} = $imposition;
		$results{Breakdown} .= "Calculating for $imposition out<br/>" if DEBUG;
EQUIPMENT:foreach my $Equipment ( @equipment ) {
			$results{Breakdown} .= 'On ' . $$Equipment{name}.'<br/>' if DEBUG;
			if ( $$services{NoOfflineBindery} ) {
				if ( $Press->id() != $Equipment->id() ) {
					$results{Breakdown} .= "No Offline bindery and not printing on $$Equipment{name}.<br/>" if DEBUG;
					next;
				} # end if
			} # end if

			my $type = $Equipment->specification('Type');
			$openprint::log->debug("Printed impo: @printed_impositions, sitched: $imposition type: $type $$Equipment{strid}") if DEBUG;
			if ( $type eq 'Press' ) {
				if ( @printed_impositions > 1 ) {
					$results{Breakdown} .= sprintf($$Equipment{strid}. ': Printed and stitched imposition must match.<br/>');
					next;
				} # end if
				if ( $$Press{id} != $$Equipment{id} ) {
					$results{Breakdown} .= "Press not the same: " . $I->Press()->id() . ' != ' . $Equipment->id() if DEBUG;
					next;
				} # end if

				if ( $$I{Folder} and ( $$I{Folder}->id() != $Equipment->id() ) ) {
					$results{Breakdown} .= "Folder not the same: " . $$I{Folder}{id}. ' != ' . $Equipment->id() if DEBUG;
					next;
				} # end if

# Need to look at all sigs...
				foreach my $I ( @$Impositions ) {
					if ( $I->Press()->id() != $Equipment->id() ) {
						$results{Breakdown} .= "All sigs must be printed on this stitcher.<br/>";
						next EQUIPMENT;
					} # end if
				} # end foreach I
			} # end if Press
			my $max_imp = $Equipment->specification("Maximum $$ServiceType{name} Imposition");
			if ( ( defined $max_imp ) and ( $max_imp < $imposition ) ) {
				$results{Breakdown} .= sprintf('Imposition too big.  This press only does ' . $max_imp . 'out.<br/>');
				if ( $Equipment->specification('Type') eq 'Press' ) {
					next;
				} else {
					next;
				} # end if
			} # end if

			my $max_spine_length = $Equipment->specification('Maximum Spine Length', $imposition );
			if ( $max_spine_length and ( $$specs{Height} > $max_spine_length ) ) {
				$results{Breakdown} .= sprintf('Spine Too big. Spine: %s, Maximum for %dout: %s<br/>', $$specs{Height}, $imposition, $max_spine_length );
				next;
			} # end if
			my $min_spine_length = $Equipment->specification('Minimum Spine Length', $imposition );
			if ( $min_spine_length and ( $$specs{Height} < $min_spine_length ) ) {
				$results{Breakdown} .= sprintf('Spine Too small. Spine: %s, Minimum for %dout: %s<br/>', $$specs{Height}, $imposition, $min_spine_length );
				next;
			} # end if
			my $max_face_trim = $Equipment->specification('Maximum Spread Width');
			if ( $max_face_trim and ( $$specs{Width} > $max_face_trim ) ) {
				$results{Breakdown} .= sprintf('Face Trim too width. %s, Maximum: %s<br/>', $$specs{Width}, $max_face_trim );
				next;
			} # end if

			my $capable = $Equipment->specification('Stitching Capable');

			if ( $capable eq 'When Digital' and $Press->specification('Printing Type') ne 'Digital' ) {
				$results{Breakdown} .= 'Not printed digital.<br/>';
				next;
			} # end if
			if ( $$I{Folder} and ( $$I{Folder}->id() != $Equipment->id() ) ) {
				if ( ( $_ = $$I{Folder}->specification('Folding Capable') ) and ( $_ eq 'When Stitching' ) ) {
					$results{Breakdown} .= $Equipment->strid() . ' is not the folding equipment, is '.$$I{Folder}->name() . '<br/>';
					next;
				} 
				if ( $capable eq 'When Folding' ) {
					$results{Breakdown} .= 'Not being folded on ' .$Equipment->name(). ' is on '. $$I{Folder}->name() . '<br/>';
					next;
				} # end if
			} # end if
			my $price = get_price( $Project, $ServiceType, $Equipment, $specs, $pockets, $plusCover, $qty_index );
			$$price{ComparisonPrice} = $$price{Price};
			if ( $folding_specs and ( defined $$folding_specs{"Price-$form-$qty_index"} ) ) {
				$$price{ComparisonPrice} += $$folding_specs{"Price-$form-$qty_index"};
			} # end if
#$results{Breakdown} .= $Equipment->strid() . ' ' . $$price{Price} . ' ' . $$folding_specs{"Price-$form-$qty_index"};
			if ( ( ! $bestPrice ) or $$price{ComparisonPrice} < $$bestPrice{ComparisonPrice} ) {
				$bestEquipment = $Equipment;
				$bestPrice = $price;
			} # end if
			$results{Breakdown} .= $$price{Price} . ' comparison: ' . $$price{ComparisonPrice} . '<br/>' if DEBUG;
 		  } # end foreach Equipment

		  if ( $imposition > 1 and ! $bestPrice ) {
			  if ( ( defined $$specs{'OverrideImposition'.$qty_index} ) and ( $$specs{'OverrideImposition'.$qty_index} eq 'Y' ) ) {
				  last;
			  } # end if
			  $imposition -= 1;
		  } else {
# Assume 2out is better than 1out
			  last;
		  } # endif
	} # while ! bestPrice and imposition
#$openprint::log->debug("Breakdown: $$specs{'hdnBreakdown'.$qty_index}");
#foreach my $press_id ( keys %error ) {
#my $Equipment = new openprint::Equipment( $press_id );
#$$specs{alert} .= 'For ' . $Equipment->name() . ': ' .  $error{$press_id};
#} # end foreach
	if ( $$bestPrice{Imposition} ) {
#$results{alert} .= sprintf('%dout on %s %dpockets', $$bestPrice{Imposition},($bestEquipment ? $bestEquipment->strid() . ' ' . $bestEquipment->name() : '' ),$$specs{'txtPockets'.$qty_index} );
		$results{Imposition} = $$bestPrice{Imposition};
		$results{Equipment} = $bestEquipment;
		$results{Status} = 'calculated';
		$results{Price} = $bestPrice;
		$results{pockets} = $pockets;
	} else {
		$results{Status} = 'uncalculated';
	} # end if
	return \%results;
} # end sub signature_calc

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	$$specs{alert} = '';
	$$specs{Status} = 'calculated';
	my $Project = new openprint::Project( $project_index );
	my $ServiceType = $Project->ServiceType( $service_index );
	if ( ! $ServiceType->id() ) {
		$$specs{alert} .= 'Unable to determine stitching type!<br/>';
		return $$specs{Status} = 'uncalculated';
	} else {
		$$specs{ServiceTypeName} = $ServiceType->name();
	} # end if

	my $services = $Project->services();
	if ( ! $$services{''} ) {
		$$specs{alert} .= 'Unable to find project service.<br/>';
		return $$specs{Status} = 'uncalculated';
	} # end if
	my @signatures = $Project->signatures();
	if ( ! @signatures ) {
		$$specs{alert} .= 'Unable to find any signatures to stitch.<br/>';
		return $$specs{Status} = 'uncalculated';
	} # end if

	my $calc_hash = {};
# Figure out whether we need a cover
	my $printing_specs = $$calc_hash{ProjectSpecs} = openprint::service::get_specs_ref( $Project, $$services{''}[0] );
	@$specs{'txtPageQuantity','txtFinalWidth','txtFinalHeight'} = @$printing_specs{'txtTotalPageQuantity','txtFinalWidth','txtFinalHeight'};
	if ( (defined $$specs{chkOverrideInsertQuantity}) and ( $$specs{chkOverrideInsertQuantity} eq 'Y' ) ) {
		$variables{txtInsertQuantity} = [ sets::exclude( ['output'], $variables{txtInsertQuantity} ) ];
	} else {
		$variables{txtInsertQuantity} = [ sets::union( 'output', @{$variables{txtInsertQuantity}} ) ];
		$$specs{txtInsertQuantity} = $$printing_specs{txtInsertQuantity};
	} # end if

	if ( $$specs{txtPageQuantity} <= 0 ) {
		$$specs{alert} .= 'Unable to determine page quantity<br/>';
		return $$specs{Status} = 'uncalculated';
	} # end if
	if ( ! $$specs{CoverFit} ) {
		foreach my $sig_id ( $Project->signatures( {Group=>1} ) ) {
			if ( form_needs_fit( $Project, $sig_id ) ) {
				$$specs{alert} .= 'Your cover is complex.  Please select how to run it.<br/>';
				return $$specs{Status} = 'uncalculated';
			} # end if
		} # end foreach
	} # endif 

	my $folding_specs = 0;
	if ( $$services{Folding} ) {
		%{$$calc_hash{FoldingSpecs}} = %{openprint::service::get_specs_ref( $Project, $$services{Folding}[0] )};
		$folding_specs = $$calc_hash{FoldingSpecs};
	} # end if
	# Actually need this for when we call folding
	my $scoring_specs = 0;
	if ( $$services{Scoring} and @{$$services{Scoring}} ) {
		$$calc_hash{ScoringSpecs} = openprint::service::get_specs_ref( $Project, $$services{Scoring}[0] );
		$scoring_specs = $$calc_hash{ScoringSpecs};
	}

	$$specs{txtCalliper} = $Project->calliper();
# Need to figure out which dimension the spine bisects
	if ( $$printing_specs{spine} ) {
		if ( $$printing_specs{spine} eq 'width' ) {
			@$specs{'Width','Height'} = @$printing_specs{'txtFinalHeight','txtFinalWidth'};
		} else {
			@$specs{'Width','Height'} = @$printing_specs{'txtFinalWidth','txtFinalHeight'};
		} # end if
	} elsif ( ( $$printing_specs{txtFinalWidth} == $$printing_specs{txtWidth} ) and ( $$printing_specs{txtFinalHeight} != $$printing_specs{txtHeight} ) ) {
		@$specs{'Width','Height'} = @$printing_specs{'txtFinalHeight','txtFinalWidth'};
	} elsif ( ( $$printing_specs{txtFinalWidth} != $$printing_specs{txtWidth} ) and ( $$printing_specs{txtFinalHeight} == $$printing_specs{txtHeight} ) ) {
		@$specs{'Width','Height'} = @$printing_specs{'txtFinalWidth','txtFinalHeight'};
	} else {
		@$specs{'Width','Height'} = @$printing_specs{'txtFinalWidth','txtFinalHeight'};
		$$specs{alert} .= 'Unable to determine spine direction. Calculations may be invalid.';
	} # end if

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$specs{'txtPrice'.$qty_index} =~ s/[^\d\.]//g if $$specs{'txtPrice'.$qty_index};
		$$specs{'txtQuantity'.$qty_index} =~ s/[^\d\.]//g;
		$$specs{'txtQuantity'.$qty_index} = $Project->quantity($qty_index) if ! $$specs{'txtQuantity'.$qty_index};

		next if ! $$specs{'txtQuantity'.$qty_index};
		$$specs{'hdnBreakdown'.$qty_index} .= 'Finished Calliper: ' . $$specs{txtCalliper} . '<br/>';
		$$specs{'hdnBreakdown'.$qty_index} .= "Face Trim: $$specs{Width} Spine Length: $$specs{Height}<br/>";

		if ( (!defined $$specs{'OverridePockets'.$qty_index}) or ($$specs{'OverridePockets'.$qty_index} ne 'Y') ) {
			foreach my $pages ( @possible_pages ) {
				$$specs{'txtSignatureQty'.$pages.'Page-'.$qty_index} = 0;
			} # end foreach
		} # end if
		$$specs{"txtPockets$qty_index"} = 0;
		my @Impositions;

		foreach my $signature_service_index ( @signatures ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
			next if ! $$sig_specs{"txtImposition$qty_index"};
			my $form = $$sig_specs{SignatureIndex};
			if ( $folding_specs and 
					( ! $$folding_specs{"ddmEquipment-$form-$qty_index"} ) and 
					( $$folding_specs{"chkOverrideEquipment-$form-$qty_index"} )
				 ) {
				$openprint::log->debug("Overrode folding to nothing.");
			} # end if
			my $Imposition = new openprint::Imposition();
			$Imposition->load( $sig_specs, $qty_index, $Project );
			push @Impositions, $Imposition;
			if ( $folding_specs ) {
				$$Imposition{Folds} = [ openprint::Estimating::Folding::get_Folds( $folding_specs, $Imposition, $qty_index ) ];
				if ( DEBUG ) {
					foreach my $F ( @{$$Imposition{Folds}} ) {
						$F->display("Stitching::calc Fold: pq($$F{page_quantity})");
					} # end foreach F
				} # end if
			}
#$openprint::log->debug(sprintf('%d %s %s %d %dx%d %s', $imposition, @$sig_specs{'txtSignatureType','ddmRunStyle'.$qty_index,'txtImposition'.$qty_index,'hdnImpositionColumns'.$qty_index,'hdnImpositionRows'.$qty_index,'hdnImageOrientation'.$qty_index} ) ) if DEBUG;
# According to Brendan, both cover and interior need to be 2out
#next if $$sig_specs{txtSignatureType} eq 'Cover Pages';
		} # end foreach signature_service_index

		my %error;
		my @possible_equipment = get_equipment( $specs, \%error );

		if ( ! @possible_equipment ) {
# alert the user that no equipment is good.
			$$specs{alert} = 'Our stitching equipment cannot run this project, for the following reasons:<br/>';
			foreach my $press_id ( keys %error ) {
				my $Equipment = new openprint::Equipment( $press_id );
				$$specs{alert} .= 'For ' . $Equipment->name() . ': ' .  $error{$press_id};
			} # end foreach
			$$specs{alert} .= '<br/> Please only print flat sheets and contact another bindery.';
			$$specs{Status} = 'uncalculated';
			return 'uncalculated';
		} elsif ( DEBUG ) {
			foreach my $press_id ( keys %error ) {
				my $Equipment = new openprint::Equipment( $press_id );
				$log->debug( 'For ' . $Equipment->name() . ': ' .  $error{$press_id} );
			} # end foreach
		} # end if
		$$calc_hash{'Stitching::signature_calc::equipment'} = \@possible_equipment;
		my %results = %{signature_calc( $Project, $service_index, $specs, $qty_index, \@Impositions, $calc_hash )};
		$$specs{Status} = $results{Status};
		$$specs{'hdnBreakdown'.$qty_index} .= $results{Breakdown};
		$$specs{alert} .= $results{alert};
		my %price = %{$results{Price}} if $results{Price};
		if ( $results{Status} eq 'calculated' ) {
			$$specs{"ddmEquipment$qty_index"} = $results{Equipment}->id();
			$$specs{'Imposition'.$qty_index} = $results{Imposition};
			#$$specs{'hdnBreakdown'.$qty_index} .= "Imposition: $price{Imposition}out<br/>";

			if ( $price{PocketMakeReady} ) {
				my $mr_time = Math::Round::nearest( 0.1, $price{Pockets} * $price{PocketMakeReady}{value} / 60 ); # assume minutes
				$$specs{'hdnBreakdown'.$qty_index} .= 'Makeready Time: ' . $price{PocketMakeReady}{value}.$price{PocketMakeReady}{units} . ' per pocket * ' . $price{Pockets} . ' pockets = ' . $mr_time . ' hours<br/>';
				$price{RunTime} -= $mr_time;
			} # end if
			$$specs{'hdnBreakdown'.$qty_index} .= "Number of Passes: ".@{$price{Passes}}.'<br/>';
			my $pass_count = 1;
			while ( my $pass = shift @{$price{Passes}} ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'Pass ' . $pass_count . ', ' . $$pass{Pockets} . ' pockets:<br/>';
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf( '&nbsp;Estimated MR Time %.2f + Run Time: %s@/%dHr = %s hours = %s total hours<br/>', 
						 Math::Round::nearest( 0.1,$$pass{PocketMakeReadyTime} ), 
						 $$specs{"txtQuantity$qty_index"}, $$pass{Runspeed}, Math::Round::nearest( 0.1, $$pass{RunTime} ),
						 Math::Round::nearest( 0.1,$$pass{PocketMakeReadyTime} + $$pass{RunTime} ),
						);

				if ( my $MakeReadyPrice = $$pass{MakeReadyPrice} ) {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;%s = $%.2f<br/>', $$MakeReadyPrice{Service}->description(), $$MakeReadyPrice{Total} );
				}
				if ( my $servicePrice = $$pass{ServicePrice} ) {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;Service: $%.2f%s=$%.2f<br/>', @$servicePrice{'Price','units','Total'});
				} # end if
				$pass_count += 1;
			} # end while pass
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Calliper Markup %d%<br/>', $price{'Calliper Markup'} ) if $price{'Calliper Markup'};
			$$specs{'hdnBreakdown'.$qty_index} .= 'Run Discount' . $price{'RunCost Discount'}.'%<br/>' if $price{'RunCost Discount'};
			$$specs{'hdnBreakdown'.$qty_index} .= 'Imposition Discount: '. $price{'Imposition Discount'} .'%<br/>' if $price{'Imposition Discount'};
			$$specs{'hdnBreakdown'.$qty_index} .= 'Spine Length Discount: ' . $price{'SpineLength Discount'} . '%<br/>' if $price{'SpineLength Discount'};
			$$specs{'hdnBreakdown'.$qty_index} .= 'Estimated Total Run Time: '. Math::Round::nearest( 0.1, $price{RunTime} ) . 'hours,<br/>';
			$$specs{'hdnBreakdown'.$qty_index} .= 'Total: $'. sprintf('%.2f', Math::Round::nearest(0.01,$price{Price})).'<br/><br/>';
			$$specs{'hdnBreakdown'.$qty_index} .= 'Comparison: $'. sprintf('%.2f', Math::Round::nearest(0.01,$price{ComparisonPrice})).'<br/><br/>';
		} else {
			foreach my $press_id ( keys %error ) {
				my $Equipment = new openprint::Equipment( $press_id );
				$$specs{'hdnBreakdown'.$qty_index} .= 'For ' . $Equipment->name() . ': ' .  $error{$press_id};
			} # end foreach
			$$specs{"ddmEquipment$qty_index"} = '' if $$specs{'chkOverrideEquipment'.$qty_index} ne 'Y';
			$$specs{'Imposition'.$qty_index} = '' if $$specs{'OverrideImposition'.$qty_index} ne 'Y';
		} # end if

#$$specs{'hdnBreakdown'.$qty_index} .= 'Quantity: ' . $$specs{"txtQuantity$qty_index"} .  ", Equipment: ".$Equipment->strid() ."<br/>";
		if ( $$specs{"Markup$qty_index"} ) {
			$price{MPrice} *= (1+$$specs{"Markup$qty_index"}/100);
			$price{Price} *= (1+$$specs{"Markup$qty_index"}/100);
		} # end if
		if ( $Project->markup() ) {
			$price{MPrice} *= (1+$Project->markup()/100);
			$price{Price} *= (1+$Project->markup()/100);
		} # end if
		if ( ( defined $$specs{'OverridePrice'.$qty_index} ) and ( $$specs{'OverridePrice'.$qty_index} eq 'Y' ) ) {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{ProjectMoneyFormat}, $$specs{'txtPrice'.$qty_index} );
		} else {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{ProjectMoneyFormat}, $price{Price} );
		} # end if
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{UnitPriceFormat}, $price{Price}/$$specs{"txtQuantity$qty_index"} );
		$$specs{"MPrice$qty_index"} = sprintf( $openprint::config{UnitPriceFormat}, $price{MPrice} );
		$$specs{"txtRunTime$qty_index"} = $price{RunTime};
	} # end foreach qty_index
	$log->debug("END STITCHING!!!!!!!");
	return $$specs{Status};
} # end sub calc

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	@{$$variable{Equipment}} = openprint::Equipment->find( Specifications => {'Stitching Capable'=>['Y','When Printing','When Digital','When Folding']}, useinestimating=>1,order=>'lower(strName)');

#my $Project = new openprint::Project( $project_index );
#my $ProjectType = $Project->Type();

	$$variable{txtPockets} = $$variable{SignatureCount} + $$variable{txtInsertQuantity};
} # end sub display

sub equipment_fits {
	my ( $Equipment, $specs ) = @_;

	if ( $_ = $Equipment->fits( $$specs{Width}, $$specs{Height}, undef, 'Stitching' ) ) {
		return $_;
	} # end if
	if ( $_ = $Equipment->specification('Maximum Spread Width') and ( $$specs{Width} > $_ ) ) {
		return ': spread too big.<br/>';
	} # end if
	if ( $_ = $Equipment->specification('Minimum Spread Width') and ( $$specs{Width} < $_ ) ) {
		return ": spread width too small ($$specs{Width} < $_).<br/>";
	} # end if
	if ( $_ = $Equipment->specification('Maximum Finished Width') and ( $$specs{Width} > $_ ) ) {
		return ': finished width too big.<br/>';
	} # end if
	if ( $_ = $Equipment->specification('Minimum Finished Width') and ( $$specs{Width} < $_ ) ) {
		return ': finished width too small.<br/>';
	} # end if
	if ( $_ = $Equipment->specification('Maximum Finished Height') and ( $$specs{Height} > $_ ) ) {
		return ': finished height too big.<br/>';
	} # end if
	if ( $_ = $Equipment->specification('Minimum Finished Height') and ( $$specs{Height} < $_ ) ) {
		return ': finished height too small.<br/>';
	} # end if
	if ( $$specs{txtCalliper} > 0 ) {
		if ( $_ = $Equipment->specification('Maximum '.$$specs{ServiceTypeName} .' Calliper') ) {
			if ( $$specs{txtCalliper} > $_ ) {
				return ": Too Thick $$specs{txtCalliper} > Maximum calliper: $_.<br/>";
			}
		} else {
			$openprint::log->warn("No max calliper set for $$specs{ServiceTypeName} on $$Equipment{strid}");
		} # end if
		if ( $_ = $Equipment->specification('Minimum ' . $$specs{ServiceTypeName} .' Calliper') ) {
			if ( $$specs{txtCalliper} < $_ ) {
				return ': Too Thick.<br/>';
			} # end if
		} else {
            $openprint::log->warn("No min calliper set for $$specs{ServiceTypeName} on $$Equipment{strid}");
        } # end if

	} else {
		$openprint::log->error("No calliper in Stitching::get_equipment");
	} # end if
	return;
}

sub get_equipment {
	my ( $specs, $error ) = @_;

	my @possible_equipment;
	my @all_equipment = openprint::Equipment->find( Specifications => {'Stitching Capable'=>['Y','When Printing','When Digital','When Folding']}, useinestimating=>1,order=>'strName');

	foreach my $Equipment ( @all_equipment ) {
		$_ = equipment_fits( $Equipment, $specs );
		if ( $_ ) {
			$$error{$$Equipment{id}} .= $_;
		} else {
			push @possible_equipment, $Equipment;
		}
	} # end foreach equipment
	return @possible_equipment;
} # end sub get_equipment


# Assumes that all checks are done, only calculates price
sub get_price {
	my ( $Project, $ServiceType, $Equipment, $specs, $pockets, $plusCover, $qty_index ) = @_;

	my %price = (
			MakeReadyTotal => 0,
			Passes	=>	[],
			Service	=> 0,
			Insert	=> 0,
			RunTime	=> 0,
			Imposition => $$specs{'Imposition'.$qty_index},
			MPrice	=> 0,
			cover	=>	$plusCover,
			);

	my $qty = $$specs{'txtQuantity'.$qty_index} ? $$specs{'txtQuantity'.$qty_index} : $Project->quantity($qty_index);
#$openprint::log->debug($price{Imposition} . ' on ' .$Equipment->name() . ' max imp: ' . $Equipment->specification('Maximum Imposition')) if DEBUG;

	#my $MakeReadyService = openprint::Service->find_one( name=>join('', $$ServiceType{name},'MakeReady',$$specs{"txtPockets$qty_index"},'Pockets') );
	my $MakeReadyService = openprint::Service->find_one( name=>join('',$$ServiceType{name},'MakeReady',$price{Imposition},'out' ) );
	$MakeReadyService = openprint::Service->find_one( name=>join('',$$ServiceType{name},'MakeReady') ) if ! $MakeReadyService;

	my $maxPockets = $Equipment->specification( 'Number of Pockets', undef );
	my $neededPockets = $pockets;
	my $PocketMakeReady = $Equipment->Specification( 'Pocket Make Ready', undef );

	my $unitsPerHour;

# Calculate Full Passes
	if ( $maxPockets and ( $neededPockets > $maxPockets ) ) {
		$openprint::log->debug("Need more pockets $neededPockets > $maxPockets") if DEBUG;

		my $MakeReadyPrice;
		if ( $MakeReadyService ) {
			$MakeReadyPrice = $MakeReadyService->get_Price( $maxPockets, $Equipment );
			$$MakeReadyPrice{Total} = $$MakeReadyPrice{Price};
		} elsif ( DEBUG ) {
			$openprint::log->debug("No Makeready Service for $maxPockets pockets");
		}

		my $servicePrice;
		my $Service = openprint::Service->find_one( name=>$$ServiceType{name}.$maxPockets.'Pockets' );
		$servicePrice = $Service->get_Price( $qty, $Equipment ) if $Service;
		if ( ! $servicePrice ) {
			$Service = openprint::Service->find_one( name=>$$ServiceType{name} );
			$servicePrice = $Service->get_Price( $maxPockets, $Equipment ) if $Service;
		} # end if

		$unitsPerHour = $Equipment->specification( $$ServiceType{name}.'Units Per Hour '.$price{Imposition}.' out', $maxPockets );
		$unitsPerHour = $Equipment->specification( $$ServiceType{name}.'Units Per Hour', $maxPockets ) if ! $unitsPerHour;
		$unitsPerHour = $Equipment->specification( 'Units Per Hour '.$price{Imposition}.' out', $maxPockets ) if ! $unitsPerHour;
		$unitsPerHour = $Equipment->specification( 'Units Per Hour', $maxPockets ) if ! $unitsPerHour;
		my $runtime = $unitsPerHour ? $qty/$unitsPerHour : 0; # in hours

		if ( $servicePrice ) {
			if ( $$servicePrice{units} eq 'per m' ) {
				$$servicePrice{Total} = $$servicePrice{Price} * $qty/1000;
			} elsif ( $$servicePrice{units} eq 'per hour' ) {
				$$servicePrice{Total} = $$servicePrice{Price} * $runtime;
			} elsif ( $$servicePrice{units} eq 'each' ) {
				$$servicePrice{Total} = $$servicePrice{Price} * $qty;
			} else {
				$openprint::log->error("880: Unknown Unit Type: ($$servicePrice{units}) for service $$Service{name} on $$Equipment{strid} $$Equipment{name} maxpockets: $maxPockets");
			} # end if
		}

		my $loopbreak_pockets = $neededPockets;
		while ( $neededPockets > $maxPockets ) {
			my %pass;
			$pass{Pockets} = $maxPockets;
			$pass{MakeReadyPrice} = $MakeReadyPrice;
			$pass{ServicePrice} = $servicePrice;
			$pass{Runspeed} = $unitsPerHour;
			$pass{RunTime} = $runtime;

			if ( $PocketMakeReady ) {
				$pass{PocketMakeReady} = $PocketMakeReady;
				if ( lc $$PocketMakeReady{units} eq 'minutes' ) {
					$pass{PocketMakeReadyTime} += $maxPockets * $$PocketMakeReady{value} /60;
					$price{RunTime} += $pass{PocketMakeReadyTime};
				} else {
					$openprint::log->error("Unknown units on PocketMakeReady");
				} # end if
			} # end if PocketMakeReady

			$price{RunTime} += $runtime;

			if ( $MakeReadyPrice ) {
				$price{MakeReadyTotal} += $$MakeReadyPrice{Total};
			}
			if ( $servicePrice ) {
				$price{Service} += $$servicePrice{Total};
			}
# The minus 1 is because the result of each pass takes up a pocket
			$neededPockets -= ( $maxPockets - 1 );
			last if $neededPockets == $loopbreak_pockets;
			push @{$price{Passes}}, \%pass;
		} # end while
	} # end if

# Calculate Last Pass
	if ( $neededPockets ) {
		my %pass;
		$pass{Pockets} = $neededPockets;

		if ( $PocketMakeReady ) {
			$pass{PocketMakeReady} = $PocketMakeReady;
			if ( lc $$PocketMakeReady{units} eq 'minutes' ) {
				$pass{PocketMakeReadyTime} = $neededPockets * $$PocketMakeReady{value} /60;
				$price{RunTime} += $pass{PocketMakeReadyTime};
			} else {
				$openprint::log->error("Unknown units on PocketMakeReady");
			} # end if
		} # end if PocketMakeReady

		my $MakeReadyPrice;
		if ( $MakeReadyService ) {
			$MakeReadyPrice = $MakeReadyService->get_Price( $neededPockets + ( $plusCover ? 1 : 0 ), $Equipment );
			if ( $MakeReadyPrice ) {
				$$MakeReadyPrice{Total} = $$MakeReadyPrice{Price};
				$pass{MakeReadyPrice} = $MakeReadyPrice;
				$price{MakeReadyTotal} += $$MakeReadyPrice{Total}
			} else {
				$openprint::log->debug("No Makeready Price on $$Equipment{strid}" . $MakeReadyService->to_string() );
			}
		} elsif ( DEBUG ) {
			$openprint::log->debug("No Makeready Service");
		}

		$unitsPerHour = $Equipment->specification( $$ServiceType{name}.'Units Per Hour '.$price{Imposition}.' out', $neededPockets );
		$unitsPerHour = $Equipment->specification( $$ServiceType{name}.'Units Per Hour', $neededPockets ) if ! $unitsPerHour;
		$unitsPerHour = $Equipment->specification( 'Units Per Hour ' . $price{Imposition} . ' out', $neededPockets ) if ! $unitsPerHour;
		$unitsPerHour = $Equipment->specification( 'Units Per Hour', $neededPockets ) if ! $unitsPerHour;
		$pass{Runspeed} = $unitsPerHour;
		my $runtime = $unitsPerHour ? $qty/$unitsPerHour : 0; # in horus
		$pass{RunTime} = $runtime;
		$price{RunTime} += $runtime;
		my $servicePrice;
		my $Service = openprint::Service->find_one( name=>$$ServiceType{name}.$neededPockets.'Pockets' );
		$servicePrice = $Service->get_Price( $qty, $Equipment ) if $Service;
		if ( ! $servicePrice ) {
			$Service = openprint::Service->find_one( name=>$$ServiceType{name} );
			$servicePrice = $Service->get_Price( $neededPockets, $Equipment ) if $Service;
		} # end if
		if ( $servicePrice ) {
			$pass{ServicePrice} = $servicePrice;
			if ( $$servicePrice{units} eq 'per m' ) {
				$$servicePrice{Total} = $$servicePrice{Price} * $qty/1000;
			} elsif ( $$servicePrice{units} =~ /per hour/i ) {
				$$servicePrice{Total} = $$servicePrice{Price} * $runtime;
			} elsif ( $$servicePrice{units} eq 'each' ) {
				$$servicePrice{Total} = $$servicePrice{Price} * $qty;
			} else {
				$openprint::log->debug("Unknown Units: $$servicePrice{units} for $$ServiceType{name} range($neededPockets) equipment(".$Equipment->strid().")");
			} # end if
			$price{Service} += $$servicePrice{Total}
		}

		$price{RunTime} += $runtime;
		push @{$price{Passes}}, \%pass;

	} # end if

	if ( ( defined $$specs{txtInsertQuantity} ) and ( $$specs{txtInsertQuantity} > 0 ) ) {
		$price{Insert} = openprint::service::get_price( $$ServiceType{name}.'Insert', $$specs{txtInsertQuantity}, $Equipment) * $$specs{txtInsertQuantity};
# Convert to cost per thousand
		$price{Insert} = ($price{Insert}*$qty)/1000;
	} # end if

	my $MinimumRunTime = $Equipment->Specification( 'Minimum Run Time' );
	if ( $MinimumRunTime ) {
		$price{RunTime} = $$MinimumRunTime{value} if $price{RunTime} < $$MinimumRunTime{value};
	} # end if

# FIXME
	my @sigs;
	if ( $plusCover and ( $$specs{CoverFit} eq 'Exact' ) and (
					(@sigs = $Project->signatures({ Group=>1 }) )
					and ( form_needs_fit( $Project, $sigs[0] ) ) 
				) ) {
		my %pass;

		my $servicePrice;
		my $Service = openprint::Service->find_one( name=>$$ServiceType{name}.'1Pockets' );
		$servicePrice = $Service->get_Price( $qty, $Equipment ) if $Service;
		if ( ! $servicePrice ) {
			$Service = openprint::Service->find_one( name=>$$ServiceType{name} );
			$servicePrice = $Service->get_Price( 1, $Equipment ) if $Service;
		} # end if
			my $slowdown_percent = $Equipment->specification('2ndPass Slowdown');

			my $runtime = $unitsPerHour ? $qty/$unitsPerHour : 0; # in hours
			if ( $slowdown_percent ) {
				$slowdown_percent =~ s/[^\d\.\-]//g;
				$runtime *= (1+$slowdown_percent/100);
			} # end if
			if ( $MinimumRunTime ) {
				$runtime = $$MinimumRunTime{value} if $runtime < $$MinimumRunTime{value};
			}
			$pass{RunTime} = $runtime;
			$price{RunTime} += $runtime;
			if ( $$servicePrice{units} eq 'per m' ) {
				$$servicePrice{Total} = $$servicePrice{Price} * $qty/1000;
			} elsif ( $$servicePrice{units} =~ /per hour/i ) {
				$$servicePrice{Total} = $$servicePrice{Price} * $runtime;
			} else {
				$openprint::log->debug("955: Unknown Unit Type: $$servicePrice{units} for $$ServiceType{name} range(1) equipment(".$Equipment->strid().")");
			} # end if
			$pass{ServicePrice} = $servicePrice;
			$price{Service} += $$servicePrice{Total};
			
			my $ExactFitMakeReady = $MakeReadyService->get_Price( 1, $Equipment );
			$pass{MakeReadyPrice} = $ExactFitMakeReady;
			$price{MakeReadyTotal} += $$ExactFitMakeReady{Price};
			push @{$price{Passes}}, \%pass;
		} # end if Exact } # end if requires exact or not
#FIXME
	#if ( $Project->signatures({'type'=>'Gate Folded Pages'}) ) {
	if ( $$specs{'txtSignatureQtySingleGateFolded'.$qty_index} or $$specs{'txtSignatureQtyDoubleGateFolded'.$qty_index} ) {
		my $gateFolds = $$specs{'txtSignatureQtySingleGateFolded'.$qty_index} + $$specs{'txtSignatureQtyDoubleGateFolded'.$qty_index};
		if ( ( $gateFolds > 0 ) and ( $$specs{rdbGateFoldFit} eq 'Exact' ) ) {
			$price{Service} += openprint::service::get_price( $$ServiceType{name}, $gateFolds, $Equipment );
			my $GateFoldFitMakeReady = $MakeReadyService->get_Price( $gateFolds, $Equipment );
			$price{MakeReady} += $$GateFoldFitMakeReady{Price};
		} # end if
	} # end if

	if ( $price{'Calliper Markup'} = $Equipment->specification( 'Calliper Price Adjustment', $$specs{txtCalliper} ) ) {
		$price{Service} *= ( 1 + $price{'Calliper Markup'}/100);
	} # end if

	if ( $price{'RunCost Discount'} = $Equipment->specification( 'RunCost Discount', $$specs{"txtQuantity$qty_index"} ) ) {
		$price{Service} *= ( 1 - $price{'RunCost Discount'}/100);
	} # end if

	$price{'Imposition Discount'} = $Equipment->specification( 'Imposition Discount', $price{Imposition} );
	$price{Service} *= ( 1 - $price{'Imposition Discount'}/100) if $price{'Imposition Discount'};
	$price{MPrice} += ( $price{Service} / $qty ) * 1000 if $qty;
	if ( my $spinelength_discount = $Equipment->specification( 'SpineLength Discount', $$specs{Height} ) ) {
		$price{'SpineLength Discount'} = $spinelength_discount;
		$price{Service} *= ( 1 - $price{'SpineLength Discount'}/100);
		$price{MPrice} *= ( 1 - $price{'SpineLength Discount'}/100);
	} else {
		$price{'SpineLength Discount'} = '';
	} # end if

	$price{Price} = Math::Round::nearest(0.01,$price{MakeReadyTotal} + $price{Service} + $price{Insert});
	$openprint::log->debug($price{Imposition} . 'out on ' .$Equipment->name() . ($price{'Imposition Discount'} ?' Discount: ' . $price{'Imposition Discount'}:'') ) if DEBUG;
	return \%price;
} # end sub get_price

sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;

	my $summary = '';
	if ( $qty_index ) {
		if ( $$specs{'Imposition'.$qty_index} and $$specs{'ddmEquipment'.$qty_index} ) {
			return $$specs{'Imposition'.$qty_index} .'out on ' . new openprint::Equipment( $$specs{'ddmEquipment'.$qty_index} )->name();
		} # en dif
	} else {
		if ( $$specs{rdbGateFoldFit} ) {
			$summary .= 'Gate Fold Fit = ' . $$specs{rdbGateFoldFit} . '<br/>';
		} # end if
		if ( $$specs{CoverFit} ) {
			$summary .= 'Cover Fit = ' . $$specs{CoverFit} . '<br/>';
		} # end if
	} # end if
	return $summary;
} # end sub summary

sub schedule_summary {
  my ( $Project, $service_id, $specs, $qty_index ) = @_;

	 return join(' ',  
			$$specs{'Imposition'.$qty_index} .'out',
			misc::sum( map {$$specs{"txtSignatureQty${_}Page-$qty_index"} ? $$specs{"txtSignatureQty${_}Page-$qty_index"} : () } @possible_pages ) . ' pockets',

			( $$specs{rdbGateFoldFit} ? 'Gate Fold Fit = ' . $$specs{rdbGateFoldFit} : () ),
			( $$specs{CoverFit} ? 'Cover Fit = ' . $$specs{CoverFit} : () ),
	);
}

sub runtime {
	my ( $Project, $Service, $Equipment, $qty_index, $speed ) = @_;

	my $ServiceType = $Service->ServiceType();
	my $specs = $Service->specs();
	if ( ! $Equipment ) {
		$openprint::log->warn("No equipment passed to runtime");
		if ( ! $$specs{'ddmEquipment'.$qty_index} ) {
			$openprint::log->error("No equipment in estimate");
			return 0;
		} # end if
		$Equipment = new openprint::Equipment($$specs{'ddmEquipment'.$qty_index});
		if ( ! $Equipment->id() ) {
			$openprint::log->error("No equipment found for quoted Equipment ");
			return 0;
		} # end if
	} # end if

	my $runTime;

# Count the # of signatures
	my $pockets = 0;
	foreach my $spec ( keys %$specs ) {
		if ( $spec =~ /^txtSignatureQty(.*)$/ ) {
			$pockets += int($$specs{$spec});
		} # end if
	} # end foreach

	$pockets += int( $$specs{txtInsertQuantity} );
	my $gateFolds = int($$specs{txtSignatureQtySingleGateFolded} ) + int($$specs{txtSignatureQtyDoubleGateFolded});
	if ( $$specs{rdbGateFoldFit} eq 'Exact' ) {
		$pockets -= $gateFolds;
	} # end if

	my $maxPockets = $Equipment->specification( 'Number of Pockets' );
	my $makereadytime = $Equipment->specification( 'Pocket Make Ready' ) * 60;
	$openprint::log->debug("Pockets: $pockets MakeReadyTime: $makereadytime");
	$runTime += $pockets * $makereadytime;

# Calculate Full Passes
	if ( $pockets > $maxPockets ) {
# Loaded here, so we don't do it in the loop many times
		my $unitsPerHour = $Equipment->specification( $$ServiceType{name}.'Units Per Hour', $maxPockets );
		$unitsPerHour = $Equipment->specification( 'Units Per Hour', $maxPockets ) if ! $unitsPerHour;

		if ( $unitsPerHour ) {
			$runTime += ($$specs{"txtQuantity$qty_index"}*3600/$unitsPerHour) * int ( $pockets / $maxPockets );
			$pockets = $pockets % $maxPockets;
		} # end if
	} # end if

	my $unitsPerHour = $Equipment->specification( $$ServiceType{name}.'Units Per Hour', $pockets );
	$unitsPerHour = $Equipment->specification( 'Units Per Hour', $pockets ) if ! $unitsPerHour;
# Calculate Last Pass
	if ( $unitsPerHour ) {
		$runTime += $$specs{"txtQuantity$qty_index"}*3600/$unitsPerHour; # in seconds
	} # end if
	return $runTime;
} # end sub get_runtime

sub save {
} # end sub save

sub form_needs_fit {
	my ( $Project, $sig_id, $sig_specs, $project_specs ) = @_;

	my $services = $Project->services();
	$project_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] ) if ! $project_specs;
	$sig_specs = openprint::service::get_specs_ref( $Project, $sig_id ) if ! $sig_specs;
	if (
			( $$sig_specs{txtFinalWidth} != $$project_specs{txtFinalWidth} or $$sig_specs{txtFinalHeight} != $$project_specs{txtFinalHeight} ) or
			( $$sig_specs{rdbTemplateType} and sets::isin( $$sig_specs{rdbTemplateType}, ['2Panel1Pocket','2Panel2Pocket','TriFoldDoublePocket'] ) ) or 
			( $$sig_specs{GroupPageQuantity} > 4 ) ) {
		return 1;
	} # end if
	return 0;
} # end sub form_needs_fitting

1;
__END__
