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

package openprint::Estimating::Perforating;
use strict;

require sql;
require openprint::service;
require openprint::Material;
require openprint::imposition;
require openprint::Imposition;
require openprint::project;

my $debug = 0;

my @variables = (
	'txtQuantity1','txtQuantity2','txtQuantity3',
    'txtPrice1','txtPrice2','txtPrice3',
);
sub variables {
	my $p_id = shift;
	my @v = @variables;

	my $Project = new openprint::Project( $p_id );
	foreach my $signature_service_index ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $p_id, $signature_service_index );
		
		foreach my $qty_index ( 1 .. 3 ) {
			next if ! $$sig_specs{'txtQuantity'.$qty_index};
			push @v, (
				 "chkOverrideDimensions-$$sig_specs{'SignatureIndex'}",
				 "txtQty-$$sig_specs{'SignatureIndex'}", "chkOverrideQty-$$sig_specs{'SignatureIndex'}",
				 "txtWidth-$$sig_specs{'SignatureIndex'}", "txtHeight-$$sig_specs{'SignatureIndex'}",
				 "ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index", "chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index",
				 "txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index", "chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index",
				 "txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index", "txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index",
				 );
		} # end foreach qty_index
	} # end foreach signature_service_index
	return @v;
} # end sub variables

my @no_output = (
	
);

sub no_outputs {
	return @no_output;
}


# A function that is smart enough to return true if the project needs perfing, and false if it doesn't.
sub neccessary {
	my ( $log, $dbh, $Project ) = @_;

    #$Project = new openprint::Project( $Project ) if ref $Project ne 'openprint::Project';
#
    #my %services = $Project->get_services( );
    #if ( $services{'NoBindery'} ) {
        #$log->debug(" ** Project is marked as No bindery, Perforating not needed ! ** ");
        #return 0;
    #} # end if

	#$log->debug("PERF NOT NEEDED!");
	return 0;
} # end sub neccessary

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';

	my $Project = new openprint::Project( $project_index );
	my %services = $Project->get_services();

$log->debug("BEGIN PERFING!!!!!!!!!!!!!!!!!!");

	my $scoring_service_index = $services{'Scoring'}[0] if $services{'Scoring'};
	my $cutting_service_index = $services{'Cutting'}[0] if $services{'Cutting'};
# Can only use the stitcher for scoring if we are stitching.  There are also thickness constraints
	my ( $stitching_service_index ) = $services{'SaddleStitching'}[0];
