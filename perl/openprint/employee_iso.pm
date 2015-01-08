package openprint::employee_iso;
use MIME::QuotedPrint;
use openprint;
use vars qw( %variable %session %param %config $log $dbh $r );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*r = \$openprint::r;

require openprint::CAR;
require openprint::CAR_Reason;
require openprint::CAR_Area;
require openprint::PAR;
require openprint::MAR;

use strict;

sub mars {
	if ( $param{btnFunction} eq 'Delete' ) {
		foreach my $mar_id ( ref $param{mars} eq 'ARRAY' ? @{$param{mars}} : $param{mars} ) {
			my $MAR = new openprint::MAR( $mar_id );
			$variable{error} .= $MAR->delete();
		} # end foreach mar_id
	} elsif ( $param{btnFunction} eq 'Download in CSV Format' ) {
		my @header = ('Issued To','Issued On','Issued By','Reply By', 'Equipment','Problem','Cause','Action','Effectiveness', 'Part2 Recipient', 'Part2 Signed On', 'Part3 Recipient', 'Part3 Signed On', 'Part4 QS Mgt Rep/Designate', 'Part4 Signed On' );
		my @data;
		my %params = (
			ssi::date_filter( 'issued_on_start', 'issued_on >=', \%param ),
			ssi::date_filter( 'issued_on_end', 'issued_on <=', \%param ),
		);
		foreach my $MAR ( openprint::MAR->find(%params) ) {
			push @data, (
					new openprint::User($MAR->issued_to_id() )->name(),
					$MAR->issued_on(),
					new openprint::User($MAR->issued_by_id() )->name(),
					$MAR->reply_by(),
					join( ',', map { new openprint::Equipment($_)->name() } split(';', $MAR->presses()) ),
					$MAR->problem(),
					$MAR->cause(),
					$MAR->action(),
					$MAR->effectiveness(),
					new openprint::User($MAR->part2_user_id())->name(),
					$MAR->part2_signed_on(),
					new openprint::User($MAR->part3_user_id())->name(),
					$MAR->part3_signed_on(),
					new openprint::User($MAR->part4_user_id())->name(),
					$MAR->part4_signed_on(),
					);
		} # end foreach MAR
		
		misc::export_csv( $r, $log, \%variable, 'MARS.csv', \@header, \@data );
	} # end if
	_mars();
	ssi::setup_date_select( '/employee/iso/mars.html', 'issued_on_start', -30 );
	ssi::setup_date_select( '/employee/iso/mars.html', 'issued_on_end', '' );
} # end sub mars

sub _mars {
	ssi::save_params( '/employee/iso/mars.html', ( 
				'issued_on_start_year','issued_on_start_month','issued_on_start_day',
				'issued_on_end_year','issued_on_end_month','issued_on_end_day',
				'status','equipment_id' ) );
} # end sub _mars

sub mar {
	$variable{MAR} = new openprint::MAR( $param{mar_id} );
	if ( $param{action} eq 'Send' ) {
		$variable{MAR}->send_notifications();
	} # end if
} # end sub view_mar

sub _mar_view_part1 {
	my $MAR = $variable{MAR} = new openprint::MAR( $param{mar_id} );
	if ( $param{btnFunction} eq 'Save' ) {
		$param{issued_on} = sprintf('%.4d-%.2d-%.2d', @param{'issued_on_year','issued_on_month','issued_on_day'} );
		$param{reply_by} = sprintf('%.4d-%.2d-%.2d', @param{'reply_by_year','reply_by_month','reply_by_day'} ) if $param{reply_by_day};
		my $send_assignee_notification = 0;

		if ( $param{issued_to_id} and ! $MAR->issued_to_id() ) {
			$send_assignee_notification = 1;
		} # end if issued_to
		# if a reprint is requested, but if the approval is already given, then we are the Approver, so don't bother.
		$variable{error} .= $MAR->save( \%param );
		if ( ! $variable{error} ) {
			$MAR->send_notifications();
			if ( $send_assignee_notification ) {
				$MAR->send_assignee_notification();
			} # end if
		} # end if no errors
	} # end if btnFunction is Save
} # end sub _mar_view_part1

