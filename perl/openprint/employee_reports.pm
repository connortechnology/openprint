package openprint::employee_reports;

sub project_history {
}

sub stock {
	ssi::save_params('/employee/reports/stock.html', 'Owner', 'Manufacturer', 'Name', 'Finish', 'Colour', 'Weight', 'Type', 'fsc_code', 'last_seen', 'location_id','width','height','OrLarger' );
} # end sub stock

sub _stock {
	ssi::save_params('/employee/reports/stock.html', 'Owner', 'Manufacturer', 'Name', 'Finish', 'Colour', 'Weight', 'Type', 'fsc_code', 'last_seen', 'location_id','width','height','OrLarger' );
} # end sub _stock

sub turnaround {
}

1;
__END__
