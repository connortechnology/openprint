package openprint::Estimating::SoftFolding;
use strict;
use warnings;
no warnings qw(uninitialized);

require openprint::service;
use sql;
use POSIX           qw(ceil);

my $debug = 1;
my @variables = (
	'Folds',
	'Equipment1', 'Equipment2', 'Equipment3',
	'txtPrice1', 'txtPrice2', 'txtPrice3',
	'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
);

sub calc {
    my ($log, $dbh, $variable, $pid, $sid, $specs) = @_;

	my $Project = new openprint::Project( $pid );

	$$specs{'Folds'} =~ s/\D//g;
	if ( ! $$specs{'Folds'} ) {
		$$specs{'alert'} = 'Please enter the # of folds.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	my @Equipment = openprint::Equipment::find('SoftFolding Capable'=>'Y');
	if ( ! @Equipment ) {
		$$specs{'alert'} = 'Please enter the # of folds.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	my $status = 'calculated';

	foreach my $qty_index ( 1 .. 3 ) {
		$$specs{'txtQuantity'.$qty_index} = $Project->quantity( $qty_index ) if ! $$specs{'txtQuantity'.$qty_index};
		next if ! $$specs{'txtQuantity'.$qty_index};

		my %BestPrice;

		foreach my $Equipment ( @Equipment ) {
			$$specs{'hdnBreakdown'.$qty_index} .= '<fieldset><legend>'.$Equipment->name().'</legend>';

			my $total = 0;

			my %MakeReady = openprint::service::get_price_object('SoftFoldingMakeReady', undef, $Equipment );
			if ( ! %MakeReady ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No MakeReady price.<br/>';
			} else {
				$total += $MakeReady{'Price'};
			} # end if

			my %ServicePrice = openprint::service::get_price_object('SoftFolding',$heads, $Equipment ); 
			if ( ! %ServicePrice ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No Service price.<br/>';
			} else {
				$ServicePrice{'Total'} += $ServicePrice{'Price'} * $runs * $$specs{'txtQuantity'.$qty_index} / 1000;
				$total += $ServicePrice{'Total'};
			} # end if

			if ( my $minimumcharge = openprint::service::get_price('SoftFoldingMinimumCharge', undef, $Equipment ) ) {
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

	my @possible_equipment = openprint::Equipment::find( 'Specifications' => {'SoftFolding Capable'=>'Y'}, 'use_in_estimating'=>1,'order'=>'lower(strName)');
	#my @possible_equipment = openprint::Equipment::find( 'Specifications' => {'ClipSealing Capable'=>'Y'}, 'use_in_estimating'=>1,'order'=>'lower(strName)');
	@{$$variable{'Equipment'}} = @possible_equipment;
} # end sub display

1;
__END__