sub _mar_view_part2 {
	my $MAR = $variable{MAR} = new openprint::MAR( $param{mar_id} );
	if ( $param{btnFunction} eq 'Save' ) {
		$param{part2_signed_on} = sprintf('%.4d-%.2d-%.2d', @param{'part2_signed_on_year','part2_signed_on_month','part2_signed_on_day'} );
		$variable{error} .= $MAR->save( \%param );
		if ( ! $variable{error} ) {
			$MAR->send_changed_notification();
		} # end if
	} # end if
} # end sub _mar_view_part2

sub _mar_view_part3 {
	my $MAR = $variable{MAR} = new openprint::MAR( $param{mar_id} );
	if ( $param{btnFunction} eq 'Save' ) {
		$param{part3_signed_on} = sprintf('%.4d-%.2d-%.2d', @param{'part3_signed_on_year','part3_signed_on_month','part3_signed_on_day'} );
		$variable{error} .= $MAR->save( \%param );
		if ( ! $variable{error} ) {
			$MAR->send_changed_notification();
		} # end if
	} # end if
} # end sub _mar_view_part3

sub _mar_view_part4 {
	my $MAR = $variable{MAR} = new openprint::MAR( $param{mar_id} );
	if ( $param{btnFunction} eq 'Save' ) {
		$param{part4_signed_on} = sprintf('%.4d-%.2d-%.2d', @param{'part4_signed_on_year','part4_signed_on_month','part4_signed_on_day'} );
		$variable{error} .= $MAR->save( \%param );
		if ( ! $variable{error} ) {
			$MAR->send_changed_notification();
		} # end if
	} # end if
} # end sub _mar_view_part4

sub _mar_edit_part1 {
	$variable{MAR} = new openprint::MAR( $param{mar_id} );
}
sub _mar_edit_part2 {
	$variable{MAR} = new openprint::MAR( $param{mar_id} );
}
sub _mar_edit_part3 {
	$variable{MAR} = new openprint::MAR( $param{mar_id} );
}
sub _mar_edit_part4 {
	$variable{MAR} = new openprint::MAR( $param{mar_id} );
}

### CARS SECTIONS BEGINS HERE
sub cars {
	if ( $param{btnFunction} eq 'Delete' ) {
		foreach my $car_id ( ref $param{cars} eq 'ARRAY' ? @{$param{cars}} : $param{cars} ) {
			my $CAR = new openprint::CAR( $car_id );
			$variable{error} .= $CAR->delete();
		} # end foreach car_id
	} elsif ( $param{btnFunction} eq 'Download in CSV Format' ) {
		my @header = ('Issued To','Issued On','Issued By','Reply By', 'Docket','Customer','Identified By','Printed On','Presses','Area','Reason','Problem','Cause','Action','Effectiveness', 'Part2 Recipient', 'Part2 Signed On', 'Part3 Recipient', 'Part3 Signed On', 'Part4 QS Mgt Rep/Designate', 'Part4 Signed On','Reprint Requested','Reprint Approved','Reprint Charge','Reprint Quantity', 'Reprint Value', 'Reprint On','Reprint Approved By', 'Approved On','Artwork' );
		my @data;
		my %params = (
			ssi::date_filter( 'issued_on_start', 'issued_on >=', \%param ),
			ssi::date_filter( 'issued_on_end', 'issued_on <=', \%param ),
		);
		foreach my $CAR ( openprint::CAR->find(%params) ) {
			push @data, (
					new openprint::User($CAR->issued_to_id() )->name(),
					$CAR->issued_on(),
					new openprint::User($CAR->issued_by_id() )->name(),
					$CAR->reply_by(),
					$CAR->docket(),
					$CAR->Company()->name(),
					$CAR->identified_by(),
					$CAR->printed_on(),
					join( ',', map { new openprint::Equipment($_)->name() } split(';', $CAR->presses()) ),
					$CAR->Area()->name(),
					$CAR->Reason()->name(),
					$CAR->problem(),
					$CAR->cause(),
					$CAR->action(),
					$CAR->effectiveness(),
					new openprint::User($CAR->part2_user_id())->name(),
					$CAR->part2_signed_on(),
					new openprint::User($CAR->part3_user_id())->name(),
					$CAR->part3_signed_on(),
					new openprint::User($CAR->part4_user_id())->name(),
					$CAR->part4_signed_on(),
					$CAR->reprint(),
					$CAR->reprint_approval(),
					$CAR->reprint_charge(),
					$CAR->reprint_quantity(),
					$CAR->reprint_value(),
					$CAR->reprint_on(),
					new openprint::User( $CAR->approved_by_id() )->name(),
					$CAR->approved_on(),
					$CAR->artwork(),
					);
		} # end foreach CAR
		
		misc::export_csv( $r, $log, \%variable, 'CARS.csv', \@header, \@data );
	} # end if
	_car_results();
	ssi::setup_date_select( '/employee/iso/cars.html', 'issued_on_start', -30 );
	ssi::setup_date_select( '/employee/iso/cars.html', 'issued_on_end', '' );
	$session{'/employee/iso/cars.html?status'} = 'Open' if ! exists $session{'/employee/iso/cars.html?status'};
} # end sub cars

