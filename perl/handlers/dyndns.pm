use strict;
package handlers::dyndns;

use Apache2::Request ();
use Apache2::RequestRec ();
use Apache2::Const -compile => qw(REDIRECT HTTP_INTERNAL_SERVER_ERROR OK DECLINED HTTP_SERVICE_UNAVAILABLE HTTP_FORBIDDEN);# Offers OK, Error,etc for web server.
use Apache2::Log ();
#use Time::HiRes qw{ time gettimeofday tv_interval }; 

require sql;

use openprint ();
use vars qw( $r $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*r = \$openprint::r;

use constant DEBUG => 0;

sub cleanup {
    if ( $r->connection->aborted( ) ) {
		$log->debug("Was aborted");
    } else {
#$log->debug("cleanup");
    } # end if
    if ( $dbh ) {
        $dbh->disconnect();
	} else {
		$log->error("No dbh in cleanup");
    } # end if
} # end sub cleanup

sub handler {

	my $request = $_[0];
	$r = Apache2::Request->new( $request );
	#my $starttime = gettimeofday() if DEBUG;
	$r->log->debug( "Beginning of Request: $ENV{HTTP_USER_AGENT} $ENV{REMOTE_ADDR} Page: " . $r->uri() );

	$log	= $r->log;
	my $hostname = lc $r->param('host');
	if ( ! $hostname ) {
		$log->warn("No hostname specified.");
		return Apache2::Const::DECLINED;
	} # end if
	$request->push_handlers(PerlCleanupHandler => \&cleanup);

	$dbh = sql::open_sql( $log, 
			port		=> $r->dir_config('db_port'),
			database	=> $r->dir_config('db_name'),
			driver		=> $r->dir_config('db_driver'), 
			host		=> $r->dir_config('db_host'),
			login		=> $r->dir_config('db_user'),
			password	=> $r->dir_config('db_password'),
			);
	
	if ( ! $dbh ) {
		$openprint::log->error("Couldn't connect to db: " . $dbh->errstr() );
		return Apache2::Const::HTTP_SERVICE_UNAVAILABLE;
	} # end if
$openprint::log->debug("Host: " . $r->param('host') );
	my $addr = $ENV{REMOTE_ADDR};

    my ( $host, $domain ) = $hostname =~ /^([^\.])+\.(.+)$/;
    #my ( $domain_id, $allow_dyndns ) = sql::execute(undef,undef,'SELECT id, dyndns FROM domains WHERE name=?', $domain );
    my ( $domain_id ) = sql::execute(undef,undef,'SELECT id FROM domains WHERE name=?', $domain ) if $domain;

	if ( ! $domain_id ) {
		$log->error( "No domain_id found for $hostname\n" );
		return Apache2::Const::DECLINED;
	#} elsif ( ! $allow_dyndns ) {
		#die "dysndns not allowed for $hostname\n";
		#return Apache2::Const::DECLINED;
	} # end if

	my $update_soa = 0;
		
	my $record = $dbh->selectrow_hashref( 'SELECT * FROM records WHERE name=? AND content!=? AND type=?', {}, $hostname, $addr, 'A' );
	if ( $record ) {
		sql::execute( undef, undef, 'DELETE FROM records WHERE name=? AND type=?', $hostname, 'A' );
		$update_soa = 1;
	} # end if
		
	$record = $dbh->selectrow_hashref( 'SELECT * FROM records WHERE name=? AND content=? AND type=?', {}, $hostname, $addr, 'A' );
	if ( $record ) {
		$r->print('nochg');
	} else {
		$log->debug("Record not found for $hostname $addr A");
		if ( $dbh->errstr() ) {
			$log->error('DB error: ' . $dbh->errstr() );
			$r->print('dnserr');
		} else {
			sql::insert( undef, undef, 'records', {
					name		=>	$hostname, 
					content		=>	$addr,
					type		=>	'A',
					change_date	=>	int(time),
					domain_id   =>  $domain_id,
					ttl			=>	600,
					} );
			if ( $dbh->errstr() ) {
				$log->error("DB error: " . $dbh->errstr() );
				$r->print('dnserr');
			} else {
				$r->print('good');
				$update_soa = 1;
			} # end if
		} # end if
	} # end if record exists

	if ( $update_soa ) {
		my $soa = $dbh->selectrow_hashref( 'SELECT * FROM records WHERE name=? AND type=?', {}, $domain, 'SOA' );
		if ( $dbh->errstr() or ! $soa ) {
			$log->error("ERror finding SOA record.");
			$r->print('dnserr');
		} # end if

		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
		$year += 1900;
		$mon += 1;
		my $date_string = sprintf('%.4d%.2d%.2d', $year,$mon,$mday);

		my ( $ns, $email, $sn, $refresh, $retry, $expiry, $min ) = $$soa{content} =~ /\s*(\S+)\s+(\S+)\s+(\d+)\s+(\d*)\s+(\d*)\d+(\d*)\s+(\d*)\s*/;
		my ( $ns, $email, $sn, $refresh, $retry, $expiry, $min ) = split( /\s/, $$soa{content} );
		if ( $sn =~ /^$date_string/ ) {
			$sn += 1;
		} else {
			$sn = $date_string .'01';
		} # end if
		sql::update( undef, undef, 'records', [ 'name=? AND type=?', $domain, 'SOA' ], content=>"$ns $email $sn $refresh $retry $expiry $min" );
		`/usr/bin/pdnssec rectify-zone $domain`;
	} # end if update_soa

	#$log->debug( "Elapsed seconds after: " . sprintf('%.4f', tv_interval([$starttime])*1000).' usecs' ) if DEBUG;
	return Apache2::Const::OK;
} # end sub handler

1;
__END__
