package openprint::Estimating::ClipSealing;
use strict;
use warnings;

use POSIX            qw(ceil);
require openprint::service;

my @variables = (
	'SealQuantity',
	'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
	'txtPrice1', 'txtPrice2', 'txtPrice3',
);

sub variables {
	return @variables;
} # end sub variables

sub calc {
    my ($log, $dbh, $variable, $pid, $sid, $specs) = @_;

	my $Project = new openprint::Project( $pid );

	if ( ! $$specs{'SealQuantity'} ) {
		$$specs{'alert'} = 'Please enter the # of clips.<br/>';
		return 'uncalculated';
	} # end if

	my $status = 'calculated';
	my @equipment = openprint::Equipment::find( 'Specifications'=>{'ClipSealing Capable'=>'Y'},'use_in_estimating'=>1);
	if ( ! @equipment ) {
		$$specs{'alert'} = 'We have no clip sealing equipment.<br/>';
		return 'uncalculated';
	} # end if

    foreach my $qty_index (1 .. 3) {
        next if ! $Project->quantity($qty_index);
		$$specs{'txtQuantity'.$qty_index} = $Project->quantity() if ! $$specs{'txtQuantity'.$qty_index};

		my %BestPrice;

		foreach my $Equipment ( @equipment ) {
			my $clips_per_run = $Equipment->specification('Clips Per Run');
			next if $clips_per_run;
			my $runs = ceil( $$specs{'SealQuantity'} / $clips_per_run );

			my %MakeReadyPrice = openprint::service::get_price_object( 'ClipSealingMakeReady', undef, $Equipment );
			my %ServicePrice = openprint::service::get_price_object('ClipSealing'.$$specs{'SealType'}, $runs, $Equipment );

			if ( $ServicePrice{'units'} eq 'Per M' ) {
				$ServicePrice{'Total'} = $ServicePrice{Price} * $$specs{'txtQuantity'.$qty_index} * $runs/ 1000;
			} # end if

			my $totalPrice = $MakeReadyPrice{'Price'} + $ServicePrice{'Total'};
			my $min_price  = openprint::service::get_price('ClipSealingMinimumCharge', undef, $Equipment );
			$totalPrice = $min_price if $totalPrice < $min_price;
			if ( (!defined $BestPrice{Total}) or $totalPrice < $BestPrice{Total} ) {
				$BestPrice{'Total'} = $totalPrice;
				$BestPrice{'Equipment'} = $Equipment;
				$BestPrice{'ServicePrice'} = $ServicePrice{'Total'};
			} # end if
		} # end foreach Equipment

		if ( ! defined $BestPrice{'Total'} ) {
			$$specs{'alert'} .= 'Unable to calculate a price for quantity ' . $qty_index . '.<br/>';
			$status = 'uncalculated';
		} # end if

        $$specs{"txtUnitPrice$qty_index"} = sprintf('%.2f', $BestPrice{'ServicePrice'} / $$specs{'txtQuantity'.$qty_index} );
		$$specs{'txtPrice'.$qty_index} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $BestPrice{'Total'} );
		$$specs{'ddmEquipment'.$qty_index} = $BestPrice{'Equipment'}->id();

    } # end foreach qty_index
    
    return $status;
} # end sub calc

sub summary {
} # end sub summary

1;
