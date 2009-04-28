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

my $debug = 0;

require openprint::project;
require openprint::Equipment;
require openprint::service;

require sql;
use openprint::Equipment;
use Time::HiRes qw{ time gettimeofday tv_interval }; 

# This is an array of all the variables that need to be saved to the database for this service.
my %variables = (
        'ProjectIndex'=>[],'ServiceIndex'=>[],
		'hdnBreakdown1'=>['output'],'hdnBreakdown2'=>['output'],'hdnBreakdown3'=>['output'],
        'txtQuantity1'=>['save'], 'txtQuantity2'=>['save'], 'txtQuantity3'=>['save'],
        'ServiceType'=>[],
		'alert'=>['output'],'Status'=>['output'],
		'txtInsertQuantity'=>['save','output'],'chkOverrideInsertQuantity'=>['save'],
		'txtCalliper'=>['save','output'],
		'OverrideImposition1'=>['save'], 'OverrideImposition2'=>['save'], 'OverrideImposition3'=>['save'],
		'Imposition1'=>['save','output'], 'Imposition2'=>['save','output'], 'Imposition3'=>['save','output'],
		'ddmEquipment1'=>['save','output'], 'ddmEquipment2'=>['save','output'], 'ddmEquipment3'=>['save','output'],
		'OverridePockets1'=>['save'], 'OverridePockets2'=>['save'], 'OverridePockets3'=>['save'],
		'chkOverrideEquipment1'=>['save'], 'chkOverrideEquipment2'=>['save'], 'chkOverrideEquipment3'=>['save'],
		'rdbGateFoldFit'=>['save'], 'CoverFit'=>['save'],
		'txtUnitPrice1'=>['output'], 'txtUnitPrice2'=>['output'], 'txtUnitPrice3'=>['output'],
		'OverridePrice1'=>['save'], 'OverridePrice2'=>['save'], 'OverridePrice3'=>['save'],
		'Markup1'=>['save'], 'Markup2'=>['save'], 'Markup3'=>['save'],
		'txtPrice1'=>['save','output'], 'txtPrice2'=>['save','output'], 'txtPrice3'=>['save','output'],
		'MPrice1'=>['save','output'], 'MPrice2'=>['save','output'], 'MPrice3'=>['save','output'],
		'txtRunTime1'=>['save'], 'txtRunTime2'=>['save'], 'txtRunTime3'=>['save'],
		'txtSignatureQty4Page-1'=>['save','output'], 'txtSignatureQty4Page-2'=>['save','output'], 'txtSignatureQty4Page-3'=>['save','output'],
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
	if ( int $$specs{'txtInsertQuantity'} ) {
		foreach my $insert_id ( 1 .. int $$specs{'txtInsertQuantity'} ) {
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
	my @v;
	foreach my $k ( keys %variables ) {
		push @v, $k, if ! sets::isin( 'output', $variables{$k} );
	} # end foreach;
	return @v;
}

# A function that is smart enough to return true if the project needs folding, and false if it doesn't.
sub neccessary {
	my ( $log, $dbh, $Project ) = @_;

	$Project = new openprint::Project( $Project ) if ref $Project ne 'openprint::Project';

	my $services = $Project->services();

	if ( $$services{'NoBindery'} ) {
		$log->debug(" ** Project is marked as No bindery, Stitching not needed ! ** ");
		return 0;
	} # end if

	my $printing_service_index = $$services{''}[0] if $$services{''};
	my $specs = openprint::service::get_specs_ref( $Project, $printing_service_index );
	if ( sets::isin( $$specs{'rdbTemplateType'},[ 'SaddleStitching','LoopStitching'] ) ) {
		return 1;
	} # end if

	return 0;
} # end sub neccessary

sub get_imposition {
	my $imposition = 2;
	foreach my $I ( @_ ) {
		last if $imposition <= 1;

		$imposition = 1 if ( 
		($$I{'imposition'} % 2 ) or 
		($$I{'image_orientation'} eq 'Vertical' and $$I{'rows'} % 2 ) or 
		($$I{'image_orientation'} eq 'Horizontal' and $$I{'columns'} % 2 ) or
		(sets::isin( $$I{'runstyle'}, ['Work & Turn','Work & Tumble'] ) and $$I{'imposition'}%4) 
		);
	} # end foreach Imposition
	return $imposition;
} # end sub get_imposition

# Calculates the cost of stitching a signature... which is not realistic, but will hopefully help when deciding between 1up or 2up stitching
sub signature_calc {
	my ( $Project, $service_index, $specs, $qty_index, $folding_specs, $sig_service_index, @Impositions ) = @_;

	my %results;
	my $services = $Project->services();
	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );
	my $ServiceType = $Project->ServiceType( $service_index );

	my $plusCover = $$printing_specs{'rdbCover'} eq 'Different' ? 1 : 0;

	# Need to figure out which dimension the spine bisects
	if ( $$printing_specs{'txtFinalWidth'} == $$printing_specs{'txtWidth'} ) {
		@$specs{'Width','Height'} = @$printing_specs{'txtFinalHeight','txtFinalWidth'};
	} else {
		@$specs{'Width','Height'} = @$printing_specs{'txtFinalWidth','txtFinalHeight'};
	} # end if
#$I->display();

	# Start with 2 and try to figure it out
	my $imposition = 2;
	$$specs{"txtPockets$qty_index"} = 0;

	foreach my $I ( @Impositions ) {
		$$specs{"txtPockets$qty_index"} += 1;

		if ( $imposition > 1 ) {
			$imposition = 1 if ( 
			($$I{'imposition'} % 2 ) or 
			($$I{'image_orientation'} eq 'Vertical' and $$I{'rows'} % 2 ) or 
			($$I{'image_orientation'} eq 'Horizontal' and $$I{'columns'} % 2 ) or
			(sets::isin( $$I{'runstyle'}, ['Work & Turn','Work & Tumble'] ) and $$I{'imposition'}%4) 
			);
		} # end if
	} # end foreach Imposition
	my $I = $Impositions[0];

#$openprint::log->debug( "Stitching Impo: " . $imposition ) if $debug;
	if ( $$specs{'OverrideImposition'.$qty_index} eq 'Y' ) {
		if ( $imposition < $$specs{'Imposition'.$qty_index} ) {
			$$specs{'alert'} .= "Can't stitch $$specs{'Imposition'.$qty_index} out";
			$$specs{'Status'} = 'uncalculated';
		} # end if
	} else {
		$$specs{'Imposition'.$qty_index} = $imposition;
	} # end if

	my $error;
	# THe Equipment::find call gets cached... and the rest is impo-specific... so we can't really cache this.
	my @possible_equipment = get_equipment( $specs, \$error );
	my @equipment = ();

	if ( $$specs{"chkOverrideEquipment$qty_index"} eq 'Y' ) {
		if ( ! $$specs{"ddmEquipment$qty_index"} ) {
			$$specs{'alert'} .= 'Please select a piece of equipment to stitch your job.<br/>';
		} else {
			@equipment = openprint::Equipment::find( 'id'=> $$specs{"ddmEquipment$qty_index"} );
			if ( ! @equipment ) {
				$$specs{'alert'} .= 'Your selected equipment was not found. Please select another.<br/>';
			} # end if
		} # end if
	} else {
		@equipment = @possible_equipment;
	} # end if

	my $bestPrice;
	my $bestEquipment;
#$results{'alert'} .= $imposition.'out on ';
#$$specs{'hdnBreakdown'.$qty_index} = 'Imposition: ' . $$specs{'Imposition'.$qty_index} .'<br/>';
	foreach my $Equipment ( @equipment ) {
		if ( $$services{'NoOfflineBindery'} ) {
			if ( $I->Press()->id() != $Equipment->id() ) {
				$$specs{'hdnBreakdown'.$qty_index} .= "No Offline bindery and not printing on $$Equipment{name}.<br/>";
				next;
			} # end if
		} # end if
		if ( $Equipment->specification('Maximum Spine Length') and ( $$specs{'Height'} > $Equipment->specification('Maximum Spine Length', $$specs{'Imposition'.$qty_index} ) ) ) {
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Spine Too big. Spine: %s, Maximum: %s<br/>', $$specs{'Height'}, $Equipment->specification('Maximum Spine Length') );
			next;
		} # end if
		if ( $Equipment->specification('Minimum Spine Length') and ( $$specs{'Height'} < $Equipment->specification('Minimum Spine Length', $$specs{'Imposition'.$qty_index} ) ) ) {
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Spine Too small. Spine: %s, Minimum: %s<br/>', $$specs{'Height'}, $Equipment->specification('Minimum Spine Length') );
			next;
		} # end if
		if ( $Equipment->specification('Type') eq 'Press' ) {
			if ( $$specs{'txtPockets'.$qty_index} > 1 ) {
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Too many pockets: %d<br/>', $$specs{'txtPockets'.$qty_index} );
				next;
			} # end if
			if ( $I->Press()->id() != $Equipment->id() ) {
				#$openprint::log->debug("Press not the same: " . $I->Press()->id() . ' != ' . $Equipment->id() );
				next;
			} # end if
			
			if ( $Impositions[0]{'Folder'}->id() != $Equipment->id() ) {
				#$openprint::log->debug("Folder not the same: " . $$folding_specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"}. ' != ' . $Equipment->id() );
				next;
			} # end if
		} # end if
		my $price = get_price( $Project, $ServiceType, $Equipment, $specs, $plusCover, $qty_index );
		if ( ( ! $bestPrice ) or $$price{'txtPrice'} < $$bestPrice{'txtPrice'} ) {
			$bestEquipment = $Equipment;
			$bestPrice = $price;
		} # end if
	} # end foreach Equipment
#$openprint::log->debug("Breakdown: $$specs{'hdnBreakdown'.$qty_index}");
	$results{'alert'} .= $error;
	$results{'alert'} .= sprintf('%dout on %s %dpockets', $$bestPrice{'Imposition'},($bestEquipment ? $bestEquipment->strid() : '' ),$$specs{'txtPockets'.$qty_index} );
	$results{'Imposition'} = $$bestPrice{'Imposition'};
	$results{'Equipment'} = $bestEquipment;
#$openprint::log->debug( "Stitching Impo REsults: " . $results{'Imposition'} ) if $debug;
	if ( $$bestPrice{'Imposition'} ) {
		$results{'Status'} = 'calculated';
		$results{'Price'} = $$bestPrice{'txtPrice'};
	} else {
		$results{'Status'} = 'uncalculated';
	} # end if
	return \%results;
} # end sub signature_calc

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	$$specs{'Status'} = 'calculated';
	my $Project = new openprint::Project( $project_index );
	my $ServiceType = $Project->ServiceType( $service_index );

	my $services = $Project->services();
	if ( ! $$services{''} ) {
		$$specs{'alert'} .= 'Unable to find project service.<br/>';
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	if ( ! $Project->signatures() ) {
		$$specs{'alert'} .= 'Unable to find any signatures to stitch.<br/>';
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	# Figure out whether we need a cover
	my $printing_specs = openprint::service::get_specs_ref( $project_index, $$services{''}[0] );
	@$specs{'txtPageQuantity','txtFinalWidth','txtFinalHeight'} = @$printing_specs{'txtTotalPageQuantity','txtFinalWidth','txtFinalHeight'};
	if ( $$specs{'chkOverrideInsertQuantity'} ne 'Y' ) {
		$variables{txtInsertQuantity} = [ sets::union( 'output', @{$variables{txtInsertQuantity}} ) ];
		$$specs{txtInsertQuantity} = $$printing_specs{'txtInsertQuantity'};
	} else {
		$variables{txtInsertQuantity} = [ sets::exclude( ['output'], $variables{txtInsertQuantity} ) ];
	} # end if

	if ( $$specs{'txtPageQuantity'} <= 0 ) {
		$$specs{'alert'} .= 'Unable to determine page quantity<br/>';
		$$specs{'Status'} = 'uncalculated';
		return 'uncalculated';
	} # end if

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$specs{'txtPrice'.$qty_index} =~ s/[^\d\.]//g;
		$$specs{'txtQuantity'.$qty_index} =~ s/[^\d\.]//g;
		$$specs{'txtQuantity'.$qty_index} = $Project->quantity($qty_index) if ! $$specs{'txtQuantity'.$qty_index};

		if ( $$specs{'OverridePockets'.$qty_index} ne 'Y' ) {
			foreach my $pages ( 4, 8, 12, 16, 20, 24, 32, 36, 40, 48, 64 ) {
				$$specs{'txtSignatureQty'.$pages.'Page-'.$qty_index} = 0;
			} # end foreach
		} # end if
		$$specs{"txtPockets$qty_index"} = 0;
		my $imposition = 2;

		foreach my $signature_service_index ( $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
$openprint::log->debug(sprintf('%d %s %s %d %dx%d %s', $imposition, @$sig_specs{'txtSignatureType','ddmRunStyle'.$qty_index,'txtImposition'.$qty_index,'hdnImpositionColumns'.$qty_index,'hdnImpositionRows'.$qty_index,'hdnImageOrientation'.$qty_index} ) );
			next if $$sig_specs{'txtSignatureType'} eq 'Cover Pages';
			if ( 
				($$sig_specs{'txtImposition'.$qty_index}%2) or 
				($$sig_specs{'hdnImageOrientation'.$qty_index} eq 'Vertical' and $$sig_specs{'hdnImpositionRows'.$qty_index} % 2 ) or 
				($$sig_specs{'hdnImageOrientation'.$qty_index} eq 'Horizontal' and $$sig_specs{'hdnImpositionColumns'.$qty_index} % 2 ) or
				(sets::isin( $$sig_specs{'ddmRunStyle'.$qty_index}, ['Work & Turn','Work & Tumble'] ) and $$sig_specs{'txtImposition'.$qty_index} % 4 ) 
			   ) {

				$openprint::log->warn("Setting imposition to 1 :" . $$sig_specs{'txtImposition'.$qty_index} . ' ' . $$sig_specs{'ddmRunStyle'.$qty_index} );
				$imposition = 1 
			} # end if
			last if $imposition == 1;
			# Why is this here, does the above not take care of it?
			#if ( $$sig_specs{'hdnImageOrientation'.$qty_index} eq 'Vertical' ) {
				#$imposition = 1 if $$sig_specs{'hdnImpositionRows'.$qty_index} % 2;
			#} elsif ( $$sig_specs{'hdnImageOrientation'.$qty_index} eq 'Horizontal' ) {
				#$imposition = 1 if $$sig_specs{'hdnImpositionColumns'.$qty_index} % 2;
			#} # end if
		} # end foreach

		if ( $$specs{'OverrideImposition'.$qty_index} eq 'Y' ) {
#$openprint::log->debug("Overriding imposiion");
			if ( $imposition < $$specs{'Imposition'.$qty_index} ) {
				$$specs{'alert'} .= "Can't stitch $$specs{'Imposition'.$qty_index} out";
				$$specs{'Status'} = 'uncalculated';
			} # end if
		} else {
			$$specs{'Imposition'.$qty_index} = $imposition;
		} # end if
	} # end foreach

	my $folding_specs = 0;
	if ( $$services{'Folding'} ) {
		$folding_specs = openprint::service::get_specs_ref( $Project, $$services{'Folding'}[0] );
	} # end if
	$$specs{'txtCalliper'} = openprint::print::get_finished_calliper( $project_index );
	my $plusCover = 0;
	if ( $$printing_specs{'rdbCover'} eq 'Different' ) {
		#$log->debug("************* We Have Plus Cover *************************");
		$plusCover = 1;
	} # end if

	# Need to figure out which dimension the spine bisects
	@$specs{'Width','Height'} = @$printing_specs{'txtFinalWidth','txtFinalHeight'};
	if ( $$printing_specs{'txtFinalWidth'} == $$printing_specs{'txtWidth'} ) {
		@$specs{'Width','Height'} = @$printing_specs{'txtFinalHeight','txtFinalWidth'};
	} # end if

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		next if ! $$specs{'txtQuantity'.$qty_index};
		$$specs{'hdnBreakdown'.$qty_index} .= 'Finished Calliper: ' . $$specs{'txtCalliper'} . '<br/>';
		$$specs{'hdnBreakdown'.$qty_index} .= 'Face Trim: ' . $$specs{'Width'} . '<br/>';

		if ( $$specs{'OverridePockets'.$qty_index} ne 'Y' ) {
			foreach my $signature_service_index ( $Project->signatures() ) {
				my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );

				if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "Signature $$sig_specs{SignatureIndex} has no imposition.<br/>";
					next;
				} # end if
				if ( ! $$sig_specs{'txtSpreadSize'} ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "Signature $$sig_specs{SignatureIndex} has no spread size.<br/>";
					next;
				} # end if
				if ( ! $$sig_specs{'PageQuantity'.$qty_index} ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "Signature $$sig_specs{SignatureIndex} has no pages.<br/>";
					next;
				} # end if

				my %pages;
				my $sig_pages = $$sig_specs{'PageQuantity'.$qty_index};
				if ( $folding_specs ) {
					foreach my $index ( 1 .. 4 ) {
						my $type = $$folding_specs{"FoldType-$$sig_specs{SignatureIndex}-$qty_index-$index"};
						next if ! $type;
						my ( $pages ) = $type =~ /(\d+)PageFold/;
						if ( $$folding_specs{"FoldQty-$$sig_specs{SignatureIndex}-$qty_index-$index"} * $pages > $$sig_specs{'PageQuantity'.$qty_index} ) {
							$pages{$pages} += $$sig_specs{'PageQuantity'.$qty_index} / $pages;
						} elsif ( $$folding_specs{"FoldQty-$$sig_specs{SignatureIndex}-$qty_index-$index"} * $pages == $$sig_specs{'PageQuantity'.$qty_index} ) {
							$pages{$pages} += $$folding_specs{"FoldQty-$$sig_specs{SignatureIndex}-$qty_index-$index"};
						} else {
							$pages{$pages} += 1;
						} # end if
#$$folding_specs{"FoldQty-$$sig_specs{SignatureIndex}-$qty_index-$index"};
					} # end foreach index
				} # end if

				# If not all pages have been folde, then revert to just pull from the sig.
				if ( misc::sum( map { $_ * $pages{$_} } keys %pages ) < $sig_pages ) {
					$$specs{"txtPockets$qty_index"} += 1;
					$$specs{'txtSignatureQty'.$sig_pages.'Page-'.$qty_index} += 1;
				} else {
					foreach my $page ( keys %pages ) {
						$$specs{"txtPockets$qty_index"} += $pages{$page};
						$$specs{'txtSignatureQty'.$page.'Page-'.$qty_index} += $pages{$page};
					} # end foreach
				} # end if
			} # end foreach signature
		} else { # Override Pockets
			foreach my $pages ( 4, 8, 12, 16, 20, 24, 32, 36, 40, 48, 64, 96 ) {
				$$specs{"txtPockets$qty_index"} += $$specs{'txtSignatureQty'.$pages.'Page-'.$qty_index};
#$openprint::log->debug("Pckets $qty_index: " . $$specs{"txtPockets$qty_index"} );
			} # end foreach
		} # end if
	} # end foreach qty_index

	#At this point, if the job supports 2out impo, our setup is 2out.  This may change later, depending on the equipment's ability to support 2out stitching
	my $error;
	my @possible_equipment = get_equipment( $specs, \$error );

	if ( ! @possible_equipment ) {
		$error =~ s/\n/<br\/>/g;
		# alert the user that no equipment is good.
		$$specs{'alert'} = "Our stitching equipment cannot run this project, for the following reasons:<br/>$error<br/> Please only print flat sheets and contact another bindery.";
		$$specs{'Status'} = 'uncalculated';
		return 'uncalculated';
	} # end if

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		next if ! $$specs{"txtQuantity$qty_index"};

		if ( $$specs{'txtInsertQuantity'} > 0 ) {
			$$specs{"txtPockets$qty_index"} += $$specs{'txtInsertQuantity'};
		} # end if

		if ( $$specs{'rdbGateFoldFit'} eq 'Exact' ) {
			$$specs{"txtPockets$qty_index"} -= ( $$specs{'txtSignatureQtySingleGateFolded'.$qty_index} + $$specs{'txtSignatureQtyDoubleGateFolded'.$qty_index} );
		} # end if

		if ( 1 > $$specs{"txtPockets$qty_index"} ) {
			$$specs{'Status'} = 'uncalculated';
			$$specs{'alert'} .= 'We are unable to determine how many pockets your project requires.  Please contact us.';
			if ( $$specs{'OverrideImposition'.$qty_index} ne 'Y' ) {
				$$specs{'Imposition'.$qty_index} = '';
			} # end if
			return $$specs{'Status'};
		} # end if
		$$specs{'hdnBreakdown'.$qty_index} .= qq{# of Pockets needed: $$specs{"txtPockets$qty_index"}<br/>};

		my $bestEquipment;
		my $bestPrice;


		my @equipment = ();
		if ( $$specs{"chkOverrideEquipment$qty_index"} eq 'Y' ) {
            $variables{"ddmEquipment$qty_index"} = [ sets::exclude( ['output'], $variables{"ddmEquipment$qty_index"} ) ];
			if ( ! $$specs{"ddmEquipment$qty_index"} ) {
				$$specs{'alert'} .= 'Please select a piece of equipment to stitch your job.<br/>';
			} else {
				@equipment = openprint::Equipment::find( 'id'=>$$specs{"ddmEquipment$qty_index"} );
				if ( ! @equipment ) {
					$$specs{'alert'} .= 'Your selected equipment was not found. Please select another.<br/>';
				} # end if
			} # end if
		} else {
			$variables{"ddmEquipment$qty_index"} = [ sets::union( 'output', @{$variables{"ddmEquipment$qty_index"}} ) ];
			@equipment = @possible_equipment;
		} # end if

		foreach my $Equipment ( @equipment ) {
			$$specs{'hdnBreakdown'.$qty_index} .= "$$Equipment{name}.<br/>";
			my ($ss_id) = $Project->signatures();
			my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
			if ( $$services{'NoOfflineBindery'} ) {
				if ( $$sig_specs{'ddmPress'.$qty_index} ne $Equipment->strid() ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "No Offline bindery and not printing on $$Equipment{name}.<br/>";
					next;
				} # end if
			} # end if
			if ( $Equipment->specification('Maximum Spine Length') and ( $$specs{'Height'} > $Equipment->specification('Maximum Spine Length', $$specs{'Imposition'.$qty_index} ) ) ) {
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Spine Too big. Spine: %s, Maximum: %s<br/>', $$specs{'Height'}, $Equipment->specification('Maximum Spine Length') );
				next;
			} # end if
			if ( $Equipment->specification('Minimum Spine Length') and ( $$specs{'Height'} < $Equipment->specification('Minimum Spine Length', $$specs{'Imposition'.$qty_index} ) ) ) {
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Spine Too small. Spine: %s, Minimum: %s<br/>', $$specs{'Height'}, $Equipment->specification('Minimum Spine Length') );
				next;
			} # end if
			if ( $Equipment->specification('Type') eq 'Press' ) {
				if ( $$specs{'txtPockets'.$qty_index} > 1 ) {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Too many pockets: %d<br/>', $$specs{'txtPockets'.$qty_index} );
					next;
				} # end if
				if ( $$sig_specs{'ddmPress'.$qty_index} ne $Equipment->strid() ) {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Printing equipment not the same: %s<br/>',$$sig_specs{"ddmPress$qty_index"} );
					next;
				} # end if
				if ( $$folding_specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} != $Equipment->id() ) {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Folding equipment not the same: %s<br/>',$$folding_specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
					next;
				} # end if
			} # end if

			my $price = get_price( $Project, $ServiceType, $Equipment, $specs, $plusCover, $qty_index );
			if ( ( ! $bestPrice ) or $$price{'txtPrice'} < $$bestPrice{'txtPrice'} ) {
				$bestEquipment = $Equipment;
				$bestPrice = $price;
			} # end if
			$$specs{'hdnBreakdown'.$qty_index} .= 'Quantity: ' . $$specs{"txtQuantity$qty_index"} .  ", Equipment: ".$Equipment->strid() ."<br/>";
			$$specs{'hdnBreakdown'.$qty_index} .= 'Estimated Run Time: '. sprintf('%.1f', $$price{'RunTime'} ) . ",<br/>";
			$$specs{'hdnBreakdown'.$qty_index} .= 'Number of Passes: '. sprintf('%.1f', $$price{'Passes'} ) . ",<br/>";
			$$specs{'hdnBreakdown'.$qty_index} .= 'Imposition: '. sprintf('%dout', $$price{'Imposition'} ) . ",<br/>";
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Discounts: Run %d% Imposition: %d%<br/>', @$price{'RunCost Discount','Imposition Discount'} );
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Calliper Markup %d%<br/>', @$price{'Calliper Markup'} );
			$$specs{'hdnBreakdown'.$qty_index} .= 'MakeReady: $' . sprintf( '%.2f', $$price{'MakeReady'}).",<br/>";
			if ( my $servicePrice = $$price{'ServicePrice'} ) {
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service: %d passes at $%.2f%s=$%.2f<br/>', $$price{'Passes'} -1, @$servicePrice{'Price','units','Total'});
			} # end if
			my $servicePrice = $$price{'LastServicePrice'};
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service: 1 pass at $%.2f%s=$%.2f<br/>', @$servicePrice{'Price','units','Total'});
			$$specs{'hdnBreakdown'.$qty_index} .= 'Total: $'. sprintf('%.2f', int($$price{'txtPrice'}))."<br/><br/>";
		} # end foreach
		if ( ! $bestEquipment ) {
			$$specs{'Status'} = 'uncalculated';
			$$specs{"ddmEquipment$qty_index"} = '';
			if ( $$specs{'OverrideImposition'.$qty_index} ne 'Y' ) {
				$$specs{'Imposition'.$qty_index} = '';
			} # end if
		} else {
			$$specs{"ddmEquipment$qty_index"} = $bestEquipment->id();
		} # end if

		##if ( $$bestPrice{'Imposition'} and ( $$specs{'Imposition'.$qty_index} != $$bestPrice{'Imposition'} ) ) {
			#foreach my $pages ( 4, 8, 12, 16, 20, 24, 32 ) {
				#$$specs{'txtSignatureQty'.$pages.'Page-'.$qty_index} *= $$specs{'Imposition'.$qty_index} / $$bestPrice{'Imposition'};
			#} # end foreach
		#} # end if
		$$specs{'Imposition'.$qty_index} = $$bestPrice{'Imposition'};
		if ( $$specs{'OverridePrice'.$qty_index} ne 'Y' ) {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$bestPrice{'txtPrice'} * (1+$$specs{"Markup$qty_index"}/100) );
		} else {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{'txtPrice'.$qty_index} );
		} # end if
		$$specs{"MPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $$bestPrice{'MPrice'} *(1+$$specs{"Markup$qty_index"}/100) );
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $$bestPrice{'txtPrice'}/$$specs{"txtQuantity$qty_index"} );
		$$specs{"txtRunTime$qty_index"} = $$bestPrice{'RunTime'};
	} # end foreach qty_index
	$log->debug("END STITCHING!!!!!!!");
	return $$specs{'Status'};
} # end sub calc

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	@{$$variable{'Equipment'}} = openprint::Equipment::find( 'Specifications' => {'Stitching Capable'=>['Y','When Printing']}, 'UseInEstimating'=>'Y','order'=>'lower(strName)');

	my $Project = new openprint::Project( $project_index );
	my $ProjectType = $Project->Type();

	$$variable{'txtPockets'} = $$variable{'SignatureCount'} + $$variable{'txtInsertQuantity'};
} # end sub display

