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
		'txtPrice1', 'txtPrice2', 'txtPrice3',
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
			foreach my $fold_type ( keys %fold_types ) {
				push @v, "$fold_type-Qty-$$sig_specs{'SignatureIndex'}-$qty_index";
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
	'4PageSignatureFold',
	'6PageSignatureFold',
	'8PageSignatureFold',
	'10PageSignatureFold',
	'12PageSignatureFold',
	'16PageSignatureFold',
	'18PageSignatureFold',
	'20PageSignatureFold',
	'24PageSignatureFold',
	'28PageSignatureFold',
	'30PageSignatureFold',
	'32PageSignatureFold',
	'36PageSignatureFold',
	'40PageSignatureFold',
	'42PageSignatureFold',
	'44PageSignatureFold',
	'48PageSignatureFold',
	'56PageSignatureFold',
	'60PageSignatureFold',
	'64PageSignatureFold',
	'72PageSignatureFold',
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
	'4PageSignatureFold', '4 Page Signature Fold',
	'6PageSignatureFold', '6 Page Signature Fold',
	'8PageSignatureFold', '8 Page Signature Fold',
	'10PageSignatureFold', '10 Page Signature Fold',
	'12PageSignatureFold', '12 Page Signature Fold',
	'16PageSignatureFold', '16 Page Signature Fold',
	'18PageSignatureFold', '18 Page Signature Fold',
	'20PageSignatureFold', '20 Page Signature Fold',
	'24PageSignatureFold', '24 Page Signature Fold',
	'28PageSignatureFold', '28 Page Signature Fold',
	'30PageSignatureFold', '30 Page Signature Fold',
	'32PageSignatureFold', '32 Page Signature Fold',
	'36PageSignatureFold', '36 Page Signature Fold',
	'40PageSignatureFold', '40 Page Signature Fold',
	'42PageSignatureFold', '42 Page Signature Fold',
	'44PageSignatureFold', '44 Page Signature Fold',
	'48PageSignatureFold', '48 Page Signature Fold',
	'56PageSignatureFold', '56 Page Signature Fold',
	'60PageSignatureFold', '60 Page Signature Fold',
	'64PageSignatureFold', '64 Page Signature Fold',
	'72PageSignatureFold', '72 Page Signature Fold',
	'PerpendicularSoftFold', 'Perpendicular Soft Fold',
	'ParallelSoftFold', 'Parallel Soft Fold',
	'2Panel1Pocket', 'Single Pocket Presentation Folder',
	'2Panel2Pocket', 'Double Pocket Presentation Folder',
	'2Panel2PocketGusset', 'Double Pocket Presentation Folder with Gussets',
	'3Panel2Pocket', '3 Panel Double Pocket Presentation Folder',
	'3Panel2PocketGusset', '3 Panel Double Pocket Presentation Folder with Gussets',
	'MapFold','Map Fold',
);

sub fold_types {
} # end sub fold_types

sub signature_needs {
	my $specs = shift;
	if ( $$specs{'rdbTemplateType'} eq 'NoBindery' ) {
		return 0;
	} # end if

	if ( $fold_types{$$specs{'rdbTemplateType'}} ) {
		return 1;
	} # end if

	# This works for books because sigs don't have a txtFinalWidth, etc.
	if ( ($$specs{'txtFinalWidth'} != $$specs{'txtWidth'}) or ($$specs{'txtFinalHeight'} != $$specs{'txtHeight'}) ) {
		#$openprint::log->debug("FOLDING NEEDED dimensions do not match!");
		return 1;
	} # end if
	return 0;
} # end sub signature_needs

