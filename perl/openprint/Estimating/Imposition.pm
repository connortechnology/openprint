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

package openprint::Estimating::Imposition;
use strict;
#use Data::Dumper;

use constant DEBUG => 0;

require openprint::service;

my @variables = (
	'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
	'txtUnitPrice1', 'txtUnitPrice2', 'txtUnitPrice3',
	'txtPrice1', 'txtPrice2', 'txtPrice3',
);

sub variables {
    return @variables;
} # end sub variables


sub neccessary {
	#my ( $Project ) = @_;

	return 1 if openprint::ServiceType->find_one(name=>'Imposition');

	return 0;
} # end sub neccessary

sub signature_calc {
	my ( $Project, $Imposition, $previous_forms, $qty_index ) = @_;

	my %price;

	my $Press = $Imposition->Press();

	my %ImpositionMakeReady;
	my $Service = openprint::Service->find_one( name=>'ImpositionMakeReady'.$Project->Type()->name() );
	$Service = openprint::Service->find_one( name=>'ImpositionMakeReady' ) if ! $Service;
	if ( $Service ) {
		%ImpositionMakeReady = $Service->get_price( undef, $Press );
	} # end if
	if ( %ImpositionMakeReady ) {
		if ( $ImpositionMakeReady{units} eq 'per form' ) {
	#$openprint::log->debug("Make Ready Per Form " . ($$specs{'PreviousForms'.$qty_index}+1) );
			%ImpositionMakeReady = $Service->get_price( scalar @{$previous_forms} + 1, $Press );
		} else {
			
		} # end if
	} elsif(DEBUG) {
		$openprint::log->error("No price found for " . $Service->name() );
	} # end if
if ( DEBUG ) {
	$openprint::log->debug("MR Price is $ImpositionMakeReady{Price}");
}

	$price{MakeReady} = \%ImpositionMakeReady;
	$price{Total} = $ImpositionMakeReady{Price};

	my %ImpositionCharge;
	$Service = openprint::Service->find_one( name=>'Imposition'.$Project->Type()->name() );
	$Service = openprint::Service->find_one( name=>'Imposition' ) if ! $Service;

	%ImpositionCharge = $Service->get_price( undef, $Press);
	if ( %ImpositionCharge ) {
		if ( $ImpositionCharge{'units'} eq 'per page' ) {
			%ImpositionCharge = $Service->get_price( $Imposition->pages(),$Press);
			$price{Total} += $ImpositionCharge{Price} * $Imposition->pages();
		} elsif ( $ImpositionCharge{'units'} eq 'per square inch of object' ) {
			%ImpositionCharge = $Service->get_price( $Imposition->layout_area(),$Press);
			$price{Total} += $ImpositionCharge{Price} * $Imposition->object_width() * $Imposition->object_height();
		} elsif ( $ImpositionCharge{'units'} eq 'per square inch of layout' ) {
			%ImpositionCharge = $Service->get_price( $Imposition->layout_area(),$Press);
			$price{Total} += $ImpositionCharge{Price} * $Imposition->layout_area();
		} else {
			%ImpositionCharge = $Service->get_price( $Imposition->imposition(),$Press);
			$price{Total} += $ImpositionCharge{Price} * $Imposition->imposition();
		} # end if
	} # end if
	$price{Price} = \%ImpositionCharge;

	my %SteppingCharge;
	if ( ! (%SteppingCharge = openprint::service::get_price_object( 'Stepping Charge'.$Project->Type()->name(), undef, $Press) ) ) {
		%SteppingCharge = openprint::service::get_price_object( 'Stepping Charge', undef, $Press);
	} # end if
	if ( %SteppingCharge ) {
		$SteppingCharge{Total} = $SteppingCharge{Price} * $Imposition->imposition();
		$price{'Stepping Charge'} = \%SteppingCharge;
		$price{Total} += $SteppingCharge{Total};
	} # end if

   if ( $Imposition->pages() ) {
		my %PageCharge;
		if ( ! ( %PageCharge = openprint::service::get_price_object( 'Page Charge'.$Project->Type()->name(), $Imposition->pages(), $Press) ) ) {
			%PageCharge = openprint::service::get_price_object( 'Page Charge', $Imposition->pages(), $Press );
		} # end if
		if ( %PageCharge ) {
			if ( $PageCharge{units} eq 'per page' ) {
				$PageCharge{Total} = $PageCharge{Price} * $Imposition->pages();
			} else {
$openprint::log->error("Bad units for Page Page $PageCharge{units}");
			} # end if
			$price{'Page Charge'} = \%PageCharge;
			$price{Total} += $PageCharge{Total};
		} # end if Page Charge
	} # end if pages

#$openprint::log->debug(Data::Dumper::Dumper(\%price));
	return \%price;
} # end sub signature_calc

