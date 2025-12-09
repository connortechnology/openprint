<? echo (
	my $Invoice = new openprint::Invoice( $param{invoice_id} );
	my $Invoicee = $param{invoicee_id} ? new openprint::Company( $param{invoicee_id} ) : $Invoice->Invoicee();
	my $Credit = $Invoicee->Credit( $session{company_id} );

	my ( $invoice_year, $invoice_month, $invoice_day );

	if ( $param{invoice_id} ) {
		( $invoice_year, $invoice_month, $invoice_day ) = $Invoice->created_on() =~ /^(\d\d\d\d)\-(\d\d)\-(\d\d)/;
		if ( ! Date::Calc::check_date( $invoice_year, $invoice_month, $invoice_day ) ) {
			$log->warn("Invlaid created_on date for invoice $$Invoice{id} $$Invoice{created_on} ( $invoice_year, $invoice_month, $invoice_day ) ");
			( $invoice_year, $invoice_month, $invoice_day ) = Date::Calc::Today();
		} # end if
	} else {
		( $invoice_year, $invoice_month, $invoice_day ) = Date::Calc::Today();
	} # end if
	my ( $early_year, $early_month, $early_day ) = Date::Calc::Add_Delta_Days( $invoice_year, $invoice_month, $invoice_day, $$Credit{early_payment_days} );
	my ( $due_year, $due_month, $due_day ) = Date::Calc::Add_Delta_Days( $invoice_year, $invoice_month, $invoice_day, $$Credit{terms} );
	
	my $js = qq`
ddm_select_by_value( document.getElementById('early_payment_date_year'), $early_year );
ddm_select_by_value( document.getElementById('early_payment_date_month'), $early_month );
ddm_select_by_value( document.getElementById('early_payment_date_day'), $early_day );
ddm_select_by_value( document.getElementById('due_on_year'), $due_year );
ddm_select_by_value( document.getElementById('due_on_month'), $due_month );
ddm_select_by_value( document.getElementById('due_on_day'), $due_day );
document.getElementById('early_payment_amount').value = '$$Credit{early_payment_amount}';
ddm_select_by_value( document.getElementById('early_payment_units'), '$$Credit{early_payment_units}' );
\document.getElementById('monthly_interest').value = '$$Credit{late_payment_amount}';
`;

$js .= q`ddm_select_by_value(document.getElementById('currency_id'), `.$Invoicee->currency_id().q`);
` if $Invoicee->currency_id();
return $js;
) ?>
