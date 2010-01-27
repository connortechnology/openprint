#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use Date::Calc;
use strict;
require sql;
require logger;
require openprint::Object;
require configuration;

use openprint ();
use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;


$log = new logger( 'warn' );

my ( $src_db, $dst_db, $src_host, $year, $month, $day ) = @ARGV;
$src_db = 'topknotch' if ! $src_db;
$dst_db = 'topknotch' if ! $dst_db;
$src_host = 'www.topknotch.com' if ! $src_host;

`/etc/init.d/apache2 reload`;
if ( $year ) {
	( $year, $month, $day ) = Date::Calc::Add_Delta_Days( Date::Calc::Today(), -1 ) if ! $month;

	if ( ! -e "/tmp/$src_db-$month-$day-$year.sql.bz2" ) {
		print "Getting db backup $month-$day-$year\n";
		`su postgres -c "scp $src_host:/media/Storage/Backups/Database/$src_db/$year-$month-$day.sql.bz2 /tmp/$src_db-$month-$day-$year.sql.bz2 "`;
	} # end if
	if ( ! -e "/tmp/$src_db-$month-$day-$year.sql.bz2" ) {
		die "No db dum[";
	}
	print "Dropping db...";
	`su postgres -c "dropdb $dst_db"`;
	print "done\n";
	print "Create db...";
	`su postgres -c "createdb -E UTF8 $dst_db"`;
	print "done\n";
	print "Loading db...";
	`su postgres -c "bunzip2 < /tmp/$src_db-$month-$day-$year.sql.bz2 | psql $dst_db"`;
	print "done\n";
} else {
#grab direclty
	print "Dropping db...";
	`su postgres -c "dropdb $dst_db"`;
	print "done\n";
	print "Create db...";
	`su postgres -c "createdb -E UTF8 $dst_db"`;
	print "done\n";
	print "Loading db...";
	`su postgres -c "ssh $src_host pg_dump $src_db | psql $dst_db"`;
	print "done\n";

} # end if

print "upgrading db ...";
`./db_update.pl $dst_db topknotch topknotch` or $log->error($!);
print "done\n";
$dbh = sql::open_sql( $log, ('database'=>$dst_db, 'driver'=>'Pg','login'=>$dst_db, 'password'=>$dst_db, 'host'=>$ARGV[3]) );
configuration::init_cache( $log, $dbh );
require openprint::PaymentType;
my $PayPal = new openprint::PaymentType();
$PayPal->save({'name'=>'PayPal','description'=>'PayPal'});

#print "upgrading signatures...";
#`/etc/apache2/lib/perl/tools/update_p1_signatures.pl $dst_db >> /tmp/db_update.log` or $log->error($!);
print "done\n";
$dbh->disconnect();
1;
__END__
