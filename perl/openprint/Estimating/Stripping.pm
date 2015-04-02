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

package openprint::Estimating::Stripping;
use strict;
#use warnings;
use POSIX qw( ceil );
use constant DEBUG => 1;

# Stripping tends to be a manual process.  There are tools to help... 

require openprint::Equipment;
require openprint::service;
use openprint;
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

my @variables = (
	'txtQuantity1','txtQuantity2','txtQuantity3',
	'OverridePrice1','OverridePrice2','OverridePrice3',
	'Markup1','Markup2','Markup3',
	'txtPrice1','txtPrice2','txtPrice3',
	'MPrice1','MPrice2','MPrice3',
	'alert',
);

sub variables {
	my ( $p_id, $s_id, $specs ) = @_;

	my @v = @variables;
	my $Project = new openprint::Project( $p_id );
	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		my $form = $$sig_specs{SignatureIndex};
		push @v, map { "$_-$form" } ( 'Complexity' );

		foreach my $qty_index ( $Project->quantity_indexes() ) {
			push @v, map { "$_-$form-$qty_index" } ( 'ddmEquipment', 'chkOverrideEquipment',);
		} # end foreach qty_index
	} # end foreach signatures
	return @v;
} # end sub variables

my @output = (
		);

sub outputs {
	return @output;
} # end sub get_output

my @no_outputs = (
	'OverridePrice1', 'OverridePrice2', 'OverridePrice3',
	'Markup1','Markup2','Markup3',
	'txtQuantity1','txtQuantity2','txtQuantity3',
);

