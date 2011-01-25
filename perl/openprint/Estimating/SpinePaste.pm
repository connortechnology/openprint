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

package openprint::Estimating::SpinePaste;
use strict;

require openprint::service;
require sql;

my @variables = (
'chkOverrideCalliper',
'txtCalliper',
'Trimming','Gluing',
        'ddmEquipment1', 'ddmEquipment2', 'ddmEquipment3',
        'txtPrice1', 'txtPrice2', 'txtPrice3',
        'txtUnitPrice1', 'txtUnitPrice2', 'txtUnitPrice3',
        'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
        'txtRunTime1', 'txtRunTime2', 'txtRunTime3',
        );
sub variables {
    return @variables;
}

sub neccessary {
	my ( $log, $dbh, $project_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	my %services = $Project->get_services();

	if ( $services{'NoBindery'} ) {
        $log->debug(" ** Project is marked as No bindery, Hand Assembly not needed ! ** ");
        return 0;
    } # end if

	my $printing_specs = openprint::service::get_specs_ref( $Project, $services{''}[0] );

    if ( $$printing_specs{'rdbTemplateType'} eq 'SpinePaste' ) {
        return 1;
	} # end if

	return 0;	
} # end sub neccessary

sub signature_calc {
	my ( $Project, $service_index, $I, $specs, $qty_index, $folding_results ) = @_;

	my $services = $Project->services();
	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );
	my @Equipment = openprint::Equipment::find('Specifications'=>{'SpinePaste Capable'=>'Y'});
	my %Results;
	if ( ! @Equipment ) {
		$Results{'Status'} = 'uncalculated';
		$Results{'alert'} .= 'No equipment for Spine Pasting';
		return \%Results;
	} # end if

	my %best;
	foreach my $Equipment ( @Equipment ) {
		if ( $Equipment->specification('Type') eq 'Press' ) {
# Inline pasting
			if ( $Equipment->id() != $I->Press()->id() ) {
				$openprint::log->debug('Not printing on ' . $Equipment->strid() . '<br/>' );
				next;
			} # end if
			if ( $Equipment->specification('SpinePaste Maximum Imposition') and $I->imposition() > $Equipment->specification('SpinePaste Maximum Imposition') ) {
				$openprint::log->debug('Imposition too large ' . $I->imposition() . '>' . $Equipment->specification('SpinePaste Maximum Imposition') . " for " . $Equipment->strid() .'<br/>' );
				next;
			} # end if
			if ( $Equipment->specification('SpinePaste Maximum Pages') and $I->pages() > $Equipment->specification('SpinePaste Maximum Pages') ) {
				$openprint::log->debug('Too many Pages ' . $I->pages() . '>' . $Equipment->specification('SpinePaste Maximum Pages') . " for " . $Equipment->strid() . '<br/>' );
				next;
			} # end if
			if ( $I->image_orientation() ne 'Vertical' ) {
				$openprint::log->debug('Can only spine paste a vertical spine. <br/>' );
				next;
			} # end if
			if ( ! $service_index ) {
				$openprint::log->debug('Can only spine paste 1 signature for ' . $Equipment->strid() . '<br/>' );
				next;
			} # end if
			my $sigs = 1;
			foreach my $ss_id ( $Project->signatures() ) {
				$sigs += 1 if ( $ss_id < $service_index );
			} # end foreach
			if ( $sigs > 1 ) {
				$openprint::log->debug("Can only spine paste 1 signature for " . $Equipment->strid() . '<br/>' );
				next;
			} # end if
			if ( ( ! $$folding_results{'Equipment'} ) or ( $$folding_results{'Equipment'}->id() != $Equipment->id() ) ) {
				$openprint::log->debug( "Must also be folded on $$Equipment{strid}.");
				next;
			} # end if
		} # end if
		my %Price = calc_price( $$specs{'txtQuantity'.$qty_index}, $Equipment, $I->pages(), $I->imposition(), $$folding_results{'RunSpeed'}, $services, $specs );
		if ( (!defined $best{'Price'}) or ($Price{'Total'} < $best{'Price'}{'Total'}) ) {
			$best{'Price'} = \%Price;
			$best{'Equipment'} = $Equipment;
		} # end if
	} # end foreach Equipment
	if ( ! %best ) {
$openprint::log->debug("Nopt best");
		$Results{'Status'} = 'uncalculated';
		$Results{'alert'} .= 'Unable to calculate.<br/>';
	} else {
$openprint::log->debug("best %best");
		$Results{'Status'} = 'calculated';
		$Results{'Equipment'} = $best{'Equipment'};
		$Results{'Price'} = $best{'Price'}{'Total'};
		$Results{'RunSpeed'} = $best{'Price'}{'RunSpeed'};
		$Results{'MakeReadyTime'} = $best{'Price'}{'MakeReadyTime'};
		$Results{'MakeReadyOvers'} = $best{'Price'}{'MakeReadyOvers'};
	} # end if
	return \%Results;

} # end sub signature_calc

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $Project = new openprint::Project( $project_index );

	if ( $$specs{'chkOverrideCalliper'} ne 'Y' ) {
		$$specs{'txtCalliper'} = openprint::print::get_finished_calliper( $project_index );
	} # end if

	my @Equipment = openprint::Equipment::find('Specifications'=>{'SpinePaste Capable'=>'Y'});
	if ( ! @Equipment ) {
		$$specs{'alert'} .= 'We are unable to automatically provide a price for Spine Pasting.  You may enter your own price in the price fields, or contact your CSR for a quote.';

		foreach my $qty_index ( $Project->quantity_indexes() ) {
			$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
			my $qty = $$specs{'txtQuantity'.$qty_index};
			if ( $qty and ! $$specs{'txtPrice'.$qty_index} ) {
				return $$specs{'Status'} = 'uncalculated';
			} # end if
		} # end foreach
		
		return $$specs{'Status'}='calculated';
	} # end if

	my $services = $Project->services();
	if ( ! ($$services{'Folding'} and @{$$services{'Folding'}} ) ) {
		$$specs{'alert'} .= 'Project does not have a folding service.  Folding is required.<br/>';
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	my $pages = 0;
	if ( $$services{''} ) {
		my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );
		$pages = $$printing_specs{'txtTotalPageQuantity'};
	} # end if
	my @sigs = $Project->signatures();

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		my $qty = $$specs{'txtQuantity'.$qty_index};

		my $imposition = 0;
		foreach my $ss_id ( @sigs ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
			my $I = new openprint::Imposition;
			$I->load( $sig_specs, $qty_index );	
			$imposition = $I->imposition() if $I->imposition() < $imposition;
		} # end foreach

		my %best;
		

		foreach my $Equipment ( @Equipment ) {
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Equipment: %s %s<br/>', $Equipment->strid(), $Equipment->name() );

			if ( $Equipment->specification('Type') eq 'Press' ) {
# Inline pasting
				if ( @sigs > 1 ) {
					$openprint::log->debug('Can only spine paste 1 signature for ' . $Equipment->strid() );
					next;
				} # end if
				my $sig_specs = openprint::service::get_specs_ref( $Project, $sigs[0] );
				my $I = new openprint::Imposition();
				$I->load( $sig_specs, $qty_index );	
				$$specs{'hdnBreakdown'.$qty_index} .= $I->to_string() . '<br/>';
				if ( $Equipment->strid() ne $$sig_specs{'ddmPress'.$qty_index} ) {
					$$specs{'hdnBreakdown'.$qty_index} .= 'Not printing on ' . $Equipment->strid();
					next;
				} # end if
				if ( $Equipment->specification('SpinePaste Maximum Imposition') and $I->imposition() > $Equipment->specification('SpinePaste Maximum Imposition') ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "Imposition too large " . $I->imposition() . '>' . $Equipment->specification('SpinePaste Maximum Imposition') . " for " . $Equipment->strid();
					next;
				} # end if
				if ( $Equipment->specification('SpinePaste Maximum Pages') and $Equipment->specification('SpinePaste Maximum Pages') and $I->pages() > $Equipment->specification('SpinePaste Maximum Pages') ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "Too many pages for " . $Equipment->strid();
					next;
				} # end if
				if ( $I->image_orientation() ne 'Vertical' ) {
					$$specs{'hdnBreakdown'.$qty_index} .= 'Can only spine paste a vertical spine. <br/>';
					next;
				} # end if
				my %folding_results;
				my $folding_specs = openprint::service::get_specs_ref( $Project, $$services{'Folding'}[0] );
				$folding_results{'Equipment'} = new openprint::Equipment( $$folding_specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
				if ( $folding_results{'Equipment'}->id() != $Equipment->id() ) {
					$$specs{'hdnBreakdown'.$qty_index} .='Must also be folded on ' . $Equipment->strid();
					next;
				} # end if
				$imposition = $I->imposition();
			} # end if is a press
			my %Price = calc_price( $qty, $Equipment, $pages, $imposition, undef, $services, $specs );
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Run Speed: %d/hr<br/>', $Price{'RunSpeed'} );
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('MakeReady: $%.2f<br/>', $Price{'MakeReady'}{'Price'} );
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('MakeReadyTime: %dminutes<br/>', $Price{'MakeReadyTime'} );
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('MakeReady Overs: %d<br/>', $Price{'MakeReadyOvers'} );
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service Price: $%.2f%s for %d = $%.2f<br/>', $Price{'ServicePrice'}{'Price'},$Price{'ServicePrice'}{'units'},$qty, $Price{'ServicePrice'}{'Total'} );
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Trimming Price: $%.2f%s for %d = $%.2f<br/>', $Price{'TrimmingPrice'}{'Price'},$Price{'TrimmingPrice'}{'units'},$qty, $Price{'TrimmingPrice'}{'Total'} );
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Trimming MakeReady: $%.2f<br/>', $Price{'TrimmingMakeReady'}{'Price'} );
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Trimming MakeReady Time: %dminutes<br/>', $Price{'TrimmingMakeReadyTime'} );
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Total: $%.2f<br/>', $Price{'Total'} );

			if ( (!defined $best{'Price'}) or $Price{'Total'} < $best{'Price'}{'Total'} ) {
				$best{'Price'} = \%Price;
				$best{'Equipment'} = $Equipment;
			} # end if
		} # end foreach Equipment

		if ( ! %best ) {
			$$specs{'ddmEquipment'.$qty_index} = '';
			$$specs{"txtPrice$qty_index"} = '';
			$$specs{"txtUnitPrice$qty_index"} = '';
			$$specs{'Status'} = 'uncalculated';
			$$specs{'alert'} = 'Unable to calculate.<br/>';
		} else {
			$$specs{'ddmEquipment'.$qty_index} = $best{'Equipment'}->id();
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $best{'Price'}{'Total'} );
			$$specs{"txtUnitPrice$qty_index"} = sprintf( '%.2f', $best{'Price'}{'ServicePrice'}{'Total'} / $qty ) if $qty;
			$$specs{'Status'} = 'calculated';
		} # end if
    } # end foreach qty_index

	$log->debug(" END Spine Paste!!!!!!!!!!!!!!!!! Status: $$specs{'Status'}");
	return $$specs{'Status'};
} # end sub calc

