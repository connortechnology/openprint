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

package openprint::Estimating::Proofs;
use POSIX qw( ceil );
use strict;

require sql;
require openprint::print;
require openprint::service;
require openprint::Estimating::Printing;

my $debug = 1;

my @variables = (
		'txtPrice',
		'CustomProofSpecs',
		'RequireColourProofs',
		);

my @output = (
);

sub variables {
	my ( $p_id, $s_id, $specs ) = @_;

	my $Project = new openprint::Project( $p_id );
	my @v = @variables;
	push @v, 'txtPrice1' if $Project->quantity( 1 );
	push @v, 'txtPrice2' if $Project->quantity( 2 );
	push @v, 'txtPrice3' if $Project->quantity( 3 );

	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		my $signature_index = $$sig_specs{'SignatureIndex'};
		foreach my $key ( keys %{$specs} ) {
			if ( $key =~ /^txtProofIndex-$signature_index-(\d*)-(\d*)$/ ) {
				my ( $proof_index, $qty_index ) = ( $1, $2 );

				push @v,	(
						"txtProofWidth-$signature_index-$proof_index-$qty_index",
						"txtProofHeight-$signature_index-$proof_index-$qty_index", 
						"txtProofQuantity-$signature_index-$proof_index-$qty_index",
						"ddmProofType-$signature_index-$proof_index-$qty_index",
						"txtProofUnitPrice-$signature_index-$proof_index-$qty_index",
						"txtProofIndex-$signature_index-$proof_index-$qty_index",
						"chkOverride-$signature_index-$proof_index-$qty_index",
						);
			} # end if
		} # end foreach key
	} # end foreach signature
	return @v;
} # end sub variables

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';

	$log->debug("START PROOFS!!!!!!!!!!!!!!!!!! ($project_index) ($service_index)") if $debug;
	my $Project = new openprint::Project( $project_index );

	my @signature_service_indices = $Project->signatures();

	foreach my $qty_index ( 1 .. 3 ) {
		if ( ! $Project->quantity($qty_index) ) {
			$$specs{"txtPrice$qty_index"} = '';
			next;
		} # end if
		my $totalPrice = 0;
		my $totalQuantity = 0;

		my %proof_indexes;
		my %proof_types;
		my %proof_totals;
		$$specs{'hdnBreakdown'.$qty_index} = "QTY: $qty_index<br/>";
        foreach my $key ( keys %{$specs} ) {
			if ( $key =~ /^txtProofIndex-(\d*)-(\d*)-$qty_index$/ ) {
				push @{$proof_indexes{$1}}, $$specs{$key};
				push @{$proof_types{$1}}, $$specs{"ddmProofType-$1-$2-$qty_index"};
			} # end if
        } # end foreach

		# First, build a hash containing the quantities of each proof.  The reason for this is to honour quantity discounts.
		foreach my $signature_service_index ( @signature_service_indices ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
			my $signature_index = $$sig_specs{'SignatureIndex'};
			$$specs{'hdnBreakdown'.$qty_index} .= "Signature $signature_index<br/>";
			if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No proofs needed because there is no imposition';
				next;
			} # end if

			#my @Equipment = openprint::Equipment::find( 'strid'=>$$signature_specs{'ddmPress'.$qty_index} );
			#return if ! @Equipment;

			#my $colour_proof_type = $Equipment[0]->specification( 'Default Colour Proof' );

			#if ( ($openprint::config{'Add Default Layout Proof'} eq 'Y') and ( ! sets::isin( $Equipment[0]->specification( 'Default Colour Proof' ), $proof_types{$signature_index} ) ) ) {
			if ( ( ! sets::isin( 1, $proof_indexes{$signature_index} ) ) and $openprint::config{'Add Default Layout Proof'} eq 'Y' ) {
				push @{$proof_indexes{$signature_index}}, 1;
			} # end if
			if ( ( ! sets::isin( 2, $proof_indexes{$signature_index} ) ) and $openprint::config{'Add Default Colour Proof'} eq 'Y' ) {
				push @{$proof_indexes{$signature_index}}, 2;
			} # end if
			if ( ( ! sets::isin( 3, $proof_indexes{$signature_index} ) ) and $openprint::config{'Add Default Press Proof'} eq 'Y' ) {
				push @{$proof_indexes{$signature_index}}, 3;
			} # end if
				
			foreach my $proof_index ( @{$proof_indexes{$signature_index}} ) {
				if ( $$specs{"chkOverride-$signature_index-$proof_index-$qty_index"} ne 'Y' ) {
					@output = sets::union( @output,
							"txtProofIndex-$signature_index-$proof_index-$qty_index",
							"txtProofWidth-$signature_index-$proof_index-$qty_index",
							"txtProofHeight-$signature_index-$proof_index-$qty_index",
							"txtProofQuantity-$signature_index-$proof_index-$qty_index",
							"ddmProofType-$signature_index-$proof_index-$qty_index",
							);

					if ( $proof_index == 1 ) {
						insert_layout_proof( $log, $dbh, $project_index, $service_index, $signature_service_index, 1, $qty_index, $specs );
					} elsif ( $proof_index == 2 ) {
						insert_colour_proof( $log, $dbh, $project_index, $service_index, $signature_service_index, 2, $qty_index, $specs );
					} elsif ( $proof_index == 3 ) {
						insert_press_proof( $log, $dbh, $project_index, $service_index, $signature_service_index, 3, $qty_index, $specs );
					} else {
						if ( sets::isin( $$specs{"ddmProofType-$signature_index-$proof_index-$qty_index"}, ['PolaProof','CanonProof','EpsonProof','FujiFinalProof'] ) ) {
							if ( $$specs{"chkOverride-$signature_index-$proof_index-$qty_index"} ne 'Y' ) {
								$$specs{"txtProofWidth-$signature_index-$proof_index-$qty_index"} = $$sig_specs{'txtWidth'};
								$$specs{"txtProofHeight-$signature_index-$proof_index-$qty_index"} = $$sig_specs{'txtHeight'};
							} # end if
						} # end if
					} # end if
				} else {

					if ( ($proof_index == 1) and ($$specs{"ddmProofType-$signature_index-$proof_index-$qty_index"} eq 'DigitalDylux' ) and ( $$specs{"txtProofQuantity-$signature_index-$proof_index-$qty_index"} < $openprint::config{'ForceDigitalDyluxQuantity'} ) ) {
						$$specs{'alert'} .= "We require Dylux Proofs<br/>";
						insert_layout_proof( $log, $dbh, $project_index, $service_index, $signature_service_index, 1, $specs );
						@output = sets::union( @output,
								"txtProofIndex-$signature_index-$proof_index-$qty_index",
								"txtProofWidth-$signature_index-$proof_index-$qty_index",
								"txtProofHeight-$signature_index-$proof_index-$qty_index",
								"txtProofQuantity-$signature_index-$proof_index-$qty_index",
								"ddmProofType-$signature_index-$proof_index-$qty_index",
								);
					} else {
						@output = sets::xor( @output,
								"txtProofIndex-$signature_index-$proof_index-$qty_index",
								"txtProofWidth-$signature_index-$proof_index-$qty_index",
								"txtProofHeight-$signature_index-$proof_index-$qty_index",
								"txtProofQuantity-$signature_index-$proof_index-$qty_index",
								"ddmProofType-$signature_index-$proof_index-$qty_index",
								);
					} # end if
				} # end if

				my ( $quantity, $type ) = @$specs{
					"txtProofQuantity-$signature_index-$proof_index-$qty_index",
						"ddmProofType-$signature_index-$proof_index-$qty_index",
				};
				if ( ! $proof_totals{$type} ) {
					$proof_totals{$type} = { Quantity => 0, Price => 0 };
				} # end if
				$proof_totals{$type}{Quantity} += $quantity;
				$totalQuantity += $quantity;
			} # end foreach my $proof_index
		} # end foreach my $signature_service_index

		foreach my $signature_service_index ( @signature_service_indices ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
			my $signature_index = $$sig_specs{'SignatureIndex'};
			if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
				next;
			} # end if
			my @Equipment = openprint::Equipment::find('strid'=>$$sig_specs{'ddmPress'.$qty_index} );
			next if ! @Equipment;

			foreach my $proof_index ( @{$proof_indexes{$signature_index}} ) {

				my ( $quantity, $type ) = @$specs{
					"txtProofQuantity-$signature_index-$proof_index-$qty_index",
						"ddmProofType-$signature_index-$proof_index-$qty_index",
				};
				$$specs{'hdnBreakdown'.$qty_index} .= "Proof: $proof_index: Quantity: $quantity, Type: $type<br/>";
				next if ! ( $type and $quantity );
				
				my %MakeReady = openprint::service::get_price_object( $type.'MakeReady', $proof_totals{$type}{Quantity}, undef );
				my %price;
				if ( $type eq 'PressProof' ) {
					%price = openprint::service::get_price_object( $type, $proof_totals{$type}{Quantity}, $Equipment[0] );
				} else {
					%price = openprint::service::get_price_object( $type, $proof_totals{$type}{Quantity}, undef );
				} # end if

				if ( lc $price{'units'} eq 'per square inch' ) {
					$price{'Total'} = $price{'Price'} * $$specs{"txtProofWidth-$signature_index-$proof_index-$qty_index"} * $$specs{"txtProofHeight-$signature_index-$proof_index-$qty_index"};	
				} elsif ( lc $price{'units'} eq 'per square foot' ) {
					$price{'Total'} = $price{'Price'} * $$specs{"txtProofWidth-$signature_index-$proof_index-$qty_index"} * $$specs{"txtProofHeight-$signature_index-$proof_index-$qty_index"} / 144;
				} else {
					$price{'Total'} = $price{'Price'};
				} # end if
				$$specs{"txtProofUnitPrice-$signature_index-$proof_index-$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price{'Total'} );
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('MR: %.2f + %.2f%s<br/>', $MakeReady{Price}, $price{Price}, $price{units} );
				$totalPrice += ( $price{'Total'} * $quantity) + $MakeReady{'Price'};
			} # end foreach my $proof_index
		} # end foreach my $signature_service_index

		my $minCharge = openprint::service::get_price( 'ProofsMinimumCharge', undef, undef );
		if ( $totalPrice < $minCharge and $totalQuantity ) {
			$totalPrice = $minCharge;
		} # end if

		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $totalPrice );
	} # end foreach qty_index

	$log->debug("PROOFS!!!!!!!!!!!!!!!!!!");
	return $status;
} # end sub calc

