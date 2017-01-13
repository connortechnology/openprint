#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Skid;
require openprint::RFIDTag;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'debug' );

$openprint::Object::no_cache = 1;
$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>'database') );
die 'No db connection' if ! $dbh;

foreach my $Tag ( openprint::RFIDTag->find( 'id_ilike' => 'R%' ) ) {
	my ( $id ) = $Tag->id() =~ /^R(\d+)$/i;
	if ( ! $id ) {
		$log->debug("Invalid id " . $Tag->to_string() );
		next;
	} # end if
	$log->debug( 'InValid: ' . $Tag->to_string() );
	my $Valid = openprint::RFIDTag->find_one( id=>$id );
	if ( $Valid ) {
		my $Invalid_Skid = openprint::Skid->find_one(rfidtag_id=>$Tag->id() );
		my $Valid_Skid = openprint::Skid->find_one(rfidtag_id=>$Valid->id() );
		if ( $Invalid_Skid and $Valid_Skid ) {
			$log->debug("Has both valid and invalid skids");
			next;
		} elsif ( $Invalid_Skid ) {
			$Invalid_Skid->save({rfidtag_id=>$Valid->id()});
		} elsif ( $Valid_Skid ) {
		} else { # No Skids
		} # end if
		$Tag->delete();

		$log->debug( 'Valid: ' . $Valid->to_string() );
	} else {
		$Tag->save({id=>$id});
	} # end if
} # end foreach
foreach my $Tag ( openprint::RFIDTag->find( valid=>0 ) ) {
	if ( length $Tag->id() == 6 ) {
		my $id = sprintf('2%.14d', $Tag->id );
		die 'no id' if ! $id;
		my $Skid = openprint::Skid->find_one( rfidtag_id=>$Tag->id );
		if ( $Skid ) {
			$_ = $Skid->save({rfidtag_id => $id});
			die $_ if $_;
		} # end if
		my $Valid =  openprint::RFIDTag->find_one( id=>$id );
		if ( $Valid ) {
			my $Invalid_Skid = openprint::Skid->find_one(rfidtag_id=>$Tag->id() );
			my $Valid_Skid = openprint::Skid->find_one(rfidtag_id=>$Valid->id() );
			if ( $Invalid_Skid and $Valid_Skid ) {
				$log->debug("Has both valid and invalid skids");
				next;
			} elsif ( $Invalid_Skid ) {
				$Invalid_Skid->save({rfidtag_id=>$Valid->id()});
			} elsif ( $Valid_Skid ) {
			} else { # No Skids
			} # end if
			$Tag->delete();
		} else {
			sql::update( undef, undef, 'rfidtags', [ 'id=?', $Tag->id() ], 'id', $id );
		} # end if
		#$_ = $Tag->save({id=>$id});
		#die $_ if $_;
	} # end if	
		
} # end foreach Tag

$dbh->disconnect();
1;
__END__
