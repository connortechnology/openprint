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

package openprint::Estimating::UVCoating;
use strict;

require sql;
require openprint::service;
require openprint::Material;
require openprint::imposition;
require openprint::Imposition;


# Offline UVCoating
# Let's assume that each piece of equipment can do 1 coat at a time
# This service doesn't store it's own data, other than price.  It gets the info from the printing service.
#
my @variables = (
	'txtQuantity1','txtQuantity2','txtQuantity3',
	'txtPrice1','txtPrice2','txtPrice3',
);

sub variables {
	my $p_id = shift;

	my $Project = new openprint::Project( $p_id );
	my @v = @variables;
	foreach my $s_s_id ( $Project->signatures() ) {
		my $specs = openprint::service::get_specs_ref( $p_id, $s_s_id );
		foreach my $qty_index ( 1 .. 3 ) {
			push @v, "chkOverrideQty-$$specs{'SignatureIndex'}", "txtWidth-$$specs{'SignatureIndex'}", "txtHeight-$$specs{'SignatureIndex'}",
				 "ddmEquipment-$$specs{'SignatureIndex'}-$qty_index", "chkOverrideEquipment-$$specs{'SignatureIndex'}-$qty_index",
				 "txtImposition-$$specs{'SignatureIndex'}-$qty_index", "chkOverrideImposition-$$specs{'SignatureIndex'}-$qty_index",
				 "txtLayoutWidth-$$specs{'SignatureIndex'}-$qty_index", "txtLayoutHeight-$$specs{'SignatureIndex'}-$qty_index",
		} # end foreach
	} # end foreach
    return @v;
} # end sub variables

my @outputs = (
	'txtUnitPrice1','txtUnitPrice2','txtUnitPrice3',
	'txtPrice1','txtPrice2','txtPrice3',
	'ddmEquipment1', 'ddmEquipment2', 'ddmEquipment3',
	'hdnBreakdown1',
	'hdnBreakdown2',
	'hdnBreakdown3',
'alert',
);
sub outputs {
	return @outputs;
}
sub no_outputs {
} # end sub no_outputs

my @no_outputs = (
);

my @all_equipment;

# A function that is smart enough to return true if the project needs perfing/UVCoating, and false if it doesn't.
sub neccessary {
	my ( $log, $dbh, $project_index ) = @_;

	return 0;
} # end sub neccessary
sub signature_needs {
	my ( $Project, $specs ) = @_;

	foreach ( openprint::Estimating::Printing::get_colours( $specs, 'SideOne' ) ) {
		return 1 if $_ =~ /UV/;
	} # end foreach colour

	foreach ( openprint::Estimating::Printing::get_colours( $specs, 'SideTwo' ) ) {
		return 1 if $_ =~ /UV/;
	} # end foreach colour
} # end sub signature_needs

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';

	my $Project = new openprint::Project( $project_index );

	@all_equipment = openprint::Equipment::find( 'Specifications' => {'UVCoating Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'lower(strName)') if ! @all_equipment;

	foreach my $qty_index ( 1 .. 3 ) {
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		if ( ! $$specs{"txtQuantity$qty_index"} > 0 ) {
			next;
		} # end if
		$$specs{'hdnBreakdown'.$qty_index} = '';
		$$specs{'txtPrice'.$qty_index} = '';
		$openprint::log->debug("Signatures: " . $Project->signatures() );

		my $qty = $$specs{"txtQuantity$qty_index"};
		if ( $$specs{'txtPressSheetComboItems'} ) {
			$qty *= $$specs{'txtPressSheetComboItems'};
		} # end if

		my $GrandTotal;
		foreach my $signature_service_index ( $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );
			my %results = signature_calc( $Project, $service_index, $specs, $signature_service_index, $sig_specs, $qty_index );
			$GrandTotal += $results{'Total'};
			$status = 'uncalculated' if $results{'Status'} eq 'uncalculated';
		} # end foreach signature

		$$specs{"txtUnitPrice$qty_index"} = sprintf( '%.2f', $GrandTotal / $qty );
		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{ProjectMoneyFormat}, $GrandTotal );
	} # end foreach qty

	return $status;

} # end sub calc

