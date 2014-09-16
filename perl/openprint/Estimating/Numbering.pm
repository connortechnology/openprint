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
package openprint::Estimating::Numbering;
use strict;

require openprint::service;
require openprint::Project;
use POSIX           qw(ceil);

use constant DEBUG => 0;

my %variables = (
	'SetsOfNumbers' => ['save'],
	'colour'		=> ['save'],
	'OverridePrice1' => ['save'], 'OverridePrice2' => ['save'], 'OverridePrice3' => ['save'],
	'Markup1' => ['save'], 'Markup2' => ['save'], 'Markup3' => ['save'],
	'txtPrice1' => ['save','output'], 'txtPrice2' => ['save','output'], 'txtPrice3' => ['save','output'],
	'MPrice1'	=> ['save','output'], 'MPrice2'	=> ['save','output'], 'MPrice3'	=> ['save','output'], 
	'txtQuantity1' => ['save'], 'txtQuantity2' => ['save'], 'txtQuantity3' => ['save'],
);

sub variables {
	my ( $pid, $sid, $specs ) = @_;
    my @v;
    foreach my $k ( keys %variables ) {
        push @v, $k if sets::isin( 'save', $variables{$k} );
    } # end foreach;
	my $Project = new openprint::Project( $pid );
	foreach my $ss_id ( $Project->signatures() ) {
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			push @v, "ddmEquipment-$ss_id-$qty_index", "chkOverrideEquipment-$ss_id-$qty_index",
					"txtImposition-$ss_id-$qty_index", "chkOverrideImposition-$ss_id-$qty_index",
		} # end foreach
	} # end foreach my ss_id
    return @v;
} # end sub variables

sub no_outputs {
	my ( $pid, $sid, $specs ) = @_;
    my @v;
    foreach my $k ( keys %variables ) {
        push @v, $k if ! sets::isin( 'output', $variables{$k} );
    } # end foreach;
    return @v;
} # end sub no_outputs

sub calc {
    my ($log, $dbh, $variable, $pid, $sid, $specs) = @_;

	my $Project = new openprint::Project( $pid );

	$$specs{Status} = 'calculated';
	$$specs{SetsOfNumbers} =~ s/\D//g;
	if ( ! $$specs{SetsOfNumbers} ) {
		$$specs{alert} = 'Please enter the # of sets of numbers.';
		return $$specs{Status} = 'uncalculated';
	} # end if
	if ( ! $$specs{colour} ) {
		$$specs{alert} = 'Please select the colour of the numbers.';
		return $$specs{Status} = 'uncalculated';
	} # end if
	foreach my $qty_index ( $Project->quantity_indexes() ) {
		if ( $$specs{"OverridePrice$qty_index"} eq 'Y' ) {
			$$specs{"txtPrice$qty_index"} =~ s/[^\d\.\-]//g;
		} else {
			$$specs{"txtPrice$qty_index"} = 0;
			$$specs{"txtUnitPrice$qty_index"} = 0;
			$$specs{"MPrice$qty_index"} = 0;
		} # end if
		$$specs{'txtQuantity'.$qty_index} = $Project->quantity( $qty_index ) if ! $$specs{'txtQuantity'.$qty_index};
		foreach my $ss_id ( $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
			my $Imposition = new openprint::Imposition()->load( $sig_specs, $qty_index );
			my $Results = signature_calc( $Project, $sid, $specs, $sig_specs, $qty_index, $Imposition );
			if ( ! $Results ) {
				$$specs{alert} .= 'No result from signature_calc.';
				$$specs{Status} = 'uncalculated';
				last;
			} # end if
		
			$$specs{'hdnBreakdown'.$qty_index} .= $$Results{Breakdown};
			if ( $$Results{Equipment} ) {
				$$specs{"ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index"} = $$Results{Equipment}->id();
			} # end if Equipment
			if ( $$Results{Imposition} ) {
				$$specs{"txtImposition-$$sig_specs{SignatureIndex}-$qty_index"} = $$Results{Imposition}->imposition();
				$$specs{"txtLayoutWidth-$$sig_specs{SignatureIndex}-$qty_index"} = $$Results{Imposition}->layout_width();
				$$specs{"txtLayoutHeight-$$sig_specs{SignatureIndex}-$qty_index"} = $$Results{Imposition}->layout_height();
			} # end if
			if ( $$Results{Status} eq 'uncalculated' ) {
				$$specs{Status} = 'uncalculated';
				$$specs{alert} .= $$Results{alert};
				last;
			} # end if

			$$specs{'txtPrice'.$qty_index} += $$Results{total};
			$$specs{'txtUnitPrice'.$qty_index} += $$Results{UnitPrice};
			$$specs{'MPrice'.$qty_index} += $$Results{MPrice};
		} # end foreach signature

		my $markup = $$specs{"Markup$qty_index"} ? $$specs{"Markup$qty_index"} : 0;

		$$specs{'txtUnitPrice'.$qty_index} = sprintf($openprint::config{UnitPriceFormat}, $$specs{'txtUnitPrice'.$qty_index} * (1+$Project->markup()/100) );
		$$specs{'MPrice'.$qty_index} = $$specs{'Markup'.$qty_index} ? sprintf( $openprint::config{UnitPriceFormat}, $$specs{'MPrice'.$qty_index}*(1+$markup/100)*(1+$Project->markup()/100) ) : '0.00';
		if ( $$specs{"OverridePrice$qty_index"} ne 'Y' ) {
			$$specs{'txtPrice'.$qty_index} = sprintf( $openprint::config{ProjectMoneyFormat}, $$specs{'txtPrice'.$qty_index}*(1+$markup/100)*(1+$Project->markup()/100) );
		} else {
			$$specs{'txtPrice'.$qty_index} = sprintf( $openprint::config{ProjectMoneyFormat}, $$specs{"txtPrice$qty_index"} );
		} # end if
    } # end foreach qty_index
	return $$specs{Status};

} # end sub calc