sub delete_proofs {
	my ( $log, $dbh, $project_index, $service_index, $signature_service_index, $qty_index ) = @_;

	my ( $signature_index ) = openprint::service::get_specifications( $log, $dbh, $project_index, $signature_service_index, 'SignatureIndex');
	$_ = 'SELECT COUNT(strValue) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=? AND strName LIKE?';
	my ( $number_of_proofs ) = sql::execute( $log, $dbh, $_, $project_index, $service_index, "txtProofQuantity-$signature_index-%-$qty_index" );
	$number_of_proofs = 3 if $number_of_proofs < 3;

	foreach my $proof_index ( 1 .. $number_of_proofs ) {
		sql::execute( undef, undef, q{DELETE FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=? AND strName=?}, $project_index, $service_index, "txtProofQuantity-$signature_index-$proof_index-$qty_index" );
		sql::execute( undef, undef, q{DELETE FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=? AND strName=?}, $project_index, $service_index, "txtProofWidth-$signature_index-$proof_index-$qty_index" );
		sql::execute( undef, undef, q{DELETE FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=? AND strName=?}, $project_index, $service_index, "txtProofHeight-$signature_index-$proof_index-$qty_index" );
		sql::execute( undef, undef, q{DELETE FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=? AND strName=?}, $project_index, $service_index, "ddmProofType-$signature_index-$proof_index-$qty_index" );
	} # end foreach

} # end sub delete_proofs

