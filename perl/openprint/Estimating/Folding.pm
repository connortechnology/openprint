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
		my $sig_specs = openprint::service::get_specs_ref( $p_id, $s_s_id );
		foreach my $qty_index ( 1 .. 3 ) {
			push @v, "chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index";
			push @v, "ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index";
			push @v, "chkOverrideFoldType-$$sig_specs{'SignatureIndex'}-$qty_index";
			push @v, "Imposition-$$sig_specs{'SignatureIndex'}-$qty_index";
			foreach my $fold_index ( 1 .. 4 ) {
				push @v, "FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index";
				push @v, "FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index";
				push @v, "FoldFolds-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index";
				push @v, "FoldAngles-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index";
			} # end foreach
			foreach my $fold_type ( keys %fold_types ) {
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
	'2Panel1Pocket', 'Single Pocket Folder',
	'2Panel2Pocket', '2 Pocket Folder',
	'2Panel2PocketGusset', '2 Pocket Folder w/Gussets',
	'3Panel2Pocket', '3 Panel 2 Pocket Folder',
	'3Panel2PocketGusset', '3 Panel 2 Pocket Folder w/Gussets',
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
		#$openprint::log->warn("FOLDING NEEDED templatetype!") if $debug;
		return 1;
	} # end if

	# This works for books because sigs don't have a txtFinalWidth, etc.
	if ( ($$specs{'txtFinalWidth'} != $$specs{'txtWidth'}) or ($$specs{'txtFinalHeight'} != $$specs{'txtHeight'}) ) {
		#$openprint::log->warn("FOLDING NEEDED dimensions do not match!") if $debug;
		return 1;
	} # end if
	return 0;
} # end sub signature_needs

