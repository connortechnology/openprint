package openprint::Estimating::SoftFolding;
use strict;
use warnings;
no warnings qw(uninitialized);

require openprint::service;
use sql;
use POSIX           qw(ceil);

my $debug = 1;

my %variables = (
	'Folds' => ['save'],
	'ddmEquipment1' => ['save','output'], 'ddmEquipment2' => ['save','output'], 'ddmEquipment3' => ['save','output'],
	'txtPrice1' => ['save','output'], 'txtPrice2' => ['save','output'], 'txtPrice3' => ['save','output'],
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

	$$specs{'Folds'} =~ s/\D//g;
	if ( ! $$specs{'Folds'} ) {
		$$specs{'alert'} = 'Please enter the # of folds.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	my @Equipment = openprint::Equipment::find('Specifications'=>{'SoftFolding Capable'=>'Y'},'use_in_estimating'=>1);
	if ( ! @Equipment ) {
		$$specs{'alert'} = 'We have no soft folding equipment.';
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

			my $total = 0;

			my %MakeReady = openprint::service::get_price_object('SoftFoldingMakeReady', undef, $Equipment );
			if ( ! %MakeReady ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No MakeReady price.<br/>';
			} else {
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('MakeReady Price: $%1$.2f%2$s<br/>', @MakeReady{'Price','units'} );
				$total += $MakeReady{'Price'};
			} # end if

			my %ServicePrice = openprint::service::get_price_object('SoftFolding',$$specs{'Folds'}, $Equipment ); 
			if ( ! %ServicePrice ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No Service price.<br/>';
			} else {
				$ServicePrice{'Total'} += $ServicePrice{'Price'} * $$specs{'Folds'} * $$specs{'txtQuantity'.$qty_index} / 1000;
				$total += $ServicePrice{'Total'};
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service Price: %4$d folds : $%1$.2f%2$s = $%3$.2f<br/>', @ServicePrice{'Price','units','Total'}, $$specs{'Folds'} );
			} # end if

			if ( my $minimumcharge = openprint::service::get_price('SoftFoldingMinimumCharge', undef, $Equipment ) ) {
				$total = $minimumcharge if $total < $minimumcharge;
			} # end if
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Total: $%.2f<br/>', $total );
			
			if ( ( ! defined $BestPrice{'Total'} ) or $total < $BestPrice{'Total'} ) {
				$BestPrice{'Total'} = $total;
				$BestPrice{'Equipment'} = $Equipment;
				$BestPrice{'ServicePrice'} = \%ServicePrice;
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

	if ( $qty_index ) {
		if ( $$specs{'ddmEquipment'.$qty_index} ) {
			my $Equipment = new openprint::Equipment( $$specs{'ddmEquipment'.$qty_index} );
			return ' on ' . $Equipment->name();
		} # end if
		return '';
	} # end if
	$specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;

	return '';
} # end sub summary

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my @possible_equipment = openprint::Equipment::find( 'Specifications' => {'SoftFolding Capable'=>'Y'}, 'use_in_estimating'=>1,'order'=>'lower(strName)');
	#my @possible_equipment = openprint::Equipment::find( 'Specifications' => {'ClipSealing Capable'=>'Y'}, 'use_in_estimating'=>1,'order'=>'lower(strName)');
	@{$$variable{'Equipment'}} = @possible_equipment;
} # end sub display

1;
__END__
