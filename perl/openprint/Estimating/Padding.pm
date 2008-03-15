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

package openprint::Estimating::Padding;
use strict;

require openprint::service;
require openprint::Material;

require sql;

my @variables = (
        'txtPrice1', 'txtPrice2', 'txtPrice3',
        'txtUnitPrice1', 'txtUnitPrice2', 'txtUnitPrice3',
        'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
		'PageQuantity',
		'rdbCardboardBacking',
		'rdbDTape',
		'glue_id',
);

sub variables {
    return @variables;
}

my @no_output = (
	'ProjectIndex','ServiceIndex','ServiceType',
	'PageQuantity',
	'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
	'rdbCardboardBacking',
	'rdbDTape',
);

sub no_outputs {
	return @no_output;
} # end sub no_outputs

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();
	my $status = 'calculated';

	if ( ! $$services{''} ) {
		$$specs{'alert'} .= 'Unable to find Project Service.<br/>';
		return 'uncalculated';
	} # end if
	# Pull from printing service
	my $sig_specs = openprint::service::get_specs_ref( $project_index, $$services{''}[0] );

	if ( ! $$specs{'rdbCardboardBacking'} ) {
		$$specs{'alert'} = 'Please select whether you need cardboard backing.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	if ( ( ! $$specs{'PageQuantity'} ) and $$sig_specs{'PageQuantity'} ) {
		$$specs{'PageQuantity'} = $$sig_specs{'PageQuantity'};
		@no_output = sets::union( @no_output, 'PageQuantity' );
	} # end if
	if ( ! $$specs{'PageQuantity'} ) {
		$$specs{'alert'} = 'Please select how many pages each pad will have.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	if ( $$specs{'PageQuantity'} < 100 ) {
		if ( ! $$services{'Counting'} ) {
			$_ = openprint::print_project::insert_service( $log, $dbh, $project_index, 'Counting' );
			openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $_, 'Counting' ) if $_;
		} # end if
	} elsif ( $$services{'Counting'} ) {
		foreach my $si ( @{$$services{'Counting'}} ) {
			openprint::print_project::delete_service( $log, $dbh, $project_index, $si );
		} # end foreach
	} # end if


	my $minimumCharge = openprint::service::get_price( 'PaddingChargeMinimum' );

	foreach my $qty_index ( 1 .. 3 ) {
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		next if ! $$specs{"txtQuantity$qty_index"};
		$$specs{'hdnBreakdown'.$qty_index} .= "Minimum Charge: $minimumCharge<br/>";
		$$specs{'hdnBreakdown'.$qty_index} .= "QTY $qty_index: ".$$specs{"txtQuantity$qty_index"}. "<br/>";
		my $price = openprint::service::get_price( 'Padding', $$specs{"txtQuantity$qty_index"}, undef );
		if ( ! $price ) {
			$log->debug('No price');
			$status = 'uncalculated';
			$$specs{"txtPrice$qty_index"} = sprintf( '%.2f', int($price) );
			$$specs{"txtUnitPrice$qty_index"} = sprintf( '%.2f', int($price) );
			next;
		} # end if
			
		$$specs{'hdnBreakdown'.$qty_index} .= "ServPrice: $price per pad<br/>";

		if ( $$specs{'rdbCardboardBacking'} eq 'Y' ) {
			if ( my @Materials = openprint::Material::find('name'=>'CardboardBacking') ) {
				my %CardboardPrice = $Materials[0]->get_price( $$specs{"txtQuantity$qty_index"}, undef );
				if ( $CardboardPrice{'units'} eq 'Per Square Inch' ) {
					$CardboardPrice{'Total'} = $CardboardPrice{'Price'} * $$sig_specs{'txtFinalWidth'} * $$sig_specs{'txtFinalHeight'};
				} elsif ( $CardboardPrice{'units'} eq 'Per Square Foot' ) {
					$CardboardPrice{'Total'} = $CardboardPrice{'Price'} * ($$sig_specs{'txtFinalWidth'} * $$sig_specs{'txtFinalHeight'}/144);
				} elsif ( $CardboardPrice{'units'} eq 'Per Pad' ) {
					$CardboardPrice{'Total'} = $CardboardPrice{'Price'};
				} # end if
				$$specs{'hdnBreakdown'.$qty_index} .= "Cardboard Price: $CardboardPrice{'Price'} $CardboardPrice{'units'} * $$sig_specs{'txtFinalWidth'} x $$sig_specs{'txtFinalHeight'} = $CardboardPrice{'Total'} per pad<br/>";
				$price += $CardboardPrice{'Total'};
			} # end if
		} # end if
		if ( $$specs{'rdbDTape'} eq 'Y' ) {
			if ( my @Materials = openprint::Material::find('name'=>'DTape') ) {
				my %DTapePrice = $Materials[0]->get_price( $$specs{"txtQuantity$qty_index"}, undef );
				my $dtape_price += $DTapePrice{Price} * $$sig_specs{'txtFinalWidth'};
				$$specs{'hdnBreakdown'.$qty_index} .= "DTape Price: $dtape_price per pad<br/>";
				$price += $dtape_price;
			} # end if
		} # end if
		if ( my @Materials = openprint::Material::find('category'=>'Padding Glue') ) {
			foreach my $Material ( @Materials ) {
				if ( $Material->id() == $$specs{'glue_id'} ) {
					my %GluePrice = $Material->get_price( $$specs{"txtQuantity$qty_index"}, undef );
					if ( $GluePrice{units} eq 'Per Square Inch' ) {
						$GluePrice{'Total'} = $GluePrice{Price} * $$sig_specs{'txtFinalWidth'} * openprint::print::get_finished_calliper( $Project->id() );
					} # end if
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('%s Price: $%.2f%s=$%.2f<br/>', $Material->description(), @GluePrice{'Price','units','Total'} );
					$price += $GluePrice{'Total'};
					last;
				} # end if
			} # end foreach

		} # end if Glues

		$$specs{"txtUnitPrice$qty_index"} = sprintf( '%.2f', $price );
	
		$price *= $$specs{"txtQuantity$qty_index"};
		$price = $minimumCharge if $price < $minimumCharge;
		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price );

	} # end foreach
	return $status;
} # end sub calc

sub summary {
} # end sub summary

1;
__END__