sub _car_results {
	ssi::save_params( '/employee/iso/cars.html', ( 
				'issued_on_start_year','issued_on_start_month','issued_on_start_day',
				'issued_on_end_year','issued_on_end_month','issued_on_end_day',
				'status','docket' ) );
} # end sub _car_results

sub car {
	$variable{CAR} = new openprint::CAR( $param{car_id} );
	if ( $param{action} eq 'Send' ) {
		$variable{CAR}->send_notifications();
	} # end if
} # end sub view_car

sub _car_view_part1 {
	$variable{CAR} = new openprint::CAR( $param{car_id} );
	if ( $param{btnFunction} eq 'Save' ) {
		$param{issued_on} = sprintf('%.4d-%.2d-%.2d', @param{'issued_on_year','issued_on_month','issued_on_day'} );
		$param{reprint_on} = sprintf('%.4d-%.2d-%.2d', @param{'reprint_on_year','reprint_on_month','reprint_on_day'} ) if $param{reprint_on_year};
		$param{printed_on} = sprintf('%.4d-%.2d-%.2d', @param{'printed_on_year','printed_on_month','printed_on_day'} ) if $param{printed_on_year} and $param{printed_on_month} and $param{printed_on_day};
		$param{approved_on} = sprintf('%.4d-%.2d-%.2d', @param{'approved_on_year','approved_on_month','approved_on_day'} ) if $param{approved_on_year} and $param{approved_on_month} and $param{approved_on_day};
		$param{reply_by} = sprintf('%.4d-%.2d-%.2d', @param{'reply_by_year','reply_by_month','reply_by_day'} ) if $param{reply_by_day};
		$param{presses} = ref $param{presses} eq 'ARRAY' ? join(';', @{$param{presses}} ) : $param{presses};
		#$param{part1_signed_on} = sprintf('%.4d-%.2d-%.2d', @param{'part1_signed_on_year','part1_signed_on_month','part1_signed_on_day'} );
		my $send_assignee_notification = 0;
		my $send_reprint_request_notification = 0;
		my $send_reprint_approval_notification = 0;

		if ( $param{area_id} and ( ! $param{issued_to_id} ) and ( ! $variable{CAR}->issued_to_id() ) ) {
			# Auto assignation
			my $Area = new openprint::CAR_Area( $param{area_id} );
			if ( $Area->assignee_id() ) {
				$param{issued_to_id} = $Area->assignee_id();
			} elsif ( $param{docket} ) {
				# Assign to the CSR for the docket
				my @Orders = openprint::Order->find('docket'=>$param{docket} );
				if ( @Orders ) {
					$param{issued_to_id} = $Orders[0]->salesrep_id();
				} # end if
			} # end if
		} # end if

		if ( $param{issued_to_id} and ! $variable{CAR}->issued_to_id() ) {
			$send_assignee_notification = 1;
		} # end if issued_to
		# if a reprint is requested, but if the approval is already given, then we are the Approver, so don't bother.
		if ( ( $param{reprint} eq 'Yes' ) and ( $variable{CAR}->reprint() ne 'Yes' ) and ( ! $param{reprint_approval} ) ) {
			$send_reprint_request_notification = 1;
		} elsif ( $param{reprint_approval} ne $variable{CAR}->reprint_approval() ) {
			$send_reprint_approval_notification = 1;
		} # end if reprint
		$variable{error} .= $variable{CAR}->save( \%param );
		if ( ! $variable{error} ) {
			if ( $variable{CAR}->id() and ( ! $param{car_id} ) and ! $send_reprint_request_notification ) {
	# Send out notifications
			} # end if
			$variable{CAR}->send_notifications();
			if ( $send_assignee_notification ) {
				$variable{CAR}->send_assignee_notification();
			} # end if
			if ( $send_reprint_request_notification ) {
				$variable{CAR}->send_reprint_request_notification();
			} # end if
			if ( $send_reprint_approval_notification ) {
				$variable{CAR}->send_reprint_approval_notification();
			} # end if
		} # end if no errors
		
	} # end if btnFunction is Save
} # end sub _car_view_part1
sub _car_view_part2 {
	$variable{CAR} = new openprint::CAR( $param{car_id} );
	if ( $param{btnFunction} eq 'Save' ) {
		$param{part2_signed_on} = sprintf('%.4d-%.2d-%.2d', @param{'part2_signed_on_year','part2_signed_on_month','part2_signed_on_day'} );
		$variable{error} .= $variable{CAR}->save( \%param );
		if ( ! $variable{error} ) {
			$variable{CAR}->send_changed_notification();
		} # end if
	} # end if
} # end sub _car_view_part2
sub _car_view_part3 {
	$variable{CAR} = new openprint::CAR( $param{car_id} );
	if ( $param{btnFunction} eq 'Save' ) {
		$param{part3_signed_on} = sprintf('%.4d-%.2d-%.2d', @param{'part3_signed_on_year','part3_signed_on_month','part3_signed_on_day'} );
		$variable{error} .= $variable{CAR}->save( \%param );
		if ( ! $variable{error} ) {
			$variable{CAR}->send_changed_notification();
		} # end if
	} # end if
} # end sub _car_view_part3