sub signature_calc {
	my ( $Project, $service_index, $specs, $sig_specs, $qty_index, $Imposition ) = @_;

	my %Results;
	my $services = $Project->services();

	$$specs{'txtQuantity'.$qty_index} = $Project->quantity($qty_index) if ! $$specs{'txtQuantity'.$qty_index};

    if ( $$specs{"chkOverrideImposition-$$sig_specs{SignatureIndex}-$qty_index"} eq 'Y' ) {
        if ( $$specs{"txtImposition-$$sig_specs{SignatureIndex}-$qty_index"} > $Imposition->imposition() or $$specs{"txtImposition-$$sig_specs{SignatureIndex}-$qty_index"} <= 0 ) {
            $Results{alert} = 'The specified imposition is not possible.';
            $Results{Status} = 'uncalculated';
            return \%Results;
        } # end if
    } # end if
    my @Impositions = ();
    if ( $$services{Cutting} and @{$$services{Cutting}} ) {
        my @imps = openprint::imposition::get_all_impositions( $Imposition );
        for ( my $i = 0; $i < @imps; $i += 1 ) {
            if ( ( $$specs{"chkOverrideImposition-$$sig_specs{SignatureIndex}-$qty_index"} ne 'Y' )
                    or ( $$specs{"txtImposition-$$sig_specs{SignatureIndex}-$qty_index"} == $imps[$i]->imposition() )
               ) {
                push @Impositions, $imps[$i];
            } # end if
            for ( my $j = $i + 1; $j < @imps; $j += 1 ) {
                if ( $imps[$i]->imposition() == $imps[$j]->imposition() and $imps[$i]->rows() == $imps[$j]->rows() ) {
                    splice @imps, $j, 1;
                    $j -= 1;
                } # end if
            } # end foreach
        } # end foreach
    } else {
        @Impositions = ( $Imposition );
    } # end if

	my @Equipment;
	if ( $$specs{"chkOverrideEquipment-$$sig_specs{SignatureIndex}-$qty_index"} eq 'Y' ) {
		@Equipment = ( new openprint::Equipment($$specs{"ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index"}) );
	} else {
		@Equipment = openprint::Equipment->find( 'Specifications'=>{'Numbering Capable'=>['Y','When Printing']}, 'useinestimating'=>1 );
	} # end if
	if ( ! @Equipment ) {
		$Results{alert} .= 'We have no numbering equipment.';
		$Results{Status} = 'uncalculated';
		return \%Results;
	} # end if

	$Results{Status} = 'calculated';

	my @side_one_colours = openprint::Estimating::Printing::get_colours( $sig_specs, 'SideOne' );
	$openprint::log->debug("@side_one_colours : " . ( sets::intersection( 'Cyan','Magenta','Yellow','Black', @side_one_colours ) ) );
	my $Press = $Imposition->Press();
$openprint::log->debug("Got press $Press for " . $$sig_specs{"ddmPress$qty_index"});
	if ( ! $Press ) {
		$Results{alert} .= 'No press.';
		$Results{Status} = 'uncalculated';
		return \%Results;
	} # end if

	foreach my $Equipment ( @Equipment ) {
		if ( $Equipment->specification('Numbering Capable') eq 'When Printing' ) {
			next if $$Press{id} != $Equipment->id();
		} # end if
		my $heads = $Equipment->specification('Numbering Heads');
		my @colours = split(',', $Equipment->specification('Numbering Colours') );
		$Results{Breakdown} .= '<fieldset><legend>'.$Equipment->name().'</legend>';
		$Results{Breakdown} .= sprintf('Heads: %s<br/>',$heads);
		$Results{Breakdown} .= sprintf('Colours: %s<br/>', join(', ', @colours ) );

		if ( @colours and ! sets::isin( $$specs{colour}, \@colours ) ) {
			$Results{Breakdown} .= $$specs{colour} . ' not in supported colours.<br/></fieldset>';
			next;
		} # end if

		foreach my $I ( @Impositions ) {
			my $Paper = $I->Paper();

			my $runs;
			my $last_run;
			$Results{Breakdown} .= sprintf('<b>Imposition: %dx%d=%dout</b><br/>', $I->get('columns','rows','imposition') ); 

			if ( $Equipment->id() eq $Press->id() and $I->imposition() == $Imposition->imposition() ) {
				$Results{Breakdown} .= 'Numbering while printing.<br/>';
	$openprint::log->debug("@side_one_colours : " . ( sets::intersection( 'Cyan','Magenta','Yellow','Black', @side_one_colours ) ) );
				if ( ! ( 
							sets::isin( $$specs{colour}, \@side_one_colours ) or 
							( 4 == sets::intersection( 'Cyan','Magenta','Yellow','Black', @side_one_colours ) )
					   ) ) {
					$last_run = $$specs{SetsOfNumbers} * $I->imposition();
				} # end if
			} else {
				if ( $_ = $Equipment->specification('Maximum Calliper') and ( $$Paper{calliper} > $_ ) ) {
					$Results{Breakdown} .= "Too thick Max: $_, Stock: " . $$Paper{calliper} . '<br/>';
					$last_run = $$specs{SetsOfNumbers};
					last;
				} # end if
				if ( $_ = $Equipment->fits( $I->layout_width(), $I->layout_height(), $Paper->calliper() ) ) {
					$Results{Breakdown} .= "$_<br/>";
					$last_run = $$specs{SetsOfNumbers};
					next;
				} # end if

				if ( $heads ) {
					$runs = int($$specs{SetsOfNumbers} / $heads);
					$last_run = $$specs{SetsOfNumbers} % $heads;
				} else {
					$last_run = $$specs{SetsOfNumbers};
				} # end if
			} # end if
			my $total = 0;
			my $mprice = 0;
			my $qty = ceil($$specs{'txtQuantity'.$qty_index} / $I->imposition());

			my %MakeReady = openprint::service::get_price_object('NumberingMakeReady', undef, $Equipment );
			if ( ! %MakeReady ) {
				$Results{Breakdown} .= 'No MakeReady price.<br/>';
			} else {
				$total += $MakeReady{price};
				$Results{Breakdown} .= sprintf('MakeReady Price: $%1$.2f%2$s<br/>', @MakeReady{'price','units'} );
			} # end if

			my %HeadMakeReady = openprint::service::get_price_object('NumberingHeadMakeReady', undef, $Equipment );
			if ( ! %HeadMakeReady ) {
				$Results{Breakdown} .= 'No HeadMakeReady price.<br/>';
			} else {
				$HeadMakeReady{total} = $HeadMakeReady{price} * $$specs{SetsOfNumbers} * $I->imposition();
				$Results{Breakdown} .= sprintf('HeadMakeReady Price: $%1$.2f%2$s * %4$d sets = $%3$.2f<br/>', @HeadMakeReady{'price','units','total'}, $$specs{SetsOfNumbers},  );
				$total += $HeadMakeReady{total};
			} # end if

			my %ServicePrice;
			if ( $runs ) {
				%ServicePrice = openprint::service::get_price_object('Numbering'.$$specs{colour},$heads, $Equipment ); 
				%ServicePrice = openprint::service::get_price_object('Numbering',$heads, $Equipment ) if ! %ServicePrice;

				if ( ! %ServicePrice ) {
					$Results{Breakdown} .= 'No Service price.<br/>';
				} elsif ( $ServicePrice{units} eq 'per m' ) {
					$ServicePrice{total} += $ServicePrice{price} * $runs * $qty / 1000;
					$total += $ServicePrice{total};
					$mprice += $ServicePrice{price} * $runs / $I->imposition();
					$Results{Breakdown} .= sprintf('Service Price: %4$d runs of %5$d numbers : $%1$.4f%2$s = $%3$.2f<br/>', @ServicePrice{'price','units','total'}, $runs, $heads );
				} elsif ( sets::isin( $ServicePrice{units},[ 'per impression', 'each' ] ) ) {
					$ServicePrice{total} += $ServicePrice{price} * $runs * $qty;
					$total += $ServicePrice{total};
					$mprice += $ServicePrice{price} * $runs / $I->imposition();
					$Results{Breakdown} .= sprintf('Service Price: %4$d runs of %5$d numbers : $%1$.4f%2$s = $%3$.2f<br/>', @ServicePrice{'price','units','total'}, $runs, $heads );
				} # end if
			} # end if

			my %LastServicePrice;
			if ( $last_run ) {
				%LastServicePrice = openprint::service::get_price_object('Numbering'.$$specs{colour},$last_run, $Equipment );
				%LastServicePrice = openprint::service::get_price_object('Numbering',$last_run, $Equipment ) if ! %LastServicePrice;
				if ( ! %LastServicePrice ) {
					$Results{Breakdown} .= 'No Service price.<br/>';
				} elsif ( sets::isin( $LastServicePrice{units},[ 'per m' ] ) ) {
					$LastServicePrice{total} += $LastServicePrice{price} * $qty / 1000;
					$Results{Breakdown} .= sprintf('Service Price: 1 run of %4$d numbers : $%1$.4f%2$s = $%3$.2f<br/>', @LastServicePrice{'price','units','total'}, $last_run );
					$total += $LastServicePrice{total};
					$mprice += $LastServicePrice{price} / $I->imposition();
				} elsif ( sets::isin( $LastServicePrice{units},[ 'per impression', 'each' ] ) ) {
					$LastServicePrice{total} += $LastServicePrice{price} * $qty;
					$total += $LastServicePrice{total};
					$mprice += $LastServicePrice{price} / $I->imposition();
					$Results{Breakdown} .= sprintf('Service Price: 1 run of %4$d numbers : $%1$.4f%2$s = $%3$.2f<br/>', @LastServicePrice{'price','units','total'}, $last_run );
				} # end if
			} # end if

			if ( my $minimumcharge = openprint::service::get_price('NumberingMinimumCharge', undef, $Equipment ) ) {
				$total = $minimumcharge if $total < $minimumcharge;
			} # end if

			$Results{Breakdown} .= sprintf('Total: $%.2f<br/>', $total );

			if ( ( ! defined $Results{total} ) or $total < $Results{total} ) {
				$Results{total} = $total;
				$Results{MPrice} = $mprice;
				$Results{Equipment} = $Equipment;
				$Results{ServicePrice} = \%ServicePrice;
				$Results{LastServicePrice} = \%LastServicePrice;
				$Results{Imposition} = $I;
			} # end if
		} # end foreach Imposition
		$Results{Breakdown} .= '</fieldset>';
	} # end foreach Equipment

	if ( ! defined $Results{total} ) {
		$Results{Status} = 'uncalculated';
	} else {
		$Results{Equipment} = $Results{Equipment};
	} # end if

	$Results{UnitPrice} = ($Results{ServicePrice}{total} + $Results{LastServicePrice}{total} ) / $$specs{'txtQuantity'.$qty_index};

	return \%Results;
} # end sub signature_calc

sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;

	$specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;
	if ( $qty_index ) {
		return '';
	} # end if

	return sprintf( '%d set%s of %s numbers', $$specs{SetsOfNumbers}, ( $$specs{SetsOfNumbers} == 1 ? '' : 's' ), $$specs{colour} );
} # end sub summary

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my @possible_equipment = openprint::Equipment->find( 'Specifications' => {'Numbering Capable'=>'Y'}, 'useinestimating'=>1,'order'=>'lower(strName)');
	#my @possible_equipment = openprint::Equipment->find( 'Specifications' => {'ClipSealing Capable'=>'Y'}, 'useinestimating'=>1,'order'=>'lower(strName)');
	@{$$variable{Equipment}} = @possible_equipment;
} # end sub display

sub save {
} # end sub save

1;
__END__
