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

package openprint::Estimating::Collating;
use strict;
use constant DEBUG => 0;

require openprint::service;
require openprint::Project;
require openprint::Estimating::Folding;

my @variables = (
	'alert',
	'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
	'txtPrice1', 'txtPrice2', 'txtPrice3',
	'txtSignatureCount1', 'txtSignatureCount2', 'txtSignatureCount3',
	'OverrideSignatureCount1', 'OverrideSignatureCount2', 'OverrideSignatureCount3',
	'chkOverrideEquipment1', 'chkOverrideEquipment2', 'chkOverrideEquipment3',
	'ddmEquipment1', 'ddmEquipment2', 'ddmEquipment3',
);

sub variables {
    return @variables;
} # end sub variables

sub has_overrides {
    my ( $Project, $service_id, $specs ) = @_;
    $specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;

    my @v;
	foreach my $qty_index ( $Project->quantity_indexes() ) {
		push @v, "chkOverrideEquipment$qty_index" if $$specs{"chkOverrideEquipment$qty_index"};
		push @v, "OverrideSignatureCount$qty_index" if $$specs{"chkOverrideEquipment$qty_index"};
	} # end foreach

    return @v;

} # end sub has_overrides

sub neccessary {
	my ( $Project ) = @_;

	my $services = $Project->services();
	if ( $$services{'PerfectBound'} ) {
		return 0;
	} # end if
	if ( $$services{'PlasticCoil'} ) {
		return 1;
	} # end if
	if ( $$services{'MetalCoil'} ) {
		return 1;
	} # end if
	if ( $$services{'PlasticComb'} ) {
		return 1;
	} # end if
	if ( $$services{'Cerlox'} ) {
		return 1;
	} # end if
	if ( $$services{'DoubleLoopWire'} ) {
		return 1;
	} # end if
	if ( $$services{'CornerStitching'} ) {
		return 1;
	} # end if

	return 0;
} # end sub neccessary

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();