# Can only use the stitcher for scoring if we are stitching.  There are also thickness constraints
	( $stitching_service_index ) = $services{'LoopStitching'}[0] if ! $stitching_service_index;

	my @all_equipment = openprint::Equipment::find( 'Specifications' => {'Perforating Capable'=>'Y'}, 'UseInEstimating'=>'Y');
	my @stitchers = openprint::Equipment::find( 'Specifications' => {'Stitching Capable'=>'Y'}, 'UseInEstimating'=>'Y');

	if ( ! $stitching_service_index ) {
		@all_equipment = sets::exclude( \@stitchers, \@all_equipment );
	} # end if

	foreach my $qty_index ( 1 .. 3 ) {
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		if ( ! $$specs{"txtQuantity$qty_index"} > 0 ) {
			next;
		} # end if
		$$specs{'hdnBreakdown'.$qty_index} = qq`QTY $qty_index ( $$specs{"txtQuantity$qty_index"} )<br/>`;
		my $qty = $$specs{"txtQuantity$qty_index"};
		if ( $$specs{'txtPressSheetComboItems'} ) {
			$qty *= $$specs{'txtPressSheetComboItems'};
		} # end if

		my $totalServicePrice = 0;
		my $totalSetupPrice = 0;
		my $totalMaterialPrice = 0;
		my $qtyTotal = 0;

		if ( openprint::project::get_project_type( $log, $dbh, $project_index ) eq 'MultiPagePublication'  ) {
			$$specs{'alert'} = 'We are unable to auto-calculate a price for perforation on a multipage publication. Please call for pricing.';
			$status = 'uncalculated';
		} # end if
		foreach my $signature_service_index ( $Project->signatures() ) {
            my $sig_specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );
			$$specs{'hdnBreakdown'.$qty_index} .= qq`Signature: $$sig_specs{'SignatureIndex'}<br/>`;

			if ( $$sig_specs{'PageQuantity'} ) {
				$qty *= $$sig_specs{'PageQuantity'};
			} # end if

			@no_output = sets::union( @no_output,
					"txtQty-$$sig_specs{'SignatureIndex'}", 
					"chkOverrideQty-$$sig_specs{'SignatureIndex'}",
					"chkOverrideDimensions-$$sig_specs{'SignatureIndex'}",
					"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index",
					"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index",
					( $$specs{"chkOverrideDimensions-$$sig_specs{'SignatureIndex'}"} eq 'Y' ? ("txtWidth-$$sig_specs{'SignatureIndex'}", "txtHeight-$$sig_specs{'SignatureIndex'}") : () ),
					( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ? "txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index" : () ),
					);


            $$specs{'hdnBreakdown'.$qty_index} .= "Signature: $$sig_specs{'txtServiceDescription'}, " if $$sig_specs{'txtServiceDescription'} ne '';

			if ( $$specs{"chkOverrideDimensions-$$sig_specs{'SignatureIndex'}"} ne 'Y' ) {
				@$specs{"txtWidth-$$sig_specs{'SignatureIndex'}", "txtHeight-$$sig_specs{'SignatureIndex'}"} = @$sig_specs{'txtWidth','txtHeight'};
			} # end if

			next if ! $$specs{"txtQty-$$sig_specs{'SignatureIndex'}"};
			$qtyTotal += $$specs{"txtQty-$$sig_specs{'SignatureIndex'}"};

			# If any of the signatures doesn't have an imposition, then we are in an incomplete state.
			if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
				$$specs{'alert'} = 'Printing calculations are not complete.';
				return 'uncalculated';
			} # end if

			my $bestPrice = 0;
			my $bestEquipment = '';
			my $bestSetupPrice = 0;
			my $bestMaterialPrice = 0;
			my $bestServicePrice = 0;
			my $bestImposition;

			my @equipment;
			if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
				@equipment = openprint::Equipment::find( 'strid'=>$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
				$log->debug("Overriding Equipment to: " . $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
			} else {
				@equipment = @all_equipment;
			} # endif

			my $imposition = new openprint::Imposition();
			$imposition->load( $sig_specs, $qty_index );

			if ( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
				if ( $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} > $imposition->imposition() or $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} <= 0 ) {
					$$specs{'alert'} = "The specified imposition is not possible.";
					last;
				} # end if
			} # end if


			my @impositions = ();
			if ( $cutting_service_index ) {
				my @imps = openprint::imposition::get_all_impositions( $imposition );
				for ( my $i = 0; $i < @imps; $i += 1 ) {
					if ( ( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' )
							or ( $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} == $imps[$i]->imposition() )
					   ) {
						push @impositions, $imps[$i];
					} # end if
					for ( my $j = $i + 1; $j < @imps; $j += 1 ) {
						if ( $imps[$i]->imposition() == $imps[$j]->imposition() and $imps[$i]->rows() == $imps[$j]->rows() ) {
							splice @imps, $j, 1;
							$j -= 1;
						} # end if
					} # end foreach
				} # end foreach

				
# if We have cutting, then we can cut the press sheets.
				#while ( $imposition->imposition() ) {
					#if ( $$specs{"chkOverrideImposition$qty_index-$$sig_specs{'SignatureIndex'}"} ne 'Y' or $$specs{"txtImposition$qty_index-$$sig_specs{'SignatureIndex'}"} == $imposition->imposition() ) {
						#my %copy = %imposition;
						#push @impositions, \%copy;
					#} # end if
				#} # end while
			} else {
				@impositions = ( $imposition );
			} # end if

			my ( $scor_equipment, $scor_imposition );
			if ( $scoring_service_index ) {
				( $scor_equipment, $scor_imposition ) = openprint::service::get_specifications( $log, $dbh, $project_index, $scoring_service_index, "ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index", "txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index" );
				if ( ! $scor_equipment ) {
					$log->debug("No equipment selected for scoring.  Quitting.");
					$$specs{'alert'} = 'Scoring calculations are not complete.  Your project contains a scoring service.  It must be completed before the Perforation service.';
					return 'uncalculated';
				} # end if
			} # end if

			foreach my $Equipment ( @equipment ) {
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf("\t\tEquipment: %s, ", $Equipment->name() );

				my $setupPrice = openprint::service::get_price( $log, $dbh, $variable, 'PerforationMakeReady', undef, $Equipment );
				$$specs{'hdnBreakdown'.$qty_index} .= "Setup: \$".sprintf( '%.2f', $setupPrice) ."<br/>";

				foreach my $imposition ( @impositions ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "\tImposition: " . $imposition->imposition() .": ";
					my $width = $$specs{"txtWidth-$$sig_specs{'SignatureIndex'}"} * ( $imposition->image_orientation() eq 'Vertical' ? $imposition->columns() : $imposition->rows() );
					my $height = $$specs{"txtHeight-$$sig_specs{'SignatureIndex'}"} * ( $imposition->image_orientation() eq 'Vertical' ? $imposition->rows() : $imposition->columns() );

					if ( $_ = $Equipment->fits( $width, $height, $$sig_specs{'txtSpecificStockCalliper'} ) ) {
						$$specs{'hdnBreakdown'.$qty_index} .= "\t$_<br/>";
						next;
					} # end if

					my %servicePrice;
					my $servicePrice;
					my %materialPrice;
					my $materialPrice = 0;

					
					if ( $scor_equipment eq $Equipment->strid() and $scor_imposition == $imposition->imposition() ) {
						$$specs{'hdnBreakdown'.$qty_index} .= "\tSame equipment as scoring, no service price needed.<br/>";
					} else {
						%servicePrice = openprint::service::get_price_object( $log, $dbh, $variable, 'Perforating', $$specs{"txtQty-$$sig_specs{'SignatureIndex'}"}, $Equipment );
						# I don't know if we should be multiplying by this or not.. how many perfs can a given piece of equipment do in an impression?
						#$servicePrice *= $$specs{"txtQty-$signature_index"};
					} # end if

					if ( lc $servicePrice{'units'} eq 'per m' ) {
						$servicePrice = $servicePrice{'Price'} / 1000;
					} elsif ( lc $servicePrice{'units'} eq 'per hour' ) {
						if ( int ( $_ = $Equipment->specifications('PerfScoreRunSpeed') ) ) {
							$servicePrice = $servicePrice{'Price'} / $_;
						} # end if
					} # end if
					if ( my @Materials = openprint::Material::find('name'=>'PerforatingRule') ) {
						%materialPrice = $Materials[0]->get_price( $$specs{"txtQty-$$sig_specs{'SignatureIndex'}"}, $Equipment );
						if ( $materialPrice{'units'} eq 'Per Rule' ) {
							$materialPrice = $materialPrice{'Price'} * $$specs{"txtQty-$$sig_specs{'SignatureIndex'}"};
						} # end if
					} # end if

# Div by imposition
					$servicePrice /= $imposition->imposition() if $imposition->imposition();

					my $totalPrice = $setupPrice + $materialPrice + $qty * $servicePrice;
					$$specs{'hdnBreakdown'.$qty_index} .= "Service: \$ $servicePrice{'Price'} $servicePrice{'units'}, ";
					$$specs{'hdnBreakdown'.$qty_index} .= "Material: \$ $materialPrice{'Price'} $materialPrice{'units'}, ";
					$$specs{'hdnBreakdown'.$qty_index} .= "\t\tTotal: \$".sprintf('%.2f', int($totalPrice) )."<br/>";


					if ( $totalPrice < $bestPrice or $bestPrice == 0 ) {
						$bestPrice = $totalPrice;
						$bestSetupPrice = $setupPrice;
						$bestMaterialPrice = $materialPrice;
						$bestServicePrice = $servicePrice;
						$bestEquipment = $Equipment;
						$bestImposition = $imposition;
					} # end if
				} # end foreach imposition
			} # end foreach equipment

			$totalSetupPrice += $bestSetupPrice;
			$totalServicePrice += $bestServicePrice;
			$totalMaterialPrice += $bestMaterialPrice;

			$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = $bestEquipment->strid();

			if ( $bestImposition ) {
				$$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} = $bestImposition->imposition();
				if ( $bestImposition->image_orientation() eq 'Vertical' ) {
					$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = $$specs{"txtWidth-$$sig_specs{'SignatureIndex'}"} * $bestImposition->columns();
					$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = $$specs{"txtHeight-$$sig_specs{'SignatureIndex'}"} * $bestImposition->rows();
				} else {
					$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = $$specs{"txtWidth-$$sig_specs{'SignatureIndex'}"} * $bestImposition->rows();
					$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = $$specs{"txtHeight-$$sig_specs{'SignatureIndex'}"} * $bestImposition->columns();
				} # end if
			} else {
				$$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
				$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
				$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
			} # end if
			if ( ! $bestEquipment ) {
				$status = 'uncalculated';
				if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
					$$specs{'alert'} = "The selected equipment can not handle your project.  This may be because the stock is too heavy, or too large.";
				} else {
					$$specs{'alert'} = "No suitable equipment could be found for your project.  This may be because the stock is too heavy, or too large.";
				} # end if
			} # end if

		} # end foreach signature

		my $price = 0;
		my $additionalPrice = 0;
		my $unitPrice = 0;

		if ( $qtyTotal ) {
			$price = $totalSetupPrice + $qty * $totalServicePrice + $totalMaterialPrice;
			$unitPrice = $price / $qty;
		} else {
			$$specs{'hdnBreakdown'.$qty_index} .= 'Please specify # of perfs';
			$status = 'uncalculated';
		} # end if
		$$specs{"txtUnitPrice$qty_index"} = sprintf( '%.2f', $unitPrice );

		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price );
	} # end foreach quantities

	$log->debug("END PERFING!!!!!!!!!!!!!!!!!!");
	return $status;
} # end sub calc

