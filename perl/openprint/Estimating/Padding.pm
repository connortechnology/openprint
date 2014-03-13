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
require openprint::Paper;
require openprint::Project;

require sql;

my @variables = (
		'OverridePrice1', 'OverridePrice2', 'OverridePrice3',
		'Markup1', 'Markup2', 'Markup3',
        'txtPrice1', 'txtPrice2', 'txtPrice3',
        'txtUnitPrice1', 'txtUnitPrice2', 'txtUnitPrice3',
        'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
		'PageQuantity',
		'Backing',
		'rdbDTape',
		'glue_id','override_glue_id',
);

sub variables {
    return @variables;
}

my @no_output = (
	'ProjectIndex','ServiceIndex','ServiceType',
	'PageQuantity',
	'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
	'Backing',
	'rdbDTape','override_glue_id',
	'OverridePrice1', 'OverridePrice2', 'OverridePrice3',
	'Markup1', 'Markup2', 'Markup3',
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
	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );

	if ( ! $$specs{'Backing'} ) {
		$$specs{'Backing'} = $$printing_specs{'Backing'};
		@no_output = sets::exclude( ['Backing'], \@no_output );
	} else {
		@no_output = sets::union(@no_output, 'Backing');
	} # end if
	if ( ! $$specs{'Backing'} ) {
		$$specs{'alert'} = 'Please select your backing type.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	if ( ! $$specs{'PageQuantity'} ) {
		if ( $$printing_specs{'PageQuantity'} ) {
			$$specs{'PageQuantity'} = $$printing_specs{'PageQuantity'};
			@no_output = sets::exclude( ['PageQuantity'], \@no_output );
		} else {
			my $Paper = openprint::Paper::load_from_signature( $Project, $printing_specs, 1 );
			if ( ! ( $Paper->id() or $$Paper{custom} ) ) {
				my @sigs = $Project->signatures();
				if ( @sigs ) {
					my $sig_specs = openprint::service::get_specs_ref( $Project,$sigs[0] );
					$Paper = openprint::Paper::load_from_signature( $Project, $sig_specs, 1 );
				} # end if
			} # end if
			
			if ( $Paper and $Paper->parts() ) {
				$$specs{'PageQuantity'} = $Paper->parts();
				@no_output = sets::exclude( ['PageQuantity'], \@no_output );
			} # end if
		} # end if
	} else {
		@no_output = sets::union(@no_output, 'PageQuantity');
	} # end if
	if ( ! $$specs{'PageQuantity'} ) {
		$$specs{'alert'} = 'Please select how many pages each pad will have.<br/>';
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	if ( $Project->Type()->name() eq 'ScratchPads' ) {
		if ( $$specs{'PageQuantity'} < $openprint::config{'MinimumPagesWithoutCounting'} ) {
			if ( ! $$services{'Counting'} ) {
				$_ = $Project->add_service( 'Counting' );
				openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $_, 'Counting' ) if $_;
			} # end if
		} # end if
	} # end if

	my @Materials = openprint::Material->find('category'=>'Padding Glue');
	if ( $$specs{'override_glue_id'} eq 'Y' ) {
	} else {
		my $Paper;
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			$Paper = openprint::Paper::load_from_signature( $Project, $printing_specs, $qty_index );
			last;
		} # end foreach
		foreach my $Material ( @Materials ) {
			if ( sets::isin( $Paper->grade(), misc::trim(split(',',$Material->specification('Recommended For Stock Grade'))) ) ) {	
				$$specs{'glue_id'} = $Material->id();
			} # end if
		} # end foreach Material
	} # end if

	my $ProjectType = $Project->Type();

	my $minimumCharge;
	if ( ! ( $minimumCharge = openprint::service::get_price( 'Padding'.$ProjectType->name().'ChargeMinimum' ) ) ) {
		$minimumCharge = openprint::service::get_price( 'PaddingChargeMinimum' );
	} # end if

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$specs{'txtPrice'.$qty_index} = '';
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		next if ! $$specs{"txtQuantity$qty_index"};
		my $qty = $$specs{"txtQuantity$qty_index"};
		if ( ( $ProjectType->name() eq 'ScratchPads' ) and ( ! $$printing_specs{'PageQuantity'} ) ) {
			#$qty /= int( $$specs{'PageQuantity'} );
		} elsif ( ( $ProjectType->name() eq 'NCR' ) and ( ! $$printing_specs{'PageQuantity'} ) ) {
			$qty *= int( $$specs{'PageQuantity'} );
		} # end if
		$$specs{'hdnBreakdown'.$qty_index} .= "Minimum Charge: $minimumCharge<br/>";
		$$specs{'hdnBreakdown'.$qty_index} .= "QTY $qty_index: $qty<br/>";

		my $price = 0;

		my %MR = openprint::service::get_price_object( 'Padding'.$ProjectType->name().'MakeReady', $qty, undef );
		if ( ! %MR ) {
			%MR = openprint::service::get_price_object( 'PaddingMakeReady', $qty, undef );
		} # end if
		if ( %MR ) {
			$MR{'Total'} = $MR{'Price'};
			$price += $MR{'Total'};
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('MakeReady: $%.2f%s=$%.2f<br/>', @MR{'Price','units','Total'});
		} # end if

		my %ServicePrice;
		if ( ! ( %ServicePrice = openprint::service::get_price_object( 'Padding'.$ProjectType->name(), $qty, undef ) ) ) {
			%ServicePrice = openprint::service::get_price_object( 'Padding', $qty, undef );
		} # end if
		if ( ! %ServicePrice ) {
			$log->debug('No price');
			$status = 'uncalculated';
			$$specs{'alert'} = 'We print press sheets only for pads - please ask a trade bindery to estimate the finishing.';
			$$specs{"txtPrice$qty_index"} = sprintf( '%.2f', 0 );
			$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, 0 );
			next;
		} elsif ( sets::isin( lc $ServicePrice{'units'}, [ 'per pad', 'each' ] ) ) {
			$ServicePrice{'Total'} = $ServicePrice{'Price'} * $qty;
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('ServicePrice: $%1$.2f%2$s * %4$d = $%3$.2f<br/>', @ServicePrice{'Price','units','Total'}, $qty );
		} elsif ( lc $ServicePrice{'units'} eq 'per m' ) {
			$ServicePrice{'Total'} = $ServicePrice{'Price'} * $qty / 1000;
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('ServicePrice: $%1$.2f%2$s * %4$d = $%3$.2f<br/>', @ServicePrice{'Price','units','Total'}, $qty );
		} else {
			$$specs{'hdnBreakdown'.$qty_index} .= 'Unknown units for padding service.<br/>';
		} # end if
		$price += $ServicePrice{'Total'};
			
		if ( $$specs{'Backing'} eq 'Cardboard' ) {
			if ( my $Material = openprint::Material->find_one('name'=>'CardboardBacking') ) {
				my %CardboardPrice = $Material->get_price( $qty, undef );
				if ( $CardboardPrice{'units'} eq 'per square inch' ) {
					$CardboardPrice{'Total'} = Math::Round::nearest( 0.01, $CardboardPrice{'Price'} * $$printing_specs{'txtFinalWidth'} * $$printing_specs{'txtFinalHeight'} * $$specs{"txtQuantity$qty_index"} );
				} elsif ( $CardboardPrice{'units'} eq 'per square foot' ) {
					$CardboardPrice{'Total'} = Math::Round::nearest( 0.01, $CardboardPrice{'Price'} * ($$printing_specs{'txtFinalWidth'} * $$printing_specs{'txtFinalHeight'}/144) * $$specs{"txtQuantity$qty_index"} );
				} elsif ( $CardboardPrice{'units'} eq 'per pad' ) {
					$CardboardPrice{'Total'} = $qty * $CardboardPrice{'Price'};
				} # end if
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Cardboard Price: $%1$.2f%2$s * %4$sx%5$s = $%3$.2f<br/>', @CardboardPrice{'Price','units','Total'}, @$printing_specs{'txtFinalWidth','txtFinalHeight'} );
				$price += $CardboardPrice{'Total'};
			} # end if
		} # end if
		if ( $$specs{'rdbDTape'} eq 'Y' ) {
			if ( my $Material = openprint::Material->find_one('name'=>'DTape') ) {
				my %DTapePrice = $Material->get_price( $qty, undef );
				$DTapePrice{'Total'} = $DTapePrice{'Price'} * $$printing_specs{'txtFinalWidth'};
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('DTape Price: $%1$.2f%2$s = $%3$.2f<br/>', @DTapePrice{'Price','units','Total'} );
				$price += $DTapePrice{'Total'};
			} # end if
		} # end if
		if ( $$specs{'glue_id'} ) {
			my $calliper = get_finished_calliper( $Project, $specs );
			my $Material = new openprint::Material( $$specs{'glue_id'} );
			my %GluePrice = $Material->get_price( $$specs{"txtQuantity$qty_index"}, undef );
			if ( $GluePrice{units} eq 'per square inch' ) {
				$GluePrice{'Total'} = $GluePrice{Price} * $$printing_specs{'txtFinalWidth'} * $calliper * $$specs{"txtQuantity$qty_index"};
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('%1$s Price: $%2$.2f%3$s * %5$.2f * %6$.4f =$%4$.2f<br/>', $Material->description(), @GluePrice{'Price','units','Total'}, $$printing_specs{'txtFinalWidth'}, $calliper );
			} elsif ( $GluePrice{units} eq 'per square foot' ) {
				$GluePrice{'Total'} = $GluePrice{Price} * $$printing_specs{'txtFinalWidth'} * $calliper * $$specs{"txtQuantity$qty_index"} / 144;
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('%1$s Price: $%2$.2f%3$s * %5$.2f * %6$.4f =$%4$.2f<br/>', $Material->description(), @GluePrice{'Price','units','Total'}, $$printing_specs{'txtFinalWidth'}, $calliper );
			} # end if
			$price += $GluePrice{'Total'};
		} # end if Glues

		$price = $minimumCharge if $price < $minimumCharge;
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, ( $price/$qty ) * (1+$Project->markup()/100) );
		if ( $$specs{"OverridePrice$qty_index"} ne 'Y' ) {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price*(1+$$specs{"Markup$qty_index"}/100)*(1+$Project->markup()/100) );
		} else {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{"txtPrice$qty_index"} );
		} # end if
	} # end foreach
	return $$specs{Status} = $status;
} # end sub calc