# Deletes stale data, and inserts default Proofs For the supplied signature
sub insert_proofs {
	my ( $log, $dbh, $project_index, $service_index, $signature_service_index, $qty_index ) = @_;

	#$log->debug(" ***** STAT OF INSERT PROOF DEFAULTS SERVICE: $signature_service_index *******");

	my $ac = sql::start_transaction( $dbh );
	delete_proofs( $log, $dbh, $project_index, $service_index, $signature_service_index, $qty_index );
	my @scanning_indices;
	foreach my $index ( openprint::print::check_for_service( $log, $dbh, $project_index, 'Scanning' ) ) {
		($_) = openprint::service::get_specifications( $log, $dbh, $project_index, $index, 'rdbRandomProof');
		if ( $_ eq 'Yes' ) {
			push @scanning_indices, $index;
		} # end if
	} # end if

	if ( sets::isin( $signature_service_index,\@scanning_indices ) ) {
		insert_scanning_proof( $log, $dbh, $project_index, $service_index, $signature_service_index, 1, $qty_index );
	} else {
		insert_colour_proof( $log, $dbh, $project_index, $service_index, $signature_service_index, 1, $qty_index );
		insert_layout_proof( $log, $dbh, $project_index, $service_index, $signature_service_index, 2, $qty_index );
	} # end if
	sql::end_transaction( $dbh, $ac );

} # end sub insert_proofs