sub no_outputs {
	return @no_outputs;
}
sub calc_price {
    my ( $specs, $Equipment, $qty_index, $Imposition, $sig_specs, $Signature_Imposition ) = @_;

	my %Total = ( Imposition => $Imposition, Status => 'calculated', alert=>'' );
	my $form = $$sig_specs{SignatureIndex};

	my $MakeReadyService = openprint::Service->find_one( name => 'Stripping-'.$$specs{'Complexity-'.$form}.'MakeReady' ) if $$specs{'Complexity-'.$form};
	$MakeReadyService = openprint::Service->find_one( name => 'StrippingMakeReady' ) if ! $MakeReadyService;

	if ( $MakeReadyService ) {
		my $MakeReady = $MakeReadyService->get_Price( undef, $Equipment );
		if ( $$MakeReady{units} eq 'per hour' ) {
			my $MRHours = $Equipment->Specification( $$specs{ServiceType}.' MakeReadyTime' );
			$Total{MakeReadyTime} = $MRHours;
			if ( $MRHours and $$MRHours{value} ) {
				$$MakeReady{Total} = Math::Round::nearest( 0.01, $$MakeReady{Price} * $$MRHours{value} );
			} else {
				$Total{alert} .= 'No MakeReadyTime set for ' . $$specs{ServiceType} . ' on ' . $Equipment->name() . '<br/>';
				$openprint::log->error( $Total{alert} );
				$$MakeReady{Total} = $$MakeReady{Price};
			} # end if
		} else {
			$$MakeReady{Total} = $$MakeReady{Price};
		}
		$Total{MPrice} = 0;
		$Total{MakeReady} = $MakeReady;
		$Total{Total} += $$MakeReady{Total};
	} # en dif

	my $impressions = ceil( ( $$specs{"txtQuantity$qty_index"} / $$Signature_Imposition{imposition} ) ) * $Imposition->quantity();
	$Total{Impressions} = $impressions;

	my $StrippingService = openprint::Service->find_one( name=>'Stripping'.$$specs{'Complexity-'.$form}.'Stripping' );
	$StrippingService = openprint::Service->find_one( name=>'Stripping' ) if ! $StrippingService;

	my %ServicePrice;
	if ( ( ! defined $$specs{'OverridePrice'.$qty_index} ) or ( $$specs{'OverridePrice'.$qty_index} ne 'Y' ) ) {
		%ServicePrice = $StrippingService->get_Price( undef, $Equipment );
		if ( %ServicePrice ) {
			if ( $ServicePrice{units} eq 'per m' ) {
				$ServicePrice{Total} = Math::Round::nearest( 0.01, $ServicePrice{Price} * $impressions / 1000 );
			} elsif ( $ServicePrice{units} eq 'per hour' ) {
 				my $Runspeed = $Equipment->Specification( 'Stripping Runspeed' );
				if ( $Runspeed and $$Runspeed{value} ) {
					$Total{Runspeed} = $Runspeed;
					my $hours = $impressions / $$Runspeed{value};
					$ServicePrice{Total} = Math::Round::nearest( 0.01, $ServicePrice{Price} * $hours );
				} else {
					$Total{alert} .= "No stripping speed on $$Equipment{name}<br/>";
					$Total{Status} = 'uncalculated';
				}
			} else {
				$Total{alert} .= "unknown units in price for Stripping on $$Equipment{name}<br/>";
				$Total{Status} = 'uncalculated';
			} # end if

			$Total{Service} = \%ServicePrice;
			$Total{MPrice} += $ServicePrice{Price};
			$Total{Total} += $ServicePrice{Total};
		} else {
			$Total{alert} .= "No service price in the system for $$StrippingService{name}<br/>";
		} # end if
	} else {
		$Total{MPrice} += ( $$specs{"Price$qty_index"} / $impressions ) * 1000;
		$Total{Total} += $$specs{"Price$qty_index"};
	} # end if

	$Total{ServicePrice} = \%ServicePrice;
	$Total{Total} += $ServicePrice{Total};
	$Total{MPrice} += ( $ServicePrice{Total} / $impressions ) * 1000;
	$Total{UnitPrice} = $Total{Total} / $$specs{"txtQuantity$qty_index"};
    return %Total;

} # end sub calc_price

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';
	my $Project = new openprint::Project( $project_index );
	my $Service = $Project->Service( $service_index );

	my @signatures_needing = ();

	foreach my $signature_service_index ( $Project->signatures( { sort=>1 }) ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
		my $form = $$sig_specs{SignatureIndex};
	
		if ( ! $$specs{"Needed-$form"} ) {
			if ( sets::isin( $$sig_specs{rdbTemplateType}, ['2Panel1Pocket','2Panel2Pocket','TriFoldDoublePocket'] ) ) {
				$$specs{"Needed-$form"} = 'Y';
			} elsif ( $Project->signatures() == 1 ) {
				$$specs{"Needed-$form"} = 'Y';
			} else {
				$$specs{"Needed-$form"} = 'N';
			} # end if
		} # end if
			
		if ( $$specs{"Needed-$form"} eq '' ) {
			$$specs{alert} .= 'Please select whether stripping is required for form ' . $form . '.<br/>';
			return $$specs{Status} = 'uncalculated';
		} elsif ( $$specs{"Needed-$form"} eq 'N' ) {
			next;
		} # end if
		push @signatures_needing, $signature_service_index;

		if ( ! $$specs{'rdbStripping-'.$form} ) {
			if ( $$sig_specs{rdbTemplateType} eq '2Panel2Pocket' ) {
				$$specs{'rdbStripping-'.$form} = 'Average';
			} elsif ( $$sig_specs{rdbTemplateType} eq '2Panel1Pocket' ) {
				$$specs{'rdbStripping-'.$form} = 'Simple';
			} else {
				$$specs{'rdbStripping-'.$form} = 'Complex';
			} # end if
		} # end if
		if ( ( $$specs{'rdbSuppliedDie-'.$form} eq 'N' ) and ( ! $$specs{'rdbStripping-'.$form} ) ) {
			$$specs{alert} .= 'Please select the complexity of the die.<br/>';
			return 'uncalculated';
		} # end if
	} # end foreach signature

	foreach my $qty_index ( $Project->quantity_indexes() ) {

		$$specs{"txtQuantity$qty_index"} = $Project->quantity( $qty_index ) if ! $$specs{"txtQuantity$qty_index"};
		my $qty = $$specs{"txtQuantity$qty_index"};

		my $totalPrice = 0;
		my $totalUnitPrice = 0;
		my $totalMPrice = 0;
		my $totalDiePrice = 0;
		my $totalStrippingPrice = 0;

		foreach my $signature_service_index ( @signatures_needing ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
			next if ! $$sig_specs{'txtImposition'.$qty_index};
			my $form = $$sig_specs{SignatureIndex};

			$$specs{'hdnBreakdown'.$qty_index} .= "Form $form: $$sig_specs{txtServiceDescription}<br/>";
			my $Imposition = new openprint::Imposition();
			$Imposition->load( $sig_specs, $qty_index );
			$$specs{'hdnBreakdown'.$qty_index} .= $Imposition->to_string() . '<br/>';

			my %results = signature_calc( $Project, $Service, $sig_specs, $specs, $qty_index, $Imposition );
			$$specs{'hdnBreakdown'.$qty_index} .= $results{breakdown} if $results{breakdown};
			$$specs{alert} .= $results{alert} if $results{alert};
			if ( $results{Equipment} ) {
				$$specs{"ddmEquipment-$form-$qty_index"} = $results{Equipment}->id();
				$$specs{'hdnBreakdown'.$qty_index} .= 'Equipment: '.$results{Equipment}->strid().'<br/>';
				#$$specs{"txtImposition-$form-$qty_index"} = $results{Imposition}->imposition();

				my $Price = $results{Price};

				# This should be a different string from above, or maybe the same if it wasn't cut.
				$$specs{'hdnBreakdown'.$qty_index} .= $Imposition->to_string() . '<br/><table>';
				if ( $$Price{MakeReady}{units} ) {
					if ( $$Price{MakeReady}{units} eq 'per hour' ) {
						$$specs{'hdnBreakdown'.$qty_index} .= sprintf('<tr><td>MakeReady: $%1$.2f%2$s * %4$s%5$s = </td><td class="Price">$%3$.2f</td></tr>', @{$$Price{MakeReady}}{'Price','units','Total'}, @{$$Price{'MakeReadyTime'}}{'value','units'} );
					} else {
						$$specs{'hdnBreakdown'.$qty_index} .= sprintf('<tr><td>MakeReady: $%.2f%s = </td><td class="Price">$%.2f</td></tr>', @{$$Price{MakeReady}}{'Price','units','Total'} );
					}
				} else {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('<tr><td>MakeReady: </td><td class="Price">$%.2f</td></tr>', $$Price{MakeReady}{Price});
				} # end if
				if ( $$Price{ServicePrice}{units} eq 'per hour' ) {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('<tr><td>Service: $%1$.2f%2$s * (%4$d impressions/%5$d per hour) = </td><td class="Price">$%3$.2f</td></tr>', @{$$Price{ServicePrice}}{'Price','units','Total'}, $$Price{Impressions}, $$Price{Runspeed}{value} );
				} else {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('<tr><td>Service: $%1$.2f%2$s * %4$d impressions = </td><td class="Price">$%3$.2f</td></tr>', @{$$Price{ServicePrice}}{'Price','units','Total'}, $$Price{Impressions} );
				} # end if

				$totalUnitPrice += $Price->{UnitPrice};
				$totalMPrice += $Price->{MPrice};
				$$specs{alert} .= $$Price{alert};
				$status = 'uncalculated' if $$Price{Status} eq 'uncalculated';

				$totalPrice += $results{Total};

				if ( $$specs{'Markup'.$qty_index} ) {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('<tr class="totals"><td>Total: $%.2f * %s%% = </td><td class="Price">$%.2f</td></tr>', $results{Total},$$specs{'Markup'.$qty_index}, $totalPrice*(1+$$specs{'Markup'.$qty_index}/100));
				} else {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('<tr class="totals"><td>Total:</td><td class="Price">$%.2f</td></tr>', $results{Total} );
				} # end if
				$$specs{'hdnBreakdown'.$qty_index} .= '</table>';
			} # end if Equipment
		} # end foreach Signature
	
		if ( $$specs{'Markup'.$qty_index} ) {
			my $markup_amount = (1+$$specs{'Markup'.$qty_index}/100);
			$totalPrice *= $markup_amount;
			$totalUnitPrice *= $markup_amount;
			$totalMPrice *= $markup_amount;
		} # end if
		if ( $Project->markup() ) {
			my $markup_amount = (1+$Project->markup()/100);
			$totalPrice *= $markup_amount;
			$totalUnitPrice *= $markup_amount;
			$totalMPrice *= $markup_amount;
		} 
		if ( (!defined $$specs{'OverridePrice'.$qty_index}) or ( $$specs{'OverridePrice'.$qty_index} ne 'Y' ) ) {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{ProjectMoneyFormat}, $totalPrice );
			@no_outputs = sets::exclude( ["txtPrice$qty_index"], \@no_outputs );
		} else {
			@no_outputs = sets::union( "txtPrice$qty_index", @no_outputs );
		} # end if
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{UnitPriceFormat}, $totalUnitPrice );
		$$specs{"MPrice$qty_index"} = sprintf( $openprint::config{UnitPriceFormat}, $totalMPrice );
	} # end foreach qty

	return $status;
} # end sub calc

