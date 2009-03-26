package openprint::project;

use strict;

require sql;
require openprint::Project;
require openprint::Estimating::Printing;
#require XML::DOM;

sub get_project_type {
	my ( $log, $dbh, $project_index ) = @_;
	my $Project = new openprint::Project( $project_index );
	my $ProjectType = $Project->Type();
	return $ProjectType->strid();
} # end sub

sub get_project_type_service_index {
	my ( $log, $dbh, $project_index ) = @_;
	$_ = 'SELECT lngServiceIndex FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName=?';
	( $_ ) = sql::execute( $log, $dbh, $_, $project_index, 'ProjectType' );
	return $_;
} # end sub

sub get_quantities {
	my ( $log, $dbh, $project_index) = @_;
	my $Project = new openprint::Project( $project_index );
	return ( $Project->quantity1(), $Project->quantity2(), $Project->quantity3() );
} # end sub get_quantities

sub view {
	my ( $log, $dbh, $variable, $project_index ) = @_;

	if ( exists $openprint::param{'ShowAllSignatures'} ) {
		$openprint::session{'ShowAllSignatures'} = $openprint::param{'ShowAllSignatures'};
	} # end if
$openprint::log->debug("Viewing Project $project_index");
	$$variable{'Project'} = new openprint::Project( $project_index );
	my $Project = $$variable{'Project'};

	my %project;
	foreach my $service_index ( sql::execute( $log, $dbh, q{SELECT lngServiceIndex FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $project_index ) ) {
		my %s = openprint::service::get_specifications_pairs( $log, $dbh, $project_index, $service_index );
		$project{$service_index} = \%s;
	} # end foreach $serviceindex
	my %statuses = sql::execute( $log, $dbh, q{SELECT lngServiceIndex, strStatus FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $project_index );

# THis is the currency that prices are displayed in
	my $Currency = openprint::Currency::get_current();
	$$variable{'Currency'} = $Currency;
	my $ProjectCurrency = $$variable{'Project'}->Currency();
	my $conversion_rate = $ProjectCurrency->conversions( $Currency->id() );

	my $ProjectType = $$variable{'Project'}->Type();

# now do printing service
	$$variable{'ProjectTypeName'} = $ProjectType->name();
	@{$$variable{'SERVICES'}} = ();
	my @services = ();

	my %services = $$variable{'Project'}->get_services();
# Put Printing service first is list of things to display
	foreach my $s_id ( @{$services{''}} ) {
		push @services, 'Printing', $ProjectType->url(), $s_id;
	} # end foreach

	$_ = q{SELECT name,description,strDetailedUrl FROM Service_Types WHERE view_visible=true ORDER BY Sorting};
	my @service_info = sql::execute( $log, $dbh, $_ );
# do a little sorting, adding services with a service type
	while ( my ($id, $n, $url ) = splice @service_info,0,3 ) {
		next if ! $services{$id};

		if ( $id eq 'AdditionalSignature' ) {
			my @sigs = sort $$variable{'Project'}->signatures();
			while ( @sigs ) {
				my $service_index = shift @sigs;

				my $sig_qty = 1;

				if ( $openprint::session{'ShowAllSignatures'} ) {
					push @services, $n, $url, $service_index;
				} else {
					for ( my $i = 0; $i < @sigs; $i += 1 ) {
						if ( ( $statuses{$sigs[$i]} eq $statuses{$service_index} ) and openprint::Estimating::Printing::compare_signatures( $project{$service_index}, $project{$sigs[$i]} ) ) {
							$sig_qty += 1;
							$project{$service_index}{'txtPrice1'} += $project{$sigs[$i]}{'txtPrice1'};
							$project{$service_index}{'txtPrice2'} += $project{$sigs[$i]}{'txtPrice2'};
							$project{$service_index}{'txtPrice3'} += $project{$sigs[$i]}{'txtPrice3'};
							splice @sigs, $i, 1;
							$i -= 1;
						} # end if
					} # end for
					if ( $sig_qty > 1 ) {
						push @services, $sig_qty . ' ' . $n.'s', $url, $service_index;
						$$variable{'HiddenSignatures'} = 1;
					} else {
						push @services, $sig_qty . ' ' . $n, $url, $service_index;
					} # end if
				} # end if
				
			} # end foreach
		} else {
		
		foreach my $service_index ( @{$services{$id}} ) {
			if ( $n eq 'Outside Service' ) {
				push @services, $project{$service_index}{'ServiceName'}, $url, $service_index;
			} else {
				push @services, $n, $url, $service_index;
			} # end if
		} # end foreach
		} # end if
	} # end while

	while ( @services ) {
		my ( $name, $url, $service_index ) = splice @services, 0, 3;


		push @{$$variable{'SERVICES'}}, $service_index, $name, $url;

		foreach my $qty_index ( 1 .. 3 ) {
			my $price = $project{$service_index}{"txtPrice$qty_index"};
			if ( $price eq '' ) {
				$price = $project{$service_index}{'txtPrice1'};
			} # end if
			$$variable{"Total$qty_index"} += $price;
			$$variable{"UnitPrice$qty_index"} += $price/$Project->quantity($qty_index) if $Project->quantity($qty_index);
			push @{$$variable{'SERVICES'}}, sprintf( $openprint::config{'ProjectMoneyFormat'}, $price * $conversion_rate );
		} # end foreach qty_index

		push @{$$variable{'SERVICES'}}, $statuses{$service_index};
	} # end foreach

	my $save = 0;
	foreach my $qty_index ( $$variable{'Project'}->quantity_indexes() ) {

		$$variable{"Total$qty_index"} = sprintf($openprint::config{'ProjectMoneyFormat'}, $$variable{"Total$qty_index"} );
		$$variable{"UnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $$variable{"UnitPrice$qty_index"} );
$openprint::log->debug("Prices $qty_index P" . $$variable{'Project'}->price($qty_index) . ' T' .  $$variable{'Total'.$qty_index} );
		if ( $$variable{'Project'}->price($qty_index) != $$variable{'Total'.$qty_index} ) {
			$$variable{'Project'}->price( $qty_index, $$variable{'Total'.$qty_index} );
			$save = 1;
		} # end if
		$$variable{"Total$qty_index"} = sprintf($openprint::config{'ProjectMoneyFormat'}, $$variable{"Total$qty_index"}*$conversion_rate );
		$$variable{"UnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $$variable{"UnitPrice$qty_index"}*$conversion_rate );
	} # end foreach
	if ( $save ) {
		$$variable{'Project'}->summary(undef);
		$$variable{'Project'}->save();
	} # end if

	@$variable{'CurrencyName', 'CurrencySymbol'} = ( $Currency->name(), $Currency->symbol() );
	$$variable{'ProjectIndex'} = $project_index;
	$$variable{'OrderID'} = $$variable{'order_id'};
	delete $$variable{'Project'}{'Services'};
} # end sub view

# This is sortof a state engine.	This function should update a project's status to whatever it should be.
sub update_status {
	my ( $log, $dbh, $variable, $project_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	return $Project->update_status( $variable );
} # end sub update_project_status

sub insert_into_log {
	my ( $log, $dbh, $cust_id, $user_id, $project_id, $text ) = @_;
	my $Project = new openprint::Project( $project_id );
	$Project->add_to_log( $cust_id, $user_id, $text );
} # end sub insert_into_log

sub get_prepress_operator {
    my ( $log, $dbh, $project_index ) = @_;

	my $Project = new openprint::Project( $project_index );
    my %services = $Project->get_services();
    my $User = new openprint::User( sql::execute( $log, $dbh, q{SELECT operator_id FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex=?}, $project_index, ( $services{'Proofs'} ? $services{'Proofs'}[0] : $services{'FilmStripping'}[0] ) ) );
    return $User->name();
} # end sub get_prepressoperator

1;

__END__
~		
