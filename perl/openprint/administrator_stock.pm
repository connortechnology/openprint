package openprint::administrator_stock;
require openprint::StockName;
require openprint::StockFinish;
require openprint::StockColour;
require openprint::StockWeight;
require openprint::Manufacturer;

use strict;

use openprint ();
use vars qw( $log $dbh %param %variable %session %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*param = \%openprint::param;
*variable = \%openprint::variable;
*session = \%openprint::variable;
*cache = \%openprint::cache;

sub filters {
} # end sub filters

sub _filters_load {
} # end sub _filters_load

sub _filters_save {
} # end sub _filters_save

1;
__END__