sub signature_needs {
	my ( $Project, $specs, $sig_specs ) = @_;
	my $form = $$sig_specs{SignatureIndex};
#$log->debug("Diecutting::signatureNeeds: for sig $form : Needed: ($$specs{'Needed-'.$form})" );
	if ( ! $$specs{"Needed-$form"} ) {
		if ( sets::isin( $$sig_specs{rdbTemplateType}, ['2Panel1Pocket','2Panel2Pocket','TriFoldDoublePocket'] ) ) {
			return 1;
		} # end if
		my $ServiceType = openprint::ServiceType->find_one(type=>'Stripping');
		if ( $ServiceType ) {
			if ( sets::isin( $ServiceType->id(), [ $Project->Type()->required_services() ] ) ) {
				return 1;
			} # end if
		} else {
			$openprint::log->error("No ServiceType for Stripping");
		}
	} # end if
	return $$specs{"Needed-$form"} eq 'Y' ? 1 : 0;
} # end sub signature_needs

sub signature_calc {
	my ( $Project, $Service, $sig_specs, $specs, $qty_index, $Imposition ) = @_;

	my $form = $$sig_specs{SignatureIndex};

	@$specs{"txtWidth-$form", "txtHeight-$form"} = @$sig_specs{'txtWidth','txtHeight'};

	my %results;

	my @equipment;
	if ( (defined $$specs{"chkOverrideEquipment-$form-$qty_index"}) and ( $$specs{"chkOverrideEquipment-$form-$qty_index"} eq 'Y' ) ) {
		@equipment = ( new openprint::Equipment( $$specs{"ddmEquipment-$form-$qty_index"} ) );
	} else {
		@equipment = openprint::Equipment->find( useinestimating=>1, 'servicetype_id any'=>$Service->servicetype_id() );
	} # end if

	my $services = $Project->services();
	my @Sets_of_Impositions;

	if ( (defined $$specs{"OverrideImposition-$form-$qty_index"}) and ( $$specs{"OverrideImposition-$form-$qty_index"} eq 'Y' ) ) {
		$openprint::log->debug("Overriding impositions");

		my @override_impos;
		foreach my $index ( 1 .. 4 ) {
			next if ! $$specs{"ImpQty-$form-$qty_index-$index"};
			my $I = $Imposition->copy();
			$I->quantity( $$specs{"ImpQty-$form-$qty_index-$index"} );
			$I->imposition( $$specs{"ImpOut-$form-$qty_index-$index"} );
			$I->columns( $$specs{"ImpColumns-$form-$qty_index-$index"} );
			$I->rows( $$specs{"ImpRows-$form-$qty_index-$index"} );
			$I->Paper( $Imposition->Paper() );
			push @override_impos, $I;
			$I->display('Override');
		} # end foreach
		@Sets_of_Impositions = ( \@override_impos );
		my $overriden_count = misc::sum( map { $_->quantity() * $_->imposition() } @override_impos );
		if ( $overriden_count != $Imposition->quantity() * $Imposition->imposition() ) {
			$results{alert} .= "Overriden imposition count does not match printed imposition count for form $form.<br/>";
		} else {
			$openprint::log->debug(" override count: $overriden_count $$Imposition{quantity} * $$Imposition{imposition}");
		} # end if
	} else {
		@Sets_of_Impositions = ( [ $Imposition ] );
	} # end if Overrides

	foreach my $Equipment ( @equipment ) {

		for ( my $Set_index = 0; $Set_index < @Sets_of_Impositions; $Set_index += 1 ) {
			my $Set_of_Impositions =  $Sets_of_Impositions[$Set_index];
			my @Impositions = openprint::imposition::sort( @{$Set_of_Impositions} );

			my %price;
			my $complete = 1;
			for( my $impo_index = 0; $impo_index < @Impositions; $impo_index += 1 ) {
				my $imposition = $Impositions[$impo_index];

				my $width = $imposition->layout_width();
				my $height = $imposition->layout_height();
				if ( $_ = $Equipment->fits( $width, $height, $$sig_specs{txtSpecificStockCalliper} ) ) {
					if ( 1 == @equipment ) {
						$results{breakdown} .= "Doesn't fit. $_<br/>";
					} # end if
					if ( $$imposition{imposition} > 1 and ! $$specs{"OverrideImposition-$form-$qty_index"} ) {
						splice ( @Impositions, $impo_index, 1, openprint::imposition::cut( $imposition ) );
						push @Sets_of_Impositions,  \@Impositions;
					} # end if
					$complete = 0;
					last;
				} # end if
				my %p = calc_price( $specs, $Equipment, $qty_index, $imposition, $sig_specs, $Imposition );
				push @{$price{Prices}}, \%p;
				$price{Total} += $p{Total};
			} # end foreach imposition
			next if ! $complete;

			if ( (! $results{Total} ) or ( $price{Total} < $results{Total} ) ) {
				$results{Equipment} = $Equipment;
				if ( $price{Prices} ) {
					@{$results{Prices}} = @{$price{Prices}};
				} else {
					$openprint::log->error("No prices?");
					$results{Prices} = [];
				}
				$results{Overs} = $price{Overs};
				$results{Total} = $price{Total};
			} # end if

		} # end foreach sets_of_impositions
	} # end foreach equipment
	return %results;
} # end sub signature_calc

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;	

	my $Project = new openprint::Project( $project_index );
	my $Service = $Project->Service( $service_index );
	my $ServiceType = $Service->ServiceType();

	$$variable{Equipment} = [ openprint::Equipment->find(order=>'lower(strname)', useinestimating=>1,
			'servicetype_id any'=>$Service->servicetype_id(),
			) ];

} # end sub display

