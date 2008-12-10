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
		my $Timetrack = new openprint::Timetrack( $param{'timetrack_id'} );
		$variable{'error'} .= $Timetrack->save(\%param);
		if ( $param{'referrer_invoice_id'} ) {
			$_ = $param{'referrer_invoice_id'};
			%param = ();
			$param{'invoice_id'} = $_;
			$variable{'Redirect'} = '/invoice/edit.html';
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Destroy' ) {
		my $Timetrack = new openprint::Timetrack( $param{'timetrack_id'} );
		$variable{'error'} .= $Timetrack->destroy();
	} # end if
} # end sub history

sub _history {
} # end sub _history

sub edit {
	$variable{'Timetrack'} = new openprint::Timetrack( $param{'timetrack_id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
		$variable{'error'} .= $variable{'Timetrack'}->save(\%param);
		$variable{'Redirect'} = '/timetrack/history.html';
	} # end if
} # end sub edit