sub signature_calc {
    my ( $Project, $service_index, $specs, $signature_service_index, $sig_specs, $qty_index, $imposition ) = @_;

	my %bestPrice;
	$bestPrice{'Status'} = 'uncalculated';


	my @front_uv;
	foreach ( openprint::Estimating::Printing::get_colours( $sig_specs, 'SideOne' ) ) {
		push @front_uv, $_ if $_ =~ /UV/;
$openprint::log->debug("Side one colour: $_");
	} # end foreach colour

	my @back_uv;
	foreach ( openprint::Estimating::Printing::get_colours( $sig_specs, 'SideTwo' ) ) {
		push @back_uv, $_ if $_ =~ /UV/;
$openprint::log->debug("Side two colour: $_");
	} # end foreach colour

	my @different_types = sets::union( @front_uv, @back_uv );

	$openprint::log->debug("Signature : $signature_service_index");
	if ( ! ( @front_uv or @back_uv ) ) {
		$$specs{'alert'} .= 'Please select the coating types.<br/>';
		return %bestPrice;
	} # end if

	my $qty = $$specs{"txtQuantity$qty_index"};
	$$specs{'hdnBreakdown'.$qty_index} .= "QTY: $qty:";
	if ( $$specs{'txtPressSheetComboItems'} ) {
		$qty *= $$specs{'txtPressSheetComboItems'};
	} # end if
	if ( $$sig_specs{'Versions'} ) {
		$qty *= $$sig_specs{'Versions'};
	} # end if

	@outputs = sets::union( @outputs, 
			"chkOverrideQty-$$sig_specs{'SignatureIndex'}", "txtWidth-$$sig_specs{'SignatureIndex'}", "txtHeight-$$sig_specs{'SignatureIndex'}",
			"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index", "chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index",
			"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index", "chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index",
			"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index", "txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index",
			);	

	$$specs{'hdnBreakdown'.$qty_index} .= "Signature: $$sig_specs{'txtServiceDescription'}, " if $$sig_specs{'txtServiceDescription'} ne '';

	@$specs{"txtWidth-$$sig_specs{'SignatureIndex'}", "txtHeight-$$sig_specs{'SignatureIndex'}"} = @$sig_specs{'txtWidth','txtHeight'};
# If any of the signatures doesn't have an imposition, then we are in an incomplete state.
	if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
		$$specs{'alert'} .= 'No imposition was found for printing. Please complete the printing estimation first.<br/>';
		return %bestPrice;
	} # end if

	@all_equipment = openprint::Equipment::find( 'Specifications' => {'UVCoating Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'lower(strName)') if ! @all_equipment;
	my @equipment;	
	if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		@equipment = openprint::Equipment::find( 'strid'=>$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
	} else {
		@equipment = @all_equipment;
	} # endif

# Get the impositions to consider
	if ( ! $imposition ) {
		$imposition = new openprint::Imposition();
		$imposition->load( $sig_specs, $qty_index );
	} # end if

	if ( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		if ( $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} > $imposition->imposition() or $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} <= 0 ) {
			$$specs{'alert'} = "The specified imposition is not possible.";
			last;
		} # end if
	} # end if

	my @impositions = ();
	my $services = $Project->services();
	if ( $$services{'Cutting'} ) {
		#$openprint::log->debug('Cutting');
		my @imps = openprint::imposition::get_all_impositions( $imposition );
		#$openprint::log->debug('After get all Cutting' . @imps);
		for ( my $i = 0; $i < @imps; $i += 1 ) {
			$openprint::log->debug("Imposition: " . $imps[$i]{'Imposition'});
			if ( ( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' )
					or ( $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} == $imps[$i]->imposition() )
			   ) {
				push @impositions, $imps[$i];
			} # end if

# Remove any other impositions that have th same setup
			for ( my $j = $i + 1; $j < @imps; $j += 1 ) {
				if ( $imps[$i]->imposition() == $imps[$j]->imposition() and $imps[$i]->rows() == $imps[$j]->rows() ) {
					splice @imps, $j, 1;
					$j -= 1;
				} # end if
			} # end for
		} # end for
	} else {
		@impositions = ( $imposition );
	} # end if
	$openprint::log->debug('DOne Cutting :' . @impositions);

	foreach my $Equipment ( @equipment ) {
		$$specs{'hdnBreakdown'.$qty_index} .= "\t\tEquipment: ".$Equipment->strid().",<br/>";

		foreach my $imp ( @impositions ) {
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf("\tImposition: \%dx\%d+\%dx\%d=\%dout :", @$imp{'columns','rows','dutch_columns','dutch_rows','imposition'} );
			next if ! ( $imp->rows() * $imp->columns() );
			my $width = $imposition->sheet_width() / ( $imposition->columns()/$imp->columns() );
#$$specs{"txtWidth-$$sig_specs{'SignatureIndex'}"} * ( $imposition->orientation() eq 'Vertical' ? $imposition->columns() : $imposition->rows() );
			my $height = $imposition->sheet_height() / ( $imposition->rows()/$imp->rows() );
#$$specs{"txtHeight-$$sig_specs{'SignatureIndex'}"} * ( $imposition->orientation() eq 'Vertical' ? $imposition->rows() : $imposition->column() );
			$$specs{'hdnBreakdown'.$qty_index} .= $width . 'x' . $height.'<br/>';

			if ( $_ = $Equipment->fits( $width, $height, $$sig_specs{'txtSpecificStockCalliper'} ) ) {
				$$specs{'hdnBreakdown'.$qty_index} .= "Doesn't fit. $_<br/>";
				next;
			} # end if

			my $totalPrice = 0;

			my @types;
			if ( sets::isin( $imposition->runstyle(), ['Work & Turn', 'Work & Tumble'] ) ) {
# need to merge any overalls into spots
				foreach my $type ( @different_types ) {
					if ( sets::isin( $type, \@front_uv ) and sets::isin( $type, \@back_uv ) ) {
						push @types, $type;
					} else {
						$type =~ s/Overall/Spot/;
					} # end if
					push @types, $type;
				} # end foreach
			} else {
				@types = @different_types;
			} # end if

			foreach my $type ( @types ) {
	
				if ( sets::isin( $type, \@front_uv ) and sets::isin( $type, \@back_uv ) ) {
				} else {
					if ( $type =~ /Overall/ and sets::isin( $imposition->runstyle(), ['Work & Turn', 'Work & Tumble'] ) ) {
						$type =~ s/Overall/Spot/;
						# Has to be a spot
					} # end if
				} # end if type is in both
			} # end foreach type
# Two sided job
# Just a spot colour then.
			foreach my $type ( @types ) {
				my $setupPrice += openprint::service::get_price( $type.' MakeReady', $qty/$imp->imposition(), $Equipment );

				my %ServicePrice = openprint::service::get_price_object( $type, $qty/$imp->imposition(), $Equipment );
				if ( lc $ServicePrice{'units'} eq 'per m' ) {
					$ServicePrice{'Total'} = $ServicePrice{'Price'} * $qty / 1000;
				} elsif ( lc $ServicePrice{'units'} eq 'per hour' ) {
					$ServicePrice{'Total'} = $ServicePrice{'Price'} * $qty / $Equipment->specification('UVCoatingRunSpeed') if $Equipment->specification('UVCoatingRunSpeed');
				} # end if
# Div by imposition
				$ServicePrice{'Total'} /= $imp->imposition();

				my %MaterialPrice;
				my $material_name = $type;
				$material_name =~ s/ ?Spot ?//;
				$material_name =~ s/ ?Overall ?//;
				if ( my @Materials = openprint::Material::find('name'=>$material_name) ) {
					%MaterialPrice = $Materials[0]->get_price( $qty*2/$imp->imposition(), $Equipment );
				} # end if
				if ( lc $MaterialPrice{'units'} eq 'per square inch' ) {
					$MaterialPrice{'Total'} = $MaterialPrice{'Price'} * $qty;
				} # end if

				$totalPrice += $setupPrice + $MaterialPrice{'Total'} + $ServicePrice{'Total'};
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('MR: $%.2f<br/>', $setupPrice );
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('MR: $%.2f + Service: $%.2f%s=%.2f + Material: $%.2f%s = $%.2f ) = $%.2f<br/>',
					$setupPrice, @ServicePrice{'Price','units','Total'}, @MaterialPrice{'Price','units','Total'}, $totalPrice );
			} # end foreach type
			my %minimum = openprint::service::get_price_object( 'UVCoatingMinimumCharge', undef, $Equipment );
			if ( $totalPrice < $minimum{Price} ) {
				$totalPrice = $minimum{Price};
			} # end if

			if ( $totalPrice < $bestPrice{'Total'} or ( ! defined $bestPrice{'Total'} ) ) {
				$bestPrice{'Total'} = $totalPrice;
				#$bestPrice{'Setup'} = $setupPrice;
				#$bestPrice{'Material'} = $MaterialPrice{'Total'};
				#$bestPrice{'Service'} = $ServicePrice{'Total'};
				$bestPrice{'Equipment'} = $Equipment;
				$bestPrice{'Imposition'} = $imp;
			} # end if
		} # end foreach equipment
	} # end foreach imposition
	$$specs{"txtPrice1-$$sig_specs{'SignatureIndex'}-$qty_index"} = $bestPrice{'Total'};

	if ( $bestPrice{'Imposition'} ) {
		$$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} = $bestPrice{'Imposition'}->imposition();
		$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = $bestPrice{'Imposition'}->layout_width();
		$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = $bestPrice{'Imposition'}->layout_height();
	} else {
		$$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
		$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
		$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
	} # end if

	if ( ! $bestPrice{'Equipment'} ) {
		if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
			$$specs{'alert'} = "The selected equipment can not handle your project.  This may be because the stock is too heavy, or too large.";
		} else {
			$$specs{'alert'} = "No suitable equipment could be found for your project.  This may be because the stock is too heavy, or too large.";
		} # end if
		$bestPrice{'Status'} = 'uncalculated';
		return %bestPrice;
	} else {
		$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = $bestPrice{'Equipment'}->strid();
	} # end if

	$bestPrice{'Status'} = 'calculated';
	return %bestPrice;
} # end sub calc

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my $Project = new openprint::Project( $project_index );

	@{$$variable{'Equipment'}} = openprint::Equipment::find( 'Specifications' => {'UVCoating Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'lower(strName)');
} # end sub display

# Copies the UV settings back into the printing service, because that is where we have chosen to store them.
sub save {
	my ( $p_id, $s_id, $params ) = @_;
	my $Project = new openprint::Project( $p_id );
	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $p_id, $ss_id );
		#openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $p_id, $ss_id, 'SideOneUVCoatingType', $$params{'SideOneCoatingType-'.$$sig_specs{'SignatureIndex'}} );
		#openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $p_id, $ss_id, 'SideTwoUVCoatingType', $$params{'SideTwoCoatingType-'.$$sig_specs{'SignatureIndex'}} );
	} # end foreach
} # end sub

sub summary {
	return '';
} # end sub summary


1;

__END__