sub _car_view_part4 {
	$variable{CAR} = new openprint::CAR( $param{car_id} );
	if ( $param{btnFunction} eq 'Save' ) {
		$param{part4_signed_on} = sprintf('%.4d-%.2d-%.2d', @param{'part4_signed_on_year','part4_signed_on_month','part4_signed_on_day'} );
		$variable{error} .= $variable{CAR}->save( \%param );
		if ( ! $variable{error} ) {
			$variable{CAR}->send_changed_notification();
		} # end if
	} # end if
} # end sub _car_view_part4

sub _car_edit_part1 {
	$variable{CAR} = new openprint::CAR( $param{car_id} );
}
sub _car_edit_part2 {
	$variable{CAR} = new openprint::CAR( $param{car_id} );
}
sub _car_edit_part3 {
	$variable{CAR} = new openprint::CAR( $param{car_id} );
}
sub _car_edit_part4 {
	$variable{CAR} = new openprint::CAR( $param{car_id} );
}

sub pars {
	if ( $param{btnFunction} eq 'Delete' ) {
		foreach my $par_id ( ref $param{pars} eq 'ARRAY' ? @{$param{pars}} : $param{pars} ) {
			my $PAR = new openprint::PAR( $par_id );
			$variable{error} .= $PAR->delete();
		} # end foreach par_id
	} elsif ( $param{btnFunction} eq 'Download in CSV Format' ) {
		my @header = ('Issued To','Issued On','Issued By','Reply By', 'Area','Reason','Problem','Cause','Action','Effectiveness', 
'Part1 Recipient', 'Part1 Signed On', 'Part2 Recipient', 'Part2 Signed On', 'Part3 Recipient', 'Part3 Signed On', 'Part4 QS Mgt Rep/Designate', 'Part4 Signed On' );
		my @data;
		my %params = (
				'issued_on >='   =>  sprintf('%.4d-%.2d-%.2d', @param{'StartYear','StartMonth','StartDay'} ),
				'issued_on <=' =>  sprintf('%.4d-%.2d-%.2d', @param{ 'EndYear', 'EndMonth', 'EndDay'} ),
		);
		foreach my $PAR ( openprint::PAR->find(%params) ) {
			push @data, (
					new openprint::User($PAR->issued_to_id() )->name(),
					$PAR->issued_on(),
					new openprint::User($PAR->issued_by_id() )->name(),
					$PAR->reply_by(),
					$PAR->Area()->name(),
					$PAR->Reason()->name(),
					$PAR->problem(),
					$PAR->cause(),
					$PAR->action(),
					$PAR->effectiveness(),
					new openprint::User($PAR->part1_user_id())->name(),
					$PAR->part1_signed_on(),
					new openprint::User($PAR->part2_user_id())->name(),
					$PAR->part2_signed_on(),
					new openprint::User($PAR->part3_user_id())->name(),
					$PAR->part3_signed_on(),
					new openprint::User($PAR->part4_user_id())->name(),
					$PAR->part4_signed_on(),
					);

		} # end foreach CAR
		
		misc::export_csv( $r, $log, \%variable, 'PARS.csv', \@header, \@data );
	} # end if
	ssi::setup_date_select( '/employee/iso/pars.html', 'issued_on_start', -365 );
	ssi::setup_date_select( '/employee/iso/pars.html', 'issued_on_end', '' );
	_par_results();
} # end sub pars
sub _par_results {
	ssi::save_params( '/employee/iso/pars.html', ( 
				'issued_on_start_year','issued_on_start_month','issued_on_start_day',
				'issued_on_end_year','issued_on_end_month','issued_on_end_day', 'status',
				'docket',
				) );
} # end sub _par_results

