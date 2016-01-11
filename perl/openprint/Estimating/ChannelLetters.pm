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

package openprint::Estimating::ChannelLetters;
use strict;

require sql;
require openprint::service;

	#'ServiceType',
	#'rdbChannelLettersType',
my @variables = (
	'letters','letter_height','letter_font',
	'can_finish',
	'include_leds','led_colour','led_density','led_quantity','led_power_supply','led_install',

	'OverridePrice1', 'OverridePrice2', 'OverridePrice3',
	'Markup1', 'Markup2', 'Markup3',
	'txtPrice1', 'txtPrice2', 'txtPrice3',
	'txtUnitPrice1', 'txtUnitPrice2', 'txtUnitPrice3',
	'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
);

sub variables {
	my ( $p_id, $s_id, $specs ) = @_;
	my @v = @variables;
	#my $Project = new openprint::Project( $p_id );
	#foreach my $ss_id ( $Project->signatures() ) {
		#my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
	#} # end foreach signature
	return @v;
} # end sub variables

my @outputs = (
	'hdnBreakdown1', 'hdnBreakdown2', 'hdnBreakdown3',
	'txtPrice1', 'txtPrice2', 'txtPrice3',
	'txtUnitPrice1', 'txtUnitPrice2', 'txtUnitPrice3',
);

sub get_outputs {
	return @outputs;
} # end sub get_output

my @no_outputs = (
	'ProjectIndex', 'ServiceIndex', 'txtQuantity1','txtQuantity2','txtQuantity3',
	'ServiceType',
	'OverridePrice1', 'OverridePrice2', 'OverridePrice3',
	'Markup1', 'Markup2', 'Markup3',
);

sub no_outputs {
	my ( $p_id, $s_id, $specs ) = @_;
	my @o = @no_outputs;

	my $Project = new openprint::Project( $p_id );
	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		#push @o, ( "chkOverrideArea-$$sig_specs{'SignatureIndex'}", );
	} # end foreach signature
	return @o;
};

sub neccessary {
	my ( $log, $dbh, $project_index ) = @_;

	my $Project = new openprint::Project( $project_index );
    my $services = $Project->services();

    if ( $$services{'NoBindery'} ) {
        $log->debug(" ** Project is marked as No bindery, Cutting not needed ! ** ");
        return 0;
    } # end if

    if ( $Project->Type()->name() eq 'PresentationFolders' ) {
        return 1;
    } # end if
	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		if ( sets::isin( $$sig_specs{'rdbTemplateType'}, ['2Panel1Pocket','2Panel2Pocket','TriFoldDoublePocket'] ) ) {
			return 1;
		} # end if
	} # end foreach signature

	return 0;
} # end sub neccessary

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;
$openprint::log->debug("CHannelLetters:");

	my $status = 'calculated';

