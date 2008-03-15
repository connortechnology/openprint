package openprint::Estimating::DTaping;
use strict;
use warnings;
no warnings qw(uninitialized);

require openprint::service;
use sql;
use POSIX           qw(ceil);

my $debug = 1;

my %variables = (
	'ddmEquipment1' => ['save','output'], 'ddmEquipment2' => ['save','output'], 'ddmEquipment3' => ['save','output'],
	'txtPrice1' => ['save','output'], 'txtPrice2' => ['save','output'], 'txtPrice3' => ['save','output'],
	'txtQuantity1' => ['save'], 'txtQuantity2' => ['save'], 'txtQuantity3' => ['save'],
);
sub variables {
	my ( $p_id, $s_id, $specs ) = @_;

    my @v;
    foreach my $k ( keys %variables ) {
        push @v, $k if sets::isin( 'save', $variables{$k} );
    } # end foreach;
	my $Project = new openprint::Project( $p_id );
	foreach my $s_s_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $p_id, $s_s_id );
		push @v, "frontquantity-$$sig_specs{'SignatureIndex'}";
	} # end foreach signature
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

	my @Equipment = openprint::Equipment::find('Specifications'=>{'DTaping Capable'=>'Y'},'use_in_estimating'=>1);
	if ( ! @Equipment ) {
		$$specs{'alert'} = 'We have no dtaping equipment.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	my $status = 'calculated';

	foreach my $qty_index ( 1 .. 3 ) {
		$$specs{'txtQuantity'.$qty_index} = $Project->quantity( $qty_index ) if ! $$specs{'txtQuantity'.$qty_index};
		next if ! $$specs{'txtQuantity'.$qty_index};

		my %BestPrice;
		$$specs{'hdnBreakdown'.$qty_index} = '';

		foreach my $Equipment ( @Equipment ) {
			$$specs{'hdnBreakdown'.$qty_index} .= '<fieldset><legend>'.$Equipment->name().'</legend>';
			my $dtapes_per_run = $Equipment->specification('DTapesPerRun');
			if ( ! $dtapes_per_run ) {
				$$specs{'hdnBreakdown'.$qty_index} = 'No numbering dtapes_per_run specified.<br/></fieldset>';
				next;
			} # end if
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Heads: %d<br/>',$dtapes_per_run);

			my $runs = ceil($$specs{''} / $dtapes_per_run);
			my $last_run = $$specs{'SetsOfDTaps'} % $dtapes_per_run;
			my $total = 0;

			my %MakeReady = openprint::service::get_price_object('DTapingMakeReady', undef, $Equipment );
			if ( ! %MakeReady ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No MakeReady price.<br/>';
			} else {
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('MakeReady Price: $%1$.2f%2$s<br/>', @MakeReady{'Price','units'} );
				$total += $MakeReady{'Price'};
			} # end if

			my %HeadMakeReady = openprint::service::get_price_object('DTapingHeadMakeReady', undef, $Equipment );
			if ( ! %HeadMakeReady ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No HeadMakeReady price.<br/>';
			} else {
				$HeadMakeReady{'Total'} = $HeadMakeReady{'Price'} * $$specs{'SetsOfDTaps'};
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('HeadMakeReady Price: $%1$.2f%2$s * %4$d sets = $%3$.2f<br/>', @HeadMakeReady{'Price','units','Total'}, $$specs{'SetsOfDTaps'},  );
				$total += $HeadMakeReady{'Total'};
			} # end if

			my %ServicePrice = openprint::service::get_price_object('DTaping',$dtapes_per_run, $Equipment ); 
			if ( ! %ServicePrice ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No Service price.<br/>';
			} else {
				$ServicePrice{'Total'} += $ServicePrice{'Price'} * $runs * $$specs{'txtQuantity'.$qty_index} / 1000;
				$total += $ServicePrice{'Total'};
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service Price: %4$d runs of %5$d numbers : $%1$.2f%2$s = $%3$.2f<br/>', @ServicePrice{'Price','units','Total'}, $runs, $dtapes_per_run );
			} # end if

			my %LastServicePrice;
			if ( $last_run ) {
				%LastServicePrice = openprint::service::get_price_object('DTaping',$last_run, $Equipment );
				if ( ! %LastServicePrice ) {
					$$specs{'hdnBreakdown'.$qty_index} .= 'No Service price.<br/>';
				} else {
					$LastServicePrice{'Total'} += $LastServicePrice{'Price'} * $$specs{'txtQuantity'.$qty_index} / 1000;
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service Price: 1 run of %4$d numbers : $%1$.2f%2$s = $%3$.2f<br/>', @LastServicePrice{'Price','units','Total'}, $last_run );
					$total += $LastServicePrice{'Total'};
				} # end if
			} # end if
			
			if ( my $minimumcharge = openprint::service::get_price('DTapingMinimumCharge', undef, $Equipment ) ) {
				$total = $minimumcharge if $total < $minimumcharge;
			} # end if
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Total: $%.2f<br/>', $total );
			
			if ( ( ! defined $BestPrice{'Total'} ) or $total < $BestPrice{'Total'} ) {
				$BestPrice{'Total'} = $total;
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

        $$specs{'txtUnitPrice'.$qty_index} = sprintf('%.2f', ($BestPrice{'ServicePrice'}{'Total'} + $BestPrice{'LastServicePrice'}{'Total'} ) / $$specs{'txtQuantity'.$qty_index} );
		$$specs{'txtPrice'.$qty_index} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $BestPrice{'Total'} );

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

	return sprintf( '%d sets of numbers', $$specs{'SetsOfDTaps'} );;
} # end sub summary

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my @possible_equipment = openprint::Equipment::find( 'Specifications' => {'DTaping Capable'=>'Y'}, 'use_in_estimating'=>1,'order'=>'lower(strName)');
	@{$$variable{'Equipment'}} = @possible_equipment;
} # end sub display

1;
__END__
