package openprint::paycheque;

use strict;
use openprint;
use vars qw( $r %variable %session %param %config $log $dbh );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*r = \$openprint::r;

require openprint::Paycheque;
require openprint::Invoice;

sub history {
	if ( $param{'btnFunction'} eq 'Save' ) {
		$param{'paid_on'} = sprintf('%.4d-%.2d-%.2d', @param{'paid_on_year','paid_on_month','paid_on_day'} );
		my $Paycheque = new openprint::Paycheque( $param{'paycheque_id'} );
		$variable{'error'} .= $Paycheque->save(\%param);
	} elsif ( $param{'btnFunction'} eq 'Destroy' ) {
		my $Paycheque = new openprint::Paycheque( $param{'paycheque_id'} );
		$variable{'error'} .= $Paycheque->destroy();
	
	} elsif ( $param{'btnFunction'} eq 'Export' ) {
		my @Header = ( 'ID', 'When', 'Employee', 'Amount' );
		my @Data;
		foreach my $Paycheque ( openprint::Paycheque->find( 
					'paid_on_start' => sprintf('%.4d-%.2d-%.2d', @param{'paid_on_start_year','paid_on_start_month','paid_on_start_day'} ),
					'paid_on_end'   => sprintf('%.4d-%.2d-%.2d', @param{'paid_on_end_year','paid_on_end_month','paid_on_end_day'} ),
					'employer_id'       => $param{'employer_id'},
					'employee_id'       => $param{'employee_id'},
					'order'             => 'paid_on',
					) ) {
			push @Data, ( $Paycheque->id(), 
					Date::Format::time2str( $config{'DateFormat'}, Date::Parse::str2time( $Paycheque->paid_on() ) ),
					$Paycheque->Employee()->name(),
					$Paycheque->total()
					);
		} # end foreach Paycheque
		misc::export_csv( $r, $log, \%variable, "Paycheques.csv", \@Header, \@Data );
	} else {
		ssi:setup_date_select( '/paycheque/history.html', 'paid_on_start', -31 );
		ssi:setup_date_select( '/paycheque/history.html', 'paid_on_end', 0 );
		ssi::save_params( '/paycheque/history.html', 'paid_on_start_year','paid_on_start_month','paid_on_start_day','paid_on_end_year','paid_on_end_month','paid_on_end_day', 'employer_id','employee_id' );
	} # end if
} # end sub history

sub _history {
		ssi::save_params( '/paycheque/history.html', 'paid_on_start_year','paid_on_start_month','paid_on_start_day','paid_on_end_year','paid_on_end_month','paid_on_end_day', 'employer_id','employee_id' );
} # end sub _history

sub edit {
	$variable{'Paycheque'} = new openprint::Paycheque( $param{'paycheque_id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
		$param{'paid_on'} = sprintf('%.4d-%.2d-%.2d', @param{'paid_on_year','paid_on_month','paid_on_day'} );
		$variable{'error'} .= $variable{'Paycheque'}->save(\%param);
	} # end if
} # end sub edit

sub _paid {
	my $Paycheque = new openprint::Paycheque( $param{'paycheque_id'} );
	if ( $param{'timetrack_id'} ) {
		my $Timetrack = new openprint::Timetrack( $param{'timetrack_id'} );
		$Timetrack->paycheque_id( $Paycheque->id() );
		$Timetrack->save();
	} # end if
	$variable{'Paycheque'} = $Paycheque;
} # end sub _paid

sub _unpaid {
	my $Paycheque = new openprint::Paycheque( $param{'paycheque_id'} );
	if ( $param{'timetrack_id'} ) {
		my $Timetrack = new openprint::Timetrack( $param{'timetrack_id'} );
		$Timetrack->paycheque_id( undef );
		$Timetrack->save();
	} # end if
	$variable{'Paycheque'} = $Paycheque;
} # end sub _paid

 1;
__END__