foreach my $k ( keys %$specs ) {
$openprint::log->debug("$k => $$specs{$k}");
}

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();

	s/^\s+//, s/\s+$// for $$specs{letters};
	if ( ! $$specs{letters} ) {
		$$specs{alert} .= 'Please enter the letters of your sign.<br/>';
		return $$specs{Status} = 'uncalculated';
	}
	if ( ! $$specs{letter_height} ) {
		$$specs{alert} .= 'Please enter the height of your upper-case letters.<br/>';
		return $$specs{Status} = 'uncalculated';
	} # end if

	my $makeReadyPrice = openprint::service::get_price( 'ChannelLettersMakeReady', undef, undef );
	my $minimumCharge = openprint::service::get_price( 'ChannelLettersMinimumCharge', undef, undef );

	my $uppercase_letters = $$specs{letters};
	$uppercase_letters =~ s/[^A-Z]//g;

	my $lowercase_letters= $$specs{letters};
	$lowercase_letters =~ s/[^a-z]//g;

	my $other_letters = $$specs{letters};
	$other_letters =~ s/[^A-Za-z]//g;

	my $CanMaterial = openprint::Material->find_one(name=>join('', 'ChannelLetterCan',@$specs{'letter_font','letter_size'} ) );
	$CanMaterial = openprint::Material->find_one(name=>join('', 'ChannelLetterCan',@$specs{'letter_font'} ) ) if ! $CanMaterial;
	$CanMaterial = openprint::Material->find_one(name=>'ChannelLetterCan' ) if ! $CanMaterial;
	my $FaceMaterial = openprint::Material->find_one(name=>join('', 'ChannelLetterFace',@$specs{'letter_font','letter_size'} ) );
	$FaceMaterial = openprint::Material->find_one(name=>join('', 'ChannelLetterFace',@$specs{'letter_font'} ) ) if ! $FaceMaterial;
	$FaceMaterial = openprint::Material->find_one(name=>'ChannelLetterFace' ) if ! $CanMaterial;
			my $num_letters = length( $$specs{letters} );

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$specs{"txtQuantity$qty_index"} = int( $$specs{"txtQuantity$qty_index"} );
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		next if ! $$specs{"txtQuantity$qty_index"};
		$$specs{"Markup$qty_index"} =~ s/[^\d\.\-]//g;
		$$specs{"txtPrice$qty_index"} =~ s/[^\d\.]//g;
		my $price = 0;
		my $unitPrice = 0;
		$$specs{'hdnBreakdown'.$qty_index} = '';
		$$specs{'hdnBreakdown'.$qty_index}  .= 'MakeReady: $' . sprintf( '%.2f', $makeReadyPrice ) . '<br/>';
		$$specs{'hdnBreakdown'.$qty_index}  .= 'MinimumCharge: $' . sprintf( '%.2f', $minimumCharge ) . '<br/>';

		my $qty = $$specs{"txtQuantity$qty_index"};
		my %servicePrice = openprint::service::get_price_object( 'ChannelLetters', $qty, undef );
		if ( sets::isin( $servicePrice{'units'}, ['', 'per m', 'per 1000'] ) ) {
			$servicePrice{'Total'} = $qty * $servicePrice{'Price'} / 1000;
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf( 'Service: $%.2f %s = $%.2f<br/>', @servicePrice{'Price','units','Total'} );
		} # end if
		$price = $makeReadyPrice + $servicePrice{'Total'};

		if ( $CanMaterial ) {
			my $CanPrice = $CanMaterial->get_Price( $num_letters * $qty );
			if ( $CanPrice ) {
				$$CanPrice{Total} = $$CanPrice{Price} * $num_letters * $qty;
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Can Price: %1$.2f%2$s * %4$d = %3$.2f', @$CanPrice{'Price','units','Total'}, $num_letters * $qty );
				$price += $$CanPrice{Total};
			} else {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No price for Cans<br/>';
			}
		}
		if ( $FaceMaterial ) {
			my $FacePrice = $FaceMaterial->get_Price( $num_letters * $qty );
			if ( $FacePrice ) {
				$$FacePrice{Total} = $$FacePrice{Price} * $num_letters * $qty;
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Face Price: %1$.2f%2$s * %4$d = %3$.2f', @$FacePrice{'Price','units','Total'}, $num_letters * $qty );
				$price += $$FacePrice{Total};
			} else {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No price for Face<br/>';
			}
		}

		if ( $minimumCharge > 0 and $price < $minimumCharge ) {
			$price = $minimumCharge;
		} # end if
		$unitPrice = $price / $qty;
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $unitPrice * (1+$Project->markup()/100) );
		if ( $$specs{"OverridePrice$qty_index"} ne 'Y' ) {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price*(1+$$specs{"Markup$qty_index"}/100)*(1+$Project->markup()/100) );
		} else {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{"txtPrice$qty_index"} );
		} # end if
	} # end foreach qty_index

	return $$specs{Status} = $status;
} # end sub calc

sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;
	if ( $qty_index ) {
		return '';
	} # end if

	return '';
} # end sub summary

sub display {
} # end sub display

sub save {
} # end sub save
1;

__END__
