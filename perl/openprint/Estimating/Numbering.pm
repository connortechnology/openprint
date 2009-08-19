package openprint::Estimating::Numbering;
use strict;
use warnings;
no warnings qw(uninitialized);

require openprint::service;
use sql;
use POSIX           qw(ceil);

my $debug = 1;

my %variables = (
	'SetsOfNumbers' => ['save'],
	'ddmEquipment1' => ['save','output'], 'ddmEquipment2' => ['save','output'], 'ddmEquipment3' => ['save','output'],
	'OverridePrice1' => ['save'], 'OverridePrice2' => ['save'], 'OverridePrice3' => ['save'],
	'Markup1' => ['save'], 'Markup2' => ['save'], 'Markup3' => ['save'],
	'txtPrice1' => ['save','output'], 'txtPrice2' => ['save','output'], 'txtPrice3' => ['save','output'],
	'MPrice1'	=> ['save','output'], 'MPrice2'	=> ['save','output'], 'MPrice3'	=> ['save','output'], 
	'txtQuantity1' => ['save'], 'txtQuantity2' => ['save'], 'txtQuantity3' => ['save'],
);
sub variables {
    my @v;
    foreach my $k ( keys %variables ) {
        push @v, $k if sets::isin( 'save', $variables{$k} );
    } # end foreach;
    return @v;
}

sub no_outputs {
    my @v;
    foreach my $k ( keys %variables ) {
        push @v, $k if ! sets::isin( 'output', $variables{$k} );
    } # end foreach;
    return @v;
}