sub get_equipment {
	my ( $specs, $error ) = @_;

	my @possible_equipment;
	my @all_equipment = openprint::Equipment::find( 'Specifications' => {'Stitching Capable'=>['Y','When Printing']}, 'UseInEstimating'=>'Y','order'=>'strName');

	foreach my $Equipment ( @all_equipment ) {
		if ( $Equipment->specification('Maximum Spread Width') and ( $$specs{'Width'} > $Equipment->specification('Maximum Spread Width') ) ) {
			$$error .= "For " . $Equipment->name() . ": Too big.<br/>";
			next;
		} # end if
		if ( $Equipment->specification('Minimum Spread Width') and ( $$specs{'Width'} < $Equipment->specification('Minimum Spread Width') ) ) {
			$$error .= "For " . $Equipment->name() . ": Too small.<br/>";
			next;
		} # end if
		if ( $Equipment->specification('Maximum Calliper') and ( $$specs{'txtCalliper'} > $Equipment->specification('Maximum Calliper') ) ) {
			$$error .= "For " . $Equipment->name() . ": Too Thick.<br/>";
			next;
		} # end if
		if ( $Equipment->specification('Minimum Calliper') and ( $$specs{'txtCalliper'} < $Equipment->specification('Minimum Calliper') ) ) {
			$$error .= "For " . $Equipment->name() . ": Too Thick.<br/>";
			next;
		} # end if
		push @possible_equipment, $Equipment;
	} # end foreach equipment
	return @possible_equipment;
} # end sub get_equipment

