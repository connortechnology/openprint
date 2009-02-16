package openprint::employee_order;
use strict;

require openprint::Order;
require openprint::order;
require openprint::Payment;

sub view {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $order_id = $openprint::param{'order_id'};
	my $Order = new openprint::Order( $order_id );

	if ( $openprint::param{'btnFunction'} eq 'Pay' ) {
		$Order->pay();
	} elsif ( $openprint::param{'btnFunction'} eq 'Save Payment' ) {

		if ( ( ! $openprint::param{'Amount'} ) or $openprint::param{'Amount'} =~ /[^-\$\d\.]/ ) {
			return misc::error( $log, $dbh, $variable, 'Invalid Amount', 'Please enter a valid monetary amount.' );
		} # end if

		my $Payment = new openprint::Payment();
		my $error = $Payment->save({
				'order_id'		=> $order_id,
				'company_id'	=> $Order->company_id(),
				'amount'		=> $openprint::param{'Amount'},
				'method'		=> 'Manual',
				'currency_id'	=> $Order->currency_id(),
				'description'	=> $openprint::param{'Description'},
				'completed'		=> 1,
				} );
		if ( $error ) {
			return misc::error( $log, $dbh, $variable, 'Error Saving Payment', $error );
		} # end if

		openprint::order::get_misc( $log, $dbh, $variable, $order_id );

		if ( $$variable{'DepositDue'} > 0 ) {
			foreach my $project_index ( sql::execute( $log, $dbh, 'SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?', $order_id ) ) {
				sql::update( $log, $dbh, 'Projects', ['Index=? AND strStatus=?', $project_index, 'In Prepress'], 'strStatus', 'Pending Deposit' );
				sql::update( $log, $dbh, 'tbl_Project_Contents', "lngProjectIndex=$project_index AND strStatus='Ordered'", 'strStatus', 'Pending Deposit' );
			} # end foreach
		} else {
			$Order->status('In Production') if $Order->status() eq 'Pending Deposit';

			foreach my $project_index ( sql::execute( $log, $dbh, 'SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?', $order_id ) ) {
				sql::update( $log, $dbh, 'Projects', ['Index=? AND strStatus=?', $project_index, 'Pending Deposit'], 'strStatus', 'In Prepress' );

				sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND strStatus=?', $project_index, 'Pending Deposit'], 'strStatus', 'Ordered' );
			} # end foreach
			if ( $$variable{'AmountPaid'} >= $$variable{'TOTAL'} ) {
				$Order->status('Paid') if $Order->status() eq 'Complete';
			} # end if
			$Order->save();
		} # end if
	} elsif ( $openprint::param{'btnFunction'} eq 'Delete Payment' ) {
		my $payment_index = $openprint::param{'payment_id'};
		$payment_index =~ s/\D//g;
		if ( $payment_index ) {
			sql::execute( $log, $dbh, 'DELETE FROM Payments WHERE id=?', $payment_index );
		} # end if
		$Order->update_status();
	} elsif ( $openprint::param{'btnFunction'} eq 'Invoice' ) {
		$Order->invoice_id( $openprint::param{'invoice_id'} );
		$Order->invoiced_on( 'NOW()' );
		$Order->save();
	} elsif ( $openprint::param{'btnFunction'} eq 'Cancel' ) {
		openprint::order::cancel_order( $log, $dbh, $order_id );
    } # end if
	$$variable{'Order'} = $Order;
    openprint::order::display_order( $log, $dbh, $variable, $order_id );
} # end sub view

1;

__END__