sub calc {
    my ($log, $dbh, $variable, $pid, $sid, $specs) = @_;

	my $Project = new openprint::Project( $pid );

	$$specs{'SetsOfNumbers'} =~ s/\D//g;
	if ( ! $$specs{'SetsOfNumbers'} ) {
		$$specs{'alert'} = 'Please enter the # of sets of numbers.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	my @Equipment = openprint::Equipment::find('Specifications'=>{'Numbering Capable'=>'Y'},'use_in_estimating'=>1);
	if ( ! @Equipment ) {
		$$specs{'alert'} = 'We have no numbering equipment.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	my $status = 'calculated';

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$specs{"txtPrice$qty_index"} =~ s/[^\d\.]//g;
		$$specs{"txtPrice$qty_index"} =~ s/[^\d\.\-]//g;
		$$specs{'txtQuantity'.$qty_index} = $Project->quantity( $qty_index ) if ! $$specs{'txtQuantity'.$qty_index};

		my %BestPrice;
		$$specs{'hdnBreakdown'.$qty_index} = '';

		foreach my $Equipment ( @Equipment ) {
			$$specs{'hdnBreakdown'.$qty_index} .= '<fieldset><legend>'.$Equipment->name().'</legend>';
			my $heads = $Equipment->specification('Heads');
			if ( ! $heads ) {
				$$specs{'hdnBreakdown'.$qty_index} = 'No numbering heads specified.<br/></fieldset>';
				next;
			} # end if
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Heads: %d<br/>',$heads);

			my $runs = ceil($$specs{'SetsOfNumbers'} / $heads);
			my $last_run = $$specs{'SetsOfNumbers'} % $heads;
			my $total = 0;
			my $mprice = 0;

			my %MakeReady = openprint::service::get_price_object('NumberingMakeReady', undef, $Equipment );
			if ( ! %MakeReady ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No MakeReady price.<br/>';
			} else {
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('MakeReady Price: $%1$.2f%2$s<br/>', @MakeReady{'Price','units'} );
				$total += $MakeReady{'Price'};
			} # end if

			my %HeadMakeReady = openprint::service::get_price_object('NumberingHeadMakeReady', undef, $Equipment );
			if ( ! %HeadMakeReady ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No HeadMakeReady price.<br/>';
			} else {
				$HeadMakeReady{'Total'} = $HeadMakeReady{'Price'} * $$specs{'SetsOfNumbers'};
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('HeadMakeReady Price: $%1$.2f%2$s * %4$d sets = $%3$.2f<br/>', @HeadMakeReady{'Price','units','Total'}, $$specs{'SetsOfNumbers'},  );
				$total += $HeadMakeReady{'Total'};
			} # end if

			my %ServicePrice = openprint::service::get_price_object('Numbering',$heads, $Equipment ); 
			if ( ! %ServicePrice ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No Service price.<br/>';
			} else {
				$ServicePrice{'Total'} += $ServicePrice{'Price'} * $runs * $$specs{'txtQuantity'.$qty_index} / 1000;
				$total += $ServicePrice{'Total'};
				$mprice += $ServicePrice{'Price'} * $runs;
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service Price: %4$d runs of %5$d numbers : $%1$.2f%2$s = $%3$.2f<br/>', @ServicePrice{'Price','units','Total'}, $runs, $heads );
			} # end if

			my %LastServicePrice;
			if ( $last_run ) {
				%LastServicePrice = openprint::service::get_price_object('Numbering',$last_run, $Equipment );
				if ( ! %LastServicePrice ) {
					$$specs{'hdnBreakdown'.$qty_index} .= 'No Service price.<br/>';
				} else {
					$LastServicePrice{'Total'} += $LastServicePrice{'Price'} * $$specs{'txtQuantity'.$qty_index} / 1000;
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service Price: 1 run of %4$d numbers : $%1$.2f%2$s = $%3$.2f<br/>', @LastServicePrice{'Price','units','Total'}, $last_run );
					$total += $LastServicePrice{'Total'};
				$mprice += $LastServicePrice{'Price'};
				} # end if
			} # end if
			
			if ( my $minimumcharge = openprint::service::get_price('NumberingMinimumCharge', undef, $Equipment ) ) {
				$total = $minimumcharge if $total < $minimumcharge;
			} # end if
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Total: $%.2f<br/>', $total );
			
			if ( ( ! defined $BestPrice{'Total'} ) or $total < $BestPrice{'Total'} ) {
				$BestPrice{'Total'} = $total;
				$BestPrice{'MPrice'} = $mprice;
				$BestPrice{'Equipment'} = $Equipment;
				$BestPrice{'ServicePrice'} = \%ServicePrice;
				$BestPrice{'LastServicePrice'} = \%LastServicePrice;
			} # end if
			$$specs{'hdnBreakdown'.$qty_index} .= '</fieldset>';
        } # end foreach Equipment

		if ( ! defined $BestPrice{'Total'} ) {
			$status = 'uncalculated';
		} else {
			$$specs{'ddmEquipment'.$qty_index} = $BestPrice{'Equipment'}->id();
		} # end if

        $$specs{'txtUnitPrice'.$qty_index} = sprintf($openprint::config{'UnitPriceFormat'}, ($BestPrice{'ServicePrice'}{'Total'} + $BestPrice{'LastServicePrice'}{'Total'} ) / $$specs{'txtQuantity'.$qty_index} );
		$$specs{'MPrice'.$qty_index} = sprintf( $openprint::config{'UnitPriceFormat'}, $BestPrice{'MPrice'}*(1+$$specs{"Markup$qty_index"}/100) );
		if ( $$specs{"OverridePrice$qty_index"} ne 'Y' ) {
		$$specs{'txtPrice'.$qty_index} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $BestPrice{'Total'}*(1+$$specs{"Markup$qty_index"}/100) );
		} else {
		$$specs{'txtPrice'.$qty_index} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{"txtPrice$qty_index"} );
		} # end if
    } # end foreach qty_index
    return $status;
} # end sub calc

sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;

	$specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;
	if ( $qty_index ) {
		if ( $$specs{'ddmEquipment'.$qty_index} ) {
			my $Equipment = new openprint::Equipment( $$specs{'ddmEquipment'.$qty_index} );
			return ' on ' . $Equipment->name();
		} # end if
		return '';
	} # end if

	return sprintf( '%d sets of numbers', $$specs{'SetsOfNumbers'} );;
} # end sub summary

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my @possible_equipment = openprint::Equipment::find( 'Specifications' => {'Numbering Capable'=>'Y'}, 'use_in_estimating'=>1,'order'=>'lower(strName)');
	#my @possible_equipment = openprint::Equipment::find( 'Specifications' => {'ClipSealing Capable'=>'Y'}, 'use_in_estimating'=>1,'order'=>'lower(strName)');
	@{$$variable{'Equipment'}} = @possible_equipment;
} # end sub display

1;
__END__