sub insert_scanning_proof {
	my ( $log, $dbh, $project_index, $service_index, $scanning_service_index, $proof_index, $qty_index ) = @_;

	my ( $qty, $width, $height ) = openprint::service::get_specifications( $log, $dbh, $project_index, $scanning_service_index, 'txtQuantity','txtScanWidthFinal', 'txtScanHeightFinal');
	insert_new_proof( $project_index, $proof_index, undef, $qty, $width, $height, 'EpsonProof', $qty_index );
} # end sub insert_scanning_proof

sub insert_press_proof {
	my ( $log, $dbh, $project_index, $service_index, $signature_service_index, $proof_index, $qty_index, $specs ) = @_;
	my %signature_specs = openprint::service::get_specifications_pairs( $log, $dbh, $project_index, $signature_service_index );
	my $quantity = 0;
	if ( sets::isin( $signature_specs{'ddmRunStyle'.$qty_index}, ['Web','Sheet Work', 'Perfecting'] ) ) {
		if ( openprint::Estimating::Printing::get_colours( \%signature_specs, 'SideOne' ) ) {
			$quantity += 1;
		} # end if
		if ( openprint::Estimating::Printing::get_colours( \%signature_specs, 'SideTwo' ) ) {
			$quantity += 1;
		} # end if
	} else {
		if ( openprint::Estimating::Printing::get_colours( \%signature_specs, 'SideOne' ) or openprint::Estimating::Printing::get_colours( \%signature_specs, 'SideTwo' ) ) {
			$quantity += 1;
		} # end if
	} # end if
	insert_new_proof( $specs, $proof_index, $signature_specs{'SignatureIndex'}, $quantity, undef, undef, 'PressProof', $qty_index );
} # end sub insert_press_proof

sub insert_colour_proof {
	my ( $log, $dbh, $project_index, $service_index, $signature_service_index, $proof_index, $qty_index, $specs ) = @_;

	#$log->debug("*** Inserting Colour Proof *******");

	my $signature_specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );
	my @Equipment = openprint::Equipment::find( 'strid'=>$$signature_specs{'ddmPress'.$qty_index} );
	return if ! @Equipment;

	my ( $default_proof_type ) = $Equipment[0]->specification( 'Default Colour Proof' );
	return if ! $default_proof_type;

	my $quantity = 0;

	if ( 
			( $$specs{'RequireColourProofs'} eq 'Y' )  or (
				($$specs{'RequireColourProofs'} ne 'N') and $$signature_specs{'chkProcessColourSideOne'} ) ) {
		$quantity += 1;
	} # end if
	if ( 
			( $$specs{'RequireColourProofs'} eq 'Y' )  or (
($$specs{'RequireColourProofs'} ne 'N') and $$signature_specs{'chkProcessColourSideTwo'} ) ) {
		$quantity += 1;
	} # end if

	# we need extra proofs for business cards.
	if ( $$signature_specs{'txtNameQuantity'} > 1 ) {
		$quantity *= $$signature_specs{'txtNameQuantity'};
	} # end if
	if ( $$signature_specs{'PageQuantity'.$qty_index} ) {
		$quantity *= $$signature_specs{'PageQuantity'.$qty_index} / $$signature_specs{'txtSpreadSize'} if $$signature_specs{'txtSpreadSize'};
	} # end if

	if ( $$specs{'RequireColourProofs'} eq 'N' ) {
		$quantity = 0;
	} # end if

