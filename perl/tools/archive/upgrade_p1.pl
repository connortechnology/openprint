#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use Date::Calc;
use strict;
require sql;
require logger;
require openprint::Object;
require openprint::Paper;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'warn' );

my ( $src_db, $dst_db, $src_host, $year, $month, $day ) = @ARGV;
`/etc/init.d/apache2 reload`;
if ( $year ) {
	( $year, $month, $day ) = Date::Calc::Add_Delta_Days( Date::Calc::Today(), -1 ) if ! $month;

	if ( ! -e "/tmp/$src_db-$month-$day-$year.sql.bz2" ) {
		print "Getting db backup $month-$day-$year\n";
		`su postgres -c "scp $src_host:/var/backups/database/$src_db/$month-$day-$year.sql.bz2 /tmp/$src_db-$month-$day-$year.sql.bz2 "`;
	} # end if
	if ( ! -e "/tmp/$src_db-$month-$day-$year.sql.bz2" ) {
		die "No db dum[";
	}
	print "Dropping db...";
	`su postgres -c "dropdb $dst_db"`;
	print "done\n";
	print "Create db...";
	`su postgres -c "createdb -E SQL_ASCII $dst_db"`;
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
	`su postgres -c "createdb -E SQL_ASCII $dst_db"`;
	print "done\n";
	print "Loading db...";
	`su postgres -c "ssh database pg_dump point-one | psql $dst_db"`;
	print "done\n";

} # end if

print "Adding database_info db...";
my %sql_server;
$sql_server{'database'} = $dst_db;
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = 'point-one';
$sql_server{'password'} = 'point-1';

$dbh = sql::open_sql( $log, %sql_server );
my ( $version, $updated_on, $backup ) = sql::execute( undef, undef, q{SELECT version,updated_on, backup FROM database_info ORDER BY updated_on DESC LIMIT 1} );

sql::insert(undef,undef,'database_info','version'=>$version,'backup'=>'false');
$dbh->disconnect();
`sync`;
print "upgrading structures...";
system(qq{su postgres -c "psql -U point-one $dst_db < /etc/apache2/lib/perl/tools/upgrade-p1.sql"} );
print "done\n";
`chmod +x /etc/apache2/lib/perl/tools/db_update.pl`;
print "upgrading structures 2...";
`/etc/apache2/lib/perl/tools/db_update.pl $dst_db point-one point-one` or $log->error($!);
print "done\n";
print "upgrading paper...";
`/etc/apache2/lib/perl/tools/update_p1_paper.pl $dst_db` or $log->error($!);
print "done\n";
print "adding web paper...";
`/etc/apache2/lib/perl/tools/add_web_paper.pl $dst_db` or $log->error($!);
print "done\n";
print "Adding bowater papers...";
`/etc/apache2/lib/perl/tools/add_bowater_papers.pl $dst_db` or $log->error($!);
print "done\n";
print "upgrading signatures...";
`/etc/apache2/lib/perl/tools/update_p1_signatures.pl $dst_db` or $log->error($!);
print "done\n";
print "upgrading proofs...";
`/etc/apache2/lib/perl/tools/update_p1_proofs.pl $dst_db` or $log->error($!);
print "done\n";

print "Cleaning db...";
`su postgres -c "psql -U point-one point-one < /etc/apache2/lib/perl/tools/cleanup-p1.sql"`;
print "done\n";
#`/etc/init.d/apache2 reload`;