sub calc_price {
	my ( $qty, $Equipment, $pages, $imposition, $runspeed, $services, $specs ) = @_;
	my %Price;
	my %MakeReady;
	my %ServicePrice;
	$Price{'RunSpeed'} = $runspeed;

	if ( $$specs{'Gluing'} ne 'N' ) {
		if ( ! ( %MakeReady = openprint::service::get_price_object( $openprint::log, $openprint::dbh, $openprint::variable,  'SpinePasteMakeReady'.$pages.'Page'.$imposition.'out', $qty, $Equipment ) ) ) {
			if ( ! ( %MakeReady = openprint::service::get_price_object( $openprint::log, $openprint::dbh, $openprint::variable,'SpinePasteMakeReady'.$pages.'Page', $qty, $Equipment ) ) ) {
				%MakeReady = openprint::service::get_price_object( $openprint::log, $openprint::dbh, $openprint::variable,'SpinePasteMakeReady', $qty, $Equipment );
			} # end if
		} # end if
		$Price{'MakeReady'} = \%MakeReady;
		
		$Price{'MakeReadyTime'} = $Equipment->specification('SpinePaste MakeReady Time');
		$Price{'MakeReadyOvers'} = $Equipment->specification('SpinePaste MakeReady Overs');

		$openprint::log->debug("Starting Runspeed $runspeed ");
		if ( ( my $RunSpeed = $Equipment->Specification('SpinePaste RunSpeed') ) ) {
			if ( $RunSpeed->units() eq 'Percent' ) {
				$Price{'Gluing RunSpeed'} = $runspeed * ( 1 + $RunSpeed->value()/100 );
			} else {
				$Price{'Gluing RunSpeed'} = $RunSpeed->value();
			} # end if
		} else {
			$openprint::log->debug("No Runspeed set");
		} # end if Runspeed
		if ( ( my $MaxRunSpeed = $Equipment->specification('SpinePaste Maximum RunSpeed') ) ) {
$openprint::log->debug("Max run speed $MaxRunSpeed");
			$Price{'Gluing RunSpeed'} = $MaxRunSpeed;
		} # end if Maximum Run SPeed
		$openprint::log->debug("Runspeed is " . $Price{'Gluing RunSpeed'});
		if ( $Price{'Gluing RunSpeed'} and ( ( ! $Price{'RunSpeed'} ) or ( $Price{'Gluing RunSpeed'} < $Price{'RunSpeed'} ) ) ) {
			$Price{'RunSpeed'} = $Price{'Gluing RunSpeed'};
		} #  end if
		if ( ! ( %ServicePrice = openprint::service::get_price_object( $openprint::log, $openprint::dbh, $openprint::variable, 'SpinePaste'.$pages.'Pages'.$imposition.'out', $qty, $Equipment ) ) ) {
			if ( ! ( %ServicePrice = openprint::service::get_price_object( $openprint::log, $openprint::dbh, $openprint::variable, 'SpinePaste'.$pages.'Pages', $qty, $Equipment ) ) ) {
				%ServicePrice = openprint::service::get_price_object( $openprint::log, $openprint::dbh, $openprint::variable, 'SpinePaste', $qty, $Equipment );
			} # end if
		} # end if
		if ( $ServicePrice{'units'} eq 'Per M' ) {
			$ServicePrice{'Total'} = $ServicePrice{'Price'} * $qty / 1000;
		} # end if
		$Price{'ServicePrice'} = \%ServicePrice;
	$Price{'Total'} = $MakeReady{'Price'} + $ServicePrice{'Total'};
	} # end if

	if ( $$specs{'Trimming'} ne 'N' ) {
		my %TrimmingMakeReady;
		if ( %TrimmingMakeReady = openprint::service::get_price_object( $openprint::log, $openprint::dbh, $openprint::variable, 'SpinePasteTrimmingMakeReady', undef, $Equipment ) ) {
			$Price{'TrimmingMakeReady'} = \%TrimmingMakeReady;
			$Price{'Total'} += $TrimmingMakeReady{'Price'};
		} # end if
		my %TrimmingPrice;
		if ( %TrimmingPrice = openprint::service::get_price_object( $openprint::log, $openprint::dbh, $openprint::variable, 'SpinePasteTrimming', $qty, $Equipment ) ) {
			$Price{'TrimmingPrice'} = \%TrimmingPrice;
			$openprint::log->debug("Trimming price: $TrimmingPrice{'Price'} - $ServicePrice{'Price'}");
			$TrimmingPrice{'Price'} -= $ServicePrice{'Price'};
			if ( $TrimmingPrice{'units'} eq 'Per M' ) {
				$TrimmingPrice{'Total'} = $TrimmingPrice{'Price'} * $qty / 1000;
			} # end if
			$Price{'Total'} += $TrimmingPrice{'Total'};
		} # end if
		if ( ( my $RunSpeed = $Equipment->Specification('Trimming RunSpeed') ) ) {
			if ( $RunSpeed->units() eq 'Percent' ) {
				$Price{'Trimming RunSpeed'} = $runspeed * ( 1 + $RunSpeed->value()/100 );
			} else {
				$Price{'Trimming RunSpeed'} = $RunSpeed->value();
			} # end if
		} else {
			$openprint::log->debug("No Runspeed set for Trimmign");
		} # end if Runspeed
		if ( ( my $MaxRunSpeed = $Equipment->specification('Trimming Maximum RunSpeed') ) ) {
$openprint::log->debug("Max run speed $MaxRunSpeed");
			$Price{'Trimming RunSpeed'} = $MaxRunSpeed;
		} # end if Maximum Run SPeed
		$openprint::log->debug("Runspeed is " . $Price{'Trimming RunSpeed'});
		if ( $Price{'Trimming RunSpeed'} and ( ( ! $Price{'RunSpeed'} ) or ( $Price{'Trimming RunSpeed'} < $Price{'RunSpeed'} ) ) ) {
			$Price{'RunSpeed'} = $Price{'Trimming RunSpeed'};
		} #  end if
	} # end if
	return %Price;
} # end sub calc_price

sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;

	if ( $qty_index ) {
		return '';
	} # end if
	my $html = 'Paste' if $$specs{'Trimming'} ne 'N';
	if ( $$specs{'Gluing'} ne 'N' ) {
		$html .= ' + ' if $html;
		$html .= 'Trim' 
	} # end if
	return $html;
} # end sub summary

1;

__END__
