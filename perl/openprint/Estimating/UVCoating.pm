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

require sql;
require openprint::service;
require openprint::Material;
require openprint::imposition;
require openprint::Imposition;

my $debug = 1;

my @variables = (
	'txtQuantity1','txtQuantity2','txtQuantity3',
	'txtPrice1','txtPrice2','txtPrice3',
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
		} # end foreach
	} # end foreach
    return @v;
} # end sub variables

my @outputs = (
	'txtUnitPrice1','txtUnitPrice2','txtUnitPrice3',
	'txtPrice1','txtPrice2','txtPrice3',
	'ddmEquipment1', 'ddmEquipment2', 'ddmEquipment3',
	'hdnBreakdown1',
	'hdnBreakdown2',
	'hdnBreakdown3',
'alert',
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

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';

	my $Project = new openprint::Project( $project_index );

	@all_equipment = openprint::Equipment::find( 'Specifications' => {'UVCoating Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'lower(strName)') if ! @all_equipment;

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		if ( ! $$specs{"txtQuantity$qty_index"} > 0 ) {
			next;
		} # end if
		$$specs{'hdnBreakdown'.$qty_index} = '';
		$$specs{'txtPrice'.$qty_index} = '';

		my $qty = $$specs{"txtQuantity$qty_index"};
		if ( $$specs{'txtPressSheetComboItems'} ) {
			$qty *= $$specs{'txtPressSheetComboItems'};
		} # end if

		my %MakeReadies;
		my $GrandTotal;
		foreach my $signature_service_index ( $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
			if ( ! ( $$specs{"SideOneCoatingType-$$sig_specs{'SignatureIndex'}"} or $$specs{"SideTwoCoatingType-$$sig_specs{'SignatureIndex'}"} ) ) {
				$$specs{"SideOneCoatingType-$$sig_specs{'SignatureIndex'}"} = $$sig_specs{'SideOneUVCoatingType'};
				$$specs{"SideTwoCoatingType-$$sig_specs{'SignatureIndex'}"} = $$sig_specs{'SideTwoUVCoatingType'};
			} # end if
	
			$$specs{'hdnBreakdown'.$qty_index} .= "Signature: $$sig_specs{'txtServiceDescription'}, " if $$sig_specs{'txtServiceDescription'} ne '';
			if ( ! ( $$specs{"SideOneCoatingType-$$sig_specs{'SignatureIndex'}"} or $$specs{"SideTwoCoatingType-$$sig_specs{'SignatureIndex'}"} ) ) {
				$$specs{'alert'} .= 'Please select the coating types.<br/>';
				$status = 'uncalculated';
				last;
			} # end if
			my $Imposition = new openprint::Imposition();
			$Imposition->load( $sig_specs, $qty_index );
			my %results = signature_calc( $Project, $service_index, $specs, $signature_service_index, $sig_specs, $qty_index, $Imposition, \%MakeReadies );
			$MakeReadies{$results{'Equipment'}->id()} = $$sig_specs{'StockWidth'.$qty_index} * $$sig_specs{'StockHeight'.$qty_index} if $results{'Equipment'};
			$GrandTotal += $results{'Total'};
			$status = 'uncalculated' if $results{'Status'} eq 'uncalculated';

		} # end foreach signature

		$$specs{"txtUnitPrice$qty_index"} = sprintf( '%.2f', $GrandTotal / $qty );
		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{ProjectMoneyFormat}, $GrandTotal );
	} # end foreach qty

	return $status;

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
	if ( ( $$specs{"SideOneCoatingType-$$sig_specs{'SignatureIndex'}"} eq 'None' ) and ( $$specs{"SideTwoCoatingType-$$sig_specs{'SignatureIndex'}"} eq 'None' ) ) {
		$BestPrice{'Status'} = 'calculated';
		return %BestPrice;
	} # end if
	$BestPrice{'Status'} = 'uncalculated';

	my @front_uv;
	push @front_uv, $$specs{"SideOneCoatingType-$$sig_specs{'SignatureIndex'}"} if $$specs{"SideOneCoatingType-$$sig_specs{'SignatureIndex'}"} and ( $$specs{"SideOneCoatingType-$$sig_specs{'SignatureIndex'}"} ne 'None' );
	my @back_uv;
	push @back_uv, $$specs{"SideTwoCoatingType-$$sig_specs{'SignatureIndex'}"} if $$specs{"SideTwoCoatingType-$$sig_specs{'SignatureIndex'}"} and  ( $$specs{"SideTwoCoatingType-$$sig_specs{'SignatureIndex'}"} ne 'None' );
	my @different_types = sets::union( @front_uv, @back_uv );
$openprint::log->debug("@different_types");

	my $qty = $$specs{"txtQuantity$qty_index"};
	if ( $$specs{'txtPressSheetComboItems'} ) {
		$qty *= $$specs{'txtPressSheetComboItems'};
	} # end if
	if ( $$sig_specs{'Versions'} ) {
		$qty *= $$sig_specs{'Versions'};
	} # end if

	@outputs = sets::union( @outputs, "ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index" );

# If any of the signatures doesn't have an imposition, then we are in an incomplete state.
	if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
		$$specs{'alert'} .= 'No imposition was found for printing. Please complete the printing estimation first.<br/>';
		return %BestPrice;
	} # end if

	@all_equipment = openprint::Equipment::find( 'Specifications' => {'UVCoating Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'lower(strName)') if ! @all_equipment;
	my @equipment;	
	if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		@equipment = openprint::Equipment::find( 'strid'=>$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
	} else {
		@equipment = @all_equipment;
	} # endif

	my @Sets_Of_Impositions = ( [ $Imposition ] );
	my $services = $Project->services();

	my @Materials = openprint::Material::find('name'=>'UVCoating');

	foreach my $Equipment ( @equipment ) {
		my %BestPricePerImposition;
		my %minimum = openprint::service::get_price_object( $openprint::log, $openprint::dbh, $openprint::variable, 'UVCoatingMinimumCharge', undef, $Equipment );

		for ( my $set_index=0; $set_index < @Sets_Of_Impositions; $set_index += 1 ) {
			my $impositions = $Sets_Of_Impositions[$set_index];
			my %MakeReadies = %$MakeReadies;

			my $complete = 1;
			my $totalPrice = 0;
			my $breakdown;

			if ( @$impositions > 1 ) {
				my %results = openprint::Estimating::Cutting::signature_calc_stock_cutting( $openprint::log, $openprint::dbh, $openprint::variable, $Project, $service_index, $sig_specs, {}, $qty_index, $$impositions[0]->Paper() );
				$totalPrice += $results{'Price'};
				$breakdown .= sprintf('Stock cutting cost: %.2f<br/>', $results{'Price'} );
			} # end if

			for ( my $imp_index = 0; $imp_index < @$impositions; $imp_index += 1 ) {
				my $imp = $$impositions[$imp_index];

				$breakdown .= sprintf( '%dx%d+%dx%d=%dout on %sx%s<br/>',$imp->get('columns','rows','dutch_columns','dutch_rows','imposition'), $imp->Paper()->width(), $imp->Paper()->height() );
$openprint::log->debug('Trying: ' . $breakdown ) if $debug;

				if ( ! ( $imp->rows() * $imp->columns() ) ) {
					$openprint::log->error("Invalid Imposition in UVCoating");
					$imp->display();
					$complete = 0;
					last;
				} # end if

				if ( sets::isin($imp->runstyle(),['Work & Turn','Work & Tumble']) and ($Equipment->specification('WT UVCoating') ne 'Y') ) {
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

				if ( $_ = $Equipment->fits( $imp->Paper()->width(), $imp->Paper()->height(), $$sig_specs{'txtSpecificStockCalliper'} ) ) {
					$breakdown .= "Doesn't fit. $_<br/>";
$openprint::log->debug('DOESNT: ' . $breakdown ) if $debug;
					$complete = 0;
					if ( $$services{'Cutting'} and ( $$imp{'imposition'} > 1 ) and ( $set_index+1 == @Sets_Of_Impositions ) ) {
						my @new_imps = @$impositions;
						splice @new_imps, $imp_index, 1, cut_imposition( $new_imps[$imp_index] );		
						push @Sets_Of_Impositions, \@new_imps;
					} # end if
					last;
				} # end if

				my $run_qty = $qty / $imp->imposition();
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

				my $price = 0;
				foreach my $type ( @types ) {
					my $setupPrice;
					if ( $MakeReadies{$Equipment->id()} and (
								(($$sig_specs{'StockWidth'.$qty_index} * $$sig_specs{'StockHeight'.$qty_index} * 1.10 ) > $MakeReadies{$Equipment->id()} ) and
								(($$sig_specs{'StockWidth'.$qty_index} * $$sig_specs{'StockHeight'.$qty_index} * .90 ) < $MakeReadies{$Equipment->id()} )
								) ) {
					} else {
						$setupPrice += openprint::service::get_price( $openprint::log, $openprint::dbh, $openprint::variable, 'UVCoating'.$type.'MakeReady', $qty, $Equipment );
						if ( ! $setupPrice ) {
							$setupPrice += openprint::service::get_price( $openprint::log, $openprint::dbh, $openprint::variable, 'UVCoatingMakeReady', $qty, $Equipment );
						} # end if
						$MakeReadies{$Equipment->id()} = $$sig_specs{'StockWidth'.$qty_index} * $$sig_specs{'StockHeight'.$qty_index};
					} # end if
					my %ServicePrice = openprint::service::get_price_object( $openprint::log, $openprint::dbh, $openprint::variable, 'UVCoating'.$type, $run_qty, $Equipment );
					if ( lc $ServicePrice{'units'} eq 'per m' ) {
						$ServicePrice{'Total'} = $ServicePrice{'Price'}*$run_qty/ 1000;
					} elsif ( lc $ServicePrice{'units'} eq 'per hour' ) {
						$ServicePrice{'Total'} = $ServicePrice{'Price'}*$run_qty/ $Equipment->specfication('UVCoatingRunSpeed') if $Equipment->specification('UVCoatingRunSpeed');
					} # end if

					my %MaterialPrice;
					if ( @Materials ) {
						%MaterialPrice = $Materials[0]->get_price( $run_qty, $Equipment );
					} # end if
					if ( lc $MaterialPrice{'units'} eq 'per square inch' ) {
						$MaterialPrice{'Total'} = $MaterialPrice{'Price'} * $run_qty;
					} # end if

					$price += sprintf('%.2f', $setupPrice + $MaterialPrice{'Total'} + $ServicePrice{'Total'} );
					$breakdown .= $type . ' ';
					$breakdown .= sprintf('Setup: $%.2f<br/>', $setupPrice );
					$breakdown .= sprintf('Service: $%1$.2f%2$s * %4$d = $%3$.2f<br/>', @ServicePrice{'Price','units','Total'}, $run_qty );
					$breakdown .= sprintf('Material: $%.2f%s=$%.2f<br/>', @MaterialPrice{'Price','units','Total'});
					$breakdown .= sprintf('Total: $%.2f<br/>', $price );
#$openprint::log->debug(" $type : $breakdown ");
				} # end foreach type
				$totalPrice += $price;
			} # end foreach imposition
			next if ! $complete;

			if ( $totalPrice < $minimum{Price} ) {
				$breakdown .= sprintf('Minimum: $%.2f<br/>', $minimum{'Price'});
				$totalPrice = $minimum{Price};
			} # end if
			if ( $totalPrice < $BestPricePerImposition{'Total'} or ( ! defined $BestPricePerImposition{'Total'} ) ) {
				$BestPricePerImposition{'Total'} = $totalPrice;
				$BestPricePerImposition{'Breakdown'} = $breakdown;
				#$BestPrice{'Setup'} = $setupPrice;
				#$BestPrice{'Material'} = $MaterialPrice{'Total'};
				#$BestPrice{'Service'} = $ServicePrice{'Total'};
				#$BestPrice{'Equipment'} = $Equipment;
				#$BestPrice{'Imposition'} = $imp;
			} # end if
		} # end foreach set of impositions
		next if ! defined $BestPricePerImposition{'Total'};
		if ( $BestPricePerImposition{'Total'} < $BestPrice{'Total'} or ( ! defined $BestPrice{'Total'} ) ) {
			$BestPrice{'Total'} = $BestPricePerImposition{'Total'};
			$BestPrice{'Equipment'} = $Equipment;
			$BestPrice{'Breakdown'} = $BestPricePerImposition{'Breakdown'};
		} # endif
	} # end foreach equipment

	$$specs{'hdnBreakdown'.$qty_index} = $BestPrice{'Breakdown'};
	$$specs{"txtPrice1-$$sig_specs{'SignatureIndex'}-$qty_index"} = $BestPrice{'Total'};

	if ( $BestPrice{'Imposition'} ) {
		if ( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
			$$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} = $BestPrice{'Imposition'}->imposition();
		} # endif
		$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = $BestPrice{'Imposition'}->layout_width();
		$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = $BestPrice{'Imposition'}->layout_height();
	} else {
		if ( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
			$$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
		} # end if
		$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
		$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
	} # end if

	if ( ! $BestPrice{'Equipment'} ) {
		if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
			$$specs{'alert'} = "The selected equipment can not handle your project.  This may be because the stock is too heavy, or too large.";
		} else {
			$$specs{'alert'} = "No suitable equipment could be found for your project.  This may be because the stock is too heavy, or too large.";
		} # end if
		$BestPrice{'Status'} = 'uncalculated';
		return %BestPrice;
	} else {
		$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = $BestPrice{'Equipment'}->strid();
	} # end if

	$BestPrice{'Status'} = 'calculated';
	return %BestPrice;
} # end sub calc

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my $Project = new openprint::Project( $project_index );

	@{$$variable{'Signatures'}} = ();

	$_ = "SELECT lngEquipmentIndex FROM tbl_Equipment_Specifications WHERE strName='UVCoating Capable' AND strValue='Y'";
	@{$$variable{'EquipmentArray'}} = sql::execute( $log, $dbh, $_ );

	foreach my $signature_service_index ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );
		push @{$$variable{'Signatures'}}, @$sig_specs{'SignatureIndex','txtServiceDescription'};
		$$variable{'SideOneCoatingType-'.$$sig_specs{'SignatureIndex'}} = $$sig_specs{'SideOneUVCoatingType'};
		$$variable{'SideTwoCoatingType-'.$$sig_specs{'SignatureIndex'}} = $$sig_specs{'SideTwoUVCoatingType'};
	} # end foreach
} # end sub display

# Copies the UV settings back into the printing service, because that is where we have chosen to store them.
sub save {
	my ( $p_id, $s_id, $params ) = @_;
	my $Project = new openprint::Project( $p_id );
	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $p_id, $ss_id );
		openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $p_id, $ss_id, 'SideOneUVCoatingType', $$params{'SideOneCoatingType-'.$$sig_specs{'SignatureIndex'}} );
		openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $p_id, $ss_id, 'SideTwoUVCoatingType', $$params{'SideTwoCoatingType-'.$$sig_specs{'SignatureIndex'}} );
	} # end foreach
} # end sub

sub summary {
	return '';
} # end sub summary


1;

__END__