$log->debug("COLLATING!!!!!!!!!!!!!!!!!!");

	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );
	if ( ! $$printing_specs{txtTotalPageQuantity} ) {
		$$specs{alert} = 'Number of pages is unknown!';
		return $$specs{Status} = 'uncalculated';
	} # end if

    my $folding_specs;
    if ( $$services{'Folding'} and @{$$services{'Folding'}} ) {
        $folding_specs = openprint::service::get_specs_ref( $Project, $$services{'Folding'}[0] );
    } # end if

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		if ( (!$$specs{'OverrideSignatureCount'.$qty_index} ) or ( $$specs{'OverrideSignatureCount'.$qty_index} ne 'Y' ) ) {

			$$specs{'txtSignatureCount'.$qty_index} = 0;
			foreach my $sig_id ( $Project->signatures({sort=>1}) ) {
				my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
				next if ! $$sig_specs{"txtImposition$qty_index"};
				my @folding_impositions = openprint::Estimating::Folding::load_Impositions( $folding_specs, $sig_specs, $qty_index ) if $folding_specs;
$openprint::log->debug("Got " . @folding_impositions . " folds for form $$sig_specs{SignatureIndex}") if DEBUG;
				if ( @folding_impositions ) {
					foreach my $Fold_Imp ( @folding_impositions ) {
$openprint::log->debug("Fold $qty_index: " . $Fold_Imp->type() . ' ' . $Fold_Imp->pages() . 'pg ' . $Fold_Imp->quantity() . ' ' . $Fold_Imp->imposition() );
						$$specs{'txtSignatureCount'.$qty_index} += $Fold_Imp->quantity();
					} # end foreach Fold product
				} else {
					$$specs{'txtSignatureCount'.$qty_index} += $$sig_specs{'PageQuantity'.$qty_index} / $$sig_specs{txtSpreadSize};
				} # end if
		
			} # end foreach signature
		} # end if
	} # end foreach qty_index

	my $minimumCharge = openprint::service::get_price( 'CollatingMinimumCharge', undef, undef );

	my @possible_equipment;
	my @all_equipment = openprint::Equipment->find( 'Specifications' => {'Collating Capable'=>['Y','When Printing']}, 'useinestimating'=>1,'order'=>'strName');
	my $error = '';
	if ( ! @all_equipment ) {
		$error .= 'We have no collating equipment.<br/>';
	} # end if
	foreach my $Equipment ( @all_equipment ) {
		if ( my $reason = $Equipment->fits( @$printing_specs{'txtFinalWidth','txtFinalHeight'}, $$specs{'txtCalliper'} ) ) {
			$error .= 'For ' . $Equipment->name() . ': '. $reason  . '<br/>';
		} else {
			push @possible_equipment, $Equipment;
		} # end if
	} # end foreach

	if ( ! @possible_equipment ) {
# alert the user that no equipment is good.
		$$specs{alert} = "Our collating equipment cannot run this project, for the following reasons:<br/>$error<br/> Please only print flat sheets and contact another bindery.";
		return $$specs{Status} = 'uncalculated';
	} # end if

	my $CollatingMakeReady = openprint::Service->find_one(name=>'CollatingMakeReady');
	my $Collating = openprint::Service->find_one(name=>'Collating');

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		my %bestPrice;

		$$specs{'hdnBreakdown'.$qty_index} = '';
		$$specs{'hdnBreakdown'.$qty_index}  .= 'MinimumCharge: ' . sprintf( '%.2f', $minimumCharge ) . '<br/>';
		$$specs{"txtQuantity$qty_index"} = int( $$specs{"txtQuantity$qty_index"} );
		$$specs{"txtQuantity$qty_index"} = $Project->quantity( $qty_index ) if ! $$specs{"txtQuantity$qty_index"};

		my $qty = $$specs{"txtQuantity$qty_index"} * $$specs{'txtSignatureCount'.$qty_index};

		my @equipment = ();
		if ( $$specs{"chkOverrideEquipment$qty_index"} eq 'Y' ) {
			@equipment = ( new openprint::Equipment( $$specs{"ddmEquipment$qty_index"} ) );
		} else {
			@equipment = @possible_equipment;
		} # end if

		foreach my $Equipment ( @equipment ) {
			my %price = (
				Service		=> 0,
				MakeReady	=> 0,
				Equipment	=> $Equipment,
				Total		=> 0,
			);
			if ( $Equipment->specification('Collating Capable') eq 'When Printing' ) {
				# All signatures must be printed on the same machine
				my $cant = 0;
				foreach my $sig_id ( $Project->signatures() ) {
					my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
					next if ! $$sig_specs{"txtImposition$qty_index"};

					if ( $$sig_specs{'ddmPress'.$qty_index} ne $Equipment->strid() ) {
						# cant
						$cant = 1;
					} # end if
				} # end foreach
				if ( $cant ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "Equipment " . $price{'Equipment'}->name() . ": Not all signatures printed on this press.<br/>";
					next;
				} # end if
			} # end if
			my %MakeReadyPrice = $CollatingMakeReady->get_price( undef, $Equipment ) if $CollatingMakeReady;
			$price{MakeReady} = $MakeReadyPrice{Price};
			my %servicePrice = $Collating->get_price( $qty, $Equipment ) if $Collating;
			if ( sets::isin( $servicePrice{'units'}, 'per m', 'per 1000' )  ) {
				$price{Service} = $servicePrice{'Price'}/1000; # Service Price for Collating is per 1000
			} else {
				$$specs{'alert'} .= 'Unknown units in service price.<br/>';
			} # end if
			$price{'Total'} = $price{'MakeReady'} + $qty * $price{'Service'};

			if ( ! $bestPrice{'Total'} or $price{'Total'} < $bestPrice{'Total'} ) {
				%bestPrice = %price;
			} # end if
			$$specs{'hdnBreakdown'.$qty_index} .= 'Equipment ' . $price{'Equipment'}->name() . ":<br/>Make Ready: $price{'MakeReady'}, Service: $servicePrice{'Price'} $servicePrice{'units'}<br/>";
		} # end foreach equipment

		if ( ! $bestPrice{'Equipment'} ) {
			$status = 'uncalculated';
		} # end if
		$$specs{"ddmEquipment$qty_index"} = $bestPrice{'Equipment'}->id();
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $bestPrice{'Service'} * (1+$Project->markup()/100) );
		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $bestPrice{'Total'} * (1+$Project->markup()/100) );
	} # end foreach qty_index

	$log->debug("COLLATING!!!!!!!!!!!!!!!!!!");
	return $$specs{Status} = $status;
} # end sub calc

sub display {
    my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	my @equipment = openprint::Equipment->find( 'Specifications' => {'Collating Capable'=>['Y','When Printing']}, 'useinestimating'=>1,'order'=>'strName');
	foreach my $qty_index ( $Project->quantity_indexes() ) {	
		$$variable{'ddmEquipment'.$qty_index} = ssi::make_drop_down( [ map { $_->id(), $_->name() } @equipment ], $$variable{'ddmEquipment'.$qty_index} );
	} # end foreach qty_index

} # end sub display

sub summary {
	return;
}

1;
__END__
