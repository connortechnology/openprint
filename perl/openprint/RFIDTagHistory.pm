package openprint::RFIDTagHistory;
@ISA = qw(openprint::Object);
require openprint::Object;

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
	my ( $self ) = @_;
	return new openprint::Location( $$self{'location_id'} );
} # end sub Location

sub Scanner {
	my ( $self ) = @_;
	return new openprint::RFIDScanner( $$self{'scanner_id'} );
} # end sub Scanner
	

1;
__END__
