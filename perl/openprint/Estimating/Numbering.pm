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
	my $services = $Project->services();

	$$specs{'SetsOfNumbers'} =~ s/\D//g;
	if ( ! $$specs{'SetsOfNumbers'} ) {
		$$specs{'alert'} = 'Please enter the # of sets of numbers.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	if ( ! $$specs{'colour'} ) {
		$$specs{'alert'} = 'Please select the colour of the numbers.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	foreach my $qty_index ( $Project->quantity_indexes() ) {
		if ( $$specs{"OverridePrice$qty_index"} eq 'Y' ) {
			$$specs{"txtPrice$qty_index"} =~ s/[^\d\.]//g;
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
			my %Results = signature_calc( $Project, $sid, $specs, $sig_specs, $qty_index, $Imposition );
			$$specs{'hdnBreakdown'.$qty_index} .= $Results{'Breakdown'};
			if ( $Results{'Equipment'} ) {
				$$specs{"ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index"} = $Results{'Equipment'}->id();
			} # end if Equipment
			if ( $Results{'Imposition'} ) {
				$$specs{"txtImposition-$$sig_specs{SignatureIndex}-$qty_index"} = $Results{'Imposition'}->imposition();
				$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = $Results{'Imposition'}->layout_width();
				$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = $Results{'Imposition'}->layout_height();
			} # end if
			if ( $Results{'Status'} eq 'uncalculated' ) {
				$$specs{'Status'} = 'uncalculated';
				last;
			} # end if

			$$specs{'txtPrice'.$qty_index} += $Results{'Total'};
			$$specs{'txtUnitPrice'.$qty_index} += $Results{'UnitPrice'};
			$$specs{'MPrice'.$qty_index} += $Results{'MPrice'};
		} # end foreach signature

		my $markup = $$specs{"Markup$qty_index"} ? $$specs{"Markup$qty_index"} : 0;

		$$specs{'txtUnitPrice'.$qty_index} = sprintf($openprint::config{'UnitPriceFormat'}, $$specs{'txtUnitPrice'.$qty_index} * (1*$Project->markup()/100) );
		$$specs{'MPrice'.$qty_index} = $$specs{'Markup'.$qty_index} ? sprintf( $openprint::config{'UnitPriceFormat'}, $$specs{'MPrice'.$qty_index}*(1+$markup/100)*(1*$Project->markup()/100) ) : '0.00';
		if ( $$specs{"OverridePrice$qty_index"} ne 'Y' ) {
			$$specs{'txtPrice'.$qty_index} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{'txtPrice'.$qty_index}*(1+$markup/100)*(1*$Project->markup()/100) );
		} else {
			$$specs{'txtPrice'.$qty_index} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{"txtPrice$qty_index"} );
		} # end if
    } # end foreach qty_index
	return $$specs{'Status'} = 'calculated';

} # end sub calc