sub get_price {
	my ( $Project, $ServiceType, $Equipment, $specs, $plusCover, $qty_index ) = @_;

	my %price = (
		'MakeReady' => 0,
		'Service'	=> 0,
		'Insert'	=> 0,
		'txtPrice'	=> 0,
		'RunTime'	=> 0,
		'Passes'	=> 0,
		'Imposition' => $$specs{'Imposition'.$qty_index},
		'MPrice'	=> 0,
	);

	my $qty = $$specs{'txtQuantity'.$qty_index};
#$openprint::log->debug($price{'Imposition'} . ' on ' .$Equipment->name() . ' max imp: ' . $Equipment->specification('Maximum Imposition')) if $debug;
	if ( $Equipment->specification("Maximum $$ServiceType{name} Imposition") and ( $Equipment->specification("Maximum $$ServiceType{name} Imposition") < $$specs{'Imposition'.$qty_index} ) ) {
		$price{'Imposition'} = 1;
		$openprint::log->debug("Maximum Imposition: " . $Equipment->specification("Maximum $$ServiceType{name} Imposition")  ) if $debug;
	} elsif ( $Equipment->specification('Maximum Spine Length',$price{'Imposition'}) and $Equipment->specification('Maximum Spine Length',$price{'Imposition'}) < $$specs{'Height'} ) {
		$openprint::log->debug("Maximum Spine Length: $$specs{'Height'} > " . $Equipment->specification('Maximum Spine Length',$price{'Imposition'})  ) if $debug;
		$price{'Imposition'} = 1;
	} # end if

	my %MakeReady = openprint::service::get_price_object( $$ServiceType{'name'}.'MakeReady'.$$specs{"txtPockets$qty_index"}.'Pockets', $price{'Imposition'}, $Equipment );
	if ( ! %MakeReady ) {
		%MakeReady = openprint::service::get_price_object( $$ServiceType{'name'}.'MakeReady', $$specs{"txtPockets$qty_index"}, $Equipment );
	} # end if
	my $pocketMakeReady = openprint::service::get_price( $$ServiceType{'name'}.'PocketMakeReady', $$specs{"txtPockets$qty_index"}, $Equipment );
	$price{'MakeReady'} = $MakeReady{'Price'} + $pocketMakeReady * ( $$specs{"txtPockets$qty_index"} + $plusCover );

	my $maxPockets = $Equipment->specification( 'Number of Pockets', undef );
	my $neededPockets = $$specs{"txtPockets$qty_index"};
	$price{'RunTime'} += $neededPockets * $Equipment->specification( 'Pocket Make Ready', undef );

# Calculate Full Passes
	if ( $maxPockets and ( $neededPockets > $maxPockets ) ) {
# Loaded here, so we don't do it in the loop many times
		my %servicePrice;
		if ( ! ( %servicePrice = openprint::service::get_price_object( $$ServiceType{'name'}.$maxPockets.'Pockets', $qty, $Equipment ) ) ) {
			%servicePrice = openprint::service::get_price_object( $$ServiceType{'name'}, $maxPockets, $Equipment );
		} # end if
		$price{'ServicePrice'} = \%servicePrice;
		
		my $unitsPerHour = $Equipment->specification( 'Units Per Hour', $maxPockets );
		my $runtime = $unitsPerHour ? $qty/$unitsPerHour : 0; # in seconds
			$price{'RunTime'} += $runtime * 360;
		my $loopbreak_pockets = $neededPockets;
		while ( $neededPockets > $maxPockets ) {
			if ( $servicePrice{'units'} eq 'Per M' ) {
				$servicePrice{'Total'} = $servicePrice{'Price'} * $qty/1000;
				$price{'Service'} += $servicePrice{'Total'};
			} elsif ( $servicePrice{'units'} =~ /Per Hour/i ) {
				$servicePrice{'Total'} = $servicePrice{'Price'} * $runtime;
				$price{'Service'} += $servicePrice{'Total'}
			} else {
				$openprint::log->debug("Unknown Unit Type: ($servicePrice{'units'}) on $$ServiceType{'name'}");
			} # end if

			# The minus 1 is because the result of each pass takes up a pocket
			$neededPockets -= ( $maxPockets - 1 );
			last if $neededPockets == $loopbreak_pockets;
			$price{'Passes'} += 1;
		} # end while
	} # end if

# Calculate Last Pass
	my %servicePrice;
	if ( ! ( %servicePrice = openprint::service::get_price_object( $$ServiceType{'name'}.$neededPockets.'Pockets', $qty, $Equipment ) ) ) {
		%servicePrice = openprint::service::get_price_object( $$ServiceType{'name'}, $neededPockets, $Equipment );
	} # end if
	$price{'LastServicePrice'} = \%servicePrice;
	my $unitsPerHour = $Equipment->specification( 'Units Per Hour', $neededPockets );
	my $runtime = $unitsPerHour ? $qty/$unitsPerHour : 0; # in seconds
	$price{'RunTime'} += $runtime * 360;
	if ( $servicePrice{'units'} eq 'Per M' ) {
		$servicePrice{'Total'} = $servicePrice{'Price'} * $qty/1000;
		$price{'Service'} += $servicePrice{'Total'};
	} elsif ( $servicePrice{'units'} =~ /Per Hour/i ) {
		$servicePrice{'Total'} = $servicePrice{'Price'} * $runtime;
		$price{'Service'} += $servicePrice{'Total'}
	} else {
		$openprint::log->debug("Unknown Unit Type: $servicePrice{'units'} for $$ServiceType{'name'} range($neededPockets) equipment(".$Equipment->strid().")");
	} # end if
	$price{'Passes'} += 1;

	if ( $$specs{'txtInsertQuantity'} > 0 ) {
		$price{'Insert'} = openprint::service::get_price( $$ServiceType{'name'}.'Insert', $$specs{'txtInsertQuantity'}, $Equipment) * $$specs{'txtInsertQuantity'};
# Convert to cost per thousand
		$price{'Insert'} = ($price{'Insert'}*$qty)/1000;
	} # end if

	if ( my @sigs = $Project->signatures({'Group'=>1}) ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $sigs[0] );


		if ( 
( $$sig_specs{'txtWidth'}/2 != $$specs{'Width'} or $$sig_specs{'txtHeight'} != $$specs{'Height'} ) or
( sets::isin( $$sig_specs{'rdbTemplateType'}, ['2Panel1Pocket','2Panel2Pocket','TriFoldDoublePocket'] ) or $$sig_specs{'PageQuantity'.$qty_index} > 4 ) 
) {
			if ( (!$$specs{'CoverFit'}) or ($$specs{'CoverFit'} eq 'Exact') ) {
				if ( ! ( %servicePrice = openprint::service::get_price_object( $$ServiceType{'name'}.'1Pockets', $qty, $Equipment ) ) ) {
					%servicePrice = openprint::service::get_price_object( $$ServiceType{'name'}, 1, $Equipment );
				} # end if
				my $slowdown_percent = $Equipment->specification('2ndPass Slowdown');
				
				my $runtime = $unitsPerHour ? $qty/$unitsPerHour : 0; # in seconds
				if ( $slowdown_percent ) {
					$slowdown_percent =~ s/[^\d\.\-]//g;
					$runtime *= (1+$slowdown_percent/100);
				} # end if
				$price{'RunTime'} += $runtime * 360;
				if ( $servicePrice{'units'} eq 'Per M' ) {
					$servicePrice{'Total'} = $servicePrice{'Price'} * $qty/1000;
					$price{'Service'} += $servicePrice{'Total'};
				} elsif ( $servicePrice{'units'} =~ /Per Hour/i ) {
					$servicePrice{'Total'} = $servicePrice{'Price'} * $runtime;
					$price{'Service'} += $servicePrice{'Total'}
				} else {
					$openprint::log->debug("Unknown Unit Type: $servicePrice{'units'} for $$ServiceType{'name'} range($neededPockets) equipment(".$Equipment->strid().")");
				} # end if
				$price{'MakeReady'} += $MakeReady{'Price'} + $pocketMakeReady;
				$price{'Passes'} += 1;
			} # end if Exact
		} # end if requires exact or not
	} # end if
	if ( $Project->signatures({'type'=>'Gate Folded Pages'}) ) {
		my $gateFolds = $$specs{'txtSignatureQtySingleGateFolded'.$qty_index} + $$specs{'txtSignatureQtyDoubleGateFolded'.$qty_index};
		if ( $$specs{'rdbGateFoldFit'} eq 'Exact' and $gateFolds > 0 ) {
			$price{'Service'} += openprint::service::get_price( $$ServiceType{'name'}, $gateFolds, $Equipment );
			$price{'MakeReady'} += $MakeReady{'Price'} + ( $pocketMakeReady * ( $gateFolds + 1 ) );
		} # end if
	} # end if

	$price{'Calliper Markup'} = $Equipment->specification( 'Calliper Price Adjustment', $$specs{'txtCalliper'} );
	$price{'Service'} *= ( 1 + $price{'Calliper Markup'}/100);

	$price{'RunCost Discount'} = $Equipment->specification( 'RunCost Discount', $$specs{"txtQuantity$qty_index"} );
	$price{'Service'} *= ( 1 - $price{'RunCost Discount'}/100);

	$price{'Imposition Discount'} = $Equipment->specification( 'Imposition Discount', $price{'Imposition'} );
	$price{'Service'} *= ( 1 - $price{'Imposition Discount'}/100);
	$price{'MPrice'} += ( $price{'Service'} / $qty ) * 1000;

	$price{'txtPrice'} = $price{'MakeReady'} + $price{'Service'} + $price{'Insert'};
