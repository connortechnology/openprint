package openprint::timetrack;

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

require openprint::Timetrack;

sub history {
	if ( $param{'btnFunction'} eq 'Save' ) {
		$param{'owner_id'} = $session{'company_id'} if ! $param{'owner_id'};
		$param{'starting'} = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', @param{'starting_year','starting_month','starting_day','starting_hour','starting_minute'} );
		$param{'ending'} = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', @param{'ending_year','ending_month','ending_day','ending_hour','ending_minute'} );
		if ( ! $param{'timetrack_id'} ) {
			if ( openprint::Timetrack->find_one('owner_id'=>$param{'owner_id'},'company_id'=>$param{'company_id'},'starting'=>$param{'starting'},'ending'=>$param{'ending'},'service_id'=>$param{'service_id'}) ) {
				$variable{'error'} = 'Not creating duplicate.<br/>';
				return;
			} # end if
		} # end if
		my $Timetrack = new openprint::Timetrack( $param{'timetrack_id'} );
		$variable{'error'} .= $Timetrack->save(\%param);
		if ( $param{'referrer_invoice_id'} ) {
			$_ = $param{'referrer_invoice_id'};
			%param = ();
			$param{'invoice_id'} = $_;
			$variable{'Redirect'} = '/invoice/edit.html';
		} else {
			ssi::save_params( '/timetrack/edit.html', 'ending', 'company_id' );
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Destroy' ) {
		my $Timetrack = new openprint::Timetrack( $param{'timetrack_id'} );
		$variable{'error'} .= $Timetrack->destroy();
	} elsif ( ! $param{'btnFunction'} ) {
		ssi::save_params( '/timetrack/history.html', ( 'starting_start_year','starting_start_month','starting_start_day','starting_end_year','starting_end_month','starting_end_day','invoiced','paid','employee_id','company_id') );
	} # end if

	if ( ( ! $session{'/timetrack/history.html?lastupdated'} ) or ( time - $session{'/timetrack/history.html?lastupdated'} ) > ( 12*60*60 ) ) {
		ssi::setup_date_select( '/timetrack/history.html', 'starting', -31 );
	} # end if

	$session{'/timetrack/history.html?invoiced'} = '0' if ! $session{'/timetrack/history.html?invoiced'};
	$session{'/timetrack/history.html?paid'} = '0' if ! $session{'/timetrack/history.html?paid'};
	$session{'/timetrack/history.html?employee_id'} = $session{'user_id'} if ! exists $session{'/timetrack/history.html?employee_id'};
} # end sub history

sub _history {
	if ( ! $param{'btnFunction'} ) {
		ssi::save_params( '/timetrack/history.html', ( 'starting_start_year','starting_start_month','starting_start_day','starting_end_year','starting_end_month','starting_end_day','invoiced','paid','employee_id','company_id') );
	} # end if
} # end sub _history

sub edit {
	$variable{'Timetrack'} = new openprint::Timetrack( $param{'timetrack_id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
		$variable{'error'} .= $variable{'Timetrack'}->save(\%param);
		$variable{'Redirect'} = '/timetrack/history.html';
	} elsif ( $param{'btnFunction'} eq 'Copy' ) {
		$variable{'Timetrack'} = $variable{'Timetrack'}->copy();
		$variable{'error'} .= $variable{'Timetrack'}->save();
	} # end if
	if ( time - $session{'/timetrack/edit.html?lastupdated'} < ( 12*60*60 ) ) {
		$variable{'Timetrack'}->company_id( $session{'/timetrack/edit.html?company_id'} ) if ! $variable{'Timetrack'}->company_id();
		$variable{'Timetrack'}->starting( $session{'/timetrack/edit.html?ending'} ) if ! $variable{'Timetrack'}->starting();
		$variable{'Timetrack'}->ending( $session{'/timetrack/edit.html?ending'} ) if ! $variable{'Timetrack'}->ending();
	} # end if
} # end sub edit

1;
__END__
