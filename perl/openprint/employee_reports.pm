package openprint::employee_reports;

sub project_history {
}

sub stock {
	ssi::save_params('/employee/reports/stock.html', 'Owner', 'Manufacturer', 'Name', 'Finish', 'Colour', 'Weight', 'Type', 'fsc_code', 'last_seen', 'location_id','width','height','OrLarger' );
} # end sub stock

sub _stock {
	ssi::save_params('/employee/reports/stock.html', 'Owner', 'Manufacturer', 'Name', 'Finish', 'Colour', 'Weight', 'Type', 'fsc_code', 'last_seen', 'location_id','width','height','OrLarger' );
} # end sub _stock

sub stock_usage {
	ssi::save_params('/employee/reports/stock_usage.html', 'company_id', 'ordered_on_start_year','ordered_on_start_month','ordered_on_start_day','ordered_on_end_year','ordered_on_end_month','ordered_on_end_day', 'Manufacturer', 'Name', 'Finish', 'Colour', 'Weight', 'Type', 'fsc_code', 'width','height','OrLarger', 'basis_weight','mweight' );
} # end sub stock_usage

sub _stock_usage {
	ssi::save_params('/employee/reports/stock_usage.html', 'company_id', 'ordered_on_start_year','ordered_on_start_month','ordered_on_start_day','ordered_on_end_year','ordered_on_end_month','ordered_on_end_day', 'Manufacturer', 'Name', 'Finish', 'Colour', 'Weight', 'Type', 'fsc_code', 'width','height','OrLarger', 'basis_weight','mweight' );
} # end sub _stock_usage

1;
__END__
