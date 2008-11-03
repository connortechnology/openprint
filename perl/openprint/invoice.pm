package openprint::invoice;

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

require openprint::Invoice;

sub history {
	if ( $param{'btnFunction'} eq 'Save' ) {
		my $Invoice = new openprint::Invoice( $param{'invoice_id'} );
		$param{'currency_id'} = openprint::Currency::get_current()->id() if ! $param{'currency_id'};
		$param{'due_on'} = sprintf('%.4d-%.2d-%.2d', @param{'due_on_year','due_on_month','due_on_day'} ) if ! $param{'due_on'};
		$param{'invoicer_id'} = $session{'company_id'} if ! $param{'invoicer_id'};
		$variable{'error'} .= $Invoice->save(\%param);
	} elsif ( $param{'btnFunction'} eq 'Post' ) {
		my $Invoice = new openprint::Invoice( $param{'invoice_id'} );
		if ( ! ( $variable{'error'} .= $Invoice->save({'posted'=>1,'posted_on'=>'NOW()'}) ) ) {
			$Invoice->add_to_log( 'Invoice posted.' );
		} # end if
	} elsif ( $param{'btnFunction'} eq 'UnPost' ) {
		my $Invoice = new openprint::Invoice( $param{'invoice_id'} );
		if ( ! ( $variable{'error'} .= $Invoice->save({'posted'=>0}) ) ) {
			$Invoice->add_to_log( 'Invoice posted.' );
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Send' ) {
		my $Invoice = new openprint::Invoice( $param{'invoice_id'} );
		$variable{'error'} .= $Invoice->send();
	} # end if
} # end sub history

sub _history {
} # end sub _history

sub edit {
	$variable{'Invoice'} = new openprint::Invoice( $param{'invoice_id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
		$param{'currency_id'} = openprint::Currency::get_current()->id() if ! $param{'currency_id'};
		$param{'due_on'} = sprintf('%.4d-%.2d-%.2d', @param{'due_on_year','due_on_month','due_on_day'} ) if ! $param{'due_on'};
		$param{'invoicer_id'} = $session{'company_id'} if ! $param{'invoicer_id'};
		$variable{'error'} .= $variable{'Invoice'}->save(\%param);
	} # end if
} # end sub edit
sub view {
	$variable{'Invoice'} = new openprint::Invoice( $param{'invoice_id'} );
} # end sub view
sub _invoiced_timetracks {
	$variable{'Invoice'} = new openprint::Invoice( $param{'invoice_id'} );
	if ( $param{'timetrack_id'} ) {
		my $Timetrack = new openprint::Timetrack( $param{'timetrack_id'} );
		$Timetrack->invoice_id( $variable{'Invoice'}->id() );
		$Timetrack->save();
	} # end if
} # end sub _invoiced_timetracks
sub _available_timetracks {
	$variable{'Invoice'} = new openprint::Invoice( $param{'invoice_id'} );
	if ( $param{'timetrack_id'} ) {
		my $Timetrack = new openprint::Timetrack( $param{'timetrack_id'} );
		$Timetrack->invoice_id( undef );
		$Timetrack->save();
	} # end if
} # end sub _available_timetracks
