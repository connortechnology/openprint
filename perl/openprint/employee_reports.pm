package openprint::employee_reports;
use strict;

use openprint qw();
use vars qw( %session %param );
*session = \%openprint::session;
*param = \%openprint::param;

sub project_history {
}

sub _order_history_results {
}

sub stock {
	ssi::save_params('/employee/reports/stock.html', 'Owner', 'Manufacturer', 'Name', 'Finish', 'Colour', 'Weight', 'Type', 'fsc_code', 'last_seen', 'location_id','width','height','OrLarger' );
} # end sub stock

sub _stock {
	ssi::save_params('/employee/reports/stock.html', 'Owner', 'Manufacturer', 'Name', 'Finish', 'Colour', 'Weight', 'Type', 'fsc_code', 'last_seen', 'location_id','width','height','OrLarger' );
} # end sub _stock

sub stock_usage {
$openprint::log->debug("Hello");
	ssi::save_params('/employee/reports/stock_usage.html', 'company_id', 'ordered_on_start_year','ordered_on_start_month','ordered_on_start_day','ordered_on_end_year','ordered_on_end_month','ordered_on_end_day', 'Manufacturer', 'Name', 'Finish', 'Colour', 'Weight', 'Type', 'fsc_code', 'width','height','OrLarger', 'basis_weight','mweight' );

	ssi::setup_date_select( '/employee/reports/stock_usage.html', 'ordered_on_start', -31 );
	ssi::setup_date_select( '/employee/reports/stock_usage.html', 'ordered_on_end', '' );
$openprint::log->debug("Hello $session{'/employee/reports/stock_usage.html?ordered_on_start_year'} $session{'/employee/reports/stock_usage.html?ordered_on_start_day'}");
} # end sub stock_usage

sub _stock_usage {
	ssi::save_params('/employee/reports/stock_usage.html', 'company_id', 'ordered_on_start_year','ordered_on_start_month','ordered_on_start_day','ordered_on_end_year','ordered_on_end_month','ordered_on_end_day', 'Manufacturer', 'Name', 'Finish', 'Colour', 'Weight', 'Type', 'fsc_code', 'width','height','OrLarger', 'basis_weight','mweight' );
} # end sub _stock_usage

1;
__END__