# only if project requires 4 colour process.
	insert_new_proof( $specs, $proof_index, $$signature_specs{'SignatureIndex'}, $quantity, @$signature_specs{'txtWidth', 'txtHeight'}, $default_proof_type, $qty_index );
} # end sub insert_colour_proof

sub insert_layout_proof {
	my ( $log, $dbh, $project_index, $service_index, $signature_service_index, $proof_index, $qty_index, $specs ) = @_;

	my $sig_specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );

	my @Equipment = openprint::Equipment::find( 'strid'=>$$sig_specs{'ddmPress'.$qty_index} );
	return if ! @Equipment;

	my ( $default_proof_type ) = $Equipment[0]->specification( 'Default Layout Proof' );
	return if ! $default_proof_type;

	my $quantity = 0;
	if ( sets::isin( $$sig_specs{'ddmRunStyle'.$qty_index}, ['Web','Sheet Work', 'Perfecting'] ) ) {
		if ( openprint::Estimating::Printing::get_colours( $sig_specs, 'SideOne' ) ) {
			$quantity += 1;
		} # end if
		if ( openprint::Estimating::Printing::get_colours( $sig_specs, 'SideTwo' ) ) {
			$quantity += 1;
		} # end if
	} else {
		if ( openprint::Estimating::Printing::get_colours( $sig_specs, 'SideOne' ) or openprint::Estimating::Printing::get_colours( $sig_specs, 'SideTwo' ) ) {
			$quantity += 1;
		} # end if
	} # end if

	my ( $width, $height ) = @$sig_specs{'StockWidth'.$qty_index,'StockHeight'.$qty_index};

	insert_new_proof( $specs, $proof_index, $$sig_specs{'SignatureIndex'}, $quantity, $width, $height, $default_proof_type, $qty_index );

} # end sub insert_dylux_proof

sub insert_new_proof {
    my ( $specs, $proof_index, $signature_index, $qty, $width, $height, $type, $qty_index ) = @_;
	$$specs{"txtProofQuantity-$signature_index-$proof_index-$qty_index"} = $qty;
	$$specs{"txtProofWidth-$signature_index-$proof_index-$qty_index"} = $width;
	$$specs{"txtProofHeight-$signature_index-$proof_index-$qty_index"} = $height;
	$$specs{"ddmProofType-$signature_index-$proof_index-$qty_index"} = $type;
	$$specs{"txtProofIndex-$signature_index-$proof_index-$qty_index"} = $proof_index;
	@output = sets::union( @output,
			"txtProofWidth-$signature_index-$proof_index-$qty_index",
			"txtProofHeight-$signature_index-$proof_index-$qty_index",
			"txtProofQuantity-$signature_index-$proof_index-$qty_index",
			"ddmProofType-$signature_index-$proof_index-$qty_index",
			"txtProofUnitPrice-$signature_index-$proof_index-$qty_index",
			);
} # end sub insert_new_proof


sub load_proof_info {
    my ( $log, $dbh, $variable, $project_index, $service_index, $signature_index, $qty_index, $specs ) = @_;

    my @proof_info = ();

	$specs = openprint::service::get_specs_ref( $project_index, $service_index ) if ( ! $specs );

	my @proofs;
	foreach my $key ( keys %$specs ) {
		if ( $key =~ /^txtProofIndex-$signature_index-\d*-$qty_index$/ ) {
			push @proofs, $$specs{$key};
		} # end if
	} # end foreach
	foreach my $proof_index ( sort @proofs ) {
        my ( $quantity, $width, $height, $type ) = @$specs{
                "txtProofQuantity-$signature_index-$proof_index-$qty_index",
                "txtProofWidth-$signature_index-$proof_index-$qty_index",
                "txtProofHeight-$signature_index-$proof_index-$qty_index",
                "ddmProofType-$signature_index-$proof_index-$qty_index"
                };
		push @proof_info, $proof_index, $quantity, $width, $height, $type, ssi::make_drop_down( [ map { $_->name(), $_->description() } openprint::Service::find('category'=>'Proofs') ], $type );
    } # end foreach
    return @proof_info;
} # end sub load_proof_info