sub get_specs {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	@{$$variable{'SignatureGroups'}} = ();

	$_ = "SELECT lngEquipmentIndex FROM tbl_Equipment_Specifications WHERE strName='Perforating Capable' AND strValue='Y'";
	@{$$variable{'EquipmentArray'}} = sets::union( @{$$variable{'EquipmentArray'}}, sql::execute( $log, $dbh, $_ ) );

	foreach my $signature_service_index ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );
		push @{$$variable{'SignatureGroups'}}, @$sig_specs{'SignatureIndex','txtServiceDescription'};
	} # end foreach

} # end sub get_scoring_specs

sub fits_on_equipment {
    my ( $log, $dbh, $equipment_specs, $width, $height, $calliper ) = @_;

    if ( $$equipment_specs{'Minimum Perforation Size'} and ( 1*$width < 1*$$equipment_specs{'Minimum Perforation Size'} ) ) {
        $log->debug("Doesn't fit width minimum");
        return 0;
    } # end if

    if ( $$equipment_specs{'Minimum Perforation Size'} and ( 1*$height < 1*$$equipment_specs{'Minimum Perforation Size'} ) ) {
        $log->debug("Doesn't fit height minimum");
        return 0;
    } # end if
    if ( $$equipment_specs{'Maximum Perforation Size'} and ( 1*$width > 1*$$equipment_specs{'Maximum Perforation Size'} ) ) {
        $log->debug("Doesn't fit width maximum");
        return 0;
    } # end if

    if ( $$equipment_specs{'Maximum Perforation Size'} and ( 1*$height > 1*$$equipment_specs{'Maximum Perforation Size'} ) ) {
        $log->debug("Doesn't fit height max");
        return 0;
    } # end if
    if ( $$equipment_specs{'Minimum Perforation Calliper'} and 1*$calliper < 1*$$equipment_specs{'Minimum Perforation Calliper'} ) {
        $log->debug("Calliper too small Calliper: ($calliper), Min: $$equipment_specs{'Minimum Perforation Calliper'}");
        return 0;
    } # end if
    if ( $$equipment_specs{'Maximum Perforation Calliper'} and 1*$calliper > 1*$$equipment_specs{'Maximum Perforation Calliper'} ) {
        $log->debug("Calliper too big");
        return 0;
    } # end if
    return 1;

} # end sub fits_on_equipment

sub summary {
	return '';
} # end sub summary

1;

__END__