# A function that is smart enough to return true if the project needs folding, and false if it doesn't.
sub neccessary {
	my ( $project_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services( );

	if ( $$services{'DieCutting'} ) {
		$openprint::log->debug(" ** Project has Die Cutting, This Folding Service is NOT needed ** ");
		return 0;
	} # end if
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
		my $specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );
		if ( signature_needs( $specs ) ) {
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
	my ( $Project, $signature_service_index, $sig_specs, $specs, $qty_index, $Paper, $Imposition ) = @_;

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

	if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		$openprint::log->debug("Overriding Folding Equipment for sig $$sig_specs{'SignatureIndex'} to " . $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"});
		if ( $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} ) {
			push @my_equipment, new openprint::Equipment( $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
		} else {
			$openprint::log->warn("Folding Equipment override to nothing");
		} # end if
		push @no_outputs, "ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index";
	} else {
		my @equipment = openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Folding Capable'=>'Y'}, 'order'=>'lower(strname)' );
		@my_equipment = @equipment;

		if ( $$services{'PerfectBound'} ) {
#$openprint::log->debug('Adding Perfect Bound' . join(',', map { $_->name() } openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Folding Capable'=>'When PerfectBound'}, 'order'=>'lower(strname)' ) ) );
			push @my_equipment, openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Folding Capable'=>'When PerfectBound'}, 'order'=>'lower(strname)' );
		} # end if
		if ( $$services{'SaddleStitching'} or $$services{'LoopStitching'} ) {
			push @my_equipment, openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Folding Capable'=>'When Stitching'}, 'order'=>'lower(strname)' );
		} # end if

		if ( my @Press = openprint::Equipment::find( 'strid'=>$$sig_specs{'ddmPress'.$qty_index} ) ) {
			my $Press = shift @Press;
			if ( $Press->specification('Folding Capable') ) {
				if ( $Press->specification('Sheeter') ne 'Y' ) {
					@my_equipment = ( $Press );
				} else {
					unshift @my_equipment, $Press;
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
		next if $ss_id == $signature_service_index;
		my $s_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		foreach my $fold_type ( keys %fold_types ) {
			if ( $$specs{$fold_type."-Qty-$$s_specs{'SignatureIndex'}-$qty_index"} > 0 ) {
				push @{$makereadies{$$specs{"ddmEquipment-$$s_specs{'SignatureIndex'}-$qty_index"}}}, $fold_type;
			} # end if
		} # end foreach
	} # end foreach

	my $imposition;
	if ( $$sig_specs{'StitchingImposition'.$qty_index} ) {
		$imposition = $$sig_specs{'StitchingImposition'.$qty_index};
$openprint::log->debug("Got impo from StitchingImposition");
	} elsif ( $$services{'SaddleStitching'} ) {
		my $stitching_specs = openprint::service::get_specs_ref( $Project, $$services{'SaddleStitching'}[0] );
		$imposition = $$stitching_specs{'Imposition'.$qty_index};
$openprint::log->debug("Got impo from SaddleStitching");
	} elsif ( $$services{'LoopStitching'} ) {
		my $stitching_specs = openprint::service::get_specs_ref( $Project, $$services{'LoopStitching'}[0] );
		$imposition = $$stitching_specs{'Imposition'.$qty_index};
$openprint::log->debug("Got impo from LoopStitching");
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
			foreach ( keys %fold_types ) {
				$$specs{$_."-Qty-$$sig_specs{'SignatureIndex'}-$qty_index"} = int $$specs{$_."-Qty-$$sig_specs{'SignatureIndex'}-$qty_index"};

				my $Fold;
				if ( $_ =~ /^(\d*)PageSignatureFold$/ ) {
					next if $1 != $pages;
					$Fold = $Equipment->Fold(
							'pages'				=>	$pages,
							'page_columns'		=>	$Imposition->page_columns(),
							'page_rows'			=>	$Imposition->page_rows(),
							'spine_direction'	=>	$Imposition->image_orientation(),
							'stitching'			=>	($$services{'SaddleStitching'} or $$services{'LoopStitching'}) ? 1 : 0,
							'perfectbind'		=>	$$services{'PerfectBound'} ? 1 : 0,
							'spinepaste'		=>	$$services{'SpinePaste'} ? 1 : 0,
							'gsm'				=>	$Imposition->Paper()->gsm(),
							);
				} else {
					$Fold = $Equipment->Fold(
							'type'				=>	$_,
							'gsm'				=>	$Imposition->Paper()->gsm(),
							);
				} # end if

				foreach $_ ( 1 .. $$specs{$_."-Qty-$$sig_specs{'SignatureIndex'}-$qty_index"} ) {
					push @{$folds{$_}}, $Fold if $Fold;
				} # end foreach
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
					);
			if ( $Fold ) {
				push @{$folds{$pages.'PageSignatureFold'}}, $Fold;
	$openprint::log->debug(sprintf('Found: %dx%d,%dout Max %dout', $Imposition->page_columns(), $Imposition->page_rows(), $Imposition->imposition(), $imposition ) ) if $debug;
			} else {
				$$specs{'hdnBreakdown'.$qty_index} .= 'Didnt find fold<br/>';
	$openprint::log->debug(sprintf('Didnt find: %dx%d %s,%dout Max %dout', $Imposition->page_columns(), $Imposition->page_rows(), $Imposition->image_orientation(), $Imposition->imposition(), $imposition ) ) if $debug;
			} # end if
		} else { # Not overriden, and not a press

			# FIgure out the fold.  Because this isn't the press, we have to figure out how it cuts...
			if ( $$sig_specs{'rdbTemplateType'} and $fold_types{$$sig_specs{'rdbTemplateType'}} ) {
$openprint::log->debug("Templatetype: $$sig_specs{'rdbTemplateType'}");
				$_ = $Equipment->fits( $Imposition->image_width(), $Imposition->image_height(), $$sig_specs{'txtSpecificStockCalliper'} );
				if ( $_ ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "Doesn't fit: $_<br/>";
				} else {
					my $Fold = $Equipment->Fold(
							'type'				=>	$$sig_specs{'rdbTemplateType'},
							'gsm'				=>	$Imposition->Paper()->gsm(),
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
$openprint::log->debug("Trying spreads:" . $Imposition->spreads() . ' on ' . $Equipment->name()) if $debug;
					
					# See if it fits
					$_ = $Equipment->fits( $I->image_orientation() eq 'Vertical' ? ( $I->image_width(), $I->image_height()*$imposition ) : ( $I->image_width()*$imposition, $I->image_height() ), $$sig_specs{'txtSpecificStockCalliper'} );
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
								);
						if ( $Fold ) {
							push @good_folds, $Fold;
							$openprint::log->debug(sprintf('Found: %dx%d %s,%dout Max %dout', $I->page_columns(), $I->page_rows(),$I->image_orientation(), $I->imposition(), $imposition ) ) if $debug;
							next;
						} else {
							$openprint::log->debug(sprintf('Didnt find: %dx%d %s,%dout Max %dout', $I->page_columns(), $I->page_rows(), $I->image_orientation(), $I->imposition(), $imposition ) ) if $debug;
						} # end if
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
$openprint::log->debug('Got fold ' . $F->pages() );
						push @{$folds{$F->pages().'PageSignatureFold'}}, $F;
					} # end foreach
				} # end if able to fold all
			} # end if
		} # end if

		next if ! %folds;
		my $totalTime = $Equipment->specification('Station Make Ready') * 60;

		my $totalPrice;
		foreach my $fold_type ( keys %folds ) {

			foreach my $Fold ( @{$folds{$fold_type}} ) {
		
				$openprint::log->debug("Pricing fold $fold_type") if $debug;

				my $RunSpeed = $Fold->Specification( $Imposition->Paper()->gsm() );
				if ( ! $RunSpeed ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "No runspeed for $fold_type on " . $Equipment->name() .'<br/>';
					next;
				} # end if

# We are assumin at this point, that all these folds are posible on this equipment, so any errors are soft errors
				my %servicePrice = openprint::service::get_price_object( $Fold->type(), scalar @{$folds{$fold_type}} * $$specs{"txtQuantity$qty_index"}/$imposition, $Equipment );
				if ( ! %servicePrice ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "No price assigned for $fold_type on ".$Equipment->name().". <br/>";
					next;
				} # end if

				my %setupPrice = openprint::service::get_price_object( $Fold->type().'MakeReady', undef, $Equipment );
				if ( $setupPrice{'units'} eq 'Per Form' ) {
					$totalPrice += $setupPrice{'Price'};
				} elsif ( ! sets::isin( $fold_type, $makereadies{$Equipment->id()} ) ) {
					$totalPrice += $setupPrice{'Price'};
				} # end if

				# In hours
				my $runTime = sprintf( '%.4f', ($$specs{"txtQuantity$qty_index"}/$imposition) / $$RunSpeed{'runspeed'} );
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf( 'Folds: %d, QTY: %d, %dout Runspeed: %d/Hr = %.2f hours<br/>', scalar @{$folds{$fold_type}}, $$specs{'txtQuantity'.$qty_index}, $imposition, $$RunSpeed{runspeed}, $runTime );

				if ( defined $bestPrice and $totalPrice > $bestPrice ) {
					last;
				} # end if

				if ( lc $servicePrice{'units'} eq 'per hour' ) {
					$servicePrice{'Total'} = $servicePrice{'Price'} * $runTime * scalar @{$folds{$fold_type}};
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('%d %s: Setup: %.2f, Run: $%.2f%s * %.2d:%.2d:%.2d = $%.2f<br/>', scalar @{$folds{$fold_type}}, $Fold->name(), $setupPrice{'Price'}, @servicePrice{'Price','units'}, misc::seconds_to_interval(int $runTime*3600), $servicePrice{'Total'} );
				} elsif ( sets::isin( lc $servicePrice{'units'}, ['per m', 'per 1000'] ) ) {
					$servicePrice{'Total'} = $servicePrice{'Price'} * ( scalar @{$folds{$fold_type}}*($$specs{"txtQuantity$qty_index"}/$imposition) / 1000 );
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('%d %s: Setup: %.2f, Run: $%.2f%s * %d = $%.2f<br/>', scalar @{$folds{$fold_type}}, $Fold->name(), $setupPrice{'Price'}, @servicePrice{'Price','units'}, @{$folds{$fold_type}}*$$specs{"txtQuantity$qty_index"}, $servicePrice{'Total'} );
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
		#last if $totalPrice and ( $Equipment->strid() eq $$sig_specs{'ddmPress'.$qty_index} );
	} # end foreach Equipment

	my %results = (
		'Price'			=> $bestPrice,
		'MPrice'		=> $$specs{'txtQuantity'.$qty_index} ? ($bestPrice/$$specs{'txtQuantity'.$qty_index})*1000 : 0,
		'Equipment'		=> $bestEquipment,
		'Imposition'	=> $imposition,
		'Status'		=> $bestEquipment ? 'calculated' : 'uncalculated',
		'Folds'			=> $bestFolds,
		);

	foreach my $fold_type ( keys %fold_types ) {
		$$specs{"$fold_type-Qty-$$sig_specs{'SignatureIndex'}-$qty_index"} = '';
#$openprint::log->debug("Foldtype: $fold_type $$bestFolds{$fold_type} ");
		if ( $$bestFolds{$fold_type} ) {
			$$specs{"$fold_type-Qty-$$sig_specs{'SignatureIndex'}-$qty_index"} = scalar @{$$bestFolds{$fold_type}};
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
		} # end if
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
	#my @signature_service_indices = openprint::print::get_signature_indices( $log, $dbh, $project_index );
	my $printing_specs = openprint::service::get_specs_ref( $project_index, openprint::project::get_project_type_service_index( $log, $dbh, $project_index ) );

	foreach my $qty_index ( 1 .. 3 ) {
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

			if ( ( ! exists $$sig_specs{'PageQuantity'.$qty_index} ) or $$sig_specs{'PageQuantity'.$qty_index} ) {
				$$specs{'hdnBreakdown'.$qty_index} .= "<fieldset><legend>Signature: $$sig_specs{SignatureIndex} $$sig_specs{'txtServiceDescription'}:</legend>";
				$$specs{'hdnBreakdown'.$qty_index} .= openprint::service::summary( $Project, $signature_service_index, $qty_index ) . '<br/>';
				my %results = signature_calc( $Project, $signature_service_index, $sig_specs, $specs, $qty_index );

				$price += $results{'Price'};
				$mprice += $results{'MPrice'};
				if ( $results{'Equipment'} ) {
					if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
						$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = $results{'Equipment'}->id();
					} # end if
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

		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price );
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