sub summary {
    my ( $Project, $service_id, $specs, $qty_index ) = @_;
    $specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;
    my $text = '';
    if ( $qty_index ) {
		return '';		
	} # end if
	$text .= $$specs{'PageQuantity'} . ' pages per pad';
	my $Material = new openprint::Material( $$specs{'glue_id'} );
	$text .= ' using ' . $Material->description();
	if ( $$specs{'Backing'} ne 'None' ) {
		$text .= ' +' . $$specs{'Backing'};
	} else {
		$text .= ' no backing';
	} # end if
	if ( $$specs{'rdbDTape'} eq 'Y' ) {
		$text .= ' +DTape';
	} # end if
	return $text;
} # end sub summary

sub save {
	my ( $p_id, $s_id, $param ) = @_;
	my $Project = new openprint::Project( $p_id );
	my $services = $Project->services();
	my $project_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );
	if ( ( $$param{'PageQuantity'} != $$project_specs{'PageQuantity'} ) or ( $$param{'Backing'} ne $$project_specs{'Backing'} ) ) {
		openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $Project->id(), $$services{''}[0], 'PageQuantity', $$param{'PageQuantity'} );
		openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $Project->id(), $$services{''}[0], 'Backing', $$param{'Backing'} );
		# FOrce recalc of printing
		openprint::Estimating::MultiPage::calculate_signatures( $Project );
		openprint::service::auto_calculate( $Project );
	} # end if
} # end sub save

sub get_finished_calliper { 
	my ( $Project, $specs ) = @_; 

	my $services = $Project->services();

	my $finished_calliper;
    foreach my $signature_service_index ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
		$finished_calliper += $$specs{'PageQuantity'} * $$sig_specs{'txtSpecificStockCalliper'};
	} # end foreach
	return $finished_calliper;
} # end sub get_finished_calliper

sub display {
} # end sub display

1;
__END__
