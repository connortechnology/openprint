package openprint::RFIDScanner;
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
require openprint::Location;
require openprint::RFIDTagHistory;
require openprint::RFIDScannerHistory;

my $debug = 1;

%fields = (
	'id'		=>	'id',
	'name'		=>	'name',
	'ipaddr'	=>	'ipaddr',
	'type'		=>	'type',
	'location_id'	=>	'location_id',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
	'lastseen_on'	=>	'lastseen_on',
	'other'			=>	'other',
);

%transforms = (
	'updated_on'	=>	['s/.*//g'],
);

%defaults = (
	'created_on'	=>	'NOW()',
	'updated_on'	=>	'NOW()',
	'lastseen_on'	=>	'NOW()',
	'location_id'	=>	undef,
);

$table = 'rfidscanners';
$serial = 'rfidscanners_id_seq';

sub delete {
    my $self = shift;
    my $ac = sql::start_transaction( );
	foreach ( openprint::RFIDScannerHistory->find('scanner_id'=>$$self{'id'}) ) {
		$_->delete();
	} # end foreach
	foreach ( openprint::RFIDTagHistory->find('scanner_id'=>$$self{'id'}) ) {
		$_->delete();
	} # end foreach
    sql::execute( undef, undef, q{DELETE FROM RFIDScanners WHERE id=?}, $$self{'id'} );
    sql::end_transaction( undef, $ac );
} # end sub delete

sub Location {
	return new openprint::Location( $_[0]{'location_id'} );
} # end sub Location

sub location_id {
    my ( $self, $new, $rfidtag_id ) = @_;
    if ( $new ) {
        if ( $new != $$self{'location_id'} ) {
            sql::insert( undef, undef, 'RFIDScannerHistory', {'location_id'=>$new, 'scanner_id'=>$$self{id}, 'rfidtag_id'=>$rfidtag_id } );
            $$self{'location_id'} = $new;
        } # end if
    } # end if
    return $$self{'location_id'};
} # end sub location_id

sub Next {
	my $self = $_[0];
	my ( $new_id ) = sql::execute( undef, undef, 'SELECT id FROM RFIDScanners WHERE name = (SELECT MIN(name) FROM RFIDScanners WHERE lower(name) > lower(?))', $$self{'name'} );
	if ( ! $new_id ) {
		( $new_id ) = sql::execute( undef, undef, 'SELECT id FROM RFIDScanners WHERE name = (SELECT MIN(name) FROM RFIDScanners)' );
	} # end if
	return new openprint::RFIDScanner( $new_id );
} # end sub Next

sub Previous {
	my $self = $_[0];
	my ( $new_id ) = sql::execute( undef, undef, 'SELECT id FROM RFIDScanners WHERE name = (SELECT MAX(name) FROM RFIDScanners WHERE lower(name) < lower(?))', $$self{'name'} );
	if ( ! $new_id ) {
		( $new_id ) = sql::execute( undef, undef, 'SELECT id FROM RFIDScanners WHERE name = (SELECT MAX(name) FROM RFIDScanners)' );
	} # end if
	return new openprint::RFIDScanner( $new_id );
} # end sub Previous

1;
__END__