sub signature_calc {
	my ( $Project, $service_index, $specs, $sig_specs, $qty_index, $Imposition ) = @_;

	my %Results;
	my $services = $Project->services();

	$$specs{'txtQuantity'.$qty_index} = $Project->quantity($qty_index) if ! $$specs{'txtQuantity'.$qty_index};

    if ( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
        if ( $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} > $Imposition->imposition() or $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} <= 0 ) {
            $Results{'alert'} = 'The specified imposition is not possible.';
            $Results{'Status'} = 'uncalculated';
            return %Results;
        } # end if
    } # end if
    my @Impositions = ();
    if ( $$services{'Cutting'} and @{$$services{'Cutting'}} ) {
        my @imps = openprint::imposition::get_all_impositions( $Imposition );
        for ( my $i = 0; $i < @imps; $i += 1 ) {
            if ( ( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' )
                    or ( $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} == $imps[$i]->imposition() )
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
		@Equipment = openprint::Equipment::find('id'=>$$specs{"ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index"},'limit'=>1 );
	} else {
		@Equipment = openprint::Equipment::find( 'Specifications'=>{'Numbering Capable'=>'Y'}, 'use_in_estimating'=>1 );
	} # end if
	if ( ! @Equipment ) {
		$Results{'alert'} .= 'We have no numbering equipment.';
		$Results{'Status'} = 'uncalculated';
		return %Results;
	} # end if

	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] ) if $$services{''};

	$Results{'Status'} = 'calculated';

	my @side_one_colours = openprint::Estimating::Printing::get_colours( $printing_specs, 'SideOne' );
	$openprint::log->debug("@side_one_colours : " . ( sets::intersection( 'Cyan','Magenta','Yellow','Black', @side_one_colours ) ) );

	foreach my $Equipment ( @Equipment ) {
		my $heads = $Equipment->specification('Numbering Heads');
		my @colours = split(',', $Equipment->specification('Numbering Colours') );
		$Results{'Breakdown'} .= '<fieldset><legend>'.$Equipment->name().'</legend>';
		$Results{'Breakdown'} .= sprintf('Heads: %s<br/>',$heads);
		$Results{'Breakdown'} .= sprintf('Colours: %s<br/>', join(', ', @colours ) );

		if ( @colours and ! sets::isin( $$specs{'colour'}, \@colours ) ) {
			$Results{'Breakdown'} .= $$specs{'colour'} . ' not in supported colours.<br/>';
			next;
		} # end if

		foreach my $I ( @Impositions ) {

			my $runs;
			my $last_run;
			$Results{'Breakdown'} .= sprintf('<b>Imposition: %dx%d=%dout</b><br/>', $I->get('columns','rows','imposition') ); 

			if ( $Equipment->strid() eq $$printing_specs{'ddmPress'.$qty_index} and $I->imposition() == $Imposition->imposition() ) {
				$Results{'Breakdown'} .= 'Numbering while printing.<br/>';
	$openprint::log->debug("@side_one_colours : " . ( sets::intersection( 'Cyan','Magenta','Yellow','Black', @side_one_colours ) ) );
				if ( ! ( 
							sets::isin( $$specs{'colour'}, \@side_one_colours ) or 
							( 4 == sets::intersection( 'Cyan','Magenta','Yellow','Black', @side_one_colours ) )
					   ) ) {
					$last_run = $$specs{'SetsOfNumbers'} * $I->imposition();
				} # end if
			} else {
				if ( $_ = $Equipment->fits( $I->layout_width(), $I->layout_height(), $I->Paper()->calliper() ) ) {
					$Results{'Breakdown'} .= "$_<br/>";
					$last_run = $$specs{'SetsOfNumbers'};
					next;
				} # end if

				if ( $heads ) {
					$runs = int($$specs{'SetsOfNumbers'} / $heads);
					$last_run = $$specs{'SetsOfNumbers'} % $heads;
				} else {
					$last_run = $$specs{'SetsOfNumbers'};
				} # end if
			} # end if
			my $total = 0;
			my $mprice = 0;
			my $qty = ceil($$specs{'txtQuantity'.$qty_index} / $I->imposition());

			my %MakeReady = openprint::service::get_price_object('NumberingMakeReady', undef, $Equipment );
			if ( ! %MakeReady ) {
				$Results{'Breakdown'} .= 'No MakeReady price.<br/>';
			} else {
				$total += $MakeReady{'Price'};
				$Results{'Breakdown'} .= sprintf('MakeReady Price: $%1$.2f%2$s<br/>', @MakeReady{'Price','units'} );
			} # end if

			my %HeadMakeReady = openprint::service::get_price_object('NumberingHeadMakeReady', undef, $Equipment );
			if ( ! %HeadMakeReady ) {
				$Results{'Breakdown'} .= 'No HeadMakeReady price.<br/>';
			} else {
				$HeadMakeReady{'Total'} = $HeadMakeReady{'Price'} * $$specs{'SetsOfNumbers'} * $I->imposition();
				$Results{'Breakdown'} .= sprintf('HeadMakeReady Price: $%1$.2f%2$s * %4$d sets = $%3$.2f<br/>', @HeadMakeReady{'Price','units','Total'}, $$specs{'SetsOfNumbers'},  );
				$total += $HeadMakeReady{'Total'};
			} # end if

			my %ServicePrice;
			if ( $runs ) {
				%ServicePrice = openprint::service::get_price_object('Numbering'.$$specs{'colour'},$heads, $Equipment ); 
				%ServicePrice = openprint::service::get_price_object('Numbering',$heads, $Equipment ) if ! %ServicePrice;

				if ( ! %ServicePrice ) {
					$Results{'Breakdown'} .= 'No Service price.<br/>';
				} elsif ( $ServicePrice{'units'} eq 'Per M' ) {
					$ServicePrice{'Total'} += $ServicePrice{'Price'} * $runs * $qty / 1000;
					$total += $ServicePrice{'Total'};
					$mprice += $ServicePrice{'Price'} * $runs / $I->imposition();
					$Results{'Breakdown'} .= sprintf('Service Price: %4$d runs of %5$d numbers : $%1$.4f%2$s = $%3$.2f<br/>', @ServicePrice{'Price','units','Total'}, $runs, $heads );
				} elsif ( sets::isin( lc $ServicePrice{'units'},[ 'per impression', 'each' ] ) ) {
					$ServicePrice{'Total'} += $ServicePrice{'Price'} * $runs * $qty;
					$total += $ServicePrice{'Total'};
					$mprice += $ServicePrice{'Price'} * $runs / $I->imposition();
					$Results{'Breakdown'} .= sprintf('Service Price: %4$d runs of %5$d numbers : $%1$.4f%2$s = $%3$.2f<br/>', @ServicePrice{'Price','units','Total'}, $runs, $heads );
				} # end if
			} # end if

			my %LastServicePrice;
			if ( $last_run ) {
				%LastServicePrice = openprint::service::get_price_object('Numbering'.$$specs{'colour'},$last_run, $Equipment );
				%LastServicePrice = openprint::service::get_price_object('Numbering',$last_run, $Equipment ) if ! %LastServicePrice;
				if ( ! %LastServicePrice ) {
					$Results{'Breakdown'} .= 'No Service price.<br/>';
				} elsif ( sets::isin( lc $LastServicePrice{'units'},[ 'per m' ] ) ) {
					$LastServicePrice{'Total'} += $LastServicePrice{'Price'} * $qty / 1000;
					$Results{'Breakdown'} .= sprintf('Service Price: 1 run of %4$d numbers : $%1$.4f%2$s = $%3$.2f<br/>', @LastServicePrice{'Price','units','Total'}, $last_run );
					$total += $LastServicePrice{'Total'};
					$mprice += $LastServicePrice{'Price'} / $I->imposition();
				} elsif ( sets::isin( lc $LastServicePrice{'units'},[ 'per impression', 'each' ] ) ) {
					$LastServicePrice{'Total'} += $LastServicePrice{'Price'} * $qty;
					$total += $LastServicePrice{'Total'};
					$mprice += $LastServicePrice{'Price'} / $I->imposition();
					$Results{'Breakdown'} .= sprintf('Service Price: 1 run of %4$d numbers : $%1$.4f%2$s = $%3$.2f<br/>', @LastServicePrice{'Price','units','Total'}, $last_run );
				} # end if
			} # end if

			if ( my $minimumcharge = openprint::service::get_price('NumberingMinimumCharge', undef, $Equipment ) ) {
				$total = $minimumcharge if $total < $minimumcharge;
			} # end if

			$Results{'Breakdown'} .= sprintf('Total: $%.2f<br/>', $total );

			if ( ( ! defined $Results{'Total'} ) or $total < $Results{'Total'} ) {
				$Results{'Total'} = $total;
				$Results{'MPrice'} = $mprice;
				$Results{'Equipment'} = $Equipment;
				$Results{'ServicePrice'} = \%ServicePrice;
				$Results{'LastServicePrice'} = \%LastServicePrice;
				$Results{'Imposition'} = $I;
			} # end if
		} # end foreach Imposition
		$Results{'Breakdown'} .= '</fieldset>';
	} # end foreach Equipment

	if ( ! defined $Results{'Total'} ) {
		$Results{'Status'} = 'uncalculated';
	} else {
		$Results{'Equipment'} = $Results{'Equipment'};
	} # end if

	$Results{'UnitPrice'} = ($Results{'ServicePrice'}{'Total'} + $Results{'LastServicePrice'}{'Total'} ) / $$specs{'txtQuantity'.$qty_index};

	return %Results;
} # end sub calc

sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;

	$specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;
	if ( $qty_index ) {
		return '';
	} # end if

	return sprintf( '%d set%s of %s numbers', $$specs{'SetsOfNumbers'}, ( $$specs{'SetsOfNumbers'} == 1 ? '' : 's' ), $$specs{'colour'} );
} # end sub summary

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my @possible_equipment = openprint::Equipment::find( 'Specifications' => {'Numbering Capable'=>'Y'}, 'use_in_estimating'=>1,'order'=>'lower(strName)');
	#my @possible_equipment = openprint::Equipment::find( 'Specifications' => {'ClipSealing Capable'=>'Y'}, 'use_in_estimating'=>1,'order'=>'lower(strName)');
	@{$$variable{'Equipment'}} = @possible_equipment;
} # end sub display

1;
__END__
