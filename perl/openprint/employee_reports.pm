package openprint::employee_reports;
use strict;

use openprint qw();
use vars qw( $r $log $dbh %variable %session %param );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;
*param = \%openprint::param;
*variable = \%openprint::variable;

sub project_history {
}
sub _project_history_results {
}

sub order_history {
}
sub _order_history_results {
}

sub stock {
	_stock();
} # end sub stock

sub _stock {
	ssi::save_params('/employee/reports/stock.html', 'Owner', 'Manufacturer', 'Name', 'Finish', 'Colour', 'Weight', 'Type', 'fsc_code', 'last_seen', 'location_id','width','height','OrLarger' );
} # end sub _stock

sub stock_usage {
	_stock_usage();

	ssi::setup_date_select( '/employee/reports/stock_usage.html', 'ordered_on_start', -31 );
	ssi::setup_date_select( '/employee/reports/stock_usage.html', 'ordered_on_end', '' );
} # end sub stock_usage

sub _stock_usage {
	ssi::save_params('/employee/reports/stock_usage.html', 'company_id', 'ordered_on_start_year','ordered_on_start_month','ordered_on_start_day','ordered_on_end_year','ordered_on_end_month','ordered_on_end_day', 'Manufacturer', 'Name', 'Finish', 'Colour', 'Weight', 'Type', 'fsc_code', 'width','height','OrLarger', 'basis_weight','mweight' );
} # end sub _stock_usage

sub prepress_overview {
} # end sub prepress_overview

sub delivery {
} # end sub delivery

sub turnaround {
}# end sub turnaround

sub _turnaround_results {
} # end sub _turnaround_results

sub job_size {
	if ( ! %param ) {
		ssi::setup_date_select( '/employee/reports/job_size.html', 'ordered_on_start', -31 );
		ssi::setup_date_select( '/employee/reports/job_size.html', 'ordered_on_end', '' );
		ssi::setup_date_select( '/employee/reports/job_size.html', 'completed_on_start', -31 );
		ssi::setup_date_select( '/employee/reports/job_size.html', 'completed_on_end', '' );
	} # end if
	_job_size();

	if ( $param{'action'} eq 'download' ) {
		misc::export_csv( $r, $log, \%variable, 'job_size_report.csv', @variable{'Header','Data'} );	
	} # end if
} # end sub job_size

