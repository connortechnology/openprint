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

package openprint::Estimating::Folding;
use strict;

require POSIX;
require Math::Round;
require openprint::Project;
require openprint::service;

use vars qw( @folds %fold_types );

use constant DEBUG => 0;
use constant DEBUG_NEEDS => 0;

my @equipment;
my @stitchers;

my @variables = (
	'OverridePrice1', 'OverridePrice2', 'OverridePrice3',
	'txtPrice1', 'txtPrice2', 'txtPrice3',
	'Markup1', 'Markup2', 'Markup3',
	'MPrice1', 'MPrice2', 'MPrice3',
	'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
	'txtRunTime1', 'txtRunTime2', 'txtRunTime3',
	'alert',
	);

sub variables {
	my @v = @variables;
	my ( $p_id, $s_id, $specs ) = @_;

	my $Project = new openprint::Project( $p_id );
	foreach my $s_s_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $s_s_id );
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			push @v, (
					"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index",
					"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index",
					"chkOverrideFold-$$sig_specs{'SignatureIndex'}-$qty_index",
					"Price-$$sig_specs{'SignatureIndex'}-$qty_index",
					);
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
sub outputs {
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

	if ( $Project->Type()->name() eq 'Banners' ) {
		$openprint::log->debug("Folding::signature_needs: is a banner") if DEBUG_NEEDS;
		return 0;
	} # end if
		
	my $services = $Project->services();
	if ( $$services{'NoBindery'} ) {
		$openprint::log->debug("Folding::signature_needs: NoBidner") if DEBUG_NEEDS;
		return 0;
	} # end if
	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] ) if $$services{''}[0] and @{$$services{''}};
	if ( $$services{'CornerStitching'} ) {
		$openprint::log->debug("Folding::signature_needs: CornerStitched") if DEBUG_NEEDS;
		return 0;
	} # end if
	if ( $$services{'SaddleStitching'} ) {
		$openprint::log->debug("Folding::signature_needs: Stitched") if DEBUG_NEEDS;
		return 1;
	} # end if
	if ( ($$specs{'pages_supplied'} eq 'Y') and ($$specs{'supplied_format'} eq 'Folded') ) {
		$openprint::log->debug("Folding::signature_needs: supplied pages already folded") if DEBUG_NEEDS;
		return 0;
	} # end if

	if ( $$services{''} ) {
		my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );
		if ( $$printing_specs{rdbTemplateType} eq 'Unbound' ) {
			$openprint::log->debug("Folding::signature_needs: Unbound") if DEBUG_NEEDS;
			return 0;
		} # end if
	} # end if

	if ( $fold_types{$$specs{'rdbTemplateType'}} ) {
		$openprint::log->warn("FOLDING NEEDED got templatetype!") if DEBUG_NEEDS;
		return 1;
	} else {
		$openprint::log->warn("FOLDING NEEDED $$specs{'rdbTemplateType'} $fold_types{$$specs{'rdbTemplateType'}}!") if DEBUG_NEEDS;
	} # end if


	if ( $$specs{'txtSignatureType'} ) {
		if ( $$specs{'txtSpreadSize'} == 1 ) {
			$openprint::log->warn("Folding not needed: spreadsize==1: $$specs{'txtSpreadSize'}") if DEBUG_NEEDS;
			return 0;
		} # end if
		if ( $qty_index ) {
			if ( ( $$specs{'PageQuantity'.$qty_index} == 0 ) or ( $$specs{'PageQuantity'.$qty_index} == 2 ) ) {
				$openprint::log->warn("Folding not needed: PageQuantity: $$specs{'PageQuantity'.$qty_index}") if DEBUG_NEEDS;
				return 0;
			} # end if	
			if ( $$printing_specs{rdbTemplateType} eq 'PlasticCoil' ) {
				# Need singltons... anything < 8pg sigs...might as well just cut them out
				if ( $$specs{'PageQuantity'.$qty_index} < 8 ) {
					return 0
				} # end if
			} # end if	
		} else {
			foreach my $qty_index ( $Project->quantity_indexes() ) {
				if ( $$specs{'PageQuantity'.$qty_index} == 2 ) {
					$openprint::log->warn("Folding not needed: PageQuantity: $$specs{'PageQuantity'.$qty_index}") if DEBUG_NEEDS;
					return 0;
				} # end if	
			} # end foreah qty_index
		} # end if
		
		$openprint::log->debug("Folding::signature_needs: book sig return 1") if DEBUG_NEEDS;
		return 1;
	} # end if

# This works for books because sigs don't have a txtFinalWidth, etc.
	if ( ($$specs{'txtFinalWidth'} != $$specs{'txtWidth'}) or ($$specs{'txtFinalHeight'} != $$specs{'txtHeight'}) ) {
		$openprint::log->warn("FOLDING NEEDED dimensions do not match!") if DEBUG_NEEDS;
		return 1;
	} # end if

	return 0;
} # end sub signature_needs

# A function that is smart enough to return true if the project needs folding, and false if it doesn't.
sub neccessary {
	my ( $Project ) = @_;

	return 0 if $Project->Type()->name() eq 'Banners';
	my $services = $Project->services( );

	if ( $$services{'NoBindery'} ) {
		$openprint::log->debug(" ** Project is marked as No bindery, Folding not needed ! ** ");
		return 0;
	} # end if
	if ( $$services{''} ) {
		my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );
		return 0 if $$printing_specs{rdbTemplateType} eq 'Unbound';
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

sub has_overrides {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;
	$specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;

	my @v;
	if ( $qty_index ) {
	foreach my $s_s_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $s_s_id );
		#foreach my $qty_index ( $Project->quantity_indexes() ) {
			push @v, "chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index" if $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"};
			push @v, "chkOverrideFold-$$sig_specs{'SignatureIndex'}-$qty_index" if $$specs{"chkOverrideFold-$$sig_specs{'SignatureIndex'}-$qty_index"};
		#} # end foreach
	} # end foreach
	} # end if

	return @v;
	
} # end sub has_overrides

