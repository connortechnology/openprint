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
	} # end if
} # end sub history

sub _history {
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