sub signature_summary {
    my ( $Project, $service_index, $specs, $qty_index, $s_id, $sig_specs ) = @_;
	return '';
} # end sub signature_summary

sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;
	#$specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;
	if ( $qty_index ) {
		my $html;
        my @signatures = $Project->signatures( { sort=>1 } );

        for ( my $sig_index = 0; $sig_index < @signatures; $sig_index += 1 ) {
            my $s_s_id = $signatures[$sig_index];
            my $sig_specs = openprint::service::get_specs_ref( $Project, $s_s_id );
            my $form = $$sig_specs{SignatureIndex};
			if ( ! $$sig_specs{"txtImposition$qty_index"} ) {
				next;
			} # end if
            my $sig_count = 1;

            if ( $sig_index < @signatures - 1 ) {
                for ( my $sig_index2 = $sig_index + 1; $sig_index2 < @signatures; $sig_index2 += 1 ) {
                    my $sig_specs2 = openprint::service::get_specs_ref( $Project, $signatures[$sig_index2] );
                    if ( openprint::Estimating::Printing::compare_signatures( $Project, $sig_specs, $sig_specs2, $qty_index ) ) {
                        $sig_count += 1;
                    } else {
                        last;
                    } # end if
                } # end for
                splice @signatures, $sig_index+1,$sig_count-1 if $sig_count > 1;
            }
            my $summary = signature_summary( $Project, $service_id, undef, $qty_index, $s_s_id, undef );
            if ( $sig_count > 1 ) {
                $html .= ($sig_count) . ' Forms ' . $$sig_specs{txtServiceDescription} ;
            } else {
                $html .= 'Form ' . $form . ' ' . $$sig_specs{txtServiceDescription};
            } # end if
			$html .= $summary . "\n";
        } # end foreach
        return $html;
	} # end if

	return '';
} # end sub summary

sub save {
	# Might have to update the DieCutting price.
} # end sub save

1;
__END__
