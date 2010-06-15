package openprint::RFIDScannerHistory;
@ISA = qw(openprint::Object);
require openprint::Object;
use MIME::QuotedPrint;

use strict;
use openprint ();
use vars qw(%variable $log $dbh %config $table $serial %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require sql;
require ssi;
require misc;

my $debug = 1;

$table = 'RFIDScannerHistory';
$serial = 'RFIDScannerHistory_id_seq';
%fields = (
	'id'				=>	'id',
	'rfidtag_id'		=>	'rfidtag_id',
	'scanner_id'		=>	'scanner_id',
	'location_id'		=>	'location_id',
	'updated_on'		=>	'updated_on',
);

%transforms = (
);

%defaults = (
);

sub Location {
	my ( $self ) = @_;
	return new openprint::Location( $$self{'location_id'} );
} # end sub Location

sub Scanner {
	my ( $self ) = @_;
	return new openprint::RFIDScanner( $$self{'scanner_id'} );
} # end sub Scanner
	

1;
__END__
