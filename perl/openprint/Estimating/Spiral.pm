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

package openprint::Estimating::Spiral;
use strict;

require openprint::service;
require openprint::Material;
require openprint::Project;

my @variables = (
	'Markup1', 'Markup2', 'Markup3',
	'OverridePrice1', 'OverridePrice2', 'OverridePrice3',
	'txtPrice1', 'txtPrice2', 'txtPrice3',
	'MPrice1', 'MPrice2', 'MPrice3',
	'txtUnitPrice1', 'txtUnitPrice2', 'txtUnitPrice3',
	'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
	'ServiceType', 'Status',
	'txtRunTime1', 'txtRunTime2', 'txtRunTime3',
	'chkOverrideFinalHeight','txtFinalHeight',
	'chkOverrideFinishedCalliper','txtFinishedCalliper',
	'chkOverrideMaterialLength', 'txtMaterialLength',
	);

sub variables {
    return @variables;
} # end sub variables

sub neccessary {
	my ( $Project ) = @_;

	$Project = new openprint::Project( $Project ) if ref $Project ne 'openprint::Project';
	my $services = $Project->services();

	return 1 if ! $$services{'PlasticCoil'};
	return 1 if ! $$services{'MetalCoil'};

	return 0;
} # end sub neccessary

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';

$log->debug("SPIRAL!!!!!!!!!!!!!!!!!!");
	# Currently there is no equipmnet for spiral
	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();
	my $ServiceType = $Project->ServiceType( $service_index );
	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );

	if ( $$specs{'chkOverrideFinalHeight'} ne 'Y' ) {
		@$specs{'txtFinalHeight'} = $$printing_specs{'txtFinalHeight'};
	} # end if

	my $makeReadyPrice = openprint::service::get_price( $ServiceType->name().'PunchingMakeReady', undef, undef );
	my $minimumCharge = openprint::service::get_price( $ServiceType->name().'PunchingMinimumCharge', undef, undef );
	my $ProjectType = $Project->Type();

	if ( $$specs{'chkOverrideFinishedCalliper'} ne 'Y' ) {
		$$specs{'txtFinishedCalliper'} = openprint::print::get_finished_calliper( $project_index );
	} else {
		$$specs{'txtFinishedCalliper'} =~ s/[^\d\.]//g;
	} # end if

	my $PunchingService = openprint::Service->find_one( name => $ServiceType->name().'Punching');
	my $CoilingService = openprint::Service->find_one( name => $ServiceType->name() );
	my $Material = openprint::Material->find_one( name=>$ServiceType->name() );

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$specs{"Markup$qty_index"} =~ s/[^\d\.\-]//g;
		$$specs{"txtPrice$qty_index"} =~ s/[^\d\.\-]//g;
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		my $price = 0;
		my $unitPrice = 0;
		my $mprice = 0;

		$$specs{'hdnBreakdown'.$qty_index} = '';
		$$specs{'hdnBreakdown'.$qty_index} .= sprintf('MakeReady: %.2f<br/>', $makeReadyPrice );
		$$specs{'hdnBreakdown'.$qty_index} .= "MinimumCharge: " . sprintf( '%.2f<br/>', $minimumCharge );
		$$specs{"txtQuantity$qty_index"} = int( $$specs{"txtQuantity$qty_index"} );

		if ( $$specs{"txtQuantity$qty_index"} ) {
			my $qty = $$specs{"txtQuantity$qty_index"};

			my %PunchingPrice;
			if ( $PunchingService ) {
				%PunchingPrice = $PunchingService->get_price( $qty, undef );
				if ( $PunchingPrice{units} eq 'per m' ) {
					$PunchingPrice{Total} = Math::Round::nearest( 0.01, $PunchingPrice{Price} * $qty / 1000 );
				} else {
					$PunchingPrice{Total} = Math::Round::nearest( 0.01, $PunchingPrice{Price} * $qty );
				} # end if
				$$specs{'hdnBreakdown'.$qty_index} .= 'Punching: ' . sprintf( '%.4f%s = %.2f<br/>', @PunchingPrice{'Price','units','Total'} );
			} # end if

			my %CoilingPrice;
			if ( $CoilingService ) {
				%CoilingPrice = $CoilingService->get_price( $qty, undef );
				if ( $CoilingPrice{units} eq 'per m' ) {
					$CoilingPrice{Total} = Math::Round::nearest( 0.01, $CoilingPrice{Price} * $qty / 1000 );
				} else {
					$openprint::log->error("Unknown units for coiling");
				} # end if
				$$specs{'hdnBreakdown'.$qty_index} .= 'Coiling: ' . sprintf( '%.4f%s = %.2f<br/>', @CoilingPrice{'Price','units','Total'} );
			} # end if CoilingService

			if ( $$specs{'chkOverrideMaterialLength'} ne 'Y' ) {
				$$specs{'txtMaterialLength'} = $$specs{txtFinalHeight} * $$specs{"txtQuantity$qty_index"};
			} # end if

			$price = $makeReadyPrice + $PunchingPrice{Total} + $CoilingPrice{Total};

			if ( $Material ) {
				my %MaterialPrice = $Material->get_price( $$specs{txtFinishedCalliper}, undef );
				if ( $MaterialPrice{'units'} eq 'project calliper-per 36 inches' ) {
					$MaterialPrice{'Total'} = Math::Round::nearest( 0.01, ( $MaterialPrice{Price} /36 ) * $$specs{txtMaterialLength} );
				} elsif ( $MaterialPrice{'units'} eq 'project calliper-per inch' ) {
					$MaterialPrice{'Total'} = Math::Round::nearest( 0.01, $MaterialPrice{'Price'} * $$specs{'txtMaterialLength'} );
				} elsif ( $MaterialPrice{'units'} eq 'per inch' ) {
					$MaterialPrice{'Total'} = Math::Round::nearest( 0.01, $MaterialPrice{'Price'} * $$specs{'txtMaterialLength'} );
				} else {
					$$specs{'hdnBreakdown'.$qty_index} .= "Unknown units for material";
				} # end if
				$$specs{'hdnBreakdown'.$qty_index} .= "Material: " . sprintf( '%.2f', $MaterialPrice{'Price'} ) . " " . $MaterialPrice{'units'} . "=$MaterialPrice{'Total'}<br/>";
				$price += $MaterialPrice{'Total'};
				$mprice += $MaterialPrice{'Total'};
			} else {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No material found';
			} # end if
	
			if ( $minimumCharge > 0 and $price < $minimumCharge ) {
				$price = $minimumCharge;
			} # end if
			$unitPrice = $price / $qty;
			$mprice += $PunchingPrice{'Total'} + $CoilingPrice{'Total'};
			$mprice = ( $mprice / $qty ) * 1000;
			$$specs{'hdnBreakdown'.$qty_index} .= "Qty: " . $$specs{"txtQuantity$qty_index"} . ": Price: $price<br/>";
		} # end if
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $unitPrice * (1+$Project->markup()/100) );
		$$specs{"MPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $mprice *(1+$$specs{"Markup$qty_index"}/100)*(1+$Project->markup()/100) );
		if ( $$specs{"OverridePrice$qty_index"} ne 'Y' ) {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price*(1+$$specs{"Markup$qty_index"}/100)*(1+$Project->markup()/100) );
		} else {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{"txtPrice$qty_index"} );
		} # end if
	} # end foreach qty_index

	$log->debug("END SPIRAL!!!!!!!!!!!!!!!!!!");
	return $$specs{Status} = $status;
} # end sub calc

sub breakdown {
}

sub display {
}

sub summary {
	return;
}

sub has_overrides {
    my ( $Project, $service_id, $specs, $qty_index ) = @_;
    $specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;

    my @v;
	push @v, map { $$specs{$_} ? $_ : () } ( 'chkOverrideFinalHeight', 'chkOverrideFinishedCalliper', 'chkOverrideMaterialLength' );
    if ( $qty_index ) {
		push @v, map { $$specs{$_.$qty_index} ? $_.$qty_index : () } ( 'OverridePrice' );
    } # end if

    return @v;

} # end sub has_overrides

1;
__END__