sub _job_size {
	ssi::save_params('/employee/reports/job_size.html', 'company_id', 
			'ordered_on_start_year','ordered_on_start_month','ordered_on_start_day',
			'ordered_on_end_year','ordered_on_end_month','ordered_on_end_day', 
			( map { 'completed_on_start_'.$_ } ( 'year','month','day' ) ),
			( map { 'completed_on_end_'.$_ } ( 'year','month','day' ) ),
			'press_id', 'csr_id', 'reprint',
			);

	my %parameters; 
	if ( ( $session{'user_type'} ne 'A' ) and ! openprint::usergroup::is_user_in( ['Sales Admin','Reporting'], $session{'user_id'} ) ) {
		$parameters{'salesrep_id'} = $session{'user_id'};
		$parameters{'or'} = "Index=(SELECT CompanyIndex FROM Users WHERE Index=$session{'user_id'})";
	} elsif ( $param{'csr_id'} ) {
		$parameters{'salesrep_id'} = $param{'csr_id'};
	} # end if
	my @Companies = openprint::Company::find( %parameters );
	if ( ! @Companies ) {
		$variable{'error'} .= 'There were no companies to filter on.<br/>';
		return;
	} # end if
	my %companies = map { int($_->id()), $_->name() } @Companies;
	my @press_names = map { new openprint::Equipment( $_ )->strid() } split(',', $session{'/employee/reports/job_size.html?press_id'} );
	my @Data;

	foreach my $Order ( openprint::Order::find(
				'company_id' => ( ($session{'/employee/reports/job_size.html?company_id'} and exists $companies{$session{'/employee/reports/job_size.html?company_id'}} ) ? $session{'/employee/reports/job_size.html?company_id'} : [ keys %companies ] ),
				ssi::date_filter( '/employee/reports/job_size.html?ordered_on_start', 'created_on_start' ),
				ssi::date_filter( '/employee/reports/job_size.html?ordered_on_end', 'created_on_end' ),
				( $param{'status'} ? (
									  'status' =>
									  ( ref $param{'status'} eq 'ARRAY' ? $param{'status'} : [ split(',', $param{'status'} ) ] )
									 ) : () ),
				'order' => ($param{'order'} ? $param{'order'} : 'Index'),
				) ) {
$log->debug("find orders");
		if ( $session{'/employee/reports/job_size.html?reprint'} ) {
			my $reprint = 0;
			foreach my $Project ( $Order->Projects() ) {
				if ( $Project->reprint() eq 'Y' ) {
					$reprint=1;
					last;
				} # end if
			} # end foreach Project
			next if ( $session{'/employee/reports/job_size.html?reprint'} eq 'Y' ) and ! $reprint;
			next if ( $session{'/employee/reports/job_size.html?reprint'} eq 'N' ) and $reprint;
		} # end if reprint

		foreach my $Project ( $Order->Projects() ) {
			my $services = $Project->services();
			my @signatures = $Project->signatures();
			next if ! @signatures;
			if ( $Project->Type()->name() ne 'MultiPagePublication' ) {
				if ( ! sets::isin( $$services{''}[0], \@signatures ) ) {
					push @signatures, $$services{''}[0];
				} # end if
			} # end if

			foreach my $sig_id ( @signatures ) {
				my $Service = $Project->Service( $sig_id );
				my $sig_specs = $Service->specs();

				next if ! $Service->ordered_price();

				if ( ! $$sig_specs{'UsePress'} ) {
					$$sig_specs{'UsePress'} = $$sig_specs{'ddmPress'.$Project->ordered_quantity_index()};
				} # end if

				if ( @press_names ) {
					next if ( ! sets::isin( $$sig_specs{'UsePress'}, \@press_names ) );
				} # end if press_names

				if ( ! $$sig_specs{'hdnImpressionQuantity'.$Project->ordered_quantity_index()} ) {
					next;
				} # end if
				if ( ! $$sig_specs{'PlateID'.$Project->ordered_quantity_index()} ) {
					my $Press = openprint::Equipment::find_one('strid'=>$$sig_specs{'UsePress'});

					$$sig_specs{'PlateID'.$Project->ordered_quantity_index()} = $Press->specification('Plate Size').'"-'.$Press->specification('Plate Type').'Plate';
				} # end if
	
				my $Plate = openprint::Material::find_one('name'=>$$sig_specs{'PlateID'.$Project->ordered_quantity_index()}) if $$sig_specs{'PlateID'.$Project->ordered_quantity_index()};
				my %plate_cost = $Plate->get_price( $$sig_specs{'txtPlateQuantity'.$Project->ordered_quantity_index()} ) if $Plate;
				

				push @Data, ( $Order->id(), $Order->docket(), $Project->id(), 
					 ( $$sig_specs{'SignatureIndex'} ? $$sig_specs{'SignatureIndex'} : 1 ),
					 $Order->company_name(), $Project->reference(), 
					 $Order->created_on(), $Project->completed_on(), 
					 $$sig_specs{'UsePress'},
					 $$sig_specs{'txtPlateQuantity'.$Project->ordered_quantity_index()},
					 $$sig_specs{'PlateID'.$Project->ordered_quantity_index()},
					 $plate_cost{'Cost'}, $plate_cost{'Price'}, $plate_cost{'units'}, $plate_cost{'Price'} * $$sig_specs{'txtPlateQuantity'.$Project->ordered_quantity_index()}, 
					 $$sig_specs{'hdnImpressionQuantity'.$Project->ordered_quantity_index()}, $Project->status(),
					 $Project->ordered_price(), $Service->ordered_price(),
					 );
			} # end foreach sig
		} # end foreach Project
	} # end foreach Order

	$variable{'Header'} = [ 'Order ID', 'Docket', 'Project ID', 'Form #', 'Company', 'Reference', 'Created On', 'Completed On', 'Press', 'Plates', 'Plate Type', 'Plate Cost', 'Plate Price', 'Plate Units', 'Plate Total', 'Impressions', 'Status', 'Project Value', 'Form Value' ];
	$variable{'Data'} = \@Data;

} # end sub _job_size

1;
__END__
