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

package openprint::Estimating::PerfectBound;
use strict;

require openprint::service;
require sql;

my $debug = 1;

my %variables = (
        'ProjectIndex'=>[],'ServiceIndex'=>[],
        'hdnBreakdown1'=>['output'],'hdnBreakdown2'=>['output'],'hdnBreakdown3'=>['output'],
        'txtQuantity1'=>['save'], 'txtQuantity2'=>['save'], 'txtQuantity3'=>['save'],
        'ServiceType'=>[],
        'alert'=>['output'],
        'txtInsertQuantity'=>['save','output'],'chkOverrideInsertQuantity'=>['save'],
        'txtCalliper'=>['save','output'],
        'Imposition1'=>['save','output'], 'Imposition2'=>['save','output'], 'Imposition3'=>['save','output'],
        'ddmEquipment1'=>['save','output'], 'ddmEquipment2'=>['save','output'], 'ddmEquipment3'=>['save','output'],
        'OverridePockets1'=>['save'], 'OverridePockets2'=>['save'], 'OverridePockets3'=>['save'],
        'chkOverrideEquipment1'=>['save'], 'chkOverrideEquipment2'=>['save'], 'chkOverrideEquipment3'=>['save'],
        'rdbGateFoldFit'=>['save'],
        'txtUnitPrice1'=>['output'], 'txtUnitPrice2'=>['output'], 'txtUnitPrice3'=>['output'],
        'txtPrice1'=>['save','output'], 'txtPrice2'=>['save','output'], 'txtPrice3'=>['save','output'],
        'txtRunTime1'=>['save'], 'txtRunTime2'=>['save'], 'txtRunTime3'=>['save'],
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
	foreach my $qty_index ( 1 .. 3 ) {
		foreach my $k ( 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40 ) {
			push @v, 'txtSignatureQty'.$k.'Page-'.$qty_index;
		} # end foreach
	} # end foreach

    return @v;
} # end sub variables

sub neccessary {
	my ( $Project ) = @_;

	my $services = $Project->services();

	if ( $$services{'NoBindery'} ) {
        return 0;
    } # end if

	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );

    if ( $$printing_specs{'rdbTemplateType'} eq 'PerfectBound' ) {
        return 1;
	} # end if

	return 0;	
} # end sub neccessary

sub signature_calc {
	my ( $Project, $service_index, $I, $specs, $qty_index, $folding_specs ) = @_;

	my $services = $Project->services();
	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );

	# Need to figure out which dimension the spine bisects
	if ( $$printing_specs{'txtFinalWidth'} == $$printing_specs{'txtWidth'} ) {
		@$specs{'Width','Height'} = @$printing_specs{'txtFinalHeight','txtFinalWidth'};
	} else {
		@$specs{'Width','Height'} = @$printing_specs{'txtFinalWidth','txtFinalHeight'};
	} # end if

	my $imposition = 2;
	$$specs{"txtPockets$qty_index"} = 1;
	$imposition = 1 if ($I->imposition()%2) or ( sets::isin( $I->runstyle(), ['Work & Turn','Work & Tumble'] ) and $I->imposition()%4);
	$imposition = 1 if $imposition > 1 and ( ($I->image_orientation() eq 'Vertical' and $I->rows() % 2 ) or ($I->image_orientation() eq 'Horizontal' and $I->columns() % 2 ) );

	# Calculate the # of pockets, and the imposition to bind at
	foreach my $signature_service_index ( $Project->signatures() ) {
		next if $service_index and ($signature_service_index >= $service_index);
		$$specs{"txtPockets$qty_index"} += 1;
		my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
		next if $$sig_specs{'txtSignatureType'} eq 'Cover Pages';
		$imposition = 1 if ( $$sig_specs{'txtImposition'.$qty_index} % 2 ) or (sets::isin( $$sig_specs{'ddmRunStyle'.$qty_index}, ['Work & Turn','Work & Tumble'] ) and $$sig_specs{'txtImposition'.$qty_index} % 4 );
	} # end foreach signature