sub calc {
$openprint::log->debug("Imposition calc: @_");
	shift @_ if $_[0] eq 'openprint::Estimating::Imposition';

	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;
$openprint::log->debug("Imposition calc: @_");

	my $status = 'calculated';

	my $Project = new openprint::Project( $project_index );
	#my $services = $Project->services();

	my @signatures = $Project->signatures();
$openprint::log->debug("Signtures: @signatures");

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$specs{"txtQuantity$qty_index"} = int( $$specs{"txtQuantity$qty_index"} );
		$$specs{"txtQuantity$qty_index"} = $Project->quantity( $qty_index ) if ! $$specs{"txtQuantity$qty_index"};

		my @Previous_Signatures;
		my $total = 0;

		foreach my $sig_id ( @signatures ) {
            my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
            $$specs{'hdnBreakdown'.$qty_index} .= "Signature: $$sig_specs{'txtServiceDescription'}, " if $$sig_specs{'txtServiceDescription'} ne '';
            if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
                $$specs{'hdnBreakdown'.$qty_index} .= "No imposition for signature $$sig_specs{'SignatureIndex'}";
                next;
            } # end if
			push @Previous_Signatures, $sig_id;
			my $Imposition = new openprint::Imposition();
			$Imposition->load( $sig_specs, $qty_index );
$Imposition->display("Signature calc for $sig_id");
			my $price = signature_calc( $Project, $Imposition, scalar @Previous_Signatures, $qty_index );
			$total += $$price{Total};

			$$specs{'hdnBreakdown'.$qty_index} = '';
			#$$specs{'hdnBreakdown'.$qty_index}  .= 'MinimumCharge: ' . sprintf( '%.2f', $minimumCharge ) . '<br/>';
		} # end foreach signature
$log->debug("$total: " . $$specs{"txtPrice$qty_index"} );
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $total * (1+$Project->markup()/100) );
		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $total * (1+$Project->markup()/100) );
	} # end foreach qty_index

	return $$specs{Status} = $status;
} # end sub calc

sub display {
    my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my $Project = new openprint::Project( $project_index );

} # end sub display

sub signature_summary {
	my ( $Imposition, $Price ) = @_;

	my $breakdown;
	my $MakeReady = $$Price{MakeReady};
    my $Service = $$Price{Price};

    if ( $$Service{units} eq 'per page' ) {
        $breakdown .= sprintf('Imposition Charge: $%1$.2f + $%2$.2f*%4$d pages = $%3$.2f<br/>', $$MakeReady{Price}, $$Service{Price}, $$Price{'Total'}, $Imposition->pages() );
    } elsif ( $$Service{units} eq 'per square inch of object' ) {
        $breakdown .= sprintf('Imposition Charge: $%1$.2f + $%2$.2f*%4$s x %5$s = $%3$.2f<br/>', $$MakeReady{Price}, $$Service{Price}, $$Price{'Total'}, $Imposition->object_width(), $Imposition->object_height() );
    } elsif ( $$Service{units} eq 'per square inch of layout' ) {
        $breakdown .= sprintf('Imposition Charge: $%1$.2f + $%2$.2f*%4$s x %5$s = $%3$.2f<br/>', $$MakeReady{Price}, $$Service{Price}, @$Price{'Total'}, $Imposition->layout_width(), $Imposition->layout_height() );
    } elsif ( $$Service{Price} ) {
        $breakdown .= sprintf('Imposition Charge: $%1$.2f + $%2$.2f*%4$d out = $%3$.2f<br/>', $$MakeReady{Price}, $$Service{Price}, @$Price{'Total'}, $Imposition->imposition() );
    } elsif ( $$MakeReady{Price} ) {
        $breakdown .= sprintf('Imposition Charge: $%1$.2f<br/>', $$MakeReady{Price} );
    } # end if

    if ( my $PageCharge = $$Price{'page charge'} ) {
        $breakdown .= sprintf('Page Charge: $%1$.2f%2$s * %4$d pages = $%3$.2f<br/>', @$PageCharge{'Price','units','Total'}, $Imposition->pages() );
    } # end if
    if ( my $SteppingCharge = $$Price{'stepping charge'} ) {
        $breakdown .= sprintf('Stepping Charge: $%1$.2f%2$s * %4$dout  = $%3$.2f<br/>', @$SteppingCharge{'Price','units','Total'}, $Imposition->imposition() );
    } # end if
	return $breakdown;
} # end sub signature_summary

sub summary {
    my ( $Project, $service_index, $specs, $qty_index ) = @_;
	if ( $qty_index ) {
	return '';
	} # end if
	return '';
}

sub has_overrides {
	return ();
}

1;
__END__
