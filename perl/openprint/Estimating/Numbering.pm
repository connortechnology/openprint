package openprint::Estimating::Numbering;
use strict;
use warnings;
no warnings qw(uninitialized);

require openprint::service;
use sql;
use POSIX           qw(ceil);

my $debug = 1;
my @variables = (
	'SetsOfNumbers',
	'Equipment1', 'Equipment2', 'Equipment3',
	'txtPrice1', 'txtPrice2', 'txtPrice3',
	'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
);

sub calc {
    my ($log, $dbh, $variable, $pid, $sid, $specs) = @_;

	my $Project = new openprint::Project( $pid );

	$$specs{'SetsOfNumbers'} =~ s/\D//g;
	if ( ! $$specs{'SetsOfNumbers'} ) {
		$$specs{'alert'} = 'Please enter the # of sets of numbers.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	my @Equipment = openprint::Equipment::find('Numbering Capable'=>'Y');
	if ( ! @Equipment ) {
		$$specs{'alert'} = 'Please enter the # of sets of numbers.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	my $status = 'calculated';

	foreach my $qty_index ( 1 .. 3 ) {
		$$specs{'txtQuantity'.$qty_index} = $Project->quantity( $qty_index ) if ! $$specs{'txtQuantity'.$qty_index};
		next if ! $$specs{'txtQuantity'.$qty_index};

		my %BestPrice;

		foreach my $Equipment ( @Equipment ) {
			$$specs{'hdnBreakdown'.$qty_index} .= '<fieldset><legend>'.$Equipment->name().'</legend>';
			my $heads = $Equipment->specification('Heads');
			if ( ! $heads ) {
				$$specs{'hdnBreakdown'.$qty_index} = 'No numbering heads specified.<br/>';
				next;
			} # end if

			my $runs = ceil($$specs{'SetsOfNumbers'} / $heads);

			my $last_run = $$specs{'SetsOfNumbers'} % $heads;


			my $total = 0;

			my %MakeReady = openprint::service::get_price_object('NumberingMakeReady', undef, $Equipment );
			if ( ! %MakeReady ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No MakeReady price.<br/>';
			} else {
				$total += $MakeReady{'Price'};
			} # end if

			my %HeadMakeReady = openprint::service::get_price_object('NumberingHeadMakeReady', undef, $Equipment );
			if ( ! %HeadMakeReady ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No HeadMakeReady price.<br/>';
			} else {
				$total += $HeadMakeReady{'Price'} * $$specs{'SetsOfNumbers'};
			} # end if

			my %ServicePrice = openprint::service::get_price_object('Numbering',$heads, $Equipment ); 
			if ( ! %ServicePrice ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No Service price.<br/>';
			} else {
				$ServicePrice{'Total'} += $ServicePrice{'Price'} * $runs * $$specs{'txtQuantity'.$qty_index} / 1000;
				$total += $ServicePrice{'Total'};
			} # end if

			my %LastServicePrice = openprint::service::get_price_object('Numbering',$last_run, $Equipment );
			if ( ! %LastServicePrice ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No Service price.<br/>';
			} else {
				$LastServicePrice{'Total'} += $LastServicePrice{'Price'} * $$specs{'txtQuantity'.$qty_index} / 1000;
				$total += $LastServicePrice{'Total'};
			} # end if
			
			if ( my $minimumcharge = openprint::service::get_price('NumberingMinimumCharge', undef, $Equipment ) ) {
				$total = $minimumcharge if $total < $minimumcharge;
			} # end if
			
			if ( ( ! defined $BestPrice{'Total'} ) or $total < $BestPrice{'Total'} ) {
				$BestPrice{'Total'} = $total;
			} # end if
        } # end foreach Equipment

		if ( ! defined $BestPrice{'Total'} ) {
			$status = 'calculated';
		} else {
			$$specs{'Equipment'.$qty_index} = $BestPrice{'Equipment'}->id();
		} # end if

        #$$specs{"txtUnitPrice$qty_index"} = sprintf('%.2f', ($BestPrice{'ServicePrice'}{'Total'} + $BestPrice{'MaterialPrice'}{'Total'} ) / $$specs{'txtQuantity'.$qty_index} );
		$$specs{'txtPrice'.$qty_index} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $BestPrice{'Total'} );

    } # end foreach qty_index
    return $status;
} # end sub calc

sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;

	if ( $qty_index ) {
		return '';
	} # end if
	$specs = openprint::service::get_specs_ref( $Project, $service_id ) if ( ! $specs );

	return '';
} # end sub summary

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my @possible_equipment = openprint::Equipment::find( 'Specifications' => {'Numbering Capable'=>'Y'}, 'use_in_estimating'=>1,'order'=>'lower(strName)');
	#my @possible_equipment = openprint::Equipment::find( 'Specifications' => {'ClipSealing Capable'=>'Y'}, 'use_in_estimating'=>1,'order'=>'lower(strName)');
	@{$$variable{'Equipment'}} = @possible_equipment;
}

1;
