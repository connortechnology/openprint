use strict;
package openprint::RFIDTagHistory;
our @ISA = qw(openprint::Object);
require openprint::Object;

use openprint ();
use vars qw( $debug $log $dbh $table $serial %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require sql;

$debug = 1;

$table = 'rfidtaghistory';
$serial = 'rfidtaghistory_id_seq';

%fields = (
	'id'				=>	'id',
	'rfidtag_id'		=>	'rfidtag_id',
	'scanner_id'		=>	'scanner_id',
	'location_id'		=>	'location_id',
	'updated_on'		=>	'updated_on',
	'comment'			=>	'comment',
);

%transforms = (
);

%defaults = (
	'updated_on'	=>	'NOW()',
);

sub Location {
	return new openprint::Location( $_[0]{'location_id'} );
} # end sub Location

sub Scanner {
	return new openprint::RFIDScanner( $_[0]{'scanner_id'} );
} # end sub Scanner
	

1;
__END__
