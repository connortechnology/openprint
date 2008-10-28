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
} # end sub history

sub _history {
} # end sub _history

sub edit {
	$variable{'Invoice'} = new openprint::Invoice( $param{'invoice_id'} );
} # end sub edit
sub view {
	$variable{'Invoice'} = new openprint::Invoice( $param{'invoice_id'} );
} # end sub view
