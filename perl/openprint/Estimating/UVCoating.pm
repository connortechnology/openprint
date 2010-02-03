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

package openprint::Estimating::UVCoating;
use strict;
#use warnings;

require sql;
require openprint::service;
require openprint::Material;
require openprint::imposition;
require openprint::Imposition;

use vars qw( $log $dbh %config @outputs );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

# Offline UVCoating
# Let's assume that each piece of equipment can do 1 coat at a time
# This service doesn't store it's own data, other than price.  It gets the info from the printing service.
#
my $debug = 0;

my @variables = (
	'txtQuantity1','txtQuantity2','txtQuantity3',
	'txtPrice1','txtPrice2','txtPrice3',
	'Markup1', 'Markup2', 'Markup3',
	'OverridePrice1', 'OverridePrice2', 'OverridePrice3',
);

sub variables {
	my $p_id = shift;

	my $Project = new openprint::Project( $p_id );
	my @v = @variables;
	foreach my $s_s_id ( $Project->signatures() ) {
		my $specs = openprint::service::get_specs_ref( $Project, $s_s_id );
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			push @v, "chkOverrideQty-$$specs{'SignatureIndex'}", 
				 "ddmEquipment-$$specs{'SignatureIndex'}-$qty_index", "chkOverrideEquipment-$$specs{'SignatureIndex'}-$qty_index",
				 "txtImposition-$$specs{'SignatureIndex'}-$qty_index", "chkOverrideImposition-$$specs{'SignatureIndex'}-$qty_index",
				 "txtLayoutWidth-$$specs{'SignatureIndex'}-$qty_index", "txtLayoutHeight-$$specs{'SignatureIndex'}-$qty_index",
				 "MakeReadyPrice-$$specs{'SignatureIndex'}-$qty_index", "OverrideMakeReadyPrice-$$specs{'SignatureIndex'}-$qty_index",
                 "BlanketPrice-$$specs{'SignatureIndex'}-$qty_index", "OverrideBlanketPrice-$$specs{'SignatureIndex'}-$qty_index",
                 "ServicePrice-$$specs{'SignatureIndex'}-$qty_index", "OverrideServicePrice-$$specs{'SignatureIndex'}-$qty_index",
                 "MaterialPrice-$$specs{'SignatureIndex'}-$qty_index", "OverrideMaterialPrice-$$specs{'SignatureIndex'}-$qty_index",
                 "SignaturePrice-$$specs{'SignatureIndex'}-$qty_index", "OverrideSignaturePrice-$$specs{'SignatureIndex'}-$qty_index",
		} # end foreach
	} # end foreach
    return @v;
} # end sub variables

@outputs = (
	'txtUnitPrice1','txtUnitPrice2','txtUnitPrice3',
	'txtPrice1','txtPrice2','txtPrice3',
	'ddmEquipment1', 'ddmEquipment2', 'ddmEquipment3',
	'hdnBreakdown1',
	'hdnBreakdown2',
	'hdnBreakdown3',
	'alert','Status',
);
sub outputs {
	return @outputs;
}
sub no_outputs {
} # end sub no_outputs

my @no_outputs = (
);

my @all_equipment;