sub get_proof_specs {
    my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	my %services = $Project->get_services();

	my $specs = openprint::service::get_specs_ref( $project_index, $service_index );
	foreach my $qty_index ( 1 .. 3 ) {
		next if ! $Project->quantity($qty_index);
		my %proof_indexes;
		foreach my $key ( keys %$specs ) {
			if ( $key =~ /^txtProofIndex-(\d*)-(\d*)-$qty_index$/ ) {
				push @{$proof_indexes{$1}}, $$specs{$key};
			} # end if
		} # end foreach

		foreach my $signature_service_index ( $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );
			my $signature_index = $$sig_specs{'SignatureIndex'};

			if ( $$sig_specs{'txtImposition'.$qty_index} ) {
				if ( ( ! sets::isin( 1, $proof_indexes{$signature_index} ) ) and $openprint::config{'Add Default Layout Proof'} eq 'Y') {
					push @{$proof_indexes{$signature_index}}, 1;
					$openprint::log->debug("ADDING Layout Proof to $signature_index");
					insert_layout_proof( $log, $dbh, $project_index, $service_index, $signature_service_index, 1, $qty_index, $variable );
				} # end if
				if ( ( ! sets::isin( 2, $proof_indexes{$signature_index} ) ) and $openprint::config{'Add Default Colour Proof'} eq 'Y') {
					push @{$proof_indexes{$signature_index}}, 2;
					$openprint::log->debug("ADDING Colour Proof to $signature_index");
					insert_colour_proof( $log, $dbh, $project_index, $service_index, $signature_service_index, 2, $qty_index, $variable );
				} # end if
				if ( ( ! sets::isin( 3, $proof_indexes{$signature_index} ) ) and $openprint::config{'Add Default Press Proof'} eq 'Y') {
					push @{$proof_indexes{$signature_index}}, 3;
					insert_press_proof( $log, $dbh, $project_index, $service_index, $signature_service_index, 3, $qty_index, $variable );
				} # end if
			} # end if

			my @proof_info = load_proof_info( $log, $dbh, $variable, $project_index, $service_index, $$sig_specs{'SignatureIndex'}, $qty_index, $variable );
			@{$$variable{'Proofs-'.$$sig_specs{'SignatureIndex'}.'-'.$qty_index}} = @proof_info;
		} # end foreach signature
	} # end foreach qty_index
    @{$$variable{'SignatureGroups'}} = ();
    foreach my $signature_service_index ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );
		push @{$$variable{'SignatureGroups'}}, @$sig_specs{'SignatureIndex', 'txtServiceDescription'};
	} # end foreach signature

# Now do scanning
	if ( $services{'Scanning'} ) {
		foreach my $index ( @{$services{'Scanning'}} ) {
			my $scanning_specs = openprint::service::get_specs_ref( $project_index, $index );
			if ( $$scanning_specs{'rdbRandomProof'} eq 'Yes' ) {
# add a scanning proof
				push @{$$variable{'SignatureGroups'}}, $$scanning_specs{'SignatureIndex'}, 'Scanning Proof';
				@{$$variable{'Proofs'.$$scanning_specs{'SignatureIndex'}}} = load_proof_info( $log, $dbh, $variable, $project_index, $service_index, $$scanning_specs{'SignatureIndex'} );
			} # end if
		} # end foreach scanning service
	} # end if

} # end sub get_proof_specs