# Finds the different ways to run the job, and returns different impositions
sub impositions {
	my ( $Project, $Imposition, $specs, $sig_specs, $qty_index ) = @_;

	my @imps = ( $Imposition );

	my $services = $Project->services();
	my $Paper = $Imposition->Paper();

	my %find = (
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
			'calliper'			=>	$$Paper{'calliper'},
	);

	my $Fold = $Imposition->Equipment()->Fold(\%find);
	return @imps if $Fold;
	delete $find{page_width};

	# Now look it up without the width
	$Fold = $Imposition->Press()->Fold(\%find);
	return @imps if ! $Fold;

	if ( $Fold->min_width() and $Fold->min_width() > ( $$Imposition{'image_orientation'} eq 'Vertical' ? $Imposition->image_width() : $Imposition->image_height() ) ) {
		my $I = $Imposition->copy();

		if ( $$I{'image_orientation'} eq 'Vertical' ) {
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

		return @imps if ( $Paper->start_width() and $Paper->start_width() < $I->used_width() );
		$Paper->width( $I->used_width() ) if ! $Paper->start_width();
		push @imps, $I;
	} # end if
	return @imps;

} # end sub impositions

sub signature_calc {
	my ( $Project, $signature_service_index, $sig_specs, $specs, $qty_index, $SignatureImposition, $uv_specs, $aq_specs, $stitching_specs, $Signature_Impositions, $calc_hash ) = @_;
	if ( ! $SignatureImposition->imposition() ) {
	Carp::cluck( 'Invalid Imposition');
				my %results = (
				'Price'		 => 0,
				'MPrice'		=> 0,
				'Equipment'	 => '',
				'Status'		=> 'uncalculated',
				'Folds'		 => '',
				'Breakdown'	 => 'Invalid Signature passed to Folding',
				);
		return %results;

	} # end if

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

	if ( ! ( $$sig_specs{txtFinalWidth} and $$sig_specs{txtFinalHeight} ) ) {
$openprint::log->error("No finished width and height, cannot continue $$Project{id} $signature_service_index $qty_index");
		# Does not need folding
		my %results = (
				'Price'			=> 0,
				'MPrice'		=> 0,
				'Equipment'		=> '',
				'Status'		=> 'uncalculated',
				'Folds'			=> '',
				'Breakdown'		=> 'No finished width and height, cannot continue',
				);
		return %results;
	} # end if
	my $Paper = $SignatureImposition->Paper();
	my $Press = $SignatureImposition->Press();
	my $ppt = $Press->specification('Printing Type');
	my $services = $Project->services();

	my $bestM;
	my $bestPrice = undef;
	my $bestComparison;
	my $bestRunPrice = 0;
	my $bestRunTime = 0;
	my $bestSetupPrice = 0;
	my $bestEquipment;
	my $bestFolds;
	my $Breakdown;

	if (DEBUG) {
		$SignatureImposition->display('Signature Imposition:');
	} # end if


	my $stitching_service_index;
	if ( $$services{'SaddleStitching'} ) {
		if ( ! $stitching_specs ) {
			$stitching_specs = openprint::service::get_specs_ref( $Project, $$services{'SaddleStitching'}[0] );
		}
		$stitching_service_index = $$services{'SaddleStitching'}[0];
	} elsif ( $$services{'LoopStitching'} ) {
		if ( ! $stitching_specs ) {
			$stitching_specs = openprint::service::get_specs_ref( $Project, $$services{'LoopStitching'}[0] );
		} # end if
		$stitching_service_index = $$services{'LoopStitching'}[0];
	} # end if
	if ( $$services{'Cutting'} and @{$$services{'Cutting'}} ) {
		$$calc_hash{'cutting_specs'} = openprint::service::get_specs_ref( $Project, $$services{'Cutting'}[0] );
	} # end if

	my @my_equipment;

	if ( $$specs{"chkOverrideEquipment-$$sig_specs{SignatureIndex}-$qty_index"} eq 'Y' ) {
		#$openprint::log->debug("Overriding Folding Equipment for sig $$sig_specs{'SignatureIndex'} to " . $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"});
		if ( $$specs{"ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index"} ) {
			push @my_equipment, new openprint::Equipment( $$specs{"ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index"} );
		} else {
			my 	%results = (
					'Price'         => 0,
					'MPrice'        => 0,
					'Equipment'     => '',
					'Status'        => 'calculated',
					'Folds'         => '',
					'Breakdown'     => 'Folding Equipment override to nothing',
                );
			push @no_outputs, "ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index";
			return %results;
		} # end if
		push @no_outputs, "ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index";
	} else {
		@no_outputs = sets::exclude( [ "ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index" ], \@no_outputs );
		if ( $Press->specification('Sheeter') eq 'Y' ) {
			if ( $$calc_hash{'Folding::signature_calc::equipment'} ) {
				@my_equipment = @{$$calc_hash{'Folding::signature_calc::equipment'}};
			} else {
				my @folding_capable = ('Y');
				push @folding_capable, 'For Pocket Folders' if $Project->Type()->name() eq 'PresentationFolders';
				push @folding_capable, 'When PerfectBound' if $$services{'PerfectBound'};
				push @folding_capable, 'When Stitching' if ( $$services{'SaddleStitching'} or $$services{'LoopStitching'} );
				@my_equipment = openprint::Equipment->find( useinestimating=>1, Specifications=>{'Folding Capable'=>\@folding_capable} );
				@{$$calc_hash{'Folding::signature_calc::equipment'}} = @my_equipment;
			} # end if 
		} elsif ( DEBUG ) {
			$openprint::log->debug("No sheeter");
		} # end if

		$openprint::log->debug("Press: $$sig_specs{'ddmPress'.$qty_index}" . $Press->strid() ) if DEBUG;
		my $add = 1;
		my $capable = $Press->specification('Folding Capable');	
		if ( $capable and ( $capable ne 'N' ) ) {
			if ( $$sig_specs{'PreviousImposition'} and $$sig_specs{'PreviousImposition'} != $$SignatureImposition{imposition} ) {
$openprint::log->debug("Not adding because previousimposition != sigImposition");
# I don't understand this code. Why would the previous impo being different have any effect on whether we are folding on web
				#$add = 0;
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
	if ( DEBUG ) {
		$openprint::log->debug("Doing signature $$sig_specs{SignatureIndex}");
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

	#foreach my $ss_id ( $Project->signatures() ) {
	# We assume that Signature_Impositions is all impos that come before
	foreach my $SigImpo ( @{$Signature_Impositions} ) {
		next if $signature_service_index and $$SigImpo{service_id} >= $signature_service_index;
		if ( $$SigImpo{folding_results} ) {
#$openprint::log->error("folds from sigimpo");
			my $Folds = $$SigImpo{folding_results}{Folds};
			if ( $Folds ) {
				foreach my $key ( keys %$Folds ) {
					my ( $fold_type, $imposition ) = $key =~ /(.*)-(\d+)out$/;
					push @{$makereadies{$$SigImpo{folding_results}{Equipment}->id()}}, $fold_type;
				} # end foreach
			} elsif ( DEBUG ) {
$openprint::log->error("No folds from sigimpo");
			} # end if
		} else {
			my $s_specs = $$SigImpo{specs};
			next if $$SigImpo{SignatureIndex} and $$SigImpo{SignatureIndex} == $$sig_specs{SignatureIndex};
			foreach my $fold_index ( 1 .. 4 ) {
				if ( $$specs{"FoldQty-$$s_specs{SignatureIndex}-$qty_index-$fold_index"} ) {
					push @{$makereadies{$$specs{"ddmEquipment-$$s_specs{SignatureIndex}-$qty_index"}}}, $$specs{"FoldType-$$s_specs{SignatureIndex}-$qty_index-$fold_index"};
				} # end if
			} # end foreach fold_index
		} # end nif
	} # end foreach signature
	if ( DEBUG ) {
		foreach my $k ( keys %makereadies ) {
			my @mrs = @{$makereadies{$k}};
			$openprint::log->debug("Makereadies for $k : @mrs");
		}
	}

	# What we do is build a set of pieces of the imposition, all of which can be folded. We don't worry about optimality, just possibility.
	my @Set_Of_Impositions;
	my @All_Impositions;


	my $width_folds = Math::Round::nearest( 1, $$sig_specs{txtWidth}/$$sig_specs{txtFinalWidth})-1;
	my $height_folds = Math::Round::nearest( 1, $$sig_specs{txtHeight}/$$sig_specs{txtFinalHeight}) -1;
	@$SignatureImposition{'width_folds','height_folds'} = ( $width_folds, $height_folds );
	$openprint::log->debug("FOlds: $width_folds x $height_folds") if DEBUG;
if ( $$sig_specs{txtSignatureType} and $$sig_specs{txtSpreadSize} == 2 ) {
	if ( $$SignatureImposition{image_orientation} eq 'Vertical' ) {
		$width_folds = 1;
	} else {
		$height_folds = 1;
	} # end if
	$openprint::log->debug("FOlds: $width_folds x $height_folds") if DEBUG;
} # end if

	# IF it's a W&T, we have to cut in half first, so just do it.
	if ( $$SignatureImposition{runstyle} eq 'Work & Turn' ) {
		my $i = $SignatureImposition->copy();
		$i->runstyle('Sheet Work');
		$i->start_columns( $i->columns() );
		$i->columns( $i->columns()/2 );
		$$i{'quantity'} = 2;
		push @Set_Of_Impositions, $i;
	} elsif ( $$SignatureImposition{runstyle} eq 'Work & Tumble' ) {
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
		} # end if

		if ( $$sig_specs{'txtFinalWidth'} and $$sig_specs{'txtFinalHeight'} ) {
			# Something else entirely
			my @Impositions = @Set_Of_Impositions;
			@Set_Of_Impositions = ();
			foreach my $I ( @Impositions ) {
				if ( $$I{width_folds} and $$I{height_folds} ) {
	# All impositions must be 1 out. This may not be true
					my $Singleton = $I->copy();
					$Singleton->rows( 1 );
					$Singleton->columns( 1 );
					$Singleton->quantity( $I->quantity()*$I->imposition() );
					push @Set_Of_Impositions, $Singleton;
				} elsif ( $$I{width_folds} ) {
					my $Singleton = $I->copy();
					if ( $$I{'image_orientation'} eq 'Vertical' ) {
						$Singleton->quantity( $I->quantity()*$I->columns() );
						$Singleton->columns( 1 );
					} else {
						$Singleton->quantity( $I->quantity()*$I->rows() );
						$Singleton->rows( 1 );
					} # end if
					push @Set_Of_Impositions, $Singleton;
				} elsif ( $$I{height_folds} ) {
					my $Singleton = $I->copy();
					if ( $$I{image_orientation} eq 'Vertical' ) {
						$Singleton->quantity( $I->quantity()*$I->rows() );
						$Singleton->rows( 1 );
					} else {
						$Singleton->quantity( $I->quantity()*$I->columns() );
						$Singleton->columns( 1 );
					} # end if Orientation
					push @Set_Of_Impositions, $Singleton;
				} else {
$openprint::log->debug("No folds") if DEBUG;
					push @Set_Of_Impositions, $I;
				} # end if
			} # end foreach I in the set of impositons
		} else {
			$openprint::log->warn("No final width and height!");
		} # end if finalwidth and height
		# Now we have a base set of Maximal Impositions.	Now some of the I's in this set may have an imposition > 1.	
		# Problem is that we apparently also need to price the situation of doing them 1 out, and everything in between.	
		if ( DEBUG ) {
			foreach my $I ( @Set_Of_Impositions ) {
				$I->display('Results after initial cuts qty: ' . $$I{quantity} . 'x ');
			} # end foreach
		} # end if

		@All_Impositions = reduce_impositions( \@Set_Of_Impositions );
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

	} else { # is a book signature
if ( 0 ) {
		my @Impositions = @Set_Of_Impositions;
		@Set_Of_Impositions = ();
		foreach my $I ( @Impositions ) {
			push @Set_Of_Impositions, $I;
			if ( ( $$I{columns} > 1 ) and ( $$I{'image_orientation'} eq 'Vertical' ) ) {
				my $Singleton = $I->copy();
				$Singleton->quantity( $I->quantity()*$I->columns() );
				$Singleton->columns( 1 );
				push @Set_Of_Impositions, $Singleton;
			} elsif ( $$I{rows} > 1 and ( $$I{'image_orientation'} eq 'Horizontal' ) ) {
				my $Singleton = $I->copy();
				$Singleton->quantity( $I->quantity()*$I->rows() );
				$Singleton->rows( 1 );
				push @Set_Of_Impositions, $Singleton;
			} else {
				push @Set_Of_Impositions, $I;
			} # end if
		} # end foreach I in the set of impositons
		if ( DEBUG ) {
			$openprint::log->debug("Is a book signatures: $$sig_specs{txtSignatureType}");
			foreach my $I ( @Set_Of_Impositions ) {
				$I->display('Results after initial cuts');
			} # end foreach
		} # end if
}

		#@All_Impositions = ( \@Set_Of_Impositions );
		@All_Impositions = reduce_impositions( \@Set_Of_Impositions );
	} # end if SignatureType

	# Foreach equipment, figure out which folds are required.
	foreach my $Equipment ( @my_equipment ) {
		$Breakdown .= '<br/><b>Equipment '.$$Equipment{name}.':</b><br/>';
		#$openprint::log->debug('2 Equipment '.$Equipment->name()) if DEBUG;
		if ( $$services{'NoOfflineBindery'} and ( $$sig_specs{'ddmPress'.$qty_index} ne $Equipment->strid() ) ) {
			$Breakdown .= "No Offline bindery and not printing on $$Equipment{name}.<br/>";
			$openprint::log->debug('No Offline Equipment '.$Equipment->name()) if DEBUG;
			next;
		} # end if
		my $capable = $Equipment->specification( 'Folding Capable' );
		if ( $capable eq 'When PerfectBound' ) {
# Means it's a PerfectBinder, so can only do covers
			if ( $$sig_specs{'Group'} != 1 ) {
				$Breakdown .= 'Perfect Binder can only fold 4pg cover:<br/>';
				next;
			} # end if
		} elsif ( $capable eq 'When Stitching' ) {
			$Breakdown .= 'When Stitching:';
# Means it's a Stitcher, or a Duplo, so can only do covers
			if ( $Equipment->specification('Fold Covers Only') and $$sig_specs{'Group'} != 1 ) {
				$Breakdown .= 'Stitcher can only fold 4pg cover:<br/>';
				next;
			} # end if
			if ( ! $stitching_service_index ) {
				$Breakdown .= 'Not stitching:<br/>';
				next;
			} # end if
			if ( ( exists $$specs{'StitchingCost'} ) and ( $$specs{'StitchingEquipment'}->id() != $Equipment->id() ) ) {
				$Breakdown .= "Not stitching on $$Equipment{name}:<br/>";
				next;
			} # end if
		} # end if
		if ( $ppt and ( my $pt = $Equipment->specification('PrintingTypes') ) ) {
			if ( ! sets::isin( $ppt, [ split(',',$pt ) ] ) ) {
				$Breakdown .= 'Wrong printing type.<br/>';
				next;
			} # end if
		} # end if

		for ( my $set_index = 0; $set_index < @All_Impositions; $set_index += 1 ) {
			my $Set_Of_Impositions = $All_Impositions[$set_index];
			if ( $$Equipment{id} == $$Press{id} ) {
				if ( scalar @$Set_Of_Impositions != 1 ) {
$openprint::log->debug("Sets of impos != 1 for $$Equipment{strid}") if DEBUG;
					next;
				} # end if
				next if $$Set_Of_Impositions[0]{quantity} != 1;
			} # end if
			# At this point, we don't modify the Set_Of_Impositions, we modify the equipment-specific copy of it.
#$openprint::log->debug("Impositions in this set: " . @Impositions );

			# complete signals whether we were able to fold all impositions
			my $complete = 1;

			my %folds;
			$openprint::log->debug("Impositions in this set: " . @$Set_Of_Impositions ) if DEBUG;
			for ( my $imp_index = 0; $imp_index < @$Set_Of_Impositions; $imp_index += 1 ) {
				my $Imposition = $$Set_Of_Impositions[$imp_index];

				if ( DEBUG ) {
					$Imposition->display('trying ' . $$Imposition{quantity} . 'x ');
				} # end if

# Web has dual delivery
if ( $$Equipment{id} != $$Press{id} ) {
				if ( $$Imposition{imposition} > 3 and ( $$Imposition{columns} > 1 and $$Imposition{rows} > 1 ) ) {
$openprint::log->debug("Can't do that impo") if DEBUG;
					$complete = 0;
					last;
				} # end if
}

				if ( my $required_bleed = $Equipment->specification($$Imposition{imposition}.'out Required Bleed') ) {
					if ( $required_bleed > $$Imposition{bleed_size} ) {
						$Breakdown .= 'Requires ' . $required_bleed . ' bleed for ' . $$Imposition{imposition} . q`out Can't fold it this way.<br/><br/>`;
						$complete = 0;
						last;
					} else {
					$openprint::log->debug("Bleed Good $$Imposition{bleed_size} < $required_bleed " . $$Imposition{imposition}.'out Required Bleed on ' . $Equipment->strid() ) if DEBUG;
					} # end if
				} else {
					$openprint::log->warn("No spec for " . $$Imposition{imposition}.'out Required Bleed on ' . $Equipment->strid() ) if DEBUG;
				} # end if

				#if ( DEBUG and 0 ) {
					#$openprint::log->debug("trying: ");
					#$Imposition->display();
				#} # end if

# Each piece of equipment can do different folds.	So we have to calculate what we can do as well.
				if ( $$Equipment{id} == $$Press{id} ) {
# Special case because we can't cut it in the middle of printing.	This case is basically for web presses

					my $Fold = $Equipment->Fold( {
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
							'calliper'			=>	$$Paper{'calliper'},
							'printing_type'		=>	$ppt,
							} );
					if ( $Fold ) {
						$Fold = $Fold->clone();
						$Fold->Imposition( $Imposition );
						
						push @{$folds{$Imposition->pages().'PageFold-'.$Imposition->imposition().'out'}}, $Fold;
						$openprint::log->debug(sprintf('Found: %dx%d,%dout', $Imposition->page_columns(), $Imposition->page_rows(), $Imposition->imposition() ) ) if DEBUG;
					} else {
						$Breakdown .= sprintf('Didnt find fold %dx%d %.3fx%.3f %s, %dout %dgsm<br/>', $Imposition->page_columns(), $Imposition->page_rows(), $Imposition->page_width(), $Imposition->page_height(), $Imposition->image_orientation(), $Imposition->imposition(), $Paper->gsm() );
						$openprint::log->debug(sprintf('Didnt find: %dx%d %s,%dout', $Imposition->page_columns(), $Imposition->page_rows(), $Imposition->image_orientation(), $Imposition->imposition() ) ) if DEBUG;
						%folds = ();
						# Last because it's on press, can't do any cut impos.	Not actually True.	Webs can slit it and do dual delivery, fold one, sheet the other. FIXME
						last;
					} # end if
				} else { # Not the press
# FIgure out the fold.	Because this isn't the press, we have to figure out how it cuts...
					if ( $$sig_specs{'rdbTemplateType'} and $fold_types{$$sig_specs{'rdbTemplateType'}} ) {
$openprint::log->debug("Templatetype: $$sig_specs{'rdbTemplateType'}") if DEBUG;
						my $rc = $Equipment->fits( $Imposition->layout_width(), $Imposition->layout_height(), $$Paper{'calliper'} );
						$openprint::log->debug("Trying to fit " . $Imposition->layout_width() . 'x' . $Imposition->layout_height() . ' on ' . $Equipment->strid(). ' (' . $rc.')' ) if DEBUG;
						if ( $rc ) {
							if ( @my_equipment == 1 ) {
								$Breakdown .= "Doesn't fit: $rc<br/>";
							} # end if
							%folds = ();
							last;
						} # end if
							
						my $Fold = $Equipment->Fold({
								type			=>	$$sig_specs{'rdbTemplateType'},
								gsm				=>	$Paper->gsm(),
								calliper		=>	$$Paper{'calliper'},
								imposition		=>	$$Imposition{'imposition'},
								printing_type	=>	$ppt,
								});
						if ( $Fold ) {
# Need to check feed width
$openprint::log->debug("Has a fold, doing extra checks") if DEBUG;
							if ( my $max_feed_width = $Equipment->specification('Maximum Feed Width', $$Imposition{imposition} ) ) {
								if ( $Equipment->specification('Orientation') ) {
									if (						
											( $Equipment->specification('Orientation') eq 'Portrait' and $Imposition->layout_width() <= $Imposition->layout_height() ) or
											( $Equipment->specification('Orientation') eq 'Landscape' and $Imposition->layout_width() >= $Imposition->layout_height() ) 
										) {
										if ( $Imposition->layout_width() >= $max_feed_width ) {
											$openprint::log->debug("Fold no good due to max feed width ($max_feed_width) on width ($$sig_specs{txtWidth}).") if DEBUG;
											$Fold = undef;
										} # end if
									} else {
										if ( $Imposition->layout_height() >= $max_feed_width ) {
											$Fold = undef;
											$openprint::log->debug("Fold no good due to max feed width ($max_feed_width) on height ($$sig_specs{txtHeight}).") if DEBUG;
										} # end if
									} # end if
								} else {
# decide whether it's running portrait or landscape basessd on which way the folds go
									my $width_folds = int( ($$sig_specs{'txtWidth'}/$$sig_specs{'txtFinalWidth'})-1 );
									my $height_folds = int( ($$sig_specs{'txtHeight'}/$$sig_specs{'txtFinalHeight'})-1 );
									$openprint::log->debug("Has max feed width width: $width_folds height: $height_folds $$sig_specs{'txtWidth'} $$sig_specs{'txtHeight'} $max_feed_width") if DEBUG;
									if ( ( $width_folds and ! $height_folds ) or ( $width_folds == $$Fold{'folds'} and $height_folds == $$Fold{'angles'} ) ) {
# If folds are on width, we grip on height...
										if ( $Imposition->layout_width() >= $max_feed_width ) {
											$openprint::log->debug("Fold no good due to max feed width ($max_feed_width) on width ($$sig_specs{'txtHeight'}).") if DEBUG;
											$Fold = undef;
										} # end if
									} elsif ( ( $height_folds and ! $width_folds ) or ( $height_folds == $$Fold{'folds'} and $height_folds == $$Fold{'angles'} ) ) {
										if ( $Imposition->layout_height() >= $max_feed_width ) {
											$Fold = undef;
											$openprint::log->debug("Fold no good due to max feed width ($max_feed_width) on height ($$sig_specs{txtWidth}.") if DEBUG;
										} # end if
									} else {
										$openprint::log->error("No fold match");
									} # end if
								} # end if has an orientation
							} # end if has max_feed_width

							if ( $Fold ) {
$openprint::log->debug("Got Fold: " . $Fold->to_string() ) if DEBUG;
								$Fold = $Fold->clone();
								$Fold->Imposition( $Imposition );
								push @{$folds{$$sig_specs{'rdbTemplateType'}.'-'.$$Imposition{'imposition'}.'out'}}, $Fold;
								next;
							} elsif ( @my_equipment == 1 ) {
								$Breakdown .= "Can't fold that:<br/>
									type			=>	$$sig_specs{'rdbTemplateType'}<br/>
									gsm				=>	".$Paper->gsm()."<br/>
									calliper		=>	".$$Paper{'calliper'}."<br/>
									imposition		=>	$$Imposition{'imposition'}<br/>";
							} # end if Fold passwes extra shceks
$openprint::log->debug("No Fold") if DEBUG;
						} # end if Fold found
						$complete = 0;
					} else { # No template, might be a book
						#$Imposition->display("Trying: $$Equipment{name}") if DEBUG;
						$openprint::log->debug(sprintf('Trying %dx%d=%dout spreads: %dx%d=%d %sx%s',$Imposition->get('columns','rows','imposition','spread_columns','spread_rows','spreads','image_width','image_height') ).' on ' . $Equipment->name()) if DEBUG;

						# See if it fits
						$_ = $Equipment->fits( $Imposition->layout_width(), $Imposition->layout_height(), $$Paper{'calliper'} );

						if ( ! $_ )	{
							$openprint::log->debug("Fits") if DEBUG;
							my $Fold = $Equipment->Fold({
									pages			=>	$Imposition->pages(),
									page_columns	=>	$Imposition->page_columns(),
									page_rows		=>	$Imposition->page_rows(),
									spine_direction	=>	$$Imposition{'image_orientation'},
									stitching		=>	(($$services{'SaddleStitching'} or $$services{'LoopStitching'}) ? 1 : 0),
									perfectbind		=>	($$services{'PerfectBound'} ? 1 : 0),
									spinepaste		=>	($$services{'SpinePaste'} ? 1 : 0),
									gsm				=>	$Paper->gsm(),
									calliper		=>	$$Paper{'calliper'},
									imposition		=>	$$Imposition{'imposition'},
									printing_type	=>	$ppt,
									});
							if ( $Fold ) {
								$Fold = $Fold->clone();
								$Fold->Imposition( $Imposition );

								push @{$folds{$Fold->pages().'PageFold-'.$$Imposition{imposition}.'out'}}, $Fold;
								$openprint::log->debug(sprintf('Found: %dx%d %s,%dout', $Imposition->page_columns(), $Imposition->page_rows(),$Imposition->image_orientation(), $Imposition->imposition()) ) if DEBUG;
								next;
							} elsif( @my_equipment == 1 ) {
								$Imposition->display('Didnt find:' ) if DEBUG;
								$Breakdown .= sprintf('Didnt find: %dx%d %s,%dout<br/>', $Imposition->page_columns(), $Imposition->page_rows(), $Imposition->image_orientation(), $Imposition->imposition() );
							} elsif ( DEBUG ) {
								$Imposition->display('Didnt find fold:' ) if DEBUG;
							} # end if
						} elsif ( DEBUG ) {
							if ( @my_equipment == 1 ) {
							$Breakdown .= "Doesn't fit $_.<br/>";
							} else {
								$Imposition->display('Didnt fiit:'.$_ );
							}
						} # end if

						# If we get here, then we couldn't find the fold
						$complete = 0;
						if ( $set_index < @All_Impositions-1 ) {
							# if we aren't the last set, then do nothing because we assume that this set has already been cut down.
#$openprint::log->debug("$set_index < " . ( @All_Impositions-1 ) );
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
				} # end if Press or not
			} # end foreach Imposition in the set
			next if ! %folds;

			my $all_found = 1;
			if ( $$specs{"chkOverrideFold-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
				# Find out if folds satisfies the overrides
				my %found;
				if ( DEBUG ) {
				foreach my $key ( keys %folds ) {
					$openprint::log->debug("DUmp folds $key...");
				}
				} 
				foreach my $index ( 1 .. 4 ) {
#$openprint::log->debug("OverrideFOld $$sig_specs{'SignatureIndex'}-$qty_index-$index (".$$specs{"FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$index"}.")");
					next if ! $$specs{"FoldQty-$$sig_specs{SignatureIndex}-$qty_index-$index"};
					$found{$index} = 0;
$openprint::log->debug(qq`Overriden $$specs{"FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} $$specs{"FoldImposition-$$sig_specs{'SignatureIndex'}-$qty_index-$index"}out $$specs{"FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$index"}`) if DEBUG;
					foreach my $key ( keys %folds ) {
						# already accounted for
						if ( $folds{$key}[0]{found} ) {
							$openprint::log->debug("Fold $key is found...") if DEBUG;
							next;
						} # end if
						my ( $fold_type, $imposition ) = $key =~ /(.*)-(\d+)out$/;

						my $qty = 0;
						foreach (@{$folds{$key}}) {
							$qty += $_->Imposition()->quantity();
						} # end foreach

						if ( $$specs{"FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} ne $fold_type ) {
$openprint::log->debug(qq`Wrong type: $$specs{"FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} ne $fold_type`) if DEBUG;
							next;
						} elsif ( $$specs{"FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} != $qty ) {
$openprint::log->debug(qq`Wrong qty: $$specs{"FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} != $qty`) if DEBUG;
							next;
						} elsif ( $$specs{"FoldImposition-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} != $imposition ) {
$openprint::log->debug(qq`Wrong imposition: $$specs{"FoldImposition-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} != $imposition`) if DEBUG;
							next;
						} # end if
						$found{$index} = 1;
						$folds{$key}[0]{found} = $index;

						foreach my $F ( @{$folds{$key}} ) {
#$openprint::log->debug("Overriding FOlds and Angles $$F{folds} $$F{angles}");
							$$F{'folds'} = $$specs{"FoldFolds-$$sig_specs{'SignatureIndex'}-$qty_index-$index"};
							$$F{'angles'} = $$specs{"FoldAngles-$$sig_specs{'SignatureIndex'}-$qty_index-$index"};
							$$F{runspeed} = $$specs{"FoldRunspeed-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} if $$specs{"FoldRunspeed-$$sig_specs{'SignatureIndex'}-$qty_index-$index"};
						} # end foreach F
					} # end foreach my $k
					if ( ! $found{$index} ) {
						if ( DEBUG ) {
							$openprint::log->debug("Not found trying generic for index $index");
							foreach my $key ( keys %folds ) {
								$openprint::log->debug("$key => " . @{$folds{$key}} );
							}
						}
# Replace with a generic one
						my $key = $$specs{"FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$index"}.'-'.$$specs{"FoldImposition-$$sig_specs{'SignatureIndex'}-$qty_index-$index"}.'out';
						my ( $pages ) = $$specs{"FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$index"} =~ /(\d+)Page/;
						my $Fold = openprint::Fold->find_one( 
								'min_imposition null_or_<='	=>	$$specs{"FoldImposition-$$sig_specs{'SignatureIndex'}-$qty_index-$index"},
									'max_imposition null_or_>='	=>	$$specs{"FoldImposition-$$sig_specs{'SignatureIndex'}-$qty_index-$index"},
									'type'			=>	$$specs{"FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$index"},
									'equipment_id'	=>	$Equipment->id(),
									'pages'			=>	$pages,
									);
						if ( $Fold ) {
							$openprint::log->debug("found the fold trying generic") if DEBUG;
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
						$$Fold{'found'} = $index;
						$$Fold{undesired} = 1;
			
						$folds{$key} = [ $Fold ];
					} # end if ! found
				} # end foreach index

				foreach my $k ( keys %folds ) {
					$all_found = 0 if ! $folds{$k}[0]{found};
				} # end foreach k
				my $folds_found = 1;
				foreach ( 1 .. 4 ) {
					$folds_found = 0 if exists $found{$_} and ! $found{$_};
				}

				# Get rid of fold that are not specified... so that we don't price them.
				foreach my $k ( keys %folds ) {
					$folds{$k}[0]{undesired} = 1 if ! $all_found or ! $folds_found;
					delete $folds{$k} if ! $folds{$k}[0]{'found'};
				} 
			} # end if override
			my $totalTime = $Equipment->specification('Station Make Ready') * 60;

			my $comparison_cost = 0;
			my $totalPrice;
			my $mprice = 0;
if ( DEBUG ) {
			foreach my $key ( keys %folds ) {
				my $impo_qty = 0;
				foreach (@{$folds{$key}}) {
					$impo_qty += $_->Imposition()->quantity();
				} # end foreach
$openprint::log->debug("Folds: $set_index : $key " . $impo_qty );
			} # end foreach

} # end if

			# This is used in cutting and stitching calcs
			my $fold_index = 1;
			my %fold_specs = %$specs;
			# Going to assume that there is at least 1 fold, so we only have to clear the others
			foreach my $fold_index ( 2 .. 4 ) {
				$fold_specs{"FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index"} = '';
				$fold_specs{"FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index"} = '';
			} # end foreach fold_index
			# Folds is a hash containing all the folds for the signature
			foreach my $key ( keys %folds ) {
				my ( $fold_type, $imposition ) = $key =~ /(.*)-(\d+)out$/;
				last if ! $imposition;

				my $Fold = $folds{$key}[0];
				$comparison_cost += 1000 if $$Fold{undesired};
				my $impo_qty = 0;
				foreach (@{$folds{$key}}) {
					$impo_qty += $_->Imposition()->quantity();
				} # end foreach

				my $Imposition = $Fold->Imposition();
				$fold_specs{"FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index"} = $fold_type;
				$fold_specs{"FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index"} = $impo_qty;
				$fold_specs{"FoldImposition-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index"} = $Imposition->imposition();
				$fold_specs{"FoldColumns-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index"} = $Imposition->columns();
				$fold_specs{"FoldRows-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index"} = $Imposition->rows();
				$fold_specs{"FoldFolds-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index"} = $$Fold{'folds'};
				$fold_specs{"FoldAngles-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index"} = $$Fold{'angles'};
				$fold_specs{"FoldRunspeed-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index"} = $Fold->runspeed($Paper->gsm());
				$fold_index += 1;

				my $run_qty = $$specs{"txtQuantity$qty_index"};
				$run_qty = POSIX::ceil( $run_qty * $impo_qty/$SignatureImposition->imposition()) if $impo_qty != $$SignatureImposition{imposition};

				$openprint::log->debug("Pricing qindex $qty_index runqty: $run_qty impo qty: $impo_qty mipo: $imposition out qty: ".$$specs{"txtQuantity$qty_index"}." Sig imp: $$SignatureImposition{imposition}out	of fold $fold_type on " . $Equipment->name()) if DEBUG;
				if ( $Fold->makeready_overs() ) {
					$run_qty += $Fold->makeready_overs_units() eq 'Percent' ? $run_qty * ( $Fold->makeready_overs() /100 ) : $Fold->makeready_overs();
					$openprint::log->debug("Make Over runqty: $run_qty impo qty: $impo_qty mipo: $imposition out qty: ".$$specs{"txtQuantity$qty_index"}." Sig imp: $$SignatureImposition{imposition}out	of fold $fold_type on " . $Equipment->name()) if DEBUG;
				} # end if
				if ( $Fold->run_overs() ) {
					$run_qty += $Fold->run_overs_units() eq 'Percent' ? $run_qty * ($Fold->run_overs()/100): $Fold->run_overs();
					$openprint::log->debug("Run Overs runqty: $run_qty impo qty: $impo_qty mipo: $imposition out qty: ".$$specs{"txtQuantity$qty_index"}." Sig imp: $$SignatureImposition{imposition}out	of fold $fold_type on " . $Equipment->name()) if DEBUG;
				} # end if

				my $width_folds;
				my $height_folds;
				if ( $$sig_specs{'txtFinalWidth'} and $$sig_specs{'txtFinalHeight'} ) {
					$width_folds = int($$sig_specs{'txtWidth'}/$$sig_specs{'txtFinalWidth'})-1;
					$height_folds = int($$sig_specs{'txtHeight'}/$$sig_specs{'txtFinalHeight'})-1;
				} else {
					$width_folds = int($Imposition->image_width()/$Imposition->object_width())-1;
					$height_folds = int($Imposition->image_height()/$Imposition->object_height())-1;
				} # end if
				if ( $$Fold{'folds'} or $$Fold{'angles'} ) {
					if ( $width_folds == $$Fold{'folds'} and $height_folds == $$Fold{'angles'} ) {
					} elsif ( $width_folds == $$Fold{'angles'} and $height_folds == $$Fold{'folds'} ) {
						$width_folds = $$Fold{'angles'};
						$height_folds = $$Fold{'folds'};
					} else {
						$width_folds = $$Fold{'folds'};
						$height_folds = $$Fold{'angles'};
					} # end if
				} else {
					$$Fold{'folds'} = $width_folds;
					$$Fold{'angles'} = $height_folds;
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

				$Breakdown .= sprintf( '%s: %d*%dout layout: %sx%s qty: %d StockWeight %.2fgsm calliper:%.4f<br/>', $Fold->name(), $impo_qty, $imposition, $Imposition->get('layout_width', 'layout_height'), $run_qty, $Paper->gsm(), $Paper->calliper() );

				my %setupPrice = openprint::service::get_price_object( $Fold->type().'MakeReady', $imposition, $Equipment );
				if ( ! %setupPrice ) {
					$openprint::log->debug("No MakeReady for " . $Fold->type().'MakeReady' . ' ' . $imposition . ' out on ' . $Equipment->strid() ) if DEBUG;
					%setupPrice = openprint::service::get_price_object( 'FoldMakeReady', $imposition, $Equipment );
				} else {
					$openprint::log->debug("Got MakeReady for " . $Fold->type().'MakeReady' . ' imp:' . $imposition . " \$$setupPrice{Price} $setupPrice{units}" ) if DEBUG;
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
					if ( $FoldMakeReady{'units'} eq 'per fold' ) {
						$FoldMakeReady{'Total'} = $FoldMakeReady{'Price'} * ($width_folds);
						$totalPrice += $FoldMakeReady{'Total'};
					} # end if

					my %AngleMakeReady = openprint::service::get_price_object( 'FoldingAngleMakeReady', undef, $Equipment );
					if ( $AngleMakeReady{'units'} eq 'per angle' ) {
						$AngleMakeReady{'Total'} = $AngleMakeReady{'Price'} * ($height_folds);
						$totalPrice += $AngleMakeReady{'Total'};
					} # end if
					$Breakdown .= sprintf( ' + FMR: ($%1$.2f%2$s=$%3$.2f)+ AMR: ($%4$.2f%5$s=$%6$.2f) = $%7$.2f<br/>', @FoldMakeReady{'Price','units','Total'}, @AngleMakeReady{'Price','units','Total'}, $totalPrice );
				} else {
					$Breakdown .= 'No Makeready<br/>';
				} # end if

# In hours
				my $runspeed = $Fold->runspeed($$Paper{'gsm'});
				my $runTime; 
				if ( ! $runspeed ) {
					$Breakdown .= "No runspeed for $fold_type(".$$Fold{name}.") on " . $$Equipment{name} .' Setting to 1/Hr.<br/>';
					$runspeed = 1;
				} else {
					$runTime = Math::Round::nearest( 0.0001, $run_qty / $runspeed ); # in hours
					$Breakdown .= sprintf('Runspeed: %d @ %d/HR = %d:%d:%d<br/>', $run_qty, $runspeed, misc::seconds_to_interval( int( 3600*$runTime ) ) );
				} # end if
$openprint::log->debug("Runspeed: $fold_type(".$Fold->name().") : " . $Equipment->name() . ' ' . $runspeed .' ' . $Paper->gsm() ) if DEBUG;
#$Breakdown .= sprintf( '&nbsp;Folds: QTY: %d, %dout Runspeed: %d/Hr = %.2f hours<br/>', $qty, $imposition, $$RunSpeed{runspeed}, $runTime );
# We are assumin at this point, that all these folds are posible on this equipment, so any errors are soft errors
				my %servicePrice = openprint::service::get_price_object( 'Folding'.$imposition.'out', $run_qty, $Equipment );
				if ( ! %servicePrice ) {
					%servicePrice = openprint::service::get_price_object( $$Fold{type}, $run_qty, $Equipment );
					if ( ! %servicePrice ) {
						%servicePrice = openprint::service::get_price_object( 'Folding',$imposition, $Equipment );
					} # end if
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
					$Breakdown .= qq`No Price given for `.$$Fold{type}.' on '.$$Equipment{'name'}.',<br/>';
				} # end if

				$mprice += $servicePrice{'Total'};
				$totalPrice += $servicePrice{'Total'};
#$openprint::log->debug("Fold $key : totalPrice: $totalPrice");
				
				$totalTime += $runTime * 3600;
if ( 0 ) {
# This would stop pricing once it's too expensive... but then we wouldn't get the breakdown 
				if ( ( defined $bestPrice ) and ( $totalPrice > $bestPrice ) ) {
					last;
				} # end if
}
			} # end foreach fold_type
			my %cutting_results;
			if ( $$services{'Cutting'} and @{$$services{'Cutting'}} ) {
				%cutting_results = openprint::Estimating::Cutting::signature_calc_folding_cutting( $Project, $sig_specs, $$calc_hash{'cutting_specs'}, $qty_index, $Paper, $SignatureImposition, \%fold_specs, $calc_hash );
			} # end if
			my $stitching_part;
			if ( $stitching_service_index ) {
				if ( ! exists $$specs{'StitchingCost'} ) {
# Add in stitching estimate, based on if the folder is this piece of equipment
					$fold_specs{"ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index"} = $Equipment->id();
					$fold_specs{"Price-$$sig_specs{SignatureIndex}-$qty_index"} = $totalPrice;
					my $results = openprint::Estimating::Stitching::signature_calc( $Project, $stitching_service_index, $stitching_specs, $qty_index, \%fold_specs, $sig_specs, [ @$Signature_Impositions, $SignatureImposition ], $calc_hash );
					if ( ! $$results{'Equipment'} ) {
						$Breakdown .= "unable to determine stitching equipment: $$results{alert} $$stitching_specs{'hdnBreakdown'.$qty_index}<br/>";
						$openprint::log->warn('unable to determine stitching equipment; ; '.$Breakdown) if DEBUG;

						$stitching_part = 1000000;
						$totalPrice += 1000000;
					} elsif ( $$results{'Equipment'}->id() != $Equipment->id() and $Equipment->specification('Folding Capable') eq 'When Stitching' ) {
						$Breakdown .= 'Not stitching on ' . $Equipment->strid().' stitching on '.$$results{'Equipment'}->strid() .'.<br/>';
						$Breakdown .= $$stitching_specs{"hdnBreakdown$qty_index"};
						$stitching_part = 1000000;
						$totalPrice += 1000000;
					} else {
						$stitching_part = $$results{'Price'};
						$Breakdown .= "Stitching cost: $stitching_part on " . $$results{'Equipment'}->name() . '<br/>';
					} # end if
					#$Breakdown .= $$results{Breakdown}.'<br/>';
				} elsif ( $$specs{'StitchingEquipment'}->id() != $Equipment->id() and $Equipment->specification('Folding Capable') eq 'When Stitching' ) {
					$Breakdown .= 'Not stitching on ' . $Equipment->strid().' stitching on '.$$specs{'StitchingEquipment'}->strid() .'.<br/>';
				} else {
					$stitching_part = $$specs{'StitchingCost'};
					$Breakdown .= "Stitching cost: $stitching_part on " . $$specs{'StitchingEquipment'}->name() . '<br/>';
				} # end if
			} # end if has sittiching

			$comparison_cost += $totalPrice + $stitching_part + $cutting_results{'Price'};
			if ( $cutting_results{'Equipment'} ) {
				$Breakdown .= 'Cutting: ' . $cutting_results{'Price'} . ' on ' . $cutting_results{'Equipment'}->name() . '<br/>';
			} else { 
				$Breakdown .= 'No Cutting: ' . $cutting_results{'Price'} . ' ' . $cutting_results{'alert'} . ' ' . $cutting_results{'Breakdown'}.'<br/>';
			} # end if

			$Breakdown .= 'Total: $' . sprintf($openprint::config{'ProjectMoneyFormat'}, $totalPrice ) . ' + stitching: ' . $stitching_part . ' / comparison : ' . $comparison_cost . ' <br/><br/>';

			if ( ( $comparison_cost < $bestComparison ) or ( ! defined $bestComparison ) ) {
#$openprint::log->debug("Got better prrice $totalPrice < $bestPrice " . $Equipment->name() ) if DEBUG;
				$bestM = $mprice;
				$bestComparison = $comparison_cost;
				$bestPrice = $totalPrice;
				$bestEquipment = $Equipment;
				$bestRunTime = int($totalTime);
				$bestFolds = \%folds;

				# folding could be free, in which case, we can probably just give up now.
				last if ! $bestPrice;
			} # end if

			if ( $$specs{"chkOverrideFold-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
				if ( $all_found ) {
					last;
				} # end if
			} else {
				# First max impo should always be the best...
				# Not neccessarily
				#last;
			} # end if

		} # end foreach set of Impositions
		# The idea is that if we find a price on the press, then we are done, cuz nothing else will be better.... 
		# Can't do this... case of digital cover on offset interioer, stitched... the stitcher does the cover
		#last if $bestPrice and ( $Equipment->strid() eq $$sig_specs{'ddmPress'.$qty_index} );
		if ( defined $bestPrice and ! $bestPrice ) {
			$openprint::log->debug("Quitting at $$Equipment{strid}");
			last;
		} # end if
	} # end foreach Equipment

	my %results = (
		Comparison		=>	$bestComparison,
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
		if ( ! $imposition ) {
			$openprint::log->error( "No imposition for $key");
			next;
		} # end if
#$openprint::log->debug("$fold_type-Qty-$$sig_specs{'SignatureIndex'}-$qty_index $imposition: " . scalar @{$$bestFolds{$key}} );
		my $Fold = $$bestFolds{$key}[0];

		$results{'MakeReadyTime'} += $Fold->makeready_time();
		if ( $Fold->makeready_overs_units() eq 'Percent' ) {
			$results{'MakeReadyOvers'} += (($$specs{'txtQuantity'.$qty_index}/$imposition)/$SignatureImposition->imposition()) * $Fold->makeready_overs() /100;
		} else {
			$results{'MakeReadyOvers'} += $Fold->makeready_overs();
		} # end if
		#my $RunSpeed = $Fold->Specification( $Paper->gsm() );
		$results{RunSpeed} = $Fold->runspeed($$Paper{'gsm'});
#$openprint::log->debug("SettingRunspeed $key : $fold_type : $imposition " . $Fold->name() . ' ' . $Fold->runspeed() );
		$results{RunOvers} += $Fold->run_overs();
		$results{RunOvers} += (($$specs{'txtQuantity'.$qty_index}/$imposition)/$SignatureImposition->imposition()) * $Fold->run_overs() /100;
	} # end foreach
	
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
	$$specs{alert} = '';

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();
	if ( ! neccessary( $Project ) ) {
		$$specs{'alert'} .= 'Folding is not needed.';
	} # end if
	#my @signature_service_indices = openprint::print::get_signature_indices( $log, $dbh, $project_index );

	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );

	my $uv_specs = openprint::service::get_specs_ref( $Project, $$services{'UVCoating'}[0] ) if $$services{'UVCoating'};
	my $aq_specs = openprint::service::get_specs_ref( $Project, $$services{'Aqueous'}[0] ) if $$services{'Aqueous'};

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$specs{"txtPrice$qty_index"} =~ s/[^\d\.]//g if $$specs{"txtPrice$qty_index"};
		$$specs{"Markup$qty_index"} =~ s/[^\d\.\-]//g if $$specs{"Markup$qty_index"};
		$$specs{"txtQuantity$qty_index"} =~ s/[^\d\.]//g if $$specs{"txtQuantity$qty_index"};
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

		my @signatures = $Project->signatures( { sort => 1 });
		my @Signature_Impositions;
		my %Impositions;
		foreach my $sig_id ( @signatures ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
			if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
				$openprint::log->debug("No imp in signature $$sig_specs{SignatureIndex}") if DEBUG;
				next;
			} # end if
			my $i = new openprint::Imposition();
			$i->load( $sig_specs, $qty_index );
			push @Signature_Impositions, $i;
			$Impositions{$sig_id} = $i;
			$$i{service_id} = $sig_id;

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
		} # end foreach signature

		my $calc_hash = {};
		foreach my $signature_service_index ( @signatures ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
			$$specs{'hdnBreakdown'.$qty_index} .= "<fieldset><legend>Signature: $$sig_specs{SignatureIndex} $$sig_specs{'txtSignatureType'} Ref: $$sig_specs{'txtServiceDescription'}:</legend>";
			$$specs{'hdnBreakdown'.$qty_index} .= openprint::service::summary( $Project, $signature_service_index ) . '<br/>';
			$$specs{'hdnBreakdown'.$qty_index} .= openprint::service::summary( $Project, $signature_service_index, $qty_index ) . '<br/>';

			$$sig_specs{'PreviousImposition'} = $previous_imposition;

			if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No imposition.<br/>';
				next;
			} # endif

			if ( (! signature_needs( $Project, $sig_specs, $qty_index ) ) and ( $$specs{"chkOverrideFold-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'Not needed.<br/>';
				next;
			} # end if

			my $Imposition = $Impositions{$signature_service_index};
			$$specs{'hdnBreakdown'.$qty_index} .= $Imposition->Paper()->to_string() . '<br/>';

			if ( ( ! exists $$sig_specs{'PageQuantity'.$qty_index} ) or $$sig_specs{'PageQuantity'.$qty_index} ) {
				my %results = signature_calc( $Project, $signature_service_index, $sig_specs, $specs, $qty_index, $Imposition, $uv_specs, $aq_specs, {}, \@Signature_Impositions, $calc_hash );
				$$specs{'hdnBreakdown'.$qty_index} .= $results{'Breakdown'};
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('MR Waste: %d, Run Waste: %d<br/>', @results{'MakeReadyOvers','RunOvers'} );
				$$specs{"Price-$$sig_specs{'SignatureIndex'}-$qty_index"} = $results{'Price'};
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

						$openprint::log->debug("Foldtype: $fold_type " . @{$$folds{$key}} . ' ' . $Fold->Imposition()->imposition() . "out $$Fold{name} $$Fold{folds} $$Fold{angles}" ) if DEBUG;
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
					} # end foreach fold

				} else {
					if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
						$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = '';
					} elsif ( $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} ) {
						$status = 'uncalculated';
						$$specs{'alert'} .= "Unable to fold form $$sig_specs{SignatureIndex} qty $qty_index<br/>";
					} # end if
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
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'},
					$price*(1+$$specs{'Markup'.$qty_index}/100)*(1+$Project->markup()/100) );
		} else {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{"txtPrice$qty_index"} );
		} # end if
		$$specs{"MPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $mprice * (1+$Project->markup()/100) );
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

	my @equipment = openprint::Equipment->find( 'useinestimating'=>1, 'Specifications'=>{'Folding Capable'=>\@folding_capable}, 'order'=>'lower(strname)' );
	@{$$variable{'EquipmentArray'}} = map { $_->id(), $_->name() } @equipment;
} # end sub display

sub signature_summary {
	my ( $Project, $service_index, $specs, $qty_index, $s_id, $sig_specs ) = @_;
	$specs = openprint::service::get_specs_ref( $Project, $service_index ) if ! $specs;
	$sig_specs = openprint::service::get_specs_ref( $Project, $s_id ) if ! $sig_specs;
	if ( $qty_index ) {
		my @folds;
		my $Equipment = new openprint::Equipment( $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
		foreach my $fold_index ( 1 .. 4 ) {
			next if ! $$specs{"FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index"};
			push @folds, sprintf('%1$d %3$s %2$dout', @$specs{"FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index",
					"FoldImposition-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index",
					"FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index"} );
		} # end foreach
		return join(', ', @folds).' on ' . $Equipment->name();
	} # end if
} # end sub signature_summary

sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;
	$specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;
	if ( $qty_index ) {
		my $html;
		my $cur_sig_specs;
		my @signatures = $Project->signatures( { sort=>1 } );

		for ( my $sig_index = 0; $sig_index < @signatures; $sig_index += 1 ) {
			my $s_s_id = $signatures[$sig_index];
			my $sig_specs = openprint::service::get_specs_ref( $Project, $s_s_id );
			my $sig_count = 1;

			if ( $sig_index < @signatures - 1 ) {
				for ( my $sig_index2 = $sig_index + 1; $sig_index2 < @signatures; $sig_index2 += 1 ) {
					my $sig_specs2 = openprint::service::get_specs_ref( $Project, $signatures[$sig_index2] );
					if ( openprint::Estimating::Printing::compare_signatures( $Project, $sig_specs, $sig_specs2, $qty_index ) ) {
						$sig_count += 1;
					} else {
						last;
					} # end if
				} # end for
				splice @signatures, $sig_index+1,$sig_count-1 if $sig_count > 1;
			} 
			if ( $sig_count > 1 ) {
				$html .= ($sig_count) . ' Forms ' . $$sig_specs{txtServiceDescription} . ' folded ' ."\n".signature_summary( $Project, $service_id, undef, $qty_index, $s_s_id, undef ) . "\n";
			} else {
			$html .= 'Form ' . $$sig_specs{SignatureIndex} . ' ' . $$sig_specs{txtServiceDescription} . ' folded ' ."\n".signature_summary( $Project, $service_id, undef, $qty_index, $s_s_id, undef ) . "\n";
			} # end if
		} # end foreach
		return $html;
	} else {
		if ( $$specs{'alert'} ) {
			return '<div class="warning">'.$$specs{'alert'}.'</span>';
		} # end if
	} # end if

	return '';
} # end sub summary

sub runspeed {
	my ( $Project, $Service, $Equipment, $qty_index, $sig_id ) = @_;
	my $specs = $Service->specs();
	my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
	my $speed;
	foreach my $type ( keys %fold_types ) {
#$openprint::log->debug("Looking for Folding $sig_id runspeed $type-Qty-$$sig_specs{SignatureIndex}-$qty_index: $speed");
		if ( $$specs{"$type-Qty-$$sig_specs{SignatureIndex}-$qty_index"} ) {
			$speed = $Equipment->specification( $type.'RunSpeed' );
			last if $speed;
		}# end if
	}# end foreach
#$openprint::log->debug("Folding runspeed: ($speed)");
	if ( ! $speed ) {
		my $Imposition = new openprint::Imposition;
		$Imposition->load( $sig_specs, $qty_index );
		#$openprint::log->debug("Getting fold from imposition: " . $Imposition->pages() );
		if ( $Imposition->pages() ) {
			$speed = $Equipment->specification( $Imposition->pages().'PageSignatureFoldRunSpeed' );
		} # end if
	} # end if
	if ( ! $speed ) {
		if ( $$sig_specs{'rdbTemplateType'} and $fold_types{$$sig_specs{'rdbTemplateType'}} ) {
			#$openprint::log->debug("Getting fold from template: " . $$sig_specs{'rdbTemplateType'} );
			$speed = $Equipment->specification( $$sig_specs{'rdbTemplateType'}.'PageSignatureFoldRunSpeed' );
		}
	} # end if
	return $speed;
} # end sub runspeed

sub runtime {
	my ( $Project, $Service, $Equipment, $qty_index, $impressions, $speed, $pertains_to ) = @_;

	my $specs = $Service->specs();
	my $runTime;

	foreach my $sig_id ( ref $pertains_to eq 'ARRAY' ? @{$pertains_to} : $pertains_to ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
		$Equipment = new openprint::Equipment( $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} ) if ! $Equipment;
# Make ready
		$runTime += $Equipment->specification( 'Station Make Ready' ) * 60;

		foreach my $name ( keys %$specs ) {
			if ( $name =~ /^txt(\w*)Qty$/ ) {
				my $type = $1;
				my $quantity = $$specs{$name} * $impressions;
				if ( $quantity > 0 ) {
					$speed = $Equipment->specification( $type.'RunSpeed' ) if ! $speed;
					$openprint::log->debug("Folding runspeed for $type: $speed");
					if ( $speed ) {
						$runTime += $quantity * 3600 / $speed; # Convert to seconds, units is typically per hour
					} # end if
				} # end if
			} # end if
		} # end foreach spec name
	} # end foreach sig_id
	return $runTime;
} # end sub runtime

# The purpose is to cut any Impos > 1 into singletons
sub reduce_impositions {
	my ( $impositions ) = @_;
	my @results = ( $impositions );

	# Find the max impo, so on each iteration, we generate a set of impositions with only the max's cut up
	my $max_impo = 1;
	foreach my $i ( @$impositions ) {
		$max_impo = $$i{imposition} if $$i{imposition} > $max_impo;
	} # end foreach

	if ( $max_impo > 1 ) {
		my @new = @$impositions;
		my $extra = 0;
		for ( my $i = 0; $i < @new; $i += 1 ) {
			if ( $new[$i]->imposition() == $max_impo ) {
				my $I2 = $new[$i]->copy();
				if ( ! ( $I2->columns() % 2 ) ) {
					$I2->columns( $I2->columns()/2 );
					$I2->quantity( $I2->quantity() * 2 );
					$extra = 1;
					splice @new, $i, 1, $I2;
				} elsif ( ! ( $I2->rows() % 2 ) ) {
					$I2->rows( $I2->rows()/2 );
					$I2->quantity( $I2->quantity() * 2 );
					$extra = 1;
					splice @new, $i, 1, $I2;
				} # end if
			} # end if
		} # end foreach I
		if ( $extra ) {
			@new = compact_impositions( @new );
			push @results, reduce_impositions( \@new );
		} # end if

		# SOmething like a 3x2 will be cut into a 1x2+2x2 but never a 2 3x1's... so do this
		$extra = 0;
		@new = @$impositions;
		for ( my $i = 0; $i < @new; $i += 1 ) {
			if ( $new[$i]->imposition() == $max_impo ) {
				if ( $new[$i]->rows() > 1 and $new[$i]->columns() > 1 ) {
					my $I2 = $new[$i]->copy();
					my $I3 = $new[$i]->copy();
					$I2->rows( int($I2->rows()/2) );
					$I3->rows( $I3->rows() - $I2->rows() );
					$extra = 1;
					splice @new, $i, 1, ( $I2, $I3 );
					$i += 1;
				} # end if
			} # end if
		} # end foreach I
		if ( $extra ) {
			@new = compact_impositions( @new );
			push @results, reduce_impositions( \@new );
		} # end if

		$extra = 0;
		@new = @$impositions;
		for ( my $i = 0; $i < @new; $i += 1 ) {
			if ( $new[$i]->imposition() == $max_impo ) {
				my $I2 = $new[$i]->copy();
				if ( $I2->columns() > 2 and ( $I2->columns() % 2 ) ) {
					$I2->quantity( $I2->quantity()*$I2->columns() );
					$I2->columns( 1 );
					$extra = 1;
				} elsif ( $I2->rows() > 2 and ( $I2->rows() % 2 ) ) {
					$I2->quantity( $I2->quantity()*$I2->rows() );
					$I2->rows( 1 );
					$extra = 1;
				} # end if

				if ( $extra ) {
					splice @new, $i, 1, $I2;
				} # end if
			} # end if
		} # end foreach I
		if ( $extra ) {
			@new = compact_impositions( @new );
			push @results, reduce_impositions( \@new );
		} # end if
	} # end if
	return @results;
	
} # end sub reduce_impositions

sub cut_imposition {
	my ( $I ) = @_;
	my ( $i1, $i2 ) = ( $I->copy(), $I->copy );
	if ( ( $$I{spread_size} >= 4 ) and ( $$I{image_orientation} eq 'Horizontal' ) and ( $$I{rows} > 1 ) ) {
		# For folding purposes, can only fold where spines are aligned
		return map { my $i = $I->copy(); $i->rows(1); $i; } ( 1 .. $$I{rows} );
	} elsif ( ( $$I{spread_size} >= 4 ) and ( $$I{image_orientation} eq 'Vertical' ) and ( $$I{columns} > 1 ) ) {
		return map { my $i = $I->copy(); $i->columns(1); $i; } ( 1 .. $$I{columns} );
	} elsif ( $$I{columns} > $$I{rows} ) {
		$i1->columns(int $$I{columns}/2);
		$i2->columns( $$I{columns} - $$i1{columns} );
	} else {
		$i1->rows(int $$I{rows}/2);
		$i2->rows( $$I{rows} - $$i1{rows} );
	} # end if
	$openprint::log->debug(sprintf("Cutting imposition down from %dx%d=%dout to %dx%d=%d and %dx%d=%d", @$I{'columns','rows','imposition'}, @$i1{'columns','rows','imposition'}, @$i2{'columns','rows','imposition'} ) ) if DEBUG;
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
	$openprint::log->debug(sprintf('Cutting pages down from %d to %d and %d', $I->pages(), $i1->pages(), $i2->pages() ) ) if DEBUG;
			return ( $i1, $i2 );
		} else {
			my $i1 = $I->copy();
			$i1->spread_rows( $i1->spread_rows()/2 );
			$i1->image_height( $i1->image_height()/2 );
			$i1->quantity( $i1->quantity() * 2 );
	$openprint::log->debug(sprintf('Cutting pages down from %d to %d', $I->pages(), $i1->pages() ) ) if DEBUG;
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
	$openprint::log->debug(sprintf('Cutting pages down from %d to %d and %d', $I->pages(), $i1->pages(), $i2->pages() ) ) if DEBUG;
			return ( $i1, $i2 );
		} else {
			my $i1 = $I->copy();
			$i1->spread_columns( $i1->spread_columns()/2 );
			$i1->image_width( $i1->image_width()/2 );
			$i1->quantity( $i1->quantity() * 2 );
	$openprint::log->debug(sprintf('Cutting pages down from %d to %d', $I->pages(), $i1->pages() ) ) if DEBUG;
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

sub save {
} # end sub save

sub load_Impositions($$$) {
	my ( $folding_specs, $sig_specs, $qty_index ) = @_;

	my @results;
	foreach my $fold_index ( 1 .. 4 ) {
		next if ! $$folding_specs{"FoldQty-$$sig_specs{SignatureIndex}-$qty_index-$fold_index"};

		my $imp = new openprint::Imposition();
		$imp->columns( $$folding_specs{"FoldColumns-$$sig_specs{SignatureIndex}-$qty_index-$fold_index"} );
		$imp->rows( $$folding_specs{"FoldRows-$$sig_specs{SignatureIndex}-$qty_index-$fold_index"} );

		$imp->type( $$folding_specs{"FoldType-$$sig_specs{SignatureIndex}-$qty_index-$fold_index"} );
		my ( $pages ) = $$folding_specs{"FoldType-$$sig_specs{SignatureIndex}-$qty_index-$fold_index"} =~ /^(\d+)PageFold$/;
		$imp->pages( $pages );
		$imp->quantity( $$folding_specs{"FoldQty-$$sig_specs{SignatureIndex}-$qty_index-$fold_index"} );
		push @results, $imp;
	} # end foreach fold_index
	return @results;
} # end sub load_Impositions

sub get_Folds {
	my ( $folding_specs, $sig_specs, $qty_index ) = @_;
	my @folds;

	foreach my $fold_index ( 1 .. 4 ) {
		next if ! $$folding_specs{"FoldQty-$$sig_specs{SignatureIndex}-$qty_index-$fold_index"};
		next if ! $$folding_specs{"FoldType-$$sig_specs{SignatureIndex}-$qty_index-$fold_index"};
		my $Imposition = new openprint::Imposition();
		$Imposition->load( $sig_specs, $qty_index );
		$Imposition->columns( $$folding_specs{"FoldColumns-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index"} );
		$Imposition->rows( $$folding_specs{"FoldRows-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index"} );
		$Imposition->quantity( $$folding_specs{"FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-$fold_index"} );
		push @folds, $Imposition;
		#$folding_imposition->display('Fold ' . $$folding_specs{"FoldType-$$sig_specs{SignatureIndex}-$qty_index-$fold_index"} ) if DEBUG;
	} # end foreach fold_index
	return @folds;
} # end sub get_Folds

1;
__END__