$openprint::log->debug($price{'Imposition'} . ' on ' .$Equipment->name() . ' max imp: ' . $Equipment->specification("Maximum $$ServiceType{'name'} Imposition") . 'Discount: ' . $Equipment->specification( 'Imposition Discount', $price{Imposition} ) . ' ' . $price{'txtPrice'} ) if $debug;
	return \%price;
} # end sub get_price

sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;

	if ( $qty_index ) {
		return $$specs{'Imposition'.$qty_index} .'out on ' . new openprint::Equipment( $$specs{'ddmEquipment'.$qty_index} )->name();
	} # end if
	return '';
} # end sub summary

sub runtime {
	my ( $p_id, $s_id, $specs, $qty_index ) = @_;

	return 0 if ! $$specs{'ddmEquipment'.$qty_index};
	my @Equipment = openprint::Equipment::find( 'id' => $$specs{'ddmEquipment'.$qty_index} );
	return 0 if @Equipment != 1;

	my $Equipment = $Equipment[0];

	my $runTime;

# Count the # of signatures
	my $pockets = 0;
	foreach my $spec ( keys %$specs ) {
		if ( $spec =~ /^txtSignatureQty(.*)$/ ) {
			$pockets += int($$specs{$spec});
		} # end if
	} # end foreach

	$pockets += int( $$specs{'txtInsertQuantity'} );
	my $gateFolds = int($$specs{'txtSignatureQtySingleGateFolded'} ) + int($$specs{'txtSignatureQtyDoubleGateFolded'});
	if ( $$specs{'rdbGateFoldFit'} eq 'Exact' ) {
		$pockets -= $gateFolds;
	} # end if

	my $maxPockets = $Equipment->specification( 'Number of Pockets' );
	my $makereadytime = $Equipment->specification( 'Pocket Make Ready' ) * 60;
	$openprint::log->debug("MakeReadyTime: $makereadytime");
	$runTime += $pockets * $makereadytime;

# Calculate Full Passes
	if ( $pockets > $maxPockets ) {
# Loaded here, so we don't do it in the loop many times
		if ( my $unitsPerHour = $Equipment->specification( 'Units Per Hour', $maxPockets ) ) {


			$runTime += ($$specs{"txtQuantity$qty_index"}*3600/$unitsPerHour) * int ( $pockets / $maxPockets );
			$pockets = $pockets % $maxPockets;
		} # end if
	} # end if

# Calculate Last Pass
	if ( my $unitsPerHour = $Equipment->specification( 'Units Per Hour', $pockets ) ) {
		$runTime += $$specs{"txtQuantity$qty_index"}*3600/$unitsPerHour; # in seconds
	} # end if
	return $runTime;
} # end sub get_runtime


1;
__END__