sub par {
	$variable{PAR} = new openprint::PAR( $param{par_id} );
} # end sub view_par
sub _par_view_part1 {
	$variable{PAR} = new openprint::PAR( $param{par_id} );
	if ( $param{btnFunction} eq 'Save' ) {
		$param{issued_on} = sprintf('%.4d-%.2d-%.2d', @param{'issued_on_year','issued_on_month','issued_on_day'} );
		$param{reply_by} = sprintf('%.4d-%.2d-%.2d', @param{'reply_by_year','reply_by_month','reply_by_day'} );
		$param{part1_signed_on} = sprintf('%.4d-%.2d-%.2d', @param{'part1_signed_on_year','part1_signed_on_month','part1_signed_on_day'} );
		$variable{error} .= $variable{PAR}->save( \%param );
		if ( $variable{PAR}->id() and ! $param{par_id} ) {
			# Send out notifications
			$variable{PAR}->send_notifications();
		} # end if
	} # end if
} # end sub _par_view_part1

sub _par_view_part2 {
	$variable{PAR} = new openprint::PAR( $param{par_id} );
	if ( $param{btnFunction} eq 'Save' ) {
		$param{part2_signed_on} = sprintf('%.4d-%.2d-%.2d', @param{'part2_signed_on_year','part2_signed_on_month','part2_signed_on_day'} );
		$param{cause} =~ s/<br\/>/\n/g;
		$variable{error} .= $variable{PAR}->save( \%param );
	} # end if
} # end sub _par_view_part2
sub _par_view_part3 {
	$variable{PAR} = new openprint::PAR( $param{par_id} );
	if ( $param{btnFunction} eq 'Save' ) {
		$param{part3_signed_on} = sprintf('%.4d-%.2d-%.2d', @param{'part3_signed_on_year','part3_signed_on_month','part3_signed_on_day'} );
		$variable{error} .= $variable{PAR}->save( \%param );
	} # end if
} # end sub _par_view_part3

sub _par_view_part4 {
	$variable{PAR} = new openprint::PAR( $param{par_id} );
	if ( $param{btnFunction} eq 'Save' ) {
		$param{part4_signed_on} = sprintf('%.4d-%.2d-%.2d', @param{'part4_signed_on_year','part4_signed_on_month','part4_signed_on_day'} );
		$variable{error} .= $variable{PAR}->save( \%param );
	} # end if
} # end sub _par_view_part4

sub _par_edit_part1 {
	$variable{PAR} = new openprint::PAR( $param{par_id} );
}
sub _par_edit_part2 {
	$variable{PAR} = new openprint::PAR( $param{par_id} );
}
sub _par_edit_part3 {
	$variable{PAR} = new openprint::PAR( $param{par_id} );
}
sub _par_edit_part4 {
	$variable{PAR} = new openprint::PAR( $param{par_id} );
}

sub _select_customer_from_docket {
	$param{docket} =~ s/\D//g;
} # end sub _select_customer_from_docket

sub _select_assignee_from_area {
} # end sub _select_assignee_from_area

1;
__END__
