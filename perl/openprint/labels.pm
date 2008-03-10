package openprint::labels;
use strict;
use Date::Calc qw(Add_Delta_Days Date_to_Days check_date );
use MIME::QuotedPrint;

use openprint ();
use vars qw{ $log $dbh %config %variable };
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*variable = \%openprint::variable;

require sql;
require openprint::Label;
require openprint::LabelType;

sub index {
} # end sub index

1;

__END__
~	   