# A function that is smart enough to return true if the project needs perfing/UVCoating, and false if it doesn't.
sub neccessary {
	my ( $log, $dbh, $project_index ) = @_;

	return 0;
} # end sub neccessary
sub signature_needs {
	my ( $Project, $specs ) = @_;

	foreach ( openprint::Estimating::Printing::get_colours( $specs, 'SideOne' ) ) {
		return 1 if $_ =~ /UV/;
	} # end foreach colour

	foreach ( openprint::Estimating::Printing::get_colours( $specs, 'SideTwo' ) ) {
		return 1 if $_ =~ /UV/;
	} # end foreach colour
} # end sub signature_needs

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';

	my $Project = new openprint::Project( $project_index );

	@all_equipment = openprint::Equipment::find( 'Specifications' => {'UVCoating Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'lower(strName)');
	if ( ! @all_equipment ) {
		$$specs{'alert'} = 'We have no equipment for UV Coating.<br/>';
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$specs{"txtPrice$qty_index"} =~ s/[^\d\.]//g;
		$$specs{"txtQuantity$qty_index"} =~ s/[^\d\.]//g;
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		if ( $$specs{"txtQuantity$qty_index"} <= 0 ) {
			next;
		} # end if
		$$specs{'hdnBreakdown'.$qty_index} = sprintf('QTY: %d<br/>',$$specs{"txtQuantity$qty_index"} );

		my $qty = $$specs{"txtQuantity$qty_index"};
		if ( $$specs{'txtPressSheetComboItems'} ) {
			$qty *= $$specs{'txtPressSheetComboItems'};
		} # end if

		my %MakeReadies;

		my $GrandTotal = 0;
		foreach my $signature_service_index ( $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
			$$specs{'hdnBreakdown'.$qty_index} .= 'Printed: ' .openprint::service::summary( $Project, $signature_service_index, $qty_index ).'<br/>';
# If any of the signatures doesn't have an imposition, then we are in an incomplete state.
			if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
				$$specs{'alert'} .= 'No imposition was found for printing. Please complete the printing estimation first.<br/>';
				next;
			} # end if
			my $Imposition = new openprint::Imposition();
			$Imposition->load( $sig_specs, $qty_index );
			my %results = signature_calc( $Project, $service_index, $specs, $signature_service_index, $sig_specs, $qty_index, $Imposition, \%MakeReadies );
			$$specs{'hdnBreakdown'.$qty_index} .= $results{'Breakdown'};

			$MakeReadies{$results{'Equipment'}->id()} = $$sig_specs{'StockWidth'.$qty_index} * $$sig_specs{'StockHeight'.$qty_index} if $results{'Equipment'};
			@outputs = sets::union( @outputs, 
					"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index", 
					"MakeReadyPrice-$$sig_specs{'SignatureIndex'}-$qty_index",
                    "BlanketPrice-$$sig_specs{'SignatureIndex'}-$qty_index",
                    "ServicePrice-$$sig_specs{'SignatureIndex'}-$qty_index",
                    "MaterialPrice-$$sig_specs{'SignatureIndex'}-$qty_index",
                    "SignaturePrice-$$sig_specs{'SignatureIndex'}-$qty_index",
					);	
			if ( $$specs{"OverrideMakeReadyPrice-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
				$$specs{"MakeReadyPrice-$$sig_specs{'SignatureIndex'}-$qty_index"} = sprintf($config{ProjectMoneyFormat}, $results{'MakeReady'} );
			} # end if
			if ( $$specs{"OverrideBlanketPrice-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
				$$specs{"BlanketPrice-$$sig_specs{'SignatureIndex'}-$qty_index"} = sprintf($config{ProjectMoneyFormat}, $results{'Blanket'} );
			} # end if
			if ( $$specs{"OverrideServicePrice-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
				$$specs{"ServicePrice-$$sig_specs{'SignatureIndex'}-$qty_index"} = sprintf($config{ProjectMoneyFormat}, $results{'Service'} );
			} # end if
			if ( $$specs{"OverrideMaterialPrice-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
				$$specs{"MaterialPrice-$$sig_specs{'SignatureIndex'}-$qty_index"} = sprintf($config{ProjectMoneyFormat}, $results{'Material'} );
			} # end if
			if ( $$specs{"OverrideSignaturePrice-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
				$$specs{"SignaturePrice-$$sig_specs{'SignatureIndex'}-$qty_index"} = sprintf($config{ProjectMoneyFormat}, $results{'Total'} );
            } # end if

			if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
				$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = '';
			} # end if
			if ( $results{'Status'} eq 'uncalculated' ) {
				$status = 'uncalculated';
				if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
					$$specs{'alert'} = 'The selected equipment can not handle your project.  This may be because the stock is too heavy, or too large.';
				} else {
					$$specs{'alert'} = $results{'alert'};
					$$specs{'alert'} .= 'No suitable equipment could be found for your project.  This may be because the stock is too heavy, or too large.' if ! $results{'alert'};
				} # end if
			} else {
				if ( $results{'Equipment'} ) {
					$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = $results{'Equipment'}->id();
					$GrandTotal += $$specs{"SignaturePrice-$$sig_specs{'SignatureIndex'}-$qty_index"};
				} # end if
			} # end if uncalculated
		} # end foreach signature
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $config{'UnitPriceFormat'}, $GrandTotal / $qty );
		if ( $$specs{'OverridePrice'.$qty_index} ne 'Y' ) {
			$$specs{"txtPrice$qty_index"} = sprintf( $config{'ProjectMoneyFormat'}, $GrandTotal * (1+$$specs{"Markup$qty_index"}/100) );
		} else {
			$$specs{"txtPrice$qty_index"} = sprintf( $config{'ProjectMoneyFormat'}, $$specs{'txtPrice'.$qty_index} );
		} # end if
	} # end foreach qty

	return $$specs{'Status'} = $status;

} # end sub calc

sub cut_imposition {
	my ( $I ) = @_;
	
	my $i1 = $I->copy();
	$i1->Paper( $i1->Paper()->clone() );
	my $i2 = $I->copy();
	$i2->Paper( $i2->Paper()->clone() );

	if ( $I->runstyle() eq 'Work & Turn' ) {
		$i1->runstyle( 'SheetWork' );
		$i1->columns( $i1->columns() / 2 );
		$i1->dutch_columns( $i1->dutch_columns() / 2 );
		$i1->sheet_width( $i1->sheet_width()/2 );

		$i2->runstyle( 'SheetWork' );
		$i2->columns( $i2->columns() / 2 );
		$i2->dutch_columns( $i2->dutch_columns() / 2 );
		$i2->sheet_width( $i2->sheet_width()/2 );
	} elsif ( $I->runstyle() eq 'Work & Tumble' ) {
		$i1->runstyle( 'SheetWork' );
		$i1->rows( $i1->rows() / 2 );
		$i1->dutch_rows( $i1->dutch_rows() / 2 );
		$i1->sheet_height( $i1->sheet_height()/2 );

		$i2->runstyle( 'SheetWork' );
		$i2->rows( $i2->rows() / 2 );
		$i2->dutch_rows( $i2->dutch_rows() / 2 );
		$i2->sheet_height( $i2->sheet_height()/2 );
	} elsif ( $I->dutch_columns() ) {
		$i1->dutch_rows( 0 );
		$i1->dutch_columns( 0 );
		if ( $I->dutch_orientation() eq 'width' ) {
			$i1->sheet_width( $i1->layout_width() );
		} else {
			$i1->sheet_height( $i1->layout_height() );
		} # end if
		$i2->rows( $I->dutch_rows() );
		$i2->columns( $I->dutch_columns() );
		$i2->image_orientation( $I->image_orientation() eq 'Vertical' ? 'Horizontal' : 'Vertical' );
		$i2->dutch_rows( 0 );
		$i2->dutch_columns( 0 );
		if ( $I->dutch_orientation() eq 'width' ) {
			$i2->sheet_width( $i2->layout_width() );
		} else {
			$i2->sheet_height( $i2->layout_height() );
		} # end if
	} elsif ( $I->layout_width() >= $I->layout_height() and $I->columns() > 1 ) {
		$i1->columns( int($I->columns() / 2) );
		$i2->columns( $I->columns() - $i1->columns() );
		$i1->sheet_width( sprintf('%.3f',$I->sheet_width() / ( $I->columns()/$i1->columns() ) ) );
		$i2->sheet_width( $I->sheet_width() - $i1->sheet_width() );
	} elsif ( $I->layout_width() < $I->layout_height() and $I->rows() > 1 ) {
		$i1->rows( int($I->rows() / 2) );
		$i2->rows( $I->rows() - $i1->rows() );
		$i1->sheet_height( sprintf( '%.3f', $I->sheet_height() / ( $I->rows()/$i1->rows() ) ) );
		$i2->sheet_height( $I->sheet_height() - $i1->sheet_height() );
	} elsif ( $I->columns() >= $I->rows() ) {
		$i1->columns( int($I->columns() / 2) );
		$i2->columns( $I->columns() - $i1->columns() );
		$i1->sheet_width( sprintf('%.3f',$I->sheet_width() / ( $I->columns()/$i1->columns() ) ) );
		$i2->sheet_width( $I->sheet_width() - $i1->sheet_width() );
	} else {
		$i1->rows( int($I->rows() / 2) );
		$i2->rows( $I->rows() - $i1->rows() );
		$i1->sheet_height( sprintf( '%.3f', $I->sheet_height() / ( $I->rows()/$i1->rows() ) ) );
		$i2->sheet_height( $I->sheet_height() - $i1->sheet_height() );
	} # end if
	return ( $i1, $i2 );
} # end sub cut_imposition

sub signature_calc {
    my ( $Project, $service_index, $specs, $signature_service_index, $sig_specs, $qty_index, $Imposition, $MakeReadies ) = @_;

	my %BestPrice;
	my @front_uv;
	foreach ( openprint::Estimating::Printing::get_colours( $sig_specs, 'SideOne' ) ) {
		push @front_uv, $_ if $_ =~ /UV/;
#$openprint::log->debug("Side one colour: $_");
	} # end foreach colour

	my @back_uv;
	foreach ( openprint::Estimating::Printing::get_colours( $sig_specs, 'SideTwo' ) ) {
		push @back_uv, $_ if $_ =~ /UV/;
#$openprint::log->debug("Side two colour: $_");
	} # end foreach colour
	my %inkCoverage = openprint::Estimating::Printing::get_inkcoverage( $sig_specs );

	my @different_types = sets::union( @front_uv, @back_uv );

	#$openprint::log->debug("Signature : $signature_service_index");
	if ( ! ( @front_uv or @back_uv ) ) {
		$BestPrice{'Status'} = 'calculated';	
		return %BestPrice;
	} # end if
	$BestPrice{'Status'} = 'uncalculated';
	if ( $Project->Type()->name() eq 'Labels' ) {
		@BestPrice{'Status','alert'} = ('uncalculated','We cannot UVCoat labels at this time.');
		return %BestPrice;
	} # end if

	my $qty = $$specs{"txtQuantity$qty_index"};
	if ( $$specs{'txtPressSheetComboItems'} ) {
		$qty *= $$specs{'txtPressSheetComboItems'};
	} # end if
	if ( $$sig_specs{'Versions'} ) {
		$qty *= $$sig_specs{'Versions'};
	} # end if

	@all_equipment = openprint::Equipment::find( 'Specifications' => {'UVCoating Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'lower(strName)') if ! @all_equipment;
	my @equipment;	
	if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		@equipment = ( new openprint::Equipment( $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} ) );
	} else {
		@equipment = @all_equipment;
	} # endif

	# Start out with the base
	my @Sets_Of_Impositions = ( [ $Imposition ] );
	my $services = $Project->services();

	foreach my $Equipment ( @equipment ) {
		my %BestPricePerImposition;
		my %minimum = openprint::service::get_price_object( 'UVCoatingMinimumCharge', undef, $Equipment );

		for ( my $set_index = 0; $set_index < @Sets_Of_Impositions; $set_index += 1 ) {
			my $impositions = $Sets_Of_Impositions[$set_index];
			my %MakeReadies = %$MakeReadies;

			my $complete = 1;
			my $totalPrice = 0;
			my $breakdown = '<b>'.$Equipment->name() . '</b><br/>';;

			my %ImpositionPrice;
			if ( @$impositions > 1 ) {
				my %results = openprint::Estimating::Cutting::signature_calc_stock_cutting( $Project, $service_index, $sig_specs, {}, $qty_index, $$impositions[0]->Paper(), $$impositions[0] );
				$ImpositionPrice{'Cutting'} = $results{'Price'};
				$breakdown .= sprintf('Stock cutting cost: %.2f<br/>', $results{'Price'} );
			} # end if

			for ( my $imp_index = 0; $imp_index < @$impositions; $imp_index += 1 ) {
				my $imp = $$impositions[$imp_index];

				$breakdown .= sprintf( '%dx%d+%dx%d=%dout on %sx%s<br/>',$imp->get('columns','rows','dutch_columns','dutch_rows','imposition'), $imp->Paper()->width(), $imp->Paper()->height() );
#$openprint::log->debug('Trying: ' . $breakdown ) if $debug;

				if ( ! ( $imp->rows() * $imp->columns() ) ) {
					$openprint::log->error("Invalid Imposition in UVCoating");
					$imp->display();
					$complete = 0;
					last;
				} # end if

				if ( (sets::intersection( @front_uv, @back_uv ) != sets::union( @front_uv, @back_uv ) ) and sets::isin($imp->runstyle(),['Work & Turn','Work & Tumble']) and ($Equipment->specification('WT UVCoating') ne 'Y') ) {
					$breakdown .= 'Does not support WT UV Coating<br/>';
					if ( $$services{'Cutting'} and ($set_index+1 == @Sets_Of_Impositions) ) {
						my @new_imps = @$impositions;
						splice @new_imps, $imp_index, 1, cut_imposition( $new_imps[$imp_index] );		
						push @Sets_Of_Impositions, \@new_imps;
					} # end if
$openprint::log->debug('W&T: ' . $breakdown ) if $debug;
					$complete = 0;
					last;
				} # end if

				if ( $_ = $Equipment->fits( $imp->Paper()->width(), $imp->Paper()->height(), $imp->Paper()->calliper() ) ) {
					$breakdown .= "Doesn't fit. $_<br/>";
$openprint::log->debug('DOESNT: ' . $breakdown ) if $debug;
					$complete = 0;
					if ( ! ( $_ =~ /Too small/ ) ) {
						if ( $$services{'Cutting'} and ( $$imp{'imposition'} > 1 ) and ( $set_index+1 == @Sets_Of_Impositions ) ) {
							my @new_imps = @$impositions;
							splice @new_imps, $imp_index, 1, cut_imposition( $new_imps[$imp_index] );		
							push @Sets_Of_Impositions, \@new_imps;
						} # end if
					} # end if
					last;
				} # end if

				my $run_qty = $qty / $Imposition->imposition();
				my @types;
				if ( sets::isin( $imp->runstyle(), ['Work & Turn', 'Work & Tumble'] ) ) {
# need to merge any overalls into spots
					foreach my $type ( @different_types ) {
						if ( ! ( sets::isin( $type, \@front_uv ) and sets::isin( $type, \@back_uv ) ) ) {
							$type =~ s/Overall/Spot/;
						} # end if
						push @types, $type;
					} # end foreach
					$run_qty *= 2;
				} else {
					@types = ( @front_uv, @back_uv );
				} # end if
$openprint::log->debug("Types: @types");

				# Has total price values for all types
				foreach my $type ( @types ) {
					my $setupPrice;
					if ( $MakeReadies{$Equipment->id()} and (
								(($$sig_specs{'StockWidth'.$qty_index} * $$sig_specs{'StockHeight'.$qty_index} * 1.10 ) > $MakeReadies{$Equipment->id()} ) and
								(($$sig_specs{'StockWidth'.$qty_index} * $$sig_specs{'StockHeight'.$qty_index} * .90 ) < $MakeReadies{$Equipment->id()} )
								) ) {
					} else {
						$setupPrice = openprint::service::get_price( $type.'MakeReady', $qty, $Equipment );
						$setupPrice = openprint::service::get_price( 'UVCoating'.$type.'MakeReady', $qty, $Equipment ) if ! $setupPrice;
						$setupPrice = openprint::service::get_price( 'UVCoatingMakeReady', $qty, $Equipment ) if ! $setupPrice;

						$ImpositionPrice{'MakeReady'} += $setupPrice;
						$MakeReadies{$Equipment->id()} = $$sig_specs{'StockWidth'.$qty_index} * $$sig_specs{'StockHeight'.$qty_index};
					} # end if
					$breakdown .= sprintf('%s MR: $%.2f', $type, $setupPrice );

					my $BlanketCutPrice = 0;
					if ( $type =~ /Spot/ ) {
						$BlanketCutPrice = openprint::service::get_price( 'BlanketCut', undef, $Equipment );
						$breakdown .= sprintf('+ BC: $%.2f', $BlanketCutPrice );
						$ImpositionPrice{'Blanket'} += $BlanketCutPrice;
					} # end if type is spot

					my %ServicePrice = openprint::service::get_price_object( $type, $run_qty, $Equipment );
					if ( ! %ServicePrice ) {
						%ServicePrice = openprint::service::get_price_object( 'UVCoating'.$type, $run_qty, $Equipment );
					} # end if
					if ( lc $ServicePrice{'units'} eq 'per m' ) {
						$ServicePrice{'Total'} = $ServicePrice{'Price'}*$run_qty/1000;
					} elsif ( lc $ServicePrice{'units'} eq 'per hour' ) {
						$ServicePrice{'Total'} = $ServicePrice{'Price'}*$run_qty/$Equipment->specfication('UVCoatingRunSpeed') if $Equipment->specification('UVCoatingRunSpeed');
					} # end if
# Div by imposition, but run_qty is already div by impo
					#$ServicePrice{'Total'} /= $imp->imposition();
					$ImpositionPrice{'Service'} += $ServicePrice{'Total'};
					$breakdown .= sprintf('+ Service: $%.2f%s=%.2f', @ServicePrice{'Price','units','Total'} );

					my %MaterialPrice;
					my $material_name = $type;
					$material_name =~ s/ ?Spot ?//;
					$material_name =~ s/ ?Overall ?//;
					if ( my @Materials = openprint::Material::find('name'=>$material_name) ) {
						%MaterialPrice = $Materials[0]->get_price( $run_qty, $Equipment );
						if ( lc $MaterialPrice{'units'} eq 'per square inch' ) {
							my $area = $imp->object_area() * $run_qty * ($inkCoverage{$type}/100);
							$MaterialPrice{'Total'} = $MaterialPrice{'Price'} * $run_qty * $area;
						} elsif ( lc $MaterialPrice{'units'} eq 'per m' ) {
							$MaterialPrice{'Total'} = $MaterialPrice{'Price'} * $run_qty / 1000;
						} else {
							$MaterialPrice{'units'} = 'unknown units';
						} # end if
						$breakdown .= sprintf('+ Material: $%.2f%s ', @MaterialPrice{'Price','units','Total'} );
						$ImpositionPrice{'Material'} += $MaterialPrice{'Total'};
					} # end if
					$breakdown .= sprintf(' = $%.2f<br/>', 
						( $setupPrice + $MaterialPrice{'Total'} + $ServicePrice{'Total'} + $BlanketCutPrice ) );

				} # end foreach type
				#$totalPrice += $ImpositionPrice{'Total'} + $ImpositionPrice{'Cutting'};
			} # end foreach imposition
		
			next if ! $complete;
			$ImpositionPrice{'Total'} += misc::sum( @ImpositionPrice{'MakeReady','Service','Material','Blanket','Cutting'} );
			$breakdown .= "Total: $ImpositionPrice{'Total'}<br/>";

			if ( $ImpositionPrice{'Total'} < $BestPricePerImposition{'Total'} or ( ! defined $BestPricePerImposition{'Total'} ) ) {
				%BestPricePerImposition = %ImpositionPrice;
				$BestPricePerImposition{'Breakdown'} = $breakdown;
			} # end if
		} # end foreach set of impositions
		next if ! defined $BestPricePerImposition{'Total'};

		if ( $$specs{"OverrideMakeReadyPrice-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
			$BestPricePerImposition{'MakeReady'} = $$specs{"MakeReadyPrice-$$sig_specs{'SignatureIndex'}-$qty_index"};
		} # end if
		if ( $$specs{"OverrideBlanketPrice-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
			$BestPricePerImposition{'Blanket'} = $$specs{"BlanketPrice-$$sig_specs{'SignatureIndex'}-$qty_index"};
		} # end if
		if ( $$specs{"OverrideServicePrice-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
			$BestPricePerImposition{'Service'} = $$specs{"ServicePrice-$$sig_specs{'SignatureIndex'}-$qty_index"};
		} # end if
		if ( $$specs{"OverrideMaterialPrice-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
			$BestPricePerImposition{'Material'} = $$specs{"MaterialPrice-$$sig_specs{'SignatureIndex'}-$qty_index"};
		} # end if
		$BestPricePerImposition{'Total'} = misc::sum( @BestPricePerImposition{'MakeReady','Service','Material','Blanket','Cutting'} );

		if ( %minimum and ( $BestPricePerImposition{'Total'} < $minimum{Price} ) ) {
			$BestPricePerImposition{'Breakdown'} .= sprintf('Minimum: $%.2f<br/>', $minimum{'Price'});
			$BestPricePerImposition{'Total'} = $minimum{Price};
		} # end if

		if ( $BestPricePerImposition{'Total'} < $BestPrice{'Total'} or ( ! defined $BestPrice{'Total'} ) ) {
			$BestPrice{'Total'} = $BestPricePerImposition{'Total'};
			$BestPrice{'MakeReady'} = $BestPricePerImposition{'MakeReady'};
			$BestPrice{'Service'} = $BestPricePerImposition{'Service'};
			$BestPrice{'Material'} = $BestPricePerImposition{'Material'};
			$BestPrice{'Blanket'} = $BestPricePerImposition{'Blanket'};
			$BestPrice{'Equipment'} = $Equipment;
			$BestPrice{'Breakdown'} = 'Equipment: ' . $Equipment->name() . '<br/>' . $BestPricePerImposition{'Breakdown'};
			$BestPrice{'Status'} = 'calculated';
		} # endif
	} # end foreach equipment

	return %BestPrice;
} # end sub signature_calc

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	@{$$variable{'Equipment'}} = openprint::Equipment::find( 'Specifications' => {'UVCoating Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'lower(strName)');
} # end sub display

# Copies the UV settings back into the printing service, because that is where we have chosen to store them.
sub save {
	my ( $p_id, $s_id, $params ) = @_;
	my $Project = new openprint::Project( $p_id );
	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		#openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $p_id, $ss_id, 'SideOneUVCoatingType', $$params{'SideOneCoatingType-'.$$sig_specs{'SignatureIndex'}} );
		#openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $p_id, $ss_id, 'SideTwoUVCoatingType', $$params{'SideTwoCoatingType-'.$$sig_specs{'SignatureIndex'}} );
	} # end foreach
} # end sub

sub summary {
	return '';
} # end sub summary


1;

__END__
