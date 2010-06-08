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

require openprint::Project;
require openprint::service;
require sql;

use vars qw( @folds %fold_types );

my $debug = 1;

my @equipment;
my @stitchers;

my @variables = (
	'OverridePrice1', 'OverridePrice2', 'OverridePrice3',
	'txtPrice1', 'txtPrice2', 'txtPrice3',
	'Markup1', 'Markup2', 'Markup3',
	'MPrice1', 'MPrice2', 'MPrice3',
	'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
	'txtRunTime1', 'txtRunTime2', 'txtRunTime3',
	);

sub variables {
my @v = @variables;
my ( $p_id, $s_id, $specs ) = @_;

my $Project = new openprint::Project( $p_id );
foreach my $s_s_id ( $Project->signatures() ) {
	my $sig_specs = openprint::service::get_specs_ref( $Project, $s_s_id );
	foreach my $qty_index ( $Project->quantity_indexes() ) {
		push @v, "chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index";
		push @v, "ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index";
		push @v, "chkOverrideFold-$$sig_specs{'SignatureIndex'}-$qty_index";
		foreach my $fold_index ( 1 .. 4 ) {
			push @v, "FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index";
			push @v, "FoldImposition-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index";
			push @v, "FoldColumns-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index";
			push @v, "FoldRows-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index";
			push @v, "FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index";
			push @v, "FoldFolds-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index";
			push @v, "FoldAngles-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index";
			push @v, "FoldRunspeed-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index";
		} # end foreach
		#foreach my $fold_type ( keys %fold_types ) {
		#} # end foreach
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

@folds = (
'2PanelFold',
'3PanelFold',
'3PanelZFold',
'4PanelFold',
'4PanelZFold',
'5PanelFold',
'5PanelZFold',
'6PanelFold',
'6PanelZFold',
'SingleGateFold',
'DoubleGateFold',
'4PageFold',
'6PageFold',
'8PageFold',
'10PageFold',
'12PageFold',
'16PageFold',
'18PageFold',
'20PageFold',
'24PageFold',
'28PageFold',
'30PageFold',
'32PageFold',
'36PageFold',
'40PageFold',
'42PageFold',
'44PageFold',
'48PageFold',
'56PageFold',
'60PageFold',
'64PageFold',
'72PageFold',
'PerpendicularSoftFold',
'ParallelSoftFold',
'2Panel1Pocket',
'2Panel2Pocket',
'2Panel2PocketGusset',
'3Panel2Pocket',
'3Panel2PocketGusset',
'MapFold',
);

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
'4PageFold', '4 Page Fold',
'6PageFold', '6 Page Fold',
'8PageFold', '8 Page Fold',
'10PageFold', '10 Page Fold',
'12PageFold', '12 Page Fold',
'16PageFold', '16 Page Fold',
'18PageFold', '18 Page Fold',
'20PageFold', '20 Page Fold',
'22PageFold', '22 Page Fold',
'24PageFold', '24 Page Fold',
'28PageFold', '28 Page Fold',
'30PageFold', '30 Page Fold',
'32PageFold', '32 Page Fold',
'36PageFold', '36 Page Fold',
'40PageFold', '40 Page Fold',
'42PageFold', '42 Page Fold',
'44PageFold', '44 Page Fold',
'48PageFold', '48 Page Fold',
'56PageFold', '56 Page Fold',
'60PageFold', '60 Page Fold',
'64PageFold', '64 Page Fold',
'72PageFold', '72 Page Fold',
'2Panel1Pocket', 'Single Pocket',
'2Panel2Pocket', '2 Pocket',
'2Panel2PocketGusset', '2 Pocket w/Gussets',
'3Panel2Pocket', '3 Panel 2 Pocket',
'3Panel2PocketGusset', '3 Panel 2 Pocket w/Gussets',
'MapFold','Map Fold',
);

sub fold_types {
} # end sub fold_types

sub signature_needs {
	my ( $Project, $specs, $qty_index ) = @_;

	return 0 if $Project->Type()->name() eq 'Banners';
	my $services = $Project->services();
	if ( $$services{'NoBindery'} ) {
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
	if ( $$services{'CornerStitching'} ) {
		return 0;
	} # end if
	if ( $$services{'SaddleStitching'} ) {
		return 1;
	} # end if
	if ( ($$specs{'pages_supplied'} eq 'Y') and ($$specs{'supplied_format'} eq 'Folded') ) {
		return 0;
	} # end if

	if ( $fold_types{$$specs{'rdbTemplateType'}} ) {
		$openprint::log->warn("FOLDING NEEDED got templatetype!") if $debug;
		return 1;
	} else {
		$openprint::log->warn("FOLDING NEEDED $$specs{'rdbTemplateType'} $fold_types{$$specs{'rdbTemplateType'}}!") if $debug;
	} # end if

	if ( $$specs{'txtSignatureType'} ) {
		if ( $$specs{'txtSpreadSize'} == 1 ) {
			$openprint::log->warn("Folding not needed: spreadsize==1: $$specs{'txtSpreadSize'}");
			return 0;
		} # end if
		if ( $qty_index ) {
			if ( ( $$specs{'PageQuantity'.$qty_index} == 0 ) or ( $$specs{'PageQuantity'.$qty_index} == 2 ) ) {
				$openprint::log->warn("Folding not needed: PageQuantity: $$specs{'PageQuantity'.$qty_index}");
				return 0;
			} # end if	
		} else {
			foreach my $qty_index ( $Project->quantity_indexes() ) {
				if ( $$specs{'PageQuantity'.$qty_index} == 2 ) {
					$openprint::log->warn("Folding not needed: PageQuantity: $$specs{'PageQuantity'.$qty_index}");
					return 0;
				} # end if	
			} # end foreah qty_index
		} # end if
		return 1;
	} # end if

# This works for books because sigs don't have a txtFinalWidth, etc.
	if ( ($$specs{'txtFinalWidth'} != $$specs{'txtWidth'}) or ($$specs{'txtFinalHeight'} != $$specs{'txtHeight'}) ) {
		$openprint::log->warn("FOLDING NEEDED dimensions do not match!") if $debug;
		return 1;
	} # end if

	return 0;
} # end sub signature_needs

# A function that is smart enough to return true if the project needs folding, and false if it doesn't.
sub neccessary {
	my ( $project_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	return 0 if $Project->Type()->name() eq 'Banners';
	my $services = $Project->services( );

	if ( $$services{'NoBindery'} ) {
		$openprint::log->debug(" ** Project is marked as No bindery, Folding not needed ! ** ");
		return 0;
	} # end if

	foreach my $signature_service_index ( $Project->signatures() ) {
		my $specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
		if ( signature_needs( $Project, $specs ) ) {
			return 1;
		} # end if
	} # end foreach
	$openprint::log->debug("FOLDING NOT NEEDED!");
	return 0;	
} # end sub neccessary

# Looks at the imposition, and if the width is too small for the fold, tries to pad the image until it can fold, wasting paper, but sometimes this is desireable.
sub impositions {
	my ( $Project, $Imposition, $specs, $sig_specs, $qty_index ) = @_;

	my @imps = ( $Imposition );

	my $services = $Project->services();

	my $Fold = $Imposition->Equipment()->Fold(
			'pages'				=>	$Imposition->pages(),
			'page_columns'		=>	$Imposition->page_columns(),
			'page_rows'			=>	$Imposition->page_rows(),
			'page_width'		=>	$Imposition->page_width(),
			'page_height'		=>	$Imposition->page_height(),
			'spine_direction'	=>	$$Imposition{'image_orientation'},
			'stitching'			=>	($$services{'SaddleStitching'} or $$services{'LoopStitching'}) ? 1 : 0,
			'perfectbind'		=>	$$services{'PerfectBound'} ? 1 : 0,
			'spinepaste'		=>	$$services{'SpinePaste'} ? 1 : 0,
			'gsm'				=>	$Imposition->Paper()->gsm(),
			'imposition'		=>	$$Imposition{'imposition'},
			'calliper'			=>	$Imposition->Paper()->calliper(),
			);
	return @imps if $Fold;

# Now look it up without the width
	$Fold = $Imposition->Equipment()->Fold(
			'pages'				=>	$Imposition->pages(),
			'page_columns'		=>	$Imposition->page_columns(),
			'page_rows'			=>	$Imposition->page_rows(),
			'page_height'		=>	$Imposition->page_height(),
			'spine_direction'	=>	$$Imposition{'image_orientation'},
			'stitching'			=>	($$services{'SaddleStitching'} or $$services{'LoopStitching'}) ? 1 : 0,
			'perfectbind'		=>	$$services{'PerfectBound'} ? 1 : 0,
			'spinepaste'		=>	$$services{'SpinePaste'} ? 1 : 0,
			'gsm'				=>	$Imposition->Paper()->gsm(),
			'imposition'		=>	$$Imposition{'imposition'},
			'calliper'			=>	$Imposition->Paper()->calliper(),
			);
	return @imps if ! $Fold;

	if ( $Fold->min_width() and $Fold->min_width() > ( $Imposition->image_orientation() eq 'Vertical' ? $Imposition->image_width() : $Imposition->image_height() ) ) {
		my $I = $Imposition->copy();

		if ( $I->image_orientation() eq 'Vertical' ) {
			my $space = $Fold->min_width() - $I->image_width();
			$I->cropmark_left(0) if $space >= $I->cropmark_left();
			$I->cropmark_right(0) if $space >= $I->cropmark_right();
			$I->gutters(0) if $space >= $I->gutters();
			$I->image_width( $Fold->min_width() );
		} else {
			my $space = $Fold->min_width() - $I->image_height();
			$I->cropmark_left(0) if $space >= $I->cropmark_left();
			$I->cropmark_right(0) if $space >= $I->cropmark_right();
			$I->gutters(0) if $space >= $I->gutters();
			$I->image_height( $Fold->min_width() );
		} # end if

		return @imps if ( $I->Paper()->start_width() and $I->Paper()->start_width() < $I->used_width() );
		$I->Paper()->width( $I->used_width() ) if ! $I->Paper()->start_width();
		push @imps, $I;
	} # end if
	return @imps;

} # end sub impositions

sub signature_calc {
	my ( $Project, $signature_service_index, $sig_specs, $specs, $qty_index, $Paper, $SignatureImposition, $uv_specs, $aq_specs ) = @_;

	my $services = $Project->services();
	my $Press = $SignatureImposition->Press();
	if ( $$sig_specs{'txtSignatureType'} and ( $SignatureImposition->pages() == 2 ) ) {
		# Does not need folding
		my %results = (
				'Price'			=> 0,
				'MPrice'		=> 0,
				'Equipment'		=> '',
				'Status'		=> 'calculated',
				'Folds'			=> '',
				'Breakdown'		=> '2 page does not require folding',
				);
		return %results;
	} # end if

	my $bestM;
	my $bestPrice;
	my $bestRunPrice = 0;
	my $bestRunTime = 0;
	my $bestSetupPrice = 0;
	my $bestEquipment;
	my $bestFolds;
	my $Breakdown;

	my @my_equipment;

	if ($debug) {
		$SignatureImposition->display('Signature Imposition:');
	} # end if

	if ( $$specs{"chkOverrideEquipment-$$sig_specs{SignatureIndex}-$qty_index"} eq 'Y' ) {
		$openprint::log->debug("Overriding Folding Equipment for sig $$sig_specs{'SignatureIndex'} to " . $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"});
		if ( $$specs{"ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index"} ) {
			push @my_equipment, new openprint::Equipment( $$specs{"ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index"} );
		} else {
			$openprint::log->warn("Folding Equipment override to nothing");
		} # end if
		push @no_outputs, "ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index";
	} else {
		if ( $Press->specification('Sheeter') eq 'Y' ) {
			my @folding_capable = ('Y');
			push @folding_capable, 'For Pocket Folders' if $Project->Type()->name() eq 'PresentationFolders';
			push @folding_capable, 'When PerfectBound' if $$services{'PerfectBound'};
			push @folding_capable, 'When Stitching' if ( $$services{'SaddleStitching'} or $$services{'LoopStitching'} );
			@my_equipment = openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Folding Capable'=>\@folding_capable} );
		} elsif ( $debug ) {
			$openprint::log->debug("No sheeter");
		} # end if

		$openprint::log->debug("Press: $$sig_specs{'ddmPress'.$qty_index}" . $Press->strid() ) if $debug;
		my $add = 1;
		my $capable = $Press->specification('Folding Capable');	
		if ( $capable and ( $capable ne 'N' ) ) {
			if ( $$sig_specs{'PreviousImposition'} and $$sig_specs{'PreviousImposition'} != $SignatureImposition->imposition() ) {
				$add = 0;
			} # end if

			if ( $$services{'UVCoating'} and openprint::Estimating::UVCoating::signature_needs( $Project, $sig_specs ) ) {
				$uv_specs = openprint::service::get_specs_ref( $Project, $$services{'UVCoating'}[0] ) if ! $uv_specs;
				if ( $$uv_specs{"ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index"} != $Press->id() ) {
					$add = 0;
				} # end if
			} # end if
			if ( $$services{'Aqueous'} and openprint::Estimating::Aqueous::signature_needs( $Project, $sig_specs ) ) {
				$aq_specs = openprint::service::get_specs_ref( $Project, $$services{'Aqueous'}[0] ) if ! $aq_specs;
				if ( $$aq_specs{"ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index"} != $Press->id() ) {
					$add = 0;
				} # end if
			} # end if
			if ( $add ) {
				unshift @my_equipment, $Press;
			} # end if
		} # end if
	} # end if override or lookup equipment

	# If the stitching is happening on a piece of equipment that can't handle large signatures, then we need to cut 
	# them down instead of folding them. Something like a duplo can do 4pg signatures only, so the cutting service 
	# will cut everything down, and we will show the 4pg sigs being folded on the duplo
	if ( $debug ) {
		foreach my $E ( @my_equipment ) {
			$openprint::log->debug("1 Equipment: " . $E->strid() );
		}
	}

	if ( ! @my_equipment ) {
		$$specs{'alert'} .= 'There is no Folding capable equipment.';
		return;
	} # end if

	#$openprint::log->debug("Makereadies...");
	my %makereadies;

	foreach my $ss_id ( $Project->signatures() ) {
		next if $signature_service_index and ($ss_id > $signature_service_index);
		next if $ss_id >= $signature_service_index;
		my $s_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		foreach my $fold_index ( 1 .. 4 ) {
			if ( $$specs{"FoldQty-$$s_specs{'SignatureIndex'}-$qty_index-$fold_index"} ) {
				push @{$makereadies{$$specs{"ddmEquipment-$$s_specs{'SignatureIndex'}-$qty_index"}}}, $$specs{"FoldType-$$s_specs{'SignatureIndex'}-$qty_index-$fold_index"};
			} # end if
		} # end foreach fold_index
	} # end foreach signature

	# What we do is build a set of pieces of the imposition, all of which can be folded. We don't worry about optimality, just possibility.
	my @Set_Of_Impositions;
	my @All_Impositions;

	# IF it's a W&T, we have to cut in half first, so just do it.
	if ( $SignatureImposition->runstyle() eq 'Work & Turn' ) {
		my $i = $SignatureImposition->copy();
		$i->runstyle('Sheet Work');
		$i->start_columns( $i->columns() );
		$i->columns( $i->columns()/2 );
		$$i{'quantity'} = 2;
		push @Set_Of_Impositions, $i;
	} elsif ( $SignatureImposition->runstyle() eq 'Work & Tumble' ) {
		my $i = $SignatureImposition->copy();
		$i->runstyle('Sheet Work');
		$i->start_rows( $i->rows() );
		$i->rows( $i->rows()/2 );
		$$i{'quantity'} = 2;
		push @Set_Of_Impositions, $i;
	} else {
		my $i = $SignatureImposition->copy();
		$$i{'quantity'} = 1;
		push @Set_Of_Impositions, $i;
	} # end if
	if ( ! $$sig_specs{'txtSignatureType'} ) {

		# Get rid of dutches
		if ( $SignatureImposition->dutch_columns() ) {
			my @Impositions = ();
			my $modified = 0;
			foreach my $I ( @Set_Of_Impositions ) {
				if ( $I->dutch_columns() ) {
					my $i = $I->copy();
					$i->dutch_columns(0);
					$i->dutch_rows(0);
					$i->quantity(1);
					push @Impositions, $i;
					my $i = $I->copy();
					$i->columns( $i->dutch_columns() );
					$i->rows( $i->dutch_rows() );
					$i->dutch_columns(0);
					$i->dutch_rows(0);
					$i->quantity(1);
					$i->image_orientation($I->image_orientation() eq 'Vertical' ? 'Horizontal' : 'Vertical');
					push @Impositions, $i;
					$modified = 1;
				} else {
					push @Impositions, $I;
				} # end if
			} # end foreach

			@Set_Of_Impositions = @Impositions if $modified;
			if ( $debug and 0 ) {
				foreach my $I ( @Impositions ) {
					$I->display('Results from dutch cuts');
				} # end foreach
			} # end if
		} # end if

		my $cut_dimension = '';
		if ( $$services{'SaddleStitching'} ) {
			#my $stitching_specs = openprint::service::get_specs_ref( $Project, $$services{'SaddleStitching'}[0] );
			#$max_out = $$stitching_specs{'Imposition'.$qty_index};
	#$openprint::log->debug("Got impo from SaddleStitching: $max_out out") if $debug;
		} elsif ( $$services{'LoopStitching'} ) {
			#my $stitching_specs = openprint::service::get_specs_ref( $Project, $$services{'LoopStitching'}[0] );
			#$max_out = $$stitching_specs{'Imposition'.$qty_index};
	#$openprint::log->debug("Got impo from LoopStitching: $imposition out") if $debug;
		} elsif ( $$sig_specs{'txtFinalWidth'} and $$sig_specs{'txtFinalHeight'} ) {
			# Something else entirely
			my @Impositions = @Set_Of_Impositions;
			@Set_Of_Impositions = ();
			foreach my $I ( @Impositions ) {
				my $width_folds = sprintf('%.0f', ($$sig_specs{'txtWidth'}/$$sig_specs{'txtFinalWidth'})-1 );
				my $height_folds = sprintf('%.0f', ($$sig_specs{'txtHeight'}/$$sig_specs{'txtFinalHeight'}) -1 );
				if ( $width_folds and $height_folds ) {
	# All impositions must be 1 out. This may not be true
					my $Singleton = $I->copy();
					$Singleton->rows( 1 );
					$Singleton->columns( 1 );
					$Singleton->quantity( $I->quantity()*$I->imposition() );
					push @Set_Of_Impositions, $Singleton;
				} elsif ( $width_folds ) {
					if ( $I->image_orientation() eq 'Vertical' ) {
						my $Singleton = $I->copy();
						$Singleton->quantity( $I->quantity()*$I->columns() );
						$Singleton->columns( 1 );
						push @Set_Of_Impositions, $Singleton;
					} else {
						my $Singleton = $I->copy();
						$Singleton->quantity( $I->quantity()*$I->rows() );
						$Singleton->rows( 1 );
						push @Set_Of_Impositions, $Singleton;
					} # end if
				} elsif ( $height_folds ) {
					if ( $I->image_orientation() eq 'Vertical' ) {
						my $Singleton = $I->copy();
						$Singleton->quantity( $I->quantity()*$I->rows() );
						$Singleton->rows( 1 );
						push @Set_Of_Impositions, $Singleton;
					} else {
						my $Singleton = $I->copy();
						$Singleton->quantity( $I->quantity()*$I->columns() );
						$Singleton->columns( 1 );
						push @Set_Of_Impositions, $Singleton;
					} # end if Orientation
				} else {
					push @Set_Of_Impositions, $I;
				} # end if
			} # end foreach I in the set of impositons
		} # end if
		# Now we have a base set of Maximal Impositions.  Now some of the I's in this set may have an imposition > 1.  
		# Problem is that we apparently also need to price the situation of doing them 1 out, and everything in between.  
		if ( $debug and 1 ) {
			foreach my $I ( @Set_Of_Impositions ) {
				$I->display('Results after initial cuts');
			} # end foreach
		} # end if

		@All_Impositions = reduce_impositions( \@Set_Of_Impositions );
		if ( $debug and 1 ) {
			$openprint::log->debug("Sets of Maximum Impositions: " . @All_Impositions);
			foreach my $Set ( @All_Impositions ) {
				$openprint::log->debug("Impositions in set: " . @$Set);
				foreach my $I ( @$Set ) {
					$I->display();
				} # end foreach I
			} # end foreach set
		} # end if debug

		$openprint::log->debug(sprintf('Original Sign info: %dx%d*%d,%dout', $SignatureImposition->spread_columns(), $SignatureImposition->spread_rows(), $SignatureImposition->spread_size(), $SignatureImposition->imposition() ) ) if $debug;
	} else {
		@All_Impositions = ( \@Set_Of_Impositions );
	} # end if

	# Foreach equipment, figure out which folds are required.
	foreach my $Equipment ( @my_equipment ) {
		$Breakdown .= '<b>Equipment '.$Equipment->name().':</b><br/>';
		#$openprint::log->debug('2 Equipment '.$Equipment->name()) if $debug;
		if ( $$services{'NoOfflineBindery'} and ( $$sig_specs{'ddmPress'.$qty_index} ne $Equipment->strid() ) ) {
			$Breakdown .= "No Offline bindery and not printing on $$Equipment{name}.<br/>";
			$openprint::log->debug('No Offline Equipment '.$Equipment->name()) if $debug;
			next;
		} # end if
		if ( $Equipment->specification( 'Folding Capable' ) eq 'When PerfectBound' ) {
# Means it's a PerfectBinder, so can only do covers
			if ( $$sig_specs{'Group'} != 1 ) {
				$Breakdown .= 'Perfect Binder can only fold 4pg cover:<br/>';
				next;
			} # end if
		} elsif ( $Equipment->specification( 'Folding Capable' ) eq 'When Stitching' ) {
# Means it's a PerfectBinder, so can only do covers
			if ( $$sig_specs{'Group'} != 1 ) {
				$Breakdown .= 'Stitcher can only fold 4pg cover:<br/>';
				next;
			} # end if
		} # end if
		if ( my $pt = $Equipment->specification('PrintingTypes') ) {
			my $ppt = $Press->specification('Printing Type');
			if ( $ppt and ! sets::isin( $ppt, split(',',$pt ) ) ) {
				$Breakdown .= 'Wrong printing type.<br/>';
				next;
			} # end if
		} # end if

		for ( my $set_index = 0; $set_index < @All_Impositions; $set_index += 1 ) {
			my $Set_Of_Impositions = $All_Impositions[$set_index];
			if ( $$Equipment{id} == $$Press{id} ) {
				next if scalar @$Set_Of_Impositions != 1;
			} # end if
			# At this point, we don't modify the Set_Of_Impositions, we modify the equipment-specific copy of it.
#$openprint::log->debug("Impositions in this set: " . @Impositions );
			my $complete = 1;

			my %folds;
			for ( my $imp_index = 0; $imp_index < @$Set_Of_Impositions; $imp_index += 1 ) {
				my $Imposition = $$Set_Of_Impositions[$imp_index];

				#if ( $debug and 0 ) {
					#$openprint::log->debug("trying: ");
					#$Imposition->display();
				#} # end if

# Each piece of equipment can do different folds.  So we have to calculate what we can do as well.
				if ( $$Equipment{id} == $$Press{id} ) {
# Special case because we can't cut it in the middle of printing.  This case is basically for web presses

					my $Fold = $Equipment->Fold(
							'pages'				=>	$Imposition->pages(),
							'page_columns'		=>	$Imposition->page_columns(),
							'page_rows'			=>	$Imposition->page_rows(),
							'page_width'		=>	$Imposition->page_width(),
							'page_height'		=>	$Imposition->page_height(),
							'spine_direction'	=>	$$Imposition{'image_orientation'},
							'stitching'			=>	($$services{'SaddleStitching'} or $$services{'LoopStitching'}) ? 1 : 0,
							'perfectbind'		=>	$$services{'PerfectBound'} ? 1 : 0,
							'spinepaste'		=>	$$services{'SpinePaste'} ? 1 : 0,
							'gsm'				=>	$Paper->gsm(),
							'imposition'		=>	$$Imposition{'imposition'},
							'calliper'			=>	$Paper->calliper(),
							'printing_type'		=>	$Press->specification('Printing Type'),
							);
					if ( $Fold ) {
						$Fold = $Fold->clone();
						$Fold->Imposition( $Imposition );
						
						push @{$folds{$Imposition->pages().'PageFold-'.$Imposition->imposition().'out'}}, $Fold;
						$openprint::log->debug(sprintf('Found: %dx%d,%dout', $Imposition->page_columns(), $Imposition->page_rows(), $Imposition->imposition() ) ) if $debug;
					} else {
						$Breakdown .= sprintf('Didnt find fold %dx%d %.3fx%.3f %s, %dout %dgsm<br/>', $Imposition->page_columns(), $Imposition->page_rows(), $Imposition->page_width(), $Imposition->page_height(), $Imposition->image_orientation(), $Imposition->imposition(), $Imposition->Paper()->gsm() );
						$openprint::log->debug(sprintf('Didnt find: %dx%d %s,%dout', $Imposition->page_columns(), $Imposition->page_rows(), $Imposition->image_orientation(), $Imposition->imposition() ) ) if $debug;
						%folds = ();
						last;
					} # end if
				} else { # Not the press
# FIgure out the fold.  Because this isn't the press, we have to figure out how it cuts...
					if ( $$sig_specs{'rdbTemplateType'} and $fold_types{$$sig_specs{'rdbTemplateType'}} ) {
#$openprint::log->debug("Templatetype: $$sig_specs{'rdbTemplateType'}") if $debug;
						my $rc = $Equipment->fits( $Imposition->layout_width(), $Imposition->layout_height(), $Imposition->Paper()->calliper() );
#$openprint::log->debug("Trying to fit " . $Imposition->layout_width() . 'x' . $Imposition->layout_height() . ' on ' . $Equipment->strid(). ' ' . $rc );
						if ( $rc ) {
							if ( @my_equipment == 1 ) {
								$Breakdown .= "Doesn't fit: $rc<br/>";
							} # end if
						} else {
							
							my $Fold = $Equipment->Fold(
									'type'				=>	$$sig_specs{'rdbTemplateType'},
									'gsm'				=>	$Paper->gsm(),
									'calliper'			=>	$Paper->calliper(),
									'imposition'		=>	$$Imposition{'imposition'},
									'printing_type'		=>	$Press->specification('Printing Type'),
									);
							if ( $Fold ) {
								# Need to check feed width
								if ( my $max_feed_width = $Equipment->specification('Maximum Feed Width') ) {
									my $width_folds = sprintf('%.0f', ($$sig_specs{'txtWidth'}/$$sig_specs{'txtFinalWidth'})-1 );
									my $height_folds = sprintf('%.0f', ($$sig_specs{'txtHeight'}/$$sig_specs{'txtFinalHeight'}) -1 );
$openprint::log->debug("Has max feed width width: $width_folds height: $height_folds $$sig_specs{'txtWidth'} $$sig_specs{'txtHeight'} $max_feed_width") if $debug;
									if ( ( $width_folds and ! $height_folds ) or ( $width_folds == $Fold->folds() ) ) {
										if ( $$sig_specs{'txtWidth'} >= $max_feed_width ) {
$openprint::log->debug("Fold no good due to max feed width on width.") if $debug;
											$Fold = undef;
										} # end if
									} elsif ( ( $height_folds and ! $width_folds ) or ( $height_folds == $Fold->folds() ) ) {
										if ( $$sig_specs{'txtHeight'} >= $max_feed_width ) {
											$Fold = undef;
$openprint::log->debug("Fold no good due to max feed width on height.") if $debug;
										} # end if
									} # end if
								} # end if has max_feed_width
							} # end if
							if ( $Fold ) {
								$Fold = $Fold->clone();
								$Fold->Imposition( $Imposition );
								push @{$folds{$$sig_specs{'rdbTemplateType'}.'-'.$$Imposition{'imposition'}.'out'}}, $Fold;
								next;
							} elsif ( @my_equipment == 1 ) {
								$Breakdown .= "Can't fold that:<br/>
									type			=>	$$sig_specs{'rdbTemplateType'}<br/>
									gsm				=>	".$Paper->gsm()."<br/>
									calliper		=>	".$Paper->calliper()."<br/>
									imposition		=>	$$Imposition{'imposition'}<br/>";
							} # end if
						} # end if
						$complete = 0;
					} else { # No template, might be a book
						$Imposition->display('Trying: ') if $debug;
						#$openprint::log->debug(sprintf('Trying %dx%d=%dout spreads: %dx%d=%d %sx%s',$Imposition->get('columns','rows','imposition','spread_columns','spread_rows','spreads','image_width','image_height') ).' on ' . $Equipment->name()) if $debug;

# See if it fits
						$_ = $Equipment->fits( $Imposition->layout_width(), $Imposition->layout_height(), $Imposition->Paper()->calliper() );

						if ( ! $_ )  {

							my $Fold = $Equipment->Fold(
									'pages'				=>	$Imposition->pages(),
									'page_columns'		=>	$Imposition->page_columns(),
									'page_rows'			=>	$Imposition->page_rows(),
									'spine_direction'	=>	$$Imposition{'image_orientation'},
									'stitching'			=>	($$services{'SaddleStitching'} or $$services{'LoopStitching'}) ? 1 : 0,
									'perfectbind'		=>	$$services{'PerfectBound'} ? 1 : 0,
									'spinepaste'		=>	$$services{'SpinePaste'} ? 1 : 0,
									'gsm'				=>	$Paper->gsm(),
									'calliper'			=>	$Paper->calliper(),
									'imposition'		=>	$$Imposition{'imposition'},
									'printing_type'		=>	$Press->specification('Printing Type'),
									);
							if ( $Fold ) {
								$Fold = $Fold->clone();
								$Fold->Imposition( $Imposition );

								push @{$folds{$Fold->pages().'PageFold-'.$Imposition->imposition().'out'}}, $Fold;
								$openprint::log->debug(sprintf('Found: %dx%d %s,%dout', $Imposition->page_columns(), $Imposition->page_rows(),$Imposition->image_orientation(), $Imposition->imposition()) ) if $debug;
								next;
							} elsif( @my_equipment == 1 ) {
								$Imposition->display('Didnt find:' ) if $debug;
								$Breakdown .= sprintf('Didnt find: %dx%d %s,%dout<br/>', $Imposition->page_columns(), $Imposition->page_rows(), $Imposition->image_orientation(), $Imposition->imposition() );
							} # end if
						} elsif ( $debug or ( @my_equipment == 1 ) ) {
							$Breakdown .= "Doesn't fit $_.<br/>";
						} # end if

						# If we get here, then we couldn't find the fold
						$complete = 0;
						if ( $set_index < @All_Impositions-1 ) {
							# if we aren't the last set, then do nothing because we assume that this set has already been cut down.
						} elsif ( $Imposition->imposition() > 1 ) {
							my @new_impositions = @$Set_Of_Impositions;
							splice @new_impositions, $imp_index, 1, cut_imposition( $Imposition );
							@new_impositions = compact_impositions( @new_impositions );
							push @All_Impositions, \@new_impositions;
						} elsif ( $Imposition->spreads() > 1 ) {
							my @new_impositions = @$Set_Of_Impositions;
							splice @new_impositions, $imp_index, 1, cut_spreads( $Imposition );
							@new_impositions = compact_impositions( @new_impositions ) if @new_impositions > 2;
							push @All_Impositions, \@new_impositions;
						} # end if
					} # end if template or book

					if ( ! $complete ) {
						%folds = ();
						last;
					} # end if 
				} # end foreach Imposition out of possible Impositions
			} # end if press/who knows
			next if ! %folds;

			if ( $$specs{"chkOverrideFold-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
				# Find out if folds satisfies the overrides
				my $found = 1;
				foreach my $index ( 1 .. 4 ) {
#$openprint::log->debug("OverrideFOld $$sig_specs{'SignatureIndex'}-$qty_index-$index (".$$specs{"FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$index"}.")");
					next if ! $$specs{"FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$index"};
#$openprint::log->debug(qq`Overriden $$specs{"FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} $$specs{"FoldImposition-$$sig_specs{'SignatureIndex'}-$qty_index-$index"}out $$specs{"FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$index"}`);
					$found = 0;
					foreach my $key ( keys %folds ) {
						# already accounted for
						next if $folds{$key}[0]{'found'};
						my ( $fold_type, $imposition ) = $key =~ /(.*)-(\d+)out$/;

						my $qty = 0;
						foreach (@{$folds{$key}}) {
							$qty += $_->Imposition()->quantity();
						} # end foreach

						if ( $$specs{"FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} ne $fold_type ) {
$openprint::log->debug(qq`Wrong type: $$specs{"FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} ne $fold_type`) if $debug;
							next;
						} elsif ( $$specs{"FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} != $qty ) {
$openprint::log->debug(qq`Wrong qty: $$specs{"FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} != $qty`) if $debug;
							next;
						} elsif ( $$specs{"FoldImposition-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} != $imposition ) {
$openprint::log->debug(qq`Wrong imposition: $$specs{"FoldImposition-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} != $imposition`) if $debug;
							next;
						} # end if
						$found = 1 ;
						$folds{$key}[0]{'found'} = 1;

						foreach my $F ( @{$folds{$key}} ) {
#$openprint::log->debug("Overriding FOlds and Angles $$F{folds} $$F{angles}");
							$F->folds( $$specs{"FoldFolds-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} );
							$F->angles( $$specs{"FoldAngles-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} );
						} # end foreach F
					} # end foreach my $k
					if ( ! $found ) {
						$openprint::log->debug("Not found trying generic");
						# Replace with a generic one
						my $key = $$specs{"FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$index"}.'-'.$$specs{"FoldImposition-$$sig_specs{'SignatureIndex'}-$qty_index-$index"}.'out';
						my $Fold;
						my ( $pages ) = $$specs{"FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} =~ /(\d)+Page/;
						if ( $Fold = openprint::Fold::find_one( 
									'imposition'	=>	$$specs{"FoldImposition-$$sig_specs{'SignatureIndex'}-$qty_index-$index"},
									'type'			=>	$$specs{"FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$index"},
									'equipment_id'	=>	$Equipment->id(),
									'pages'			=>	$pages,
									) ) {
						} else {
							$Fold = new openprint::Fold();
							$$Fold{'type'} = $$specs{"FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$index"};
						} # end if
						$$Fold{'Imposition'} = $SignatureImposition->copy();
						if ( $$Fold{'Imposition'}{'imposition'} != $$specs{"FoldImposition-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} ) {
						$$Fold{'Imposition'}->rows(1);
						$$Fold{'Imposition'}->columns( $$specs{"FoldImposition-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} );
						} # end if
						$$Fold{'Imposition'}{'quantity'} = $$specs{"FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$index"};
						$$Fold{'found'} = 1;
			
						$folds{$key} = [ $Fold ];
					} # end if ! found
				} # end foreach index
				foreach my $k ( keys %folds ) {
					delete $folds{$k} if ! $folds{$k}[0]{'found'};
				} 
			} # end if override
			my $totalTime = $Equipment->specification('Station Make Ready') * 60;

			my $totalPrice;
			my $mprice = 0;
if ( $debug ) {
			foreach my $key ( keys %folds ) {
				my $impo_qty = 0;
				foreach (@{$folds{$key}}) {
					$impo_qty += $_->Imposition()->quantity();
				} # end foreach
$openprint::log->debug("Folds: $set_index : $key " . $impo_qty );
			} # end foreach

} # end if

			# Folds is a hash containing all the folds for the signature
			foreach my $key ( keys %folds ) {
				my ( $fold_type, $imposition ) = $key =~ /(.*)-(\d+)out$/;
				last if ! $imposition;

				my $Fold = $folds{$key}[0];
				my $impo_qty = 0;
				foreach (@{$folds{$key}}) {
					$impo_qty += $_->Imposition()->quantity();
				} # end foreach
				my $Imposition = $Fold->Imposition();
				my $run_qty = ( $impo_qty * $$specs{"txtQuantity$qty_index"} )/$SignatureImposition->imposition();

				$run_qty += $Fold->makeready_overs_units() eq 'Percent' ? $run_qty * ( $Fold->makeready_overs() /100 ) : $Fold->makeready_overs();
				$run_qty += $Fold->run_overs_units() eq 'Percent' ? $run_qty * ($Fold->run_overs()/100): $Fold->run_overs();
#$openprint::log->debug("Overs: " . $Fold->makeready_overs() );

				#$openprint::log->debug("Pricing $impo_qty $imposition out of fold $fold_type on " . $Equipment->name()) if $debug;

				my $width_folds;
				my $height_folds;
				if ( $$sig_specs{'txtFinalWidth'} ) {
					$width_folds = sprintf('%.0f', ($$sig_specs{'txtWidth'}/$$sig_specs{'txtFinalWidth'})-1 );
					$height_folds = sprintf('%.0f', ($$sig_specs{'txtHeight'}/$$sig_specs{'txtFinalHeight'}) -1 );
				} else {
					$width_folds = sprintf('%.0f', ($Imposition->image_width()/$Imposition->object_width())-1 );
					$height_folds = sprintf('%.0f', ($Imposition->image_height()/$Imposition->object_height())-1 );
				} # end if
				if ( $Fold->folds() or $Fold->angles() ) {
					if ( $width_folds == $Fold->folds() and $height_folds == $Fold->angles() ) {
					} elsif ( $width_folds == $Fold->angles() and $height_folds == $Fold->folds() ) {
						$width_folds = $Fold->angles();
						$height_folds = $Fold->folds();
					} else {
						$width_folds = $Fold->folds();
						$height_folds = $Fold->angles();
					} # end if
				} else {
					$Fold->folds( $width_folds );
					$Fold->angles( $height_folds );
				} # end if
				my $width = 0;
				if ( $width_folds and $height_folds ) {
					$width = $Imposition->image_width() * $Fold->imposition();
				} elsif ( $width_folds ) {
					if ( $$Imposition{'image_orientation'} eq 'Vertical' ) {
						$width = $Imposition->image_height() * $$Imposition{'rows'};
					} else {
						$width = $Imposition->image_height() * $$Imposition{'columns'};
					} # end if
				} elsif ( $height_folds ) {
					if ( $Imposition->image_orientation() eq 'Vertical' ) {
						$width = $Imposition->image_width() * $$Imposition{'columns'};
					} else {
						$width = $Imposition->image_width() * $$Imposition{'rows'};
					} # end if
				} # end if

				$Breakdown .= sprintf( '%s: %dx%dout layout: %sx%s qty: %d StockWeight %.2fgsm<br/>', $Fold->name(), $impo_qty, $imposition, $Imposition->get('layout_width', 'layout_height'), $run_qty, $Imposition->Paper()->gsm() );

				my %setupPrice = openprint::service::get_price_object( $Fold->type().'MakeReady', $imposition, $Equipment );
				if ( ! %setupPrice ) {
$openprint::log->debug("No MakeReady for " . $Fold->type().'MakeReady' . ' ' . $imposition ) if $debug;
					%setupPrice = openprint::service::get_price_object( 'FoldMakeReady', $imposition, $Equipment );
				} # end if
				$Breakdown .= 'MR: ';
				if ( lc $setupPrice{'units'} eq 'per form' ) {
					$setupPrice{'Total'} = $setupPrice{'Price'};
					$totalPrice += $setupPrice{'Total'};
					$Breakdown .= sprintf( '($%1$.2f%2$s=$%3$.2f)<br/>', @setupPrice{'Price','units','Total'} );
				} elsif ( ! sets::isin( $fold_type, $makereadies{$Equipment->id()} ) ) {
					if ( lc $setupPrice{'units'} eq 'per imposition' ) {
						$setupPrice{'Total'} = $setupPrice{'Price'} * $imposition;
					} else {
						$setupPrice{'Total'} = $setupPrice{'Price'};
					} # end if
					$Breakdown .= sprintf( '($%1$.2f%2$s=$%3$.2f)', @setupPrice{'Price','units','Total'} );
					$totalPrice += $setupPrice{'Total'};

					my %FoldMakeReady = openprint::service::get_price_object( 'FoldingFoldMakeReady', undef, $Equipment );
					if ( $FoldMakeReady{'units'} eq 'Per Fold' ) {
						$FoldMakeReady{'Total'} = $FoldMakeReady{'Price'} * ($width_folds);
						$totalPrice += $FoldMakeReady{'Total'};
					} # end if

					my %AngleMakeReady = openprint::service::get_price_object( 'FoldingAngleMakeReady', undef, $Equipment );
					if ( $AngleMakeReady{'units'} eq 'Per Angle' ) {
						$AngleMakeReady{'Total'} = $AngleMakeReady{'Price'} * ($height_folds);
						$totalPrice += $AngleMakeReady{'Total'};
					} # end if
					$Breakdown .= sprintf( ' + FMR: ($%1$.2f%2$s=$%3$.2f)+ AMR: ($%4$.2f%5$s=$%6$.2f)', @FoldMakeReady{'Price','units','Total'}, @AngleMakeReady{'Price','units','Total'} );
					$Breakdown .= sprintf( ' = $%.2f<br/>', $totalPrice );
				} else {
					$Breakdown .= 'No Makeready<br/>';
				} # end if

				if ( defined $bestPrice and $totalPrice > $bestPrice ) {
#$openprint::log->debug("Already have a better price $bestPrice < $totalPrice");
					last;
				} # end if

# In hours
				my $runspeed = $Fold->runspeed($$Paper{'gsm'});
				my $runTime; 
				if ( ! $runspeed ) {
					$Breakdown .= "No runspeed for $fold_type(".$Fold->name().") on " . $Equipment->name() .'<br/>';
					last;
				} else {
					$runTime = sprintf( '%.4f', $run_qty / $runspeed ); # in hours
					$Breakdown .= sprintf('Runspeed: %d @ %d/HR = %d:%d:%d<br/>', $run_qty, $runspeed, misc::seconds_to_interval( int( 3600*$runTime ) ) );
				} # end if
#$openprint::log->debug("Runspeed: $fold_type(".$Fold->name().") : " . $Equipment->name() . ' ' . $Fold->runspeed() .' ' . $Paper->gsm() );
#$Breakdown .= sprintf( '&nbsp;Folds: QTY: %d, %dout Runspeed: %d/Hr = %.2f hours<br/>', $qty, $imposition, $$RunSpeed{runspeed}, $runTime );
# We are assumin at this point, that all these folds are posible on this equipment, so any errors are soft errors
				my %servicePrice = openprint::service::get_price_object( $Fold->type(), $run_qty, $Equipment );
				if ( ! %servicePrice ) {
					%servicePrice = openprint::service::get_price_object( 'Folding'.$imposition.'up', $run_qty, $Equipment );
				} # end if
				if ( ! %servicePrice ) {
					%servicePrice = openprint::service::get_price_object( 'Folding',$imposition, $Equipment );
				} # end if
				my %AnglePrice = openprint::service::get_price_object( 'FoldingAngle'.$imposition.'up', $run_qty, $Equipment );
				%AnglePrice = openprint::service::get_price_object( 'FoldingAngle', $imposition, $Equipment ) if ! %AnglePrice;

				if ( lc $servicePrice{'units'} eq 'per hour' ) {
					$servicePrice{'Total'} = $servicePrice{'Price'} * $runTime;
					$Breakdown .= sprintf('&nbsp;Run: $%.2f%s * %.2d:%.2d:%.2d = $%.2f<br/>', @servicePrice{'Price','units'}, misc::seconds_to_interval(int $runTime*3600), $servicePrice{'Total'} );
				} elsif ( sets::isin( lc $servicePrice{'units'}, ['per m', 'per 1000'] ) ) {
					# Need adjustment
					my $Adjustment = 1;
					if ( my $Base = $Fold->RunSpeed( 0 ) ) {
						$Adjustment = $$Base{'runspeed'}/$runspeed;
						$servicePrice{'Total'} = $servicePrice{'Price'} * ( $run_qty/1000 ) * ($Adjustment);
	#$openprint::log->debug("Adjusting: Base: " . $$Base{'runspeed'} . ' actual: ' . $runspeed . ' calculated: ' . $Adjustment );
						$Breakdown .= sprintf('&nbsp;Run: $%.2f%s * %d * %d% runspeed adjustment = $%.2f<br/>', @servicePrice{'Price','units'}, $run_qty, $Adjustment*100, $servicePrice{'Total'} );
					} else {
						$servicePrice{'Total'} = $servicePrice{'Price'} * ( $run_qty/1000 ) * $Adjustment;
						$Breakdown .= sprintf('&nbsp;Run: $%.2f%s * %d = $%.2f<br/>', @servicePrice{'Price','units'}, $run_qty, $servicePrice{'Total'} );
					} # end if
				} elsif ( sets::isin( lc $servicePrice{'units'}, ['per inch per m'] ) ) {
					$servicePrice{'Total'} = $servicePrice{'Price'} * $width * $run_qty / 1000;
					if ( $height_folds ) {
						if ( ! %AnglePrice ) {
							%AnglePrice = %servicePrice;
						} # end if
						$AnglePrice{'Total'} = $AnglePrice{'Price'} * $width * $run_qty / 1000;
					} # end if

					$Breakdown .= sprintf('&nbsp;Run: ($%1$.4f%4$s * %4$s&quot;=$%3$.2f) + (%5$.4f%8$s * %4$s&quot;=%7$.2f) = $%8$.2f<br/>', @servicePrice{'Price','units','Total'}, $width, @AnglePrice{'Price','units','Total'}, $servicePrice{'Total'} );
					$servicePrice{'Total'} += $AnglePrice{'Total'};
				} elsif ( sets::isin( lc $servicePrice{'units'}, ['per inch of width per m'] ) ) {
					$servicePrice{'Total'} = $servicePrice{'Price'} * $Imposition->image_width() * $run_qty / 1000;
					if ( $height_folds ) {
						if ( ! %AnglePrice ) {
							%AnglePrice = %servicePrice;
						} # end if
						$AnglePrice{'Total'} = $AnglePrice{'Price'} * $Imposition->image_width() * $run_qty / 1000;
					} # end if

					$Breakdown .= sprintf('Run: ($%3$.4f%4$s * %6$s&quot;=$%5$.2f) + (%7$.4f%8$s * %6$s&quot;=%9$.2f) = $%10$.2f<br/>', undef, $Fold->name(), @servicePrice{'Price','units','Total'}, $Imposition->image_width(), @AnglePrice{'Price','units','Total'}, $servicePrice{'Total'}+$AnglePrice{'Total'} );
					$servicePrice{'Total'} += $AnglePrice{'Total'};
				} elsif ( sets::isin( lc $servicePrice{'units'}, ['per inch per hour'] ) ) {
					$servicePrice{'Total'} = $servicePrice{'Price'} * ( $$sig_specs{'txtWidth'} ) * $runTime;
					$Breakdown .= sprintf('&nbsp;Run: $%.4f%s * %d folds * %s&quot; + %d folds * %s&quot; = $%.2f<br/>',$Fold->name(), @servicePrice{'Price','units'}, $width_folds, $$sig_specs{'txtWidth'}, $height_folds, $$sig_specs{'txtHeight'}, $servicePrice{'Total'} );
				} elsif ( %servicePrice ) {
					$Breakdown .= qq`No Units ($servicePrice{'units'}) given for `.$Fold->name().' on '.$Equipment->name().',<br/>';
					$servicePrice{'Total'} += 1000000;
				} else {
					$Breakdown .= qq`No Price given for `.$Fold->name().' on '.$Equipment->name().',<br/>';
				} # end if

				$mprice += $servicePrice{'Total'};
				$totalPrice += $servicePrice{'Total'};
				
				$totalTime += $runTime * 3600;
				if ( defined $bestPrice and $totalPrice > $bestPrice ) {
					last;
				} # end if
			} # end foreach fold_type

			$Breakdown .= 'Total: $' . sprintf($openprint::config{'ProjectMoneyFormat'}, $totalPrice ) . '<br/><br/>';

			if ( ( $totalPrice < $bestPrice ) or ( ! defined $bestPrice ) ) {
#$openprint::log->debug("Got better prrice $totalPrice < $bestPrice " . $Equipment->name() ) if $debug;
				$bestM = $mprice;
				$bestPrice = $totalPrice;
				$bestEquipment = $Equipment;
				$bestRunTime = int($totalTime);
				$bestFolds = \%folds;
			} # end if

		} # end foreach set of Impositions
		# The idea is that if we find a price on the press, then we are done, cuz nothing else will be better.... 
		last if $bestPrice and ( $Equipment->strid() eq $$sig_specs{'ddmPress'.$qty_index} );
	} # end foreach Equipment

	my %results = (
		'Price'			=> $bestPrice,
		'MPrice'		=> $$specs{'txtQuantity'.$qty_index} ? ($bestM/$$specs{'txtQuantity'.$qty_index})*1000 : 0,
		'Equipment'		=> $bestEquipment,
		'Status'		=> $bestEquipment ? 'calculated' : 'uncalculated',
		'Folds'			=> $bestFolds,
		'Breakdown'		=> $Breakdown,
		);
	my @keys = keys %$bestFolds;

	if ( 1 == @keys ) {
		my ( $fold_type, $imposition ) = $keys[0] =~ /(.*)-(\d+)out$/;
		$results{'Imposition'} = $imposition;
	} # end if

	foreach my $key ( @keys ) {
		my ( $fold_type, $imposition ) = $key =~ /(.*)-(\d+)out$/;
		#next if ! $imposition;
#$openprint::log->debug("$fold_type-Qty-$$sig_specs{'SignatureIndex'}-$qty_index $imposition: " . scalar @{$$bestFolds{$key}} );
		my $Fold = $$bestFolds{$key}[0];

		$results{'MakeReadyTime'} += $Fold->makeready_time();
		if ( $Fold->makeready_overs_units() eq 'Percent' ) {
			$results{'MakeReadyOvers'} += (($$specs{'txtQuantity'.$qty_index}/$imposition)/$SignatureImposition->imposition()) * $Fold->makeready_overs() /100;
		} else {
			$results{'MakeReadyOvers'} += $Fold->makeready_overs();
		} # end if
		#my $RunSpeed = $Fold->Specification( $Paper->gsm() );
		$results{'RunSpeed'} = $Fold->runspeed($$Paper{'gsm'});
#$openprint::log->debug("SettingRunspeed $key : $fold_type : $imposition " . $Fold->name() . ' ' . $Fold->runspeed() );
		$results{'RunOvers'} += $Fold->run_overs();
		$results{'RunOvers'} += (($$specs{'txtQuantity'.$qty_index}/$imposition)/$SignatureImposition->imposition()) * $Fold->run_overs() /100;
	} # end foreach
	
	$$specs{'Status'} = $bestEquipment ? 'calculated' : 'uncalculated';
#$openprint::log->debug("Return from folding");
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
	my $services = $Project->services();
	#my @signature_service_indices = openprint::print::get_signature_indices( $log, $dbh, $project_index );
	if ( ! neccessary( $project_index ) ) {
		$$specs{'alert'} .= 'Folding is not needed.';
	} # end if

	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );

	my $uv_specs = openprint::service::get_specs_ref( $Project, $$services{'UVCoating'}[0] ) if $$services{'UVCoating'};
	my $aq_specs = openprint::service::get_specs_ref( $Project, $$services{'Aqueous'}[0] ) if $$services{'Aqueous'};

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$specs{"txtPrice$qty_index"} =~ s/[^\d\.]//g;
		$$specs{"Markup$qty_index"} =~ s/[^\d\.\-]//g;
		$$specs{"txtQuantity$qty_index"} =~ s/[^\d\.]//g;
		if ( ! $$specs{"txtQuantity$qty_index"} ) {
			$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
			if ( @{$$services{'Folding'}} > 1 ) {
				foreach my $s_id ( @{$$services{'Folding'}} ) {
					next if $s_id >= $service_index;
					my $folding_specs = openprint::service::get_specs_ref( $Project, $s_id );
					$$specs{"txtQuantity$qty_index"} -= $$folding_specs{'txtQuantity'.$qty_index};
				} # end foreach
			} # end if
			@no_outputs = sets::exclude( ['txtQuantity'.$qty_index], \@no_outputs );
		} else {
			@no_outputs = sets::union( 'txtQuantity'.$qty_index, @no_outputs );
		} # end if
		next if ! int $$specs{"txtQuantity$qty_index"};
		$$specs{'hdnBreakdown'.$qty_index} = '';

		my $price;
		my $mprice;

		my $previous_imposition;

		foreach my $signature_service_index ( sort $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
			$$specs{'hdnBreakdown'.$qty_index} .= "<fieldset><legend>Signature: $$sig_specs{SignatureIndex} $$sig_specs{'txtSignatureType'} Ref: $$sig_specs{'txtServiceDescription'}:</legend>";
			$$specs{'hdnBreakdown'.$qty_index} .= openprint::service::summary( $Project, $signature_service_index ) . '<br/>';
			$$specs{'hdnBreakdown'.$qty_index} .= openprint::service::summary( $Project, $signature_service_index, $qty_index ) . '<br/>';

			if ( $$specs{"chkOverrideFold-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
				foreach my $index ( 1 .. 4 ) {
					$$specs{"FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = '';
					$$specs{"FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = 0;
					$$specs{"FoldImposition-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = '';
					$$specs{"FoldColumns-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = '';
					$$specs{"FoldRows-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = '';
					$$specs{"FoldFolds-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = '';
					$$specs{"FoldAngles-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = '';
					$$specs{"FoldRunspeed-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = '';
				} # end for
			} # end if

			$$sig_specs{'PreviousImposition'} = $previous_imposition;

			if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No imposition.<br/>';
				next;
			} # endif

			if ( (! signature_needs( $Project, $sig_specs, $qty_index ) ) and ( $$specs{"chkOverrideFold-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'Not needed.<br/>';
				next;
			} # end if

			if ( ( ! exists $$sig_specs{'PageQuantity'.$qty_index} ) or $$sig_specs{'PageQuantity'.$qty_index} ) {
				my $Imposition = new openprint::Imposition;
				$Imposition->load( $sig_specs, $qty_index );
				my %results = signature_calc( $Project, $signature_service_index, $sig_specs, $specs, $qty_index, $Imposition->Paper(), $Imposition, $uv_specs, $aq_specs );
				$$specs{'hdnBreakdown'.$qty_index} .= $results{'Breakdown'};
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('MR Waste: %d, Run Waste: %d<br/>', @results{'MakeReadyOvers','RunOvers'} );
				$price += $results{'Price'};
				$mprice += $results{'MPrice'};
				if ( $results{'Equipment'} ) {
					if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
						$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = $results{'Equipment'}->id();
					} # end if
					#$$specs{"Imposition-$$sig_specs{SignatureIndex}-$qty_index"} = $results{'Imposition'};
					my $index = 1;
					my $folds = $results{'Folds'};
					foreach my $key ( keys %$folds ) {
						my ( $fold_type, $imposition ) = $key =~ /(.*)-(\d+)out$/;

						if ( ! @{$$folds{$key}} ) {
							$openprint::log->error('wtf ' . $fold_type);
							next;
						} # end if
						my $Fold = $$folds{$key}[0];
						#my $RunSpeed = $Fold->Specification( $Imposition->Paper()->gsm() );

						$openprint::log->debug("Foldtype: $fold_type " . @{$$folds{$key}} . ' ' . $Fold->Imposition()->imposition() . "out $$Fold{name} $$Fold{folds} $$Fold{angles}" ) if $debug;
						$$specs{"FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = $fold_type;
						my $qty = 0;
						foreach (@{$$folds{$key}}) {
							$qty += $_->Imposition()->quantity();
						} # end foreach
						$$specs{"FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = $qty;
						$$specs{"FoldImposition-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = $Fold->Imposition()->imposition();
						$$specs{"FoldColumns-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = $Fold->Imposition()->columns();
						$$specs{"FoldRows-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = $Fold->Imposition()->rows();
						$$specs{"FoldFolds-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = $Fold->folds();
						$$specs{"FoldAngles-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = $Fold->angles();
						$$specs{"FoldRunspeed-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = $Fold->runspeed($Imposition->Paper()->gsm());
						$index += 1;
					} # end foreach

				} else {
					if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
						$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = '';
					} # end if
					$status = 'uncalculated';
$openprint::log->debug("Unable to fold $qty_index $$sig_specs{SignatureIndex}");
				} # end if
				if ( $results{'Status'} eq 'uncalculated' ) {
					$status = 'uncalculated';
				} # end if
				if ( (!$previous_imposition) and ( new openprint::Equipment( $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} )->strid() eq $$sig_specs{'ddmPress'.$qty_index} ) ) {
					$previous_imposition = $$sig_specs{'txtImposition'.$qty_index};
				} # end if
			} # end if has pages
			$$specs{'hdnBreakdown'.$qty_index} .= '</fieldset>';
		} # end foreach signature
		if ( $status eq 'uncalculated' and ! $$specs{'alert'} ) {
			$$specs{'alert'} = 'Unable to fold.';
		} # end if

		if ( $$specs{'OverridePrice'.$qty_index} ne 'Y' ) {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price*(1+$$specs{'Markup'.$qty_index}/100) );
		} else {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{"txtPrice$qty_index"} );
		} # end if
		$$specs{"MPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $mprice );
	} # end foreach qty
	$log->debug(" END FOLDING!!!!!!!!!!!!!!!!!! $status");
	return $$specs{'Status'} = $status;
} # end sub calc

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();
	my @folding_capable = ('Y','When Printing');
	push @folding_capable, 'For Pocket Folders' if $Project->Type()->name() eq 'PresentationFolders';
	push @folding_capable, 'When PerfectBound' if $$services{'PerfectBound'};
	push @folding_capable, 'When Stitching' if ( $$services{'SaddleStitching'} or $$services{'LoopStitching'} );

	my @equipment = openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Folding Capable'=>\@folding_capable}, 'order'=>'lower(strname)' );
	@{$$variable{'EquipmentArray'}} = map { $_->id(), $_->name() } @equipment;
} # end sub display

sub summary {
	return '';
} # end sub summary

sub runtime {
	my ( $p_id, $s_id, $specs, $qty_index ) = @_;
	return 0 if ! $$specs{'ddmEquipment'.$qty_index};
	my $Equipment = new openprint::Equipment($$specs{'ddmEquipment'.$qty_index});

	my $runTime = $Equipment->specification( 'Station Make Ready' ) * 60;
	foreach my $name ( keys %$specs ) {
		if ( $name =~ /^txt(\w*)Qty$/ ) {
			my $type = $1;
			my $quantity = $$specs{$name} * $$specs{'txtQuantity'.$qty_index};
			if ( $quantity > 0 ) {
				my $runSpeed = $Equipment->specification( $type.'RunSpeed' );
				if ( $runSpeed ) {
					$runTime += $quantity * 3600 / $runSpeed; # Convert to seconds
				} # end if
			} # end if
		} # end if
	} # end foreach
	return $runTime;
} # end sub runtime

# The purpose is to cut any Impos > 1 into singletons
sub reduce_impositions {
	my ( $impositions ) = @_;
	my @results = ( $impositions );
	my $max_impo = 1;
	foreach my $i ( @$impositions ) {
		$max_impo = $$i{imposition} if $$i{imposition} > $max_impo;
	} # end foreach

	if ( $max_impo > 1 ) {
		my @new = @$impositions;
		for ( my $i = 0; $i < @new; $i += 1 ) {
			if ( $new[$i]->imposition() == $max_impo ) {
				my $I2 = $new[$i]->copy();
				my $I3 = $new[$i]->copy();
				if ( $I2->columns() > 1 ) {
					$I2->columns( int($I2->columns()/2) );
					$I3->columns( $I3->columns() - $I2->columns() );
				} else {
					$I2->rows( int($I2->rows()/2) );
					$I3->rows( $I3->rows() - $I2->rows() );
				} # end if

				splice @new, $i, 1, ( $I2, $I3 );
				$i += 1;
			} # end if
		} # end foreach I
		@new = compact_impositions( @new );
		push @results, reduce_impositions( \@new );
	} # end if
	return @results;
	
} # end sub reduce_impositions

sub cut_imposition {
	my ( $I ) = @_;
	my ( $i1, $i2 ) = ( $I->copy(), $I->copy );
	if ( ( $$I{spread_size} >= 4 ) and ( $$I{image_orientation} eq 'Horizontal' ) and ( $$I{rows} > 1 ) ) {
		# For folding purposes, can only fold where spines are aligned
		return map { $_ = $I->copy(); $_->rows(1); $_; } ( 1 .. $$I{rows} );
	} elsif ( ( $$I{spread_size} >= 4 ) and ( $$I{image_orientation} eq 'Vertical' ) and ( $$I{columns} > 1 ) ) {
		return map { $_ = $I->copy(); $_->columns(1); $_; } ( 1 .. $$I{columns} );
	} elsif ( $$I{columns} > $$I{rows} ) {
		$i1->columns(int $$I{columns}/2);
		$i2->columns( $$I{columns} - $$i1{columns} );
	} else {
		$i1->rows(int $$I{rows}/2);
		$i2->rows( $$I{rows} - $$i1{rows} );
	} # end if
	$openprint::log->debug(sprintf("Cutting imposition down from %dx%d=%dout to %dx%d=%d and %dx%d=%d", @$I{'columns','rows','imposition'}, @$i1{'columns','rows','imposition'}, @$i2{'columns','rows','imposition'} ) ) if $debug;
	return ( $i1, $i2 );
} # end sub cut_imposition

sub cut_spreads {
	my ( $I ) = @_;
	if ( $I->layout_height() > $I->layout_width() ) {
	#if ( $I->spread_rows() > $I->spread_columns() ) {
		if ( ( $I->spread_rows() > 1 ) and ( $I->spread_rows() % 2 ) ) {
			my $i1 = $I->copy();
			my $i2 = $I->copy();
			$i1->spread_rows(1);
			$i1->image_height( $I->image_height()/$I->spread_rows() );
			$i2->spread_rows( $i2->spread_rows() - 1 );
			$i2->image_height( ($i2->image_height()/($i2->spread_rows()+1))*$i2->spread_rows() );
	$openprint::log->debug(sprintf('Cutting pages down from %d to %d and %d', $I->pages(), $i1->pages(), $i2->pages() ) ) if $debug;
			return ( $i1, $i2 );
		} else {
			my $i1 = $I->copy();
			$i1->spread_rows( $i1->spread_rows()/2 );
			$i1->image_height( $i1->image_height()/2 );
			$i1->quantity( $i1->quantity() * 2 );
	$openprint::log->debug(sprintf('Cutting pages down from %d to %d', $I->pages(), $i1->pages() ) ) if $debug;
			return $i1;
		} # end if
	} else {
		if ( ( $I->spread_columns() > 1 ) and ( $I->spread_columns() % 2 ) ) {
			my $i1 = $I->copy();
			my $i2 = $I->copy();
			$i1->spread_columns(1);
			$i1->image_width( $I->image_width()/$I->spread_columns() );
			$i2->spread_columns( $I->spread_columns() - 1 );
			$i2->image_width( ($I->image_width()/($I->spread_columns()+1))*$I->spread_columns() );
	$openprint::log->debug(sprintf('Cutting pages down from %d to %d and %d', $I->pages(), $i1->pages(), $i2->pages() ) ) if $debug;
			return ( $i1, $i2 );
		} else {
			my $i1 = $I->copy();
			$i1->spread_columns( $i1->spread_columns()/2 );
			$i1->image_width( $i1->image_width()/2 );
			$i1->quantity( $i1->quantity() * 2 );
	$openprint::log->debug(sprintf('Cutting pages down from %d to %d', $I->pages(), $i1->pages() ) ) if $debug;
			return $i1;
		} # end if
	} # end if
} # end cut_spreads

# Takes an array of impositions(Folds) and merges duplicates. 
sub compact_impositions {
	my @results;
	while ( @_ ) {
		my $Imposition = shift @_;
		$Imposition = $Imposition->copy();
		push @results, $Imposition;

		for ( my $index = 0; $index < @_; $index += 1 ) {
			if ( $Imposition->imposition() == $_[$index]->imposition() and $Imposition->spreads() == $_[$index]->spreads() ) {
				$$Imposition{'quantity'} += $_[$index]->quantity();
				splice @_, $index, 1;
				$index -= 1;
			} # end if
		} # end for each index
	} # end while @_
	return @results;
} # end sub compact_impositions
1;

__END__
