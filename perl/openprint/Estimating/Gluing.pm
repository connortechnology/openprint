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

package openprint::Estimating::Gluing;
use strict;

require sql;
require openprint::service;

	#'ServiceType',
	#'rdbGluingType',
my @variables = (
	'OverridePrice1', 'OverridePrice2', 'OverridePrice3',
	'Markup1', 'Markup2', 'Markup3',
	'txtPrice1', 'txtPrice2', 'txtPrice3',
	'txtUnitPrice1', 'txtUnitPrice2', 'txtUnitPrice3',
	'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
);

sub variables {
	my ( $p_id, $s_id, $specs ) = @_;
	my @v = @variables;
	my $Project = new openprint::Project( $p_id );
	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		push @v, ( "txtArea-$$sig_specs{'SignatureIndex'}","chkOverrideArea-$$sig_specs{'SignatureIndex'}", );
	} # end foreach signature
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
		push @o, ( "chkOverrideArea-$$sig_specs{'SignatureIndex'}", );
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

	my $status = 'calculated';

$log->debug("GLUING!!!!!!!!!!!!!!!!!!");

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();

	foreach ( @outputs ) {
		delete $$specs{$_};
	} # end foreach

	my $makeReadyPrice = openprint::service::get_price( 'GluingMakeReady', undef, undef );
	my $minimumCharge = openprint::service::get_price( 'GluingMinimumCharge', undef, undef );

	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );

		if ( $$specs{"chkOverrideArea-$$sig_specs{SignatureIndex}"} ne 'Y' ) {
			$$specs{"txtArea-$$sig_specs{SignatureIndex}"} = 0;
# Figure out square area of gluing
			if ( sets::isin( $$sig_specs{'rdbTemplateType'}, ['2Panel1Pocket','2Panel2Pocket','TriFoldDoublePocket'] ) ) {
				if ( $$sig_specs{'chkPocketLeft'} eq 'Left' ) {
					$$specs{"txtArea-$$sig_specs{SignatureIndex}"} += .5 * $$sig_specs{'PocketSize'};
				} # end if
				if ( $$sig_specs{'chkPocketRight'} eq 'Right' ) {
					$$specs{"txtArea-$$sig_specs{SignatureIndex}"} += .5 * $$sig_specs{'PocketSize'};
				} # end if
			} # end if
		} # end if

		if ( $$specs{"txtArea-$$sig_specs{SignatureIndex}"} eq '' ) {
			$$specs{'help'} = 'Please enter the area in square inches to be covered in glue.';
			return 'uncalculated';
		} # end if

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
			my %servicePrice = openprint::service::get_price_object( 'Gluing', $qty, undef );
			if ( sets::isin( $servicePrice{'units'}, ['', 'Per M', 'Per 1000'] ) ) {
				$servicePrice{'Total'} = $qty * $servicePrice{'Price'} / 1000;
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf( "Service: \$\%.2f \%s = \$\%.2f<br/>", @servicePrice{'Price','units','Total'} );
			} # end if
			$price = $makeReadyPrice + $servicePrice{'Total'};
			if ( my @Materials = openprint::Material::find('name'=>'Glue') ) {
				my %materialPrice = $Materials[0]->get_price( $$specs{"txtArea-$$sig_specs{SignatureIndex}"}, undef );
				if ( %materialPrice ) {
					$materialPrice{'Total'} = $materialPrice{'Price'} * $$specs{"txtArea-$$sig_specs{SignatureIndex}"} * $qty;
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf( "Material: \$\%.2f \%s * \%.2f square inches * \%d = \$\%.2f<br/>", @materialPrice{'Price','units'}, $$specs{"txtArea-$$sig_specs{SignatureIndex}"}, $qty, $materialPrice{'Total'} );
				} else {
					$$specs{'hdnBreakdown'.$qty_index} .= "No Material Price.<br/>";
				} # end if
				$price += $materialPrice{'Total'};
			} else {
				$$specs{'hdnBreakdown'.$qty_index} .= "No Material.<br/>";
			} # end if

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
	} # end foreach signature

	return $status;
} # end sub calc

sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;
	if ( $qty_index ) {
		return '';
	} # end if

	return '';
} # end sub summary

sub save {
} # end sub save
1;

__END__
