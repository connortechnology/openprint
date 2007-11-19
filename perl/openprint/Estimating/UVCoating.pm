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
		push @v, "SideOneCoatingType-$$specs{'SignatureIndex'}";
		push @v, "SideTwoCoatingType-$$specs{'SignatureIndex'}";
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

# A function that is smart enough to return true if the project needs perfing/UVCoating, and false if it doesn't.
sub neccessary {
	my ( $log, $dbh, $project_index ) = @_;

	return 0;
} # end sub neccessary

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';

	my $Project = new openprint::Project( $project_index );

	my %services = $Project->get_services( );

	my @all_equipment = openprint::Equipment::find( 'Specifications' => {'UVCoating Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'lower(strName)');

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
			my %results = signature_calc( $Project, $service_index, $specs, $signature_service_index, $sig_specs, $qty_index ) = @_;
			$GrandTotal += $results{'Total'};

		} # end foreach signature

		$$specs{"txtUnitPrice$qty_index"} = sprintf( '%.2f', $GrandTotal / $qty );
		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{ProjectMoneyFormat}, $GrandTotal );
	} # end foreach qty

	return $status;

} # end sub calc

sub signature_calc {
    my ( $Project, $service_index, $specs, $signature_service_index, $sig_specs, $qty_index ) = @_;

	$openprint::log->debug("Signatuer : $signature_service_index");
	if ( ! ( $$specs{"SideOneCoatingType-$$sig_specs{'SignatureIndex'}"} or $$specs{"SideTwoCoatingType-$$sig_specs{'SignatureIndex'}"} ) ) {
		$$specs{'alert'} .= 'Please select the coating types.<br/>';
		return 'uncalculated';
	} # end if
	if ( ( $$specs{"SideOneCoatingType-$$sig_specs{'SignatureIndex'}"} eq 'None' ) and ( $$specs{"SideTwoCoatingType-$$sig_specs{'SignatureIndex'}"} eq 'None' ) ) {
#$openprint::log->debug("Both are none");	
		next;
	} # end if

	my $qty = $$specs{"txtQuantity$qty_index"};
	$$specs{'hdnBreakdown'.$qty_index} .= "QTY: $qty:";
	if ( $$specs{'txtPressSheetComboItems'} ) {
		$qty *= $$specs{'txtPressSheetComboItems'};
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
		return 'uncalculated';
	} # end if

	my %bestPrice;

	my @equipment;	
	if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		@equipment = openprint::Equipment::find( 'strid'=>$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
	} else {
		@equipment = @all_equipment;
	} # endif

# Get the impositions to consider
	my $imposition = new openprint::Imposition();
	$imposition->load( $sig_specs, $qty_index );

	if ( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		if ( $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} > $imposition->imposition() or $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} <= 0 ) {
			$$specs{'alert'} = "The specified imposition is not possible.";
			last;
		} # end if
	} # end if

	my @impositions = ();
	if ( $services{'Cutting'} ) {
		$openprint::log->debug('Cutting');
		my @imps = openprint::imposition::get_all_impositions( $imposition );
		$openprint::log->debug('After get all Cutting' . @imps);
		for ( my $i = 0; $i < @imps; $i += 1 ) {
			$log->debug("Imposition: " . $imps[$i]{'Imposition'});
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
			my %ServicePrice;
			my %MaterialPrice;
			my $setupPrice;

			if ( 
					( $$specs{"SideOneCoatingType-$$sig_specs{'SignatureIndex'}"} and $$specs{"SideOneCoatingType-$$sig_specs{'SignatureIndex'}"} ne 'None' ) and 
					( $$specs{"SideTwoCoatingType-$$sig_specs{'SignatureIndex'}"} and $$specs{"SideTwoCoatingType-$$sig_specs{'SignatureIndex'}"} ne 'None' ) ) {
# Two sided job
				if ( $$specs{"SideOneCoatingType-$$sig_specs{'SignatureIndex'}"} ne $$specs{"SideTwoCoatingType-$$sig_specs{'SignatureIndex'}"} ) {
					if ( sets::isin( $$sig_specs{'ddmRunStyle'.$qty_index}, ['Work & Turn', 'Work & Tumble'] ) ) {
# Just a spot colour then.
						my $type = 'Spot';
						$setupPrice = openprint::service::get_price( $log, $dbh, $variable, 'UVCoating'.$type.'MakeReady', $qty*2, $Equipment );
						%ServicePrice = openprint::service::get_price_object( $log, $dbh, $variable, 'UVCoating'.$type, $qty*2/$imp->imposition(), $Equipment );
						if ( ! %ServicePrice ) {
# Don't have Spot
							if ( $$sig_specs{'txtImposition'.$qty_index} == $imp->imposition() ) {
								$$specs{'hdnBreakdown'.$qty_index} .= "Has to be cut in half, we don't support Spot UV.<br/>";

# Has to be cut in half at least.
								next;
							} # end if
						} # endif
						if ( $ServicePrice{'units'} eq 'Per M' ) {
							$ServicePrice{'Total'} = $ServicePrice{'Price'} / 1000;
						} elsif ( $ServicePrice{'units'} eq 'Per Hour' ) {
							$ServicePrice{'Total'} = $ServicePrice{'Price'} / $Equipment->specfication('UVCoatingRunSpeed') if $Equipment->specification('UVCoatingRunSpeed');
						} # end if

						if ( my @Materials = openprint::Material::find('name'=>'UVCoating') ) {
							%MaterialPrice = $Materials[0]->get_price( $qty*2/$imp->imposition(), $Equipment );
						} # end if
						if ( $MaterialPrice{'units'} eq 'Per Square Inch' ) {
							$MaterialPrice{'Total'} = $MaterialPrice{'Price'} * $qty;
						} # end if

# Div by imposition
						$ServicePrice{'Total'} /= $imp->imposition() if $imp->imposition();

						$totalPrice = $setupPrice + $MaterialPrice{'Total'} + ( $qty * $ServicePrice{'Total'} );
						$$specs{'hdnBreakdown'.$qty_index} .= "Setup: \$ $setupPrice, ";
						$$specs{'hdnBreakdown'.$qty_index} .= "Service: \$ $ServicePrice{'Price'} $ServicePrice{'units'}, ";
						$$specs{'hdnBreakdown'.$qty_index} .= "Material: \$ $MaterialPrice{'Price'} $MaterialPrice{'units'}, ";
						$$specs{'hdnBreakdown'.$qty_index} .= "Total: \$".sprintf('%.2f', int($totalPrice) )."<br/>";
					} else { # not @ & T
# Two separate runs
						$setupPrice = openprint::service::get_price( $log, $dbh, $variable, 'UVCoating'.$$specs{"SideOneCoatingType-$$sig_specs{'SignatureIndex'}"}.'MakeReady', $qty/$imp->imposition(), $Equipment );
						$setupPrice += openprint::service::get_price( $log, $dbh, $variable, 'UVCoating'.$$specs{"SideTwoCoatingType-$$sig_specs{'SignatureIndex'}"}.'MakeReady', $qty/$imp->imposition(), $Equipment );
						my %SideOneServicePrice = openprint::service::get_price_object( $log, $dbh, $variable, 'UVCoating'.$$specs{"SideOneCoatingType-$$sig_specs{'SignatureIndex'}"}, $qty*2/$imp->imposition(), $Equipment );
						if ( ! %SideOneServicePrice ) {
							%SideOneServicePrice = openprint::service::get_price_object( $log, $dbh, $variable, 'UVCoating',$qty*2/$imp->imposition(), $Equipment );
						} # end if
						if ( $SideOneServicePrice{'units'} eq 'Per M' ) {
							$SideOneServicePrice{'Total'} = $SideOneServicePrice{'Price'} / 1000;
						} elsif ( $SideOneServicePrice{'units'} eq 'Per Hour' ) {
							$SideOneServicePrice{'Total'} = $SideOneServicePrice{'Price'} / $Equipment->specification('UVCoatingRunSpeed') if $Equipment->specification('UVCoatingRunSpeed');
						} # end if
# Div by imposition
						$SideOneServicePrice{'Total'} /= $imp->imposition() if $imp->imposition();
						my %SideTwoServicePrice = openprint::service::get_price_object( $log, $dbh, $variable, 'UVCoating'.$$specs{"SideTwoCoatingType-$$sig_specs{'SignatureIndex'}"}, $qty*2/$imp->imposition(), $Equipment );
						if ( ! %SideTwoServicePrice ) {
							%SideTwoServicePrice = openprint::service::get_price_object( $log, $dbh, $variable, 'UVCoating',$qty*2/$imp->imposition(), $Equipment );
						} # end if
						if ( $SideTwoServicePrice{'units'} eq 'Per M' ) {
							$SideTwoServicePrice{'Total'} = $SideTwoServicePrice{'Price'} / 1000;
						} elsif ( $SideTwoServicePrice{'units'} eq 'Per Hour' ) {
							$SideTwoServicePrice{'Total'} = $SideTwoServicePrice{'Price'} / $Equipment->specification('UVCoatingRunSpeed') if $Equipment->specification('UVCoatingRunSpeed');
						} # end if
# Div by imposition
						$SideTwoServicePrice{'Total'} /= $imp->imposition() if $imp->imposition();

						$ServicePrice{'Total'} = $SideOneServicePrice{'Total'} + $SideTwoServicePrice{'Total'};

						if ( my @Materials = openprint::Material::find('name'=>'UVCoating') ) {
							%MaterialPrice = $Materials[0]->get_price( $qty*2/$imp->imposition(), $Equipment );
						} # end if
						if ( $MaterialPrice{'units'} eq 'Per Square Inch' ) {
							$MaterialPrice{'Total'} = $MaterialPrice{'Price'} * $qty;
						} # end if

						$totalPrice = $setupPrice + $MaterialPrice{'Total'} + ( $qty * ( $SideOneServicePrice{'Total'} + $SideTwoServicePrice{'Total'} ) );
						$$specs{'hdnBreakdown'.$qty_index} .= "Setup: \$ $setupPrice, ";
						$$specs{'hdnBreakdown'.$qty_index} .= "Side One Service: \$ $SideOneServicePrice{'Price'} $SideOneServicePrice{'units'}, ";
						$$specs{'hdnBreakdown'.$qty_index} .= "Side Two Service: \$ $SideTwoServicePrice{'Price'} $SideTwoServicePrice{'units'}, ";
						$$specs{'hdnBreakdown'.$qty_index} .= "Material: \$ $MaterialPrice{'Price'} $MaterialPrice{'units'}, ";
						$$specs{'hdnBreakdown'.$qty_index} .= "Total: \$".sprintf('%.2f', int($totalPrice) )."<br/>";
					} # end if together as W&T or Sheet Work
				} else { # both sides the same
					my $type = $$specs{"SideOneCoatingType-$$sig_specs{'SignatureIndex'}"};
					my $setupPrice = openprint::service::get_price( $log, $dbh, $variable, 'UVCoating'.$type.'MakeReady', $qty/$imp->imposition(), $Equipment );
					my %ServicePrice = openprint::service::get_price_object( $log, $dbh, $variable, 'UVCoating'.$type, $qty*2/$imp->imposition(), $Equipment );
					if ( ! %ServicePrice ) {
						%ServicePrice = openprint::service::get_price_object( $log, $dbh, $variable, 'UVCoating',$qty*2/$imp->imposition(), $Equipment );
					} # end if
					if ( $ServicePrice{'units'} eq 'Per M' ) {
						$ServicePrice{'Total'} = $ServicePrice{'Price'} / 1000;
					} elsif ( $ServicePrice{'units'} eq 'Per Hour' ) {
						$ServicePrice{'Total'} = $ServicePrice{'Price'} / $Equipment->specification('UVCoatingRunSpeed') if $Equipment->specification('UVCoatingRunSpeed');
					} # end if

					my %MaterialPrice;
					if ( my @Materials = openprint::Material::find('name'=>'UVCoating') ) {
						%MaterialPrice = $Materials[0]->get_price( $qty*2/$imp->imposition(), $Equipment );
					} # end if
					if ( $MaterialPrice{'units'} eq 'Per Square Inch' ) {
						$MaterialPrice{'Total'} = $MaterialPrice{'Price'} * $qty*2;
					} # end if

# Div by imposition
					$ServicePrice{'Total'} /= $imp->imposition() if $imp->imposition();

					$totalPrice = $setupPrice + $MaterialPrice{'Total'} + ( $qty *2* $ServicePrice{'Total'} );
					$$specs{'hdnBreakdown'.$qty_index} .= "Setup: \$ $setupPrice, ";
					$$specs{'hdnBreakdown'.$qty_index} .= "Service: \$ $ServicePrice{'Price'} $ServicePrice{'units'}, ";
					$$specs{'hdnBreakdown'.$qty_index} .= "Material: \$ $MaterialPrice{'Price'} $MaterialPrice{'units'}, ";
					$$specs{'hdnBreakdown'.$qty_index} .= "Total: \$".sprintf('%.2f', int($totalPrice) )."<br/>";
				} # end if sides the same or different

			} else { 
# Single sided
				my $type;
				if ( sets::isin( $$sig_specs{'ddmRunStyle'.$qty_index}, ['Work & Turn','Work & Tumble'] ) and $$sig_specs{'txtImposition'.$qty_index} == $imp->imposition() ) {
					$type = 'Spot';
				} elsif ( $$specs{"SideOneCoatingType-$$sig_specs{'SignatureIndex'}"} and $$specs{"SideOneCoatingType-$$sig_specs{'SignatureIndex'}"} ne 'None' ) {
					$type = $$specs{"SideOneCoatingType-$$sig_specs{'SignatureIndex'}"};
				} else { 
					$type = $$specs{"SideTwoCoatingType-$$sig_specs{'SignatureIndex'}"};
				} # end if
				my $setupPrice = openprint::service::get_price( $log, $dbh, $variable, 'UVCoating'.$type.'MakeReady', $qty, $Equipment );
				my %ServicePrice = openprint::service::get_price_object( $log, $dbh, $variable, 'UVCoating'.$type, $qty/$imp->imposition(), $Equipment );
				if ( ! %ServicePrice ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "$type UV not supported.<br/>";
					next;
				} # end if
				if ( $ServicePrice{'units'} eq 'Per M' ) {
					$ServicePrice{'Total'} = $ServicePrice{'Price'} / 1000;
				} elsif ( $ServicePrice{'units'} eq 'Per Hour' ) {
					$ServicePrice{'Total'} = $ServicePrice{'Price'} / $Equipment->specification('UVCoatingRunSpeed') if $Equipment->specification('UVCoatingRunSpeed');
				} # end if

				my %MaterialPrice;
				if ( my @Materials = openprint::Material::find('name'=>'UVCoating') ) {
					%MaterialPrice = $Materials[0]->get_price( $qty/$imp->imposition(), $Equipment );
				} # end if
				if ( $MaterialPrice{'units'} eq 'Per Square Inch' ) {
					$MaterialPrice{'Total'} = $MaterialPrice{'Price'} * $qty;
				} # end if

# Div by imposition
				$ServicePrice{'Total'} /= $imp->imposition() if $imp->imposition();


				$totalPrice = $setupPrice + $MaterialPrice{'Total'} + ( $qty * $ServicePrice{'Total'} );
				my %minimum = openprint::service::get_price_object( $log, $dbh, $variable, 'UVCoatingMinimumCharge', undef, $Equipment );
				if ( $totalPrice < $minimum{Price} ) {
					$totalPrice = $minimum{Price};
				} # end if
				$$specs{'hdnBreakdown'.$qty_index} .= "Setup: \$ $setupPrice, ";
				$$specs{'hdnBreakdown'.$qty_index} .= "Service: \$ $ServicePrice{'Price'} $ServicePrice{'units'}, ";
				$$specs{'hdnBreakdown'.$qty_index} .= "Material: \$ $MaterialPrice{'Price'} $MaterialPrice{'units'}, ";
				$$specs{'hdnBreakdown'.$qty_index} .= "Minimum: \$ $minimum{'Price'}, ";
				$$specs{'hdnBreakdown'.$qty_index} .= "Total: \$".sprintf('%.2f', int($totalPrice) )."<br/>";
			} # end if

			if ( $totalPrice < $bestPrice{'Total'} or ( ! defined $bestPrice{'Total'} ) ) {
				$bestPrice{'Total'} = $totalPrice;
				$bestPrice{'Setup'} = $setupPrice;
				$bestPrice{'Material'} = $MaterialPrice{'Total'};
				$bestPrice{'Service'} = $ServicePrice{'Total'};
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

#if ( $bestPrice{'Imposition'}->{'Orientation'} eq 'Vertical' ) {
#$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = $$specs{"txtWidth-$$sig_specs{'SignatureIndex'}"} * $bestPrice{'Imposition'}->columns();
#$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = $$specs{"txtHeight-$$sig_specs{'SignatureIndex'}"} * $bestPrice{'Imposition'}->rows();
#} else {
#$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = $$specs{"txtWidth-$$sig_specs{'SignatureIndex'}"} * $bestPrice{'Imposition'}->rows();
#$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = $$specs{"txtHeight-$$sig_specs{'SignatureIndex'}"} * $bestPrice{'Imposition'}->columns();
#} # end if
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
		return 'uncalculated';
	} else {
		$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = $bestPrice{'Equipment'}->strid();
	} # end if

	return %bestPrice;
} # end sub calc

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my $Project = new openprint::Project( $project_index );

	@{$$variable{'Signatures'}} = ();

	$_ = "SELECT lngEquipmentIndex FROM tbl_Equipment_Specifications WHERE strName='UVCoating Capable' AND strValue='Y'";
	@{$$variable{'EquipmentArray'}} = sql::execute( $log, $dbh, $_ );

	foreach my $signature_service_index ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );
		push @{$$variable{'Signatures'}}, @$sig_specs{'SignatureIndex','txtServiceDescription'};
	} # end foreach
} # end sub display


1;

__END__