sub save_proof_specs {
    my ( $r, $log, $dbh, $variable, $project_index, $service_index ) = @_;

    $log->debug("In Save Proof Specs" );

# First off, slap everything in, just like every other service
	#openprint::service::save_service( $r, $log, $dbh, $project_index, $service_index );
	my @v = variables( $project_index, $service_index, \%openprint::param );
	my $ac = sql::start_transaction( $dbh );
	foreach my $key (@v) {
		if ( ! exists $openprint::param{$key} ) {
			openprint::service::delete_service_spec( $project_index, $service_index, $key );
		} else {
			openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, $key, $openprint::param{$key}, 0 );
		} # end if
	} # end foreach
	sql::end_transaction( $dbh, $ac );

	my $redirect = 0;

# Now check to see if we need to add more proofs, and redirect back
	foreach my $key ( keys %openprint::param ) {
		if ( $key =~ /rdbAdditional-(\d*)-(\d*)/ ) {
			if ( $openprint::param{$key} eq 'Yes' ) {
				my $signature_index = $1;

				my $ac = sql::start_transaction( $dbh );
				$_ = 'SELECT lngServiceIndex FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName=? AND strValue=?';
				my ( $signature_service_index ) = sql::execute( $log, $dbh, $_, $project_index, 'SignatureIndex',$signature_index );

				foreach my $qty_index ( 1 .. 3 ) {
					$_ = 'SELECT MAX(strValue::integer) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=? AND strName LIKE ?';
					my ( $proof_index ) = sql::execute( $log, $dbh, $_, $project_index, $service_index, "txtProofIndex-$signature_index-%-$qty_index" );
					$proof_index += 1;
					$proof_index = 4 if $proof_index < 4;

					openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, "txtProofQuantity-$signature_index-$proof_index-$qty_index", 1 );
					openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, "txtProofWidth-$signature_index-$proof_index-$qty_index", '' );
					openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, "txtProofHeight-$signature_index-$proof_index-$qty_index", '' );
					openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, "ddmProofType-$signature_index-$proof_index-$qty_index", '' );
					openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, "txtProofIndex-$signature_index-$proof_index-$qty_index", $proof_index );
				} # end foreach

				sql::end_transaction( $dbh, $ac );

				$redirect = 1;
			} # end if
		} # end if
	} # end foreach

	if ( $redirect ) {
		( $_ ) = sql::execute( $log,  $dbh, 'SELECT strDetailedURL FROM Service_Types WHERE name=?', 'Proofs');
		$$variable{'Redirect'} = '/main/project/'.$_;
	} else {
		if ($r->param('txtPrice1') > 0 || $r->param('txtPrice2') > 0 || $r->param('txtPrice3') > 0 ) {
			sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $service_index ], 'strStatus', 'calculated');
		} # end if
	} # end if
} # end sub save_proof_specs

sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;
	$specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;
	if ( $qty_index ) {
		my %proof_totals;
		foreach my $ss_id ( $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
			my $signature_index = $$sig_specs{'SignatureIndex'};
			foreach my $key ( keys %{$specs} ) {
				if ( my ($proof_index) = $key =~ /^txtProofIndex-$signature_index-(\d*)-$qty_index$/ ) {
					my @Service = openprint::Service::find('name'=>$$specs{"ddmProofType-$signature_index-$proof_index-$qty_index"});
					if ( @Service ) {	
						my $desc = sprintf('<td align="left"> %s&quot;x%s&quot;</td><td align="left">%s', @$specs{
								"txtProofWidth-$signature_index-$proof_index-$qty_index",
								"txtProofHeight-$signature_index-$proof_index-$qty_index"}, $Service[0]->description() );
						$proof_totals{$desc} += $$specs{"txtProofQuantity-$signature_index-$proof_index-$qty_index"};
					} # end if
				} # end if
			} # end foreach key
		} # end foreach signature
		my $summary = '<table style="width:auto;table-layout:auto;">';
		foreach my $k ( keys %proof_totals ) {
			$summary .= '<tr><td align="left">'.$proof_totals{$k}.'&nbsp;</td>'.$k.'</td></tr>';
		} # end foreach
		return $summary.'</table>';
	} # end if qty_index
	return '';
} # end sub summary