#$openprint::log->debug( "PerfectBind Impo: " . $imposition ) if $debug;
	if ( $$specs{'OverrideImposition'.$qty_index} eq 'Y' ) {
		if ( $imposition < $$specs{'Imposition'.$qty_index} ) {
			$$specs{'alert'} .= "Can't perfectbind $$specs{'Imposition'.$qty_index} out";
		} # end if
	} else {
		$$specs{'Imposition'.$qty_index} = $imposition;
	} # end if

	my $error;
	# THe Equipment::find call gets cached... and the rest is impo-specific... so we can't really cache this.
	my @possible_equipment = get_equipment( $specs, \$error );

	my @equipment = ();

	if ( $$specs{"chkOverrideEquipment$qty_index"} eq 'Y' ) {
$openprint::log->debug("Override PerfectBind to " . $$specs{"ddmEquipment$qty_index"} );
		@equipment = openprint::Equipment::find( 'id' => $$specs{"ddmEquipment$qty_index"} );
	} else {
		@equipment = @possible_equipment;
	} # end if

	my $bestPrice;
	my $bestEquipment;
#$$specs{'hdnBreakdown'.$qty_index} = 'Imposition: ' . $$specs{'Imposition'.$qty_index} .'<br/>';
	foreach my $Equipment ( @equipment ) {
		if ( $Equipment->specification('Maximum Spine Length') and ( $$specs{'Height'} > $Equipment->specification('Maximum Spine Length', $$specs{'Imposition'.$qty_index} ) ) ) {
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Spine Too big. Spine: %s, Maximum: %s<br/>', $$specs{'Height'}, $Equipment->specification('Maximum Spine Length') );
			next;
		} # end if
		if ( $Equipment->specification('Minimum Spine Length') and ( $$specs{'Height'} < $Equipment->specification('Minimum Spine Length', $$specs{'Imposition'.$qty_index} ) ) ) {
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Spine Too small. Spine: %s, Minimum: %s<br/>', $$specs{'Height'}, $Equipment->specification('Minimum Spine Length') );
			next;
		} # end if

		if ( $Equipment->specification('Type') eq 'Press' ) {
			next if $$specs{'txtPockets'.$qty_index} > 1;
			my @sigs = $Project->signatures();
			my $sig_specs = openprint::service::get_specs_ref( $Project, $sigs[0] );
			if ( $I->Press()->id() != $Equipment->id() ) {
				$openprint::log->debug("Press not the same: " . $I->Press()->id() . ' != ' . $Equipment->id() );
				next;
			} # end if
			if ( $$folding_specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} != $Equipment->id() ) {
				$openprint::log->debug("Folder not the same: " . $$folding_specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"}. ' != ' . $Equipment->id() );
				next;
			} # end if
		} # end if

		my $price = get_price( $Equipment, $specs, $qty_index );
		if ( ( ! $bestPrice ) or $$price{'Price'} < $$bestPrice{'Price'} ) {
			$bestEquipment = $Equipment;
			$bestPrice = $price;
		} # end if
	} # end foreach Equipment

	my %results;
	$results{'alert'} = $error;
	$results{'alert'} .= $$bestPrice{'Imposition'}.'out on ' . ($bestEquipment ? $bestEquipment->strid() : '') . ' ' . $$specs{'txtPockets'.$qty_index} . 'pockets ';
	$results{'Imposition'} = $$bestPrice{'Imposition'};
	$results{'Equipment'} = $bestEquipment;
#$openprint::log->debug( "PerfectBind Impo REsults: " . $results{'Imposition'} ) if $debug;
	if ( $$bestPrice{'Imposition'} ) {
		$results{'Status'} = 'calculated';
		$results{'Price'} = $$bestPrice{'Price'};
	} else {
		$results{'Status'} = 'uncalculated';
	} # end if
	return \%results;
} # end sub signature_calc