# A function that is smart enough to return true if the project needs folding, and false if it doesn't.
sub neccessary {
	my ( $project_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services( );

	if ( $$services{'NoBindery'} ) {
		$openprint::log->debug(" ** Project is marked as No bindery, Folding not needed ! ** ");
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
	$openprint::log->debug("FOLDING NOT NEEDED!");
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
	if ( ( defined $Equipment->specification($foldtype.'MaximumImposition') and $Equipment->specification($foldtype.'MaximumImposition') > $Imposition->imposition() ) ) {
		$openprint::log->debug('No fold due to max impo ' . $Imposition->imposition() . '>' . $Equipment->specification($foldtype.'MaximumImposition' ) ) if $debug;
		return @imps;
	} 
	if ( ( defined $Equipment->specification($foldtype.'MaximumColumns') and $Equipment->specification($foldtype.'MaximumColumns') > $Imposition->columns() ) ) {
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
			my $space = $Equipment->specification($foldtype.'MinimumWidth') - $I->image_width();
			$I->cropmark_left(0) if $space >= $I->cropmark_left();
			$I->cropmark_right(0) if $space >= $I->cropmark_right();
			$I->gutters(0) if $space >= $I->gutters();
			$I->image_width( $Equipment->specification($foldtype.'MinimumWidth') );
		} else {
			my $space = $Equipment->specification($foldtype.'MinimumWidth') - $I->image_height();
			$I->cropmark_left(0) if $space >= $I->cropmark_left();
			$I->cropmark_right(0) if $space >= $I->cropmark_right();
			$I->gutters(0) if $space >= $I->gutters();
			$I->image_height( $Equipment->specification($foldtype.'MinimumWidth') );
		} # end if

		return @imps if ( $I->paper()->start_width() and $I->paper()->start_width() < $I->used_width() );
		$I->paper()->width( $I->used_width() ) if ! $I->paper()->start_width();
		push @imps, $I;
	} # end if
	return @imps;

} # end sub impositions

sub signature_calc {
	my ( $Project, $signature_service_index, $sig_specs, $specs, $qty_index, $Paper, $Imposition, $uv_specs, $aq_specs ) = @_;

	# First step, find out if we are stitching, then find out which equipment is being used for stitching
	my $services = $Project->services();

	$$specs{"txtQuantity$qty_index"} = int $$specs{"txtQuantity$qty_index"};
	$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
	if ( $$specs{'txtPressSheetComboItems'} ) {
		$$specs{"txtQuantity$qty_index"} *= $$specs{'txtPressSheetComboItems'};
	} # end if

	if ( ! $Imposition ) {
$openprint::log->debug("Loading imposition");
		$Imposition = new openprint::Imposition;
		$Imposition->paper( $Paper );
		$Imposition->load( $sig_specs, $qty_index );
	} # end if

	my $bestPrice;
	my $bestRunPrice = 0;
	my $bestRunTime = 0;
	my $bestSetupPrice = 0;
	my $bestEquipment;
	my $bestFolds;
	
	my @my_equipment;

	if ( $$specs{"chkOverrideEquipment-$$sig_specs{SignatureIndex}-$qty_index"} eq 'Y' ) {
		$openprint::log->debug("Overriding Folding Equipment for sig $$sig_specs{'SignatureIndex'} to " . $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"});
		if ( $$specs{"ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index"} ) {
			push @my_equipment, new openprint::Equipment( $$specs{"ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index"} );
		} else {
			$openprint::log->warn("Folding Equipment override to nothing");
		} # end if
		push @no_outputs, "ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index";
	} else {
		@my_equipment = openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Folding Capable'=>'Y'} );

		if ( $$services{'PerfectBound'} ) {
#$openprint::log->debug('Adding Perfect Bound' . join(',', map { $_->name() } openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Folding Capable'=>'When PerfectBound'}, 'order'=>'lower(strname)' ) ) );
			push @my_equipment, openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Folding Capable'=>'When PerfectBound'} );
		} # end if
		if ( $$services{'SaddleStitching'} or $$services{'LoopStitching'} ) {
			push @my_equipment, openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Folding Capable'=>'When Stitching'} );
		} # end if

		if ( my @Press = openprint::Equipment::find( 'strid'=>$$sig_specs{'ddmPress'.$qty_index} ) ) {
			my $Press = shift @Press;
			my $add = 1;
			if ( $Press->specification('Folding Capable') ) {

				if ( $$services{'UVCoating'} ) {
					$uv_specs = openprint::service::get_specs_ref( $Project, $$services{'UVCoating'}[0] ) if ! $uv_specs;
					if ( $$uv_specs{"ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index"} != $Press->id() ) {
						$add = 0;
					} # end if
				} # end if
				if ( $$services{'Aqueous'} ) {
					$aq_specs = openprint::service::get_specs_ref( $Project, $$services{'Aqueous'}[0] ) if ! $aq_specs;
					if ( $$aq_specs{"ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index"} != $Press->id() ) {
						$add = 0;
					} # end if
				} # end if
				if ( $add ) {
					if ( $Press->specification('Sheeter') ne 'Y' ) {
						@my_equipment = ( $Press );
					} else {
						unshift @my_equipment, $Press;
					} # end if
				} # end if
			} # end if
		} # end if
	} # end if

	# If the stitching is happening on a piece of equipment that can't handle large signatures, then we need to cut them down instead of folding them.
	# Something like a duplo can do 4pg signatures only, so the cutting service will cut everything down, and we will show the 4pg sigs being folded on the duplo

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
		$$specs{'hdnBreakdown'.$qty_index} .= '<b>Equipment '.$Equipment->name().':</b><br/>';
		#$openprint::log->debug('Equipment '.$Equipment->name());

# Each piece of equipment can do different folds.  So we have to calculate what we can do as well.
		if ( $$specs{"chkOverrideFoldType-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
$openprint::log->debug("OVerriding Fold Types") if $debug;
			foreach my $index ( 1 .. 4 ) {
				$$specs{"FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} =~ s/\D//g;
				$$specs{"FoldFolds-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} =~ s/\D//g;
				$$specs{"FoldAngles-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} =~ s/\D//g;
				my $type = $$specs{"FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$index"};
				next if ! ( $type and $$specs{"FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} );

				my $Fold;
				if ( $type =~ /^(\d*)PageFold$/ ) {
					#next if $1 != $pages;
					$Fold = $Equipment->Fold(
							'pages'				=>	$pages,
							'page_columns'		=>	$Imposition->page_columns(),
							'page_rows'			=>	$Imposition->page_rows(),
							'spine_direction'	=>	$Imposition->image_orientation(),
							'stitching'			=>	($$services{'SaddleStitching'} or $$services{'LoopStitching'}) ? 1 : 0,
							'perfectbind'		=>	$$services{'PerfectBound'} ? 1 : 0,
							'spinepaste'		=>	$$services{'SpinePaste'} ? 1 : 0,
							'gsm'				=>	$Imposition->Paper()->gsm(),
							'calliper'			=>	$Imposition->Paper()->calliper(),
							);
				} else {
					$Fold = $Equipment->Fold(
							'type'				=>	$type,
							'gsm'				=>	$Imposition->Paper()->gsm(),
							'calliper'			=>	$Imposition->Paper()->calliper(),
							);
				} # end if
				if ( $Fold ) {
					if ( $$specs{"FoldFolds-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} or $$specs{"FoldAngles-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} ) {
						$Fold->folds( $$specs{"FoldFolds-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} );
						$Fold->angles( $$specs{"FoldAngles-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} );
					} # end if
					foreach $_ ( 1 .. $$specs{"FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} ) {
						push @{$folds{$Fold->type()}}, $Fold;
					} # end foreach
				} # end if Fold
			} # end foreach fold type
		} elsif ( $Equipment->strid() eq $$sig_specs{'ddmPress'.$qty_index} ) {
# Special case because we can't cut it in the middle of printing.  This case is basically for web presses

			my $Fold = $Equipment->Fold(
					'pages'				=>	$pages,
					'page_columns'		=>	$Imposition->page_columns(),
					'page_rows'			=>	$Imposition->page_rows(),
					'page_width'		=>	$Imposition->page_width(),
					'page_height'		=>	$Imposition->page_height(),
					'spine_direction'	=>	$Imposition->image_orientation(),
					'stitching'			=>	($$services{'SaddleStitching'} or $$services{'LoopStitching'}) ? 1 : 0,
					'perfectbind'		=>	$$services{'PerfectBound'} ? 1 : 0,
					'spinepaste'		=>	$$services{'SpinePaste'} ? 1 : 0,
					'gsm'				=>	$Imposition->Paper()->gsm(),
					'imposition'		=>	$Imposition->imposition(),
					'calliper'			=>	$Imposition->Paper()->calliper(),
					);
			if ( $Fold ) {
				push @{$folds{$pages.'PageFold'}}, $Fold;
$openprint::log->debug(sprintf('Found: %dx%d,%dout Max %dout', $Imposition->page_columns(), $Imposition->page_rows(), $Imposition->imposition(), $imposition ) ) if $debug;
			} else {
				$$specs{'hdnBreakdown'.$qty_index} .= 'Didnt find fold<br/>';
	$openprint::log->debug(sprintf('Didnt find: %dx%d %s,%dout Max %dout', $Imposition->page_columns(), $Imposition->page_rows(), $Imposition->image_orientation(), $Imposition->imposition(), $imposition ) ) if $debug;
				next;
			} # end if
		} else { # Not overriden, and not a press
#$openprint::log->debug("Not overriden not a press");

			# FIgure out the fold.  Because this isn't the press, we have to figure out how it cuts...
			if ( $$sig_specs{'rdbTemplateType'} and $fold_types{$$sig_specs{'rdbTemplateType'}} ) {
#$openprint::log->debug("Templatetype: $$sig_specs{'rdbTemplateType'}");
				$_ = $Equipment->fits( $Imposition->image_width(), $Imposition->image_height() );
				if ( $_ ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "Doesn't fit: $_<br/>";
				} else {
					my $Fold = $Equipment->Fold(
							'type'				=>	$$sig_specs{'rdbTemplateType'},
							'gsm'				=>	$Imposition->Paper()->gsm(),
							'calliper'			=>	$Imposition->Paper()->calliper(),
							);
					if ( $Fold ) {
						push @{$folds{$$sig_specs{'rdbTemplateType'}}}, $Fold;
					} else {
						$$specs{'hdnBreakdown'.$qty_index} .= "Can't fold that:<br/>";
					} # end if
				} # end if

			} else {
				# A book
$openprint::log->debug("Starting spreads:" . $Imposition->spreads() . ' on ' . $Equipment->name()) if $debug;
				if ( $Equipment->specification( 'Folding Capable' ) eq 'When PerfectBound' ) {
					# Means it's a PerfectBinder, so can only do covers
					if ( $$sig_specs{'txtSignatureType'} ne 'Cover Pages' ) {
						$$specs{'hdnBreakdown'.$qty_index} .= "Perfect Binder can only fold 4pg cover:<br/>";
						next;
					} # end if
				} elsif ( $Equipment->specification( 'Folding Capable' ) eq 'When Stitching' ) {
					# Means it's a PerfectBinder, so can only do covers
					if ( $$sig_specs{'txtSignatureType'} ne 'Cover Pages' ) {
						$$specs{'hdnBreakdown'.$qty_index} .= "Stitcher can only fold 4pg cover:<br/>";
						next;
					} # end if
				} # end if

				my @folds = ( $Imposition->copy() );
				my @good_folds;
				while ( @folds ) {
					my $I = shift @folds;
					last if ! $I->spreads();
					$openprint::log->debug("Trying spreads:" . $Imposition->spreads() . ' ' . join('x',$I->image_width(), $I->image_height()).' on ' . $Equipment->name()) if $debug;

# See if it fits
					$_ = $Equipment->fits( $I->image_orientation() eq 'Vertical' ? ( $I->image_width(), $I->image_height() * $imposition ) : ( $I->image_width() * $imposition, $I->image_height() ) );

					if ( ! $_ )  {

						my $Fold = $Equipment->Fold(
								'pages'				=>	$pages,
								'page_columns'		=>	$Imposition->page_columns(),
								'page_rows'			=>	$Imposition->page_rows(),
								'spine_direction'	=>	$Imposition->image_orientation(),
								'stitching'			=>	($$services{'SaddleStitching'} or $$services{'LoopStitching'}) ? 1 : 0,
								'perfectbind'		=>	$$services{'PerfectBound'} ? 1 : 0,
								'spinepaste'		=>	$$services{'SpinePaste'} ? 1 : 0,
								'gsm'				=>	$Imposition->Paper()->gsm(),
								'calliper'			=>	$Imposition->Paper()->calliper(),
								);
						if ( $Fold ) {
							push @good_folds, $Fold;
							$openprint::log->debug(sprintf('Found: %dx%d %s,%dout Max %dout', $I->page_columns(), $I->page_rows(),$I->image_orientation(), $I->imposition(), $imposition ) ) if $debug;
							next;
						} else {
							$openprint::log->debug(sprintf('Didnt find: %dx%d %s,%dout Max %dout', $I->page_columns(), $I->page_rows(), $I->image_orientation(), $I->imposition(), $imposition ) ) if $debug;
						} # end if
					} elsif ( @my_equipment == 1 ) {
						$$specs{'hdnBreakdown'.$qty_index} .= "Doesn't fit $_.<br/>";
					} # end if

					# This tells us whether it's a book or not
					last if ! $$sig_specs{'PageQuantity'.$qty_index};

# If we have to cut it down
					if ( $I->spread_rows() > $I->spread_columns() ) {
						if ( $I->spread_rows() % 2 ) {
							my $i2 = $I->copy();
							$i2->spread_rows(1);
							$i2->image_height( $I->image_height()/$I->spread_rows() );

							push @folds, $i2;
							$I->spread_rows( $I->spread_rows() - 1 );
							$I->image_height( ($I->image_height()/($I->spread_rows()+1))*$I->spread_rows() );
							push @folds, $I;
						} else {
							$I->spread_rows( $I->spread_rows()/2 );
							$I->image_height( $I->image_height() /2 );
							push @folds, $I;
							my $i2 = $I->copy();
							push @folds, $i2;
						} # end if
					} else {
						if ( $I->spread_columns() % 2 ) {
							my $i2 = $I->copy();
							$i2->spread_columns(1);
							$i2->image_width( $I->image_width()/$I->spread_columns() );
							push @folds, $i2;
							$I->spread_columns( $I->spread_columns() - 1 );
							$I->image_width( ($I->image_width()/($I->spread_columns()+1))*$I->spread_columns() );
							push @folds, $I;
						} else {
							$I->spread_columns( $I->spread_columns()/2 );
							$I->image_width( $I->image_width()/2 );
							push @folds, $I;
							push @folds, $I->copy();
						} # end if
					} # end if
				} # end while spreads

				if ( @folds ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "Unable to fold all pages.<br/>";
					next;
				} else {
					foreach my $F ( @good_folds ) {
#$openprint::log->debug('Got fold ' . $F->pages() );
						push @{$folds{$F->pages().'PageFold'}}, $F;
					} # end foreach
				} # end if able to fold all
			} # end if
		} # end if

		next if ! %folds;
		my $totalTime = $Equipment->specification('Station Make Ready') * 60;

		my $totalPrice;
		foreach my $fold_type ( keys %folds ) {

			foreach my $Fold ( @{$folds{$fold_type}} ) {
		
				$openprint::log->debug("Pricing fold $fold_type on " . $Equipment->name()) if $debug;

				my $width = $Imposition->image_width();
				my $width_folds;
				my $height_folds;
				if ( $$sig_specs{'txtFinalWidth'} ) {
					$width_folds = sprintf('%.0f', ($$sig_specs{'txtWidth'}/$$sig_specs{'txtFinalWidth'} )-1 );
					$height_folds = sprintf('%.0f', ($$sig_specs{'txtHeight'}/$$sig_specs{'txtFinalHeight'}) -1 );
				} else {
					$width_folds = sprintf('%.0f', ($Imposition->image_width() / $Imposition->object_width())-1 );
					$height_folds = sprintf('%.0f', ($Imposition->image_height()/$Imposition->object_height()) -1 );
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
				} # end if

				my %setupPrice = openprint::service::get_price_object( $Fold->type().'MakeReady', $imposition, $Equipment );
				if ( ! %setupPrice ) {
					%setupPrice = openprint::service::get_price_object( 'FoldMakeReady', $imposition, $Equipment );
				} # end if
				if ( $setupPrice{'units'} eq 'Per Form' ) {
					$setupPrice{'Total'} = $setupPrice{'Price'};
				} elsif ( $setupPrice{'units'} eq 'Per Imposition' ) {
					$setupPrice{'Total'} = $setupPrice{'Price'} * $imposition;
				} elsif ( ! sets::isin( $fold_type, $makereadies{$Equipment->id()} ) ) {
					$setupPrice{'Total'} = $setupPrice{'Price'};
				} # end if
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
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf( 'MR: ($%1$.2f%2$s=$%3$.2f) + FMR: ($%4$.2f%5$s=$%6$.2f)+ AMR: ($%7$.2f%8$s=$%9$.2f) = $%10$.2f<br/>', @setupPrice{'Price','units','Total'}, @FoldMakeReady{'Price','units','Total'}, @AngleMakeReady{'Price','units','Total'}, $totalPrice );

				if ( defined $bestPrice and $totalPrice > $bestPrice ) {
#$openprint::log->debug("Already have a better price $bestPrice < $totalPrice");
					last;
				} # end if

				# In hours
				my $RunSpeed = $Fold->Specification( $Imposition->Paper()->gsm() );
				if ( ! ( $RunSpeed and $$RunSpeed{'runspeed'} ) ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "No runspeed for $fold_type on " . $Equipment->name() .'<br/>';
					last;
				} # end if

				my $runTime = sprintf( '%.4f', ($$specs{"txtQuantity$qty_index"}/$imposition) / $$RunSpeed{'runspeed'} );
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf( 'Folds: %d, QTY: %d, %dout Runspeed: %d/Hr = %.2f hours<br/>', scalar @{$folds{$fold_type}}, $$specs{'txtQuantity'.$qty_index}, $imposition, $$RunSpeed{runspeed}, $runTime );
# We are assumin at this point, that all these folds are posible on this equipment, so any errors are soft errors
				my %servicePrice = openprint::service::get_price_object( $Fold->type(), scalar @{$folds{$fold_type}} * $$specs{"txtQuantity$qty_index"}/$imposition, $Equipment );
				if ( ! %servicePrice ) {
					%servicePrice = openprint::service::get_price_object( 'Folding', $imposition, $Equipment );
				} # end if
				my %AnglePrice = openprint::service::get_price_object( 'FoldingAngle', $height_folds, $Equipment );

				if ( lc $servicePrice{'units'} eq 'per hour' ) {
					$servicePrice{'Total'} = $servicePrice{'Price'} * $runTime * scalar @{$folds{$fold_type}};
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('%d %s: Run: $%.2f%s * %.2d:%.2d:%.2d = $%.2f<br/>', scalar @{$folds{$fold_type}}, $Fold->name(), @servicePrice{'Price','units'}, misc::seconds_to_interval(int $runTime*3600), $servicePrice{'Total'} );
				} elsif ( sets::isin( lc $servicePrice{'units'}, ['per m', 'per 1000'] ) ) {
					$servicePrice{'Total'} = $servicePrice{'Price'} * ( scalar @{$folds{$fold_type}}*($$specs{"txtQuantity$qty_index"}/$imposition) / 1000 );
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('%d %s: Run: $%.2f%s * %d = $%.2f<br/>', scalar @{$folds{$fold_type}}, $Fold->name(), @servicePrice{'Price','units'}, @{$folds{$fold_type}}*$$specs{"txtQuantity$qty_index"}, $servicePrice{'Total'} );
				} elsif ( sets::isin( lc $servicePrice{'units'}, ['per inch per m'] ) ) {
					$servicePrice{'Total'} = $servicePrice{'Price'} * $width * $$specs{"txtQuantity$qty_index"} / 1000;
					if ( $height_folds ) {
						if ( ! %AnglePrice ) {
							%AnglePrice = %servicePrice;
						} # end if
						$AnglePrice{'Total'} = $AnglePrice{'Price'} * $width * $$specs{"txtQuantity$qty_index"} / 1000;
					} # end if
					
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('%1$d %2$s: Run: ($%3$.4f%4$s * %6$s&quot;=$%5$.2f) + (%7$.4f%8$s * %6$s&quot;=%9$.2f) = $%10$.2f<br/>', scalar @{$folds{$fold_type}}, $Fold->name(), @servicePrice{'Price','units','Total'}, $width, @AnglePrice{'Price','units','Total'}, $servicePrice{'Total'} );
					$servicePrice{'Total'} += $AnglePrice{'Total'};
				} elsif ( sets::isin( lc $servicePrice{'units'}, ['per inch per hour'] ) ) {
					$servicePrice{'Total'} = $servicePrice{'Price'} * ( $$sig_specs{'txtWidth'} ) * $runTime;
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('%d %s: Run: $%.4f%s * %d folds * %s&quot; + %d folds * %s&quot; = $%.2f<br/>', scalar @{$folds{$fold_type}}, $Fold->name(), @servicePrice{'Price','units'}, $width_folds, $$sig_specs{'txtWidth'}, $height_folds, $$sig_specs{'txtHeight'}, $servicePrice{'Total'} );
				} else {
				
					$$specs{'hdnBreakdown'.$qty_index} .= qq`No Units ($servicePrice{'units'}) given for `.$Fold->name().' on '.$Equipment->name().',<br/>';
					next;
				} # end if

				$totalPrice += $servicePrice{'Total'};
				$totalTime += $runTime * 3600;
				if ( defined $bestPrice and $totalPrice > $bestPrice ) {
					last;
				} # end if
			} # end foreach fold
		} # end foreach fold_type

		$$specs{'hdnBreakdown'.$qty_index} .= 'Total: ' . sprintf($openprint::config{'ProjectMoneyFormat'}, $totalPrice ) . '<br/>';

		if ( ( $totalPrice < $bestPrice ) or ( ! defined $bestPrice ) ) {
			$bestPrice = $totalPrice;
			$bestEquipment = $Equipment;
			$bestRunTime = int($totalTime);
			$bestFolds = \%folds;
		} # end if

		# Dunno about this last line, the idea is that if we find a price on the press, then we are done, cuz nothing else will be better.... 
		last if $totalPrice and ( $Equipment->strid() eq $$sig_specs{'ddmPress'.$qty_index} );
	} # end foreach Equipment

	my %results = (
		'Price'			=> $bestPrice,
		'MPrice'		=> $$specs{'txtQuantity'.$qty_index} ? ($bestPrice/$$specs{'txtQuantity'.$qty_index})*1000 : 0,
		'Equipment'		=> $bestEquipment,
		'Imposition'	=> $imposition,
		'Status'		=> $bestEquipment ? 'calculated' : 'uncalculated',
		'Folds'			=> $bestFolds,
		);

	foreach my $fold_type ( keys %$bestFolds ) {
#$openprint::log->debug("$fold_type-Qty-$$sig_specs{'SignatureIndex'}-$qty_index : " . scalar @{$$bestFolds{$fold_type}} );
		foreach my $Fold ( @{$$bestFolds{$fold_type}} ) {
			$results{'MakeReadyTime'} += $Fold->makeready_time();
			if ( $Fold->makeready_overs_units() eq 'Percent' ) {
				$results{'MakeReadyOvers'} += (($$specs{'txtQuantity'.$qty_index}/$imposition)/$Imposition->imposition()) * $Fold->makeready_overs() /100;
			} else {
				$results{'MakeReadyOvers'} += $Fold->makeready_overs();
			} # end if
			my $RunSpeed = $Fold->Specification( $Imposition->Paper()->gsm() );
			$results{'RunSpeed'} = $$RunSpeed{'runspeed'};
			$results{'RunOvers'} += $Fold->run_overs();
			$results{'RunOvers'} += (($$specs{'txtQuantity'.$qty_index}/$imposition)/$Imposition->imposition()) * $Fold->run_overs() /100;
		} # end foreach Fold
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

	foreach my $qty_index ( 1 .. 3 ) {
		$$specs{"txtPrice$qty_index"} =~ s/[^\d\.]//g;
		$$specs{"Markup$qty_index"} =~ s/[^\d\.\-]//g;
		$$specs{"txtQuantity$qty_index"} =~ s/[^\d\.]//g;
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		next if ! int $$specs{"txtQuantity$qty_index"};
		$$specs{'hdnBreakdown'.$qty_index} = '';

		my $price;
		my $mprice;

		foreach my $signature_service_index ( sort $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
			if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No imposition.<br/>';
				next;
			} # endif

			next if (! signature_needs( $sig_specs ) ) 
				and ( $$sig_specs{"chkOverrideFoldType-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' );

			if ( ( ! exists $$sig_specs{'PageQuantity'.$qty_index} ) or $$sig_specs{'PageQuantity'.$qty_index} ) {
				$$specs{'hdnBreakdown'.$qty_index} .= "<fieldset><legend>Signature: $$sig_specs{SignatureIndex} $$sig_specs{'txtServiceDescription'}:</legend>";
				$$specs{'hdnBreakdown'.$qty_index} .= openprint::service::summary( $Project, $signature_service_index, $qty_index ) . '<br/>';
				my %results = signature_calc( $Project, $signature_service_index, $sig_specs, $specs, $qty_index, undef, undef, $uv_specs, $aq_specs );

				$price += $results{'Price'};
				$mprice += $results{'MPrice'};
				if ( $results{'Equipment'} ) {
					if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
						$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = $results{'Equipment'}->id();
					} # end if
					$$specs{"Imposition-$$sig_specs{SignatureIndex}-$qty_index"} = $results{'Imposition'};
					my $index = 1;
					my $folds = $results{'Folds'};
					foreach my $fold_type ( keys %$folds ) {

						my $Fold = $$folds{$fold_type}[0];

				$openprint::log->debug("Foldtype: $fold_type $$folds{$fold_type} $$Fold{name} $$Fold{folds} $$Fold{angles}" ) if $debug;
						$$specs{"FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = $fold_type;
						$$specs{"FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = scalar @{$$folds{$fold_type}};
						$$specs{"FoldFolds-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = $$folds{$fold_type}[0]->folds();
						$$specs{"FoldAngles-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = $$folds{$fold_type}[0]->angles();
				#$openprint::log->debug("$fold_type-Qty-$$sig_specs{'SignatureIndex'}-$qty_index : " . scalar @{$$bestFolds{$fold_type}} );
						$index += 1;
					} # end foreach
					for ( ; $index <= 4; $index += 1 ) {
						$$specs{"FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = '';
						$$specs{"FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = 0;
						$$specs{"FoldFolds-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = '';
						$$specs{"FoldAngles-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} = '';
					} # end for

				} else {
					if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
						$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = '';
					} # end if
					$status = 'uncalculated';
				} # end if
				if ( $results{'Status'} eq 'uncalculated' ) {
					$status = 'uncalculated';
				} # end if
				$$specs{'hdnBreakdown'.$qty_index} .= '</fieldset>';
			}# # end if
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

	my @equipment = openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Folding Capable'=>'Y'}, 'order'=>'lower(strname)' );
	push @equipment, openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Folding Capable'=>'When Printing'}, 'order'=>'lower(strname)' );
	if ( $$services{'PerfectBound'} ) {
		push @equipment, openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Folding Capable'=>'When PerfectBound'}, 'order'=>'lower(strname)' );
	} # end if
	if ( $$services{'SaddleStitching'} or $$services{'LoopStitching'} ) {
		push @equipment, openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Folding Capable'=>'When Stitching'}, 'order'=>'lower(strname)' );
	} # end if
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

1;

__END__