sub breakupsummary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;

	my $Currency = openprint::Currency::get_current();
	$specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;
	if ( $qty_index ) {
		my %proof_totals;
		my %proof_tot;
		my %Totprice;
		foreach my $ss_id ( $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
			my $signature_index = $$sig_specs{'SignatureIndex'};
			foreach my $key ( keys %{$specs} ) {
				if ( my ($proof_index) = $key =~ /^txtProofIndex-$signature_index-(\d*)-$qty_index$/ ) {
					my @Service = openprint::Service::find('name'=>$$specs{"ddmProofType-$signature_index-$proof_index-$qty_index"});
					if ( @Service ) {	
						my $desc = sprintf('<td align="left"> %s&quot;x%s&quot;</td><td align="left">%s', @$specs{
								"txtProofWidth-$signature_index-$proof_index-$qty_index",
								"txtProofHeight-$signature_index-$proof_index-$qty_index"}, $Service[0]->description() );
						my $qty      = $$specs{"txtProofQuantity-$signature_index-$proof_index-$qty_index"};
						if ( $qty != 0 ) {
							$proof_totals{$desc} += $$specs{"txtProofQuantity-$signature_index-$proof_index-$qty_index"};
							my $Uprice   = $$specs{"txtProofUnitPrice-$signature_index-$proof_index-$qty_index"};
							my $type = @$specs{"ddmProofType-$signature_index-$proof_index-$qty_index"};
							if ( ! $proof_tot{$type} ) {
								$proof_tot{$type} = { Quantity => 0, Price => 0 };
							} # end if
							$proof_tot{$type}{Quantity} += $qty;
							my %MkReady  = openprint::service::get_price_object( $type.'MakeReady', $proof_tot{$type}{Quantity}, undef );
							$Totprice{$desc} += ($Uprice*$qty) + $MkReady{Price};
						} # end if
					} # end if
				} # end if
			} # end foreach key
		} # end foreach signature
##		my $summary = '<table class = "insideservice" style="width:auto;table-layout:auto;">';
		my $summary = '<table style="width:100%;table-layout:auto;">';

		foreach my $k ( keys %proof_totals ) {
			$summary .= '<tr><td align="left">'.$proof_totals{$k}.'&nbsp;&nbsp;&nbsp;</td>'.$k.'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>';
			$summary .= '<td align="right"><b>'.sprintf('%s%.2f',$Currency->symbol(), $Totprice{$k}).'</b></td></tr>';
#$openprint::log->debug("TESTING TEXT : ".$Totprice{$k}." |||||| ".$k." ENDING TEXT");
		} # end foreach
		return $summary.'</table>';
	} # end if qty_index
	return '';
} # end sub summary


sub project_summary {
	my ( $Project, $service_id, $specs ) = @_;
	$specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;

	my %types;

	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		my $signature_index = $$sig_specs{'SignatureIndex'};
		foreach my $key ( keys %{$specs} ) {
			if ( my ($proof_index, $qty_index) = $key =~ /^txtProofIndex-$signature_index-(\d*)-(\d*)$/ ) {
				if ( my @Service = openprint::Service::find('name'=>$$specs{"ddmProofType-$signature_index-$proof_index-$qty_index"}) ) {
					$types{$Service[0]->description()} = 1;
				} # end if
			} # end if
		} # end foreach key
	} # end foreach signature
	return ' ' . join(',', keys %types) . ' Proofs<br/>';
} # end sub project_summary
sub get_next_proof_index {
	my ( $sig_specs ) = @_;

	my @proof_indexes;
	my $signature_index = $$sig_specs{'SignatureIndex'};
	if ( ( ! sets::isin( 1, \@proof_indexes ) ) and $openprint::config{'Add Default Layout Proof'} eq 'Y' ) {
		push @proof_indexes, 1;
	} # end if
	if ( ( ! sets::isin( 2, \@proof_indexes ) ) and $openprint::config{'Add Default Colour Proof'} eq 'Y' ) {
		push @proof_indexes, 2;
	} # end if
	if ( ( ! sets::isin( 3, \@proof_indexes ) ) and $openprint::config{'Add Default Press Proof'} eq 'Y' ) {
		push @proof_indexes, 3;
	} # end if
	return sets::max( \@proof_indexes ) + 1;
}

1;
__END__