sub get_equipment {
	my ( $specs, $error ) = @_;

	my @possible_equipment;
	my @all_equipment = openprint::Equipment::find( 'Specifications' => {'PerfectBound Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'strName');
	$$error .= 'There are no perfect binders in the system.<br/>' if ! @all_equipment;

	foreach my $Equipment ( @all_equipment ) {
		if ( $Equipment->specification('Maximum Spread Width') and ( $$specs{'Width'} > $Equipment->specification('Maximum Spread Width') ) ) {
			$$error .= "For " . $Equipment->name() . ': Too big.<br/>';
			next;
		} # end if
		if ( $Equipment->specification('Minimum Spread Width') and ( $$specs{'Width'} < $Equipment->specification('Minimum Spread Width') ) ) {
			$$error .= "For " . $Equipment->name() . ": Too small.<br/>";
			next;
		} # end if
		if ( $Equipment->specification('Maximum Calliper') and ( $$specs{'txtCalliper'} > $Equipment->specification('Maximum Calliper') ) ) {
			$$error .= "For " . $Equipment->name() . ": Too thick.<br/>";
			next;
		} # end if
		if ( $Equipment->specification('Minimum Calliper') and ( $$specs{'txtCalliper'} < $Equipment->specification('Minimum Calliper') ) ) {
			$$error .= "For " . $Equipment->name() . ": Too thin.<br/>";
			next;
		} # end if
		push @possible_equipment, $Equipment;
	} # end foreach equipment
	return @possible_equipment;
} # end sub get_equipment

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';
	my $Project = new openprint::Project( $project_index );

	my $services = $Project->services();
	if ( ! $$services{'Folding'} ) {
		$$specs{'alert'} .= 'Project must be folded.<br/>';
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	my $folding_specs = openprint::service::get_specs_ref( $Project, $$services{'Folding'}[0] );

	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );

	if ( $$specs{'chkOverrideCalliper'} ne 'Y' ) {
		foreach my $qty_index ( 1 .. 3 ) {
			$$specs{'txtCalliper'} = 0;
			foreach my $signature_service_index ( $Project->signatures({'type'=>'Interior Pages'}) ) {
				my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
				my $calliper = $$sig_specs{'PageQuantity'.$qty_index} ? ($$sig_specs{'PageQuantity'.$qty_index}/2) * $$sig_specs{'txtSpecificStockCalliper'} : $$sig_specs{'txtSpecificStockCalliper'};
				$$specs{'txtCalliper'} += $calliper;
			} # end foreach
			last if $$specs{'txtCalliper'};
		} # end foreach
	} # end if

# Need to figure out which dimension the spine bisects
	@$specs{'Width','Height'} = @$printing_specs{'txtFinalWidth','txtFinalHeight'};
	if ( $$printing_specs{'txtFinalWidth'} == $$printing_specs{'txtWidth'} ) {
		@$specs{'Width','Height'} = @$printing_specs{'txtFinalHeight','txtFinalWidth'};
	} # end if


	foreach my $qty_index ( 1 .. 3 ) {
		next if ! $$specs{'txtQuantity'.$qty_index};
		$$specs{'txtPrice'.$qty_index} = '0.00';
		$$specs{'txtUnitPrice'.$qty_index} = '0.00';
		$$specs{'hdnBreakdown'.$qty_index} .= 'Finished Calliper: ' . $$specs{'txtCalliper'} . '<br/>';
		$$specs{'hdnBreakdown'.$qty_index} .= 'Face Trim: ' . $$specs{'Width'} . '<br/>';
		my $imposition = 2;

		if ( $$specs{'OverridePockets'.$qty_index} ne 'Y' ) {
			foreach my $pages ( 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48 ) {
				$$specs{'txtSignatureQty'.$pages.'Page-'.$qty_index} = '';
			} # end foreach

			$$specs{"txtPockets$qty_index"} = 0;

			foreach my $signature_service_index ( $Project->signatures() ) {
				my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
				next if $$sig_specs{'txtSignatureType'} eq 'Cover Spreads';
				if ( 
						($$sig_specs{'txtImposition'.$qty_index} % 2) or 
						($$sig_specs{'hdnImageOrientation'.$qty_index} eq 'Vertical' and $$sig_specs{'hdnImpositionRows'} % 2 ) or 
						($$sig_specs{'hdnImageOrientation'.$qty_index} eq 'Horizontal' and $$sig_specs{'hdnImpositionColumns'} % 2 ) or
						(sets::isin( $$sig_specs{'ddmRunStyle'.$qty_index}, ['Work & Turn','Work & Tumble'] ) and $$sig_specs{'txtImposition'.$qty_index} % 4 ) 
				   ) {
					$imposition = 1
				} # end if

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
					foreach my $pages ( 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48 ) {
						$pages{$pages} += $$folding_specs{$pages.'PageSignatureFold-Qty-'.$$sig_specs{'SignatureIndex'}.'-'
							.$qty_index};
					} # end foreach
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
			foreach my $pages ( 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48 ) {
				$$specs{"txtPockets$qty_index"} += $$specs{'txtSignatureQty'.$pages.'Page-'.$qty_index};
			} # end foreach
		} # end if

		if ( $$specs{'OverrideImposition'.$qty_index} eq 'Y' ) {
			$openprint::log->debug("Overriding imposiion");
			if ( $imposition < $$specs{'Imposition'.$qty_index} ) {
				$$specs{'alert'} .= "Can't bind $$specs{'Imposition'.$qty_index} out";
			} # end if
		} else {
			$$specs{'Imposition'.$qty_index} = $imposition;
		} # end if
	} # end foreach qty_index

	my $error;
	my @Equipment = get_equipment( $specs, \$error );
	if ( ! @Equipment ) {
		$$specs{'alert'} .= 'We are unable to automatically provide a price for Perfect Binding.  You may enter your own price in the price fields, or contact your CSR for a quote.';
		foreach my $qty_index ( 1 ..3 ) {
			$$specs{'hdnBreakdown'.$qty_index} .= $error;
			$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
			my $qty = $$specs{'txtQuantity'.$qty_index};
$openprint::log->debug("QTY: $qty " . $$specs{'txtPrice'.$qty_index});
			if ( $qty and ! (1*$$specs{'txtPrice'.$qty_index}) ) {
$openprint::log->debug("uncalc");
				return $$specs{'Status'} = 'uncalculated';
			} # end if
		} # end foreach
$openprint::log->debug("calc");
		return $$specs{'Status'} = 'calculated';
	} # end if
	
	foreach my $qty_index ( 1 .. 3 ) {
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		my $qty = $$specs{'txtQuantity'.$qty_index};
		next if ! $qty;

		my $bestPrice;

		foreach my $Equipment ( @Equipment ) {
			my $Price = get_price( $Equipment, $specs, $qty_index );
			if ( ( ! defined $bestPrice ) or ( $$bestPrice{'Price'} > $$Price{'Price'} ) ) {
				$bestPrice = $Price;
			} # end if

		$$specs{'hdnBreakdown'.$qty_index} .= 'Quantity: ' . $$specs{"txtQuantity$qty_index"} .  ", Equipment: ".$Equipment->strid() ."<br/>";
		$$specs{'hdnBreakdown'.$qty_index} .= 'Estimated Run Time: '. sprintf('%.1f', $$Price{'RunTime'} ) . ",<br/>";
		$$specs{'hdnBreakdown'.$qty_index} .= 'Number of Passes: '. sprintf('%.1f', $$Price{'Passes'} ) . ",<br/>";
		$$specs{'hdnBreakdown'.$qty_index} .= 'Imposition: '. sprintf('%dout', $$Price{'Imposition'} ) . ",<br/>";
		$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Discounts: Run %d% Imposition: %d%<br/>', @$Price{'RunCost Discount','Imposition Discount'} );
		$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Calliper Markup %d%<br/>', @$Price{'Calliper Markup'} );
		$$specs{'hdnBreakdown'.$qty_index} .= 'MakeReady: $' . sprintf( '%.2f', $$Price{'MakeReady'}).",<br/>";
		my $servicePrice = $$Price{'ServicePrice'};
		$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service: $%.2f%s=$%.2f<br/>', @$servicePrice{'Price','units','Total'});
		$$specs{'hdnBreakdown'.$qty_index} .= 'Total: $'. sprintf('%.2f', int($$Price{'txtPrice'}))."<br/><br/>";
		} # end foreach

		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$bestPrice{'Price'} );
		$$specs{"txtUnitPrice$qty_index"} = sprintf( '%.2f', $$bestPrice{'Price'} / $qty );
    } # end foreach

	$log->debug(" END Perfect Bound!!!!!!!!!!!!!!!!!!");
	return $status;
} # end sub calc

sub get_price {
	my ( $Equipment, $specs, $qty_index ) = @_;

	my %price = (
		'MakeReady' => 0,
		'Service'	=> 0,
		'Insert'	=> 0,
		'Price'		=> 0,
		'RunTime'	=> 0,
		'Passes'	=> 0,
		'Imposition' => $$specs{'Imposition'.$qty_index},
	);

	my $qty = $$specs{'txtQuantity'.$qty_index};
#$openprint::log->debug($price{'Imposition'} . ' on ' .$Equipment->name() . ' max imp: ' . $Equipment->specification('Maximum Imposition'));
	if ( $Equipment->specification('Maximum Imposition') and ( $Equipment->specification('Maximum Imposition') < $$specs{'Imposition'.$qty_index} ) ) {
		$price{'Imposition'} = 1;
		#$openprint::log->debug("Maximum Imposition: " . $Equipment->specification('Maximum Imposition')  ) if $debug;
	} elsif ( $Equipment->specification('Maximum Spine Length',$price{'Imposition'}) and $Equipment->specification('Maximum Spine Length',$price{'Imposition'}) < $$specs{'Height'} ) {
		#$openprint::log->debug("Maximum Spine Length: $$specs{'Height'} > " . $Equipment->specification('Maximum Spine Length',$price{'Imposition'})  ) if $debug;
		$price{'Imposition'} = 1;
	} # end if

	my %MakeReady = openprint::service::get_price( $$specs{'ServiceType'}.'MakeReady'. $$specs{"txtPockets$qty_index"}.'Pockets', $price{'Imposition'}, $Equipment );
	if ( ! %MakeReady ) {
		%MakeReady = openprint::service::get_price( $$specs{'ServiceType'}.'MakeReady', $$specs{"txtPockets$qty_index"}, $Equipment );
	} # end if
	my $pocketMakeReady = openprint::service::get_price( $$specs{'ServiceType'}.'PocketMakeReady', $$specs{"txtPockets$qty_index"}, $Equipment );
	$price{'MakeReady'} = $MakeReady{'Price'} + $pocketMakeReady * ( $$specs{"txtPockets$qty_index"} + 1 );

	my $maxPockets = $Equipment->specification( 'Number of Pockets' );
	my $neededPockets = $$specs{"txtPockets$qty_index"};
	$price{'RunTime'} += $neededPockets * $Equipment->specification( 'Pocket Make Ready' );

# Calculate Full Passes
	if ( $neededPockets > $maxPockets ) {
# Loaded here, so we don't do it in the loop many times
		my %servicePrice;
		if ( ! ( %servicePrice = openprint::service::get_price_object( $$specs{'ServiceType'}.$maxPockets.'Pockets', $qty, $Equipment ) ) ) {
			%servicePrice = openprint::service::get_price_object( $$specs{'ServiceType'}, $maxPockets, $Equipment );
		} # end if
		
		my $unitsPerHour = $Equipment->specification( 'Units Per Hour', $maxPockets );
		my $runtime = $unitsPerHour ? $qty/$unitsPerHour : 0; # in seconds
			$price{'RunTime'} += $runtime * 360;
		my $loopbreak_pockets = $neededPockets;
		while ( $neededPockets > $maxPockets ) {
			if ( $servicePrice{'units'} eq 'Per M' ) {
				$price{'Service'} += $servicePrice{'Price'} * $qty/1000;
			} elsif ( $servicePrice{'units'} =~ /Per Hour/i ) {
				$price{'Service'} += $servicePrice{'Price'} * $runtime;
			} else {
				$openprint::log->debug("Unknown Unit Type: ($servicePrice{'units'}) on $$specs{'ServiceType'}");
			} # end if

			$neededPockets -= $maxPockets;
			last if $neededPockets == $loopbreak_pockets;
			$price{'Passes'} += 1;
		} # end while
	} # end if

# Calculate Last Pass
	my %servicePrice;
	if ( ! ( %servicePrice = openprint::service::get_price_object( $$specs{'ServiceType'}.$neededPockets.'Pockets', $qty, $Equipment ) ) ) {
		%servicePrice = openprint::service::get_price_object( $$specs{'ServiceType'}, $neededPockets, $Equipment );
	} # end if
	$price{'ServicePrice'} = \%servicePrice;
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
		$openprint::log->debug("Unknown Unit Type: $servicePrice{'units'} for $$specs{'ServiceType'} range($neededPockets) equipment(".$Equipment->strid().")");
	} # end if
	$price{'Passes'} += 1;

	if ( $$specs{'txtInsertQuantity'} > 0 ) {
		$price{'Insert'} = openprint::service::get_price( $$specs{'ServiceType'}.'Insert', $$specs{'txtInsertQuantity'}, $Equipment) * $$specs{'txtInsertQuantity'};
# Convert to cost per thousand
		$price{'Insert'} = ($price{'Insert'}*$qty)/1000;
	} # end if

	my $gateFolds = $$specs{'txtSignatureQtySingleGateFolded'.$qty_index} + $$specs{'txtSignatureQtyDoubleGateFolded'.$qty_index};
	if ( $$specs{'rdbGateFoldFit'} eq 'Exact' and $gateFolds > 0 ) {
		$price{'Service'} += openprint::service::get_price( $$specs{'ServiceType'}, $gateFolds, $Equipment );
		$price{'MakeReady'} += $MakeReady{'Price'} + ( $pocketMakeReady * ( $gateFolds + 1 ) );
	} # end if

	$price{'Calliper Markup'} = $Equipment->specification( 'Calliper Price Adjustment', $$specs{'txtCalliper'} );
	$price{'Service'} *= ( 1 + $price{'Calliper Markup'}/100);

	$price{'RunCost Discount'} = $Equipment->specification( 'RunCost Discount', $$specs{"txtQuantity$qty_index"} );
	$price{'Service'} *= ( 1 - $price{'RunCost Discount'}/100);

	$price{'Imposition Discount'} = $Equipment->specification( 'Imposition Discount', $price{'Imposition'} );
	$price{'Service'} *= ( 1 - $price{'Imposition Discount'}/100);

	$price{'Price'} = $price{'MakeReady'} + $price{'Service'} + $price{'Insert'};
$openprint::log->debug($price{'Imposition'} . ' on ' .$Equipment->name() . ' max imp: ' . $Equipment->specification('Maximum Imposition') . 'Discount: ' . $Equipment->specification( 'Imposition Discount', $price{Imposition} ) . ' ' . $price{'Price'} ) if $debug;
	return \%price;
} # end sub get_price

sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;

	if ( $qty_index and $$specs{'Imposition'.$qty_index} ) {
		return $$specs{'Imposition'.$qty_index} .'out';
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

1;

__END__
