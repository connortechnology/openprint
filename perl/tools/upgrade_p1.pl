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
		`su postgres -c "scp $src_host:/var/backups/www2/$src_db/$year-$month-$day.sql.bz2 /tmp/$src_db-$month-$day-$year.sql.bz2 "`;
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
	`su postgres -c "ssh $src_host pg_dump point-one | psql $dst_db"`;
	print "done\n";

} # end if

`chmod +x /etc/apache2/lib/perl/tools/db_update.pl`;
print "upgrading structures 2...";
`/etc/apache2/lib/perl/tools/db_update.pl $dst_db point-one point-one` or $log->error($!);
print "upgrading signatures...";
`/etc/apache2/lib/perl/tools/update_p1_signatures.pl $dst_db point-one point-one` or $log->error($!);
print "done\n";
print 'Turning off backups...';
$dbh = sql::open_sql( $log, ('database'=>$dst_db, 'driver'=>'Pg','login'=>'point-one', 'password'=>'point-one') );
my ( $version, $updated_on, $backup ) = sql::execute( undef, undef, q{SELECT version,updated_on, backup FROM database_info ORDER BY updated_on DESC LIMIT 1} );
sql::insert( undef, undef, 'database_info', 'version', $version, 'backup', 'false' );
print "done\n";

foreach my $Service ( openprint::Service::find('name'=>'Imposition') ) {
	foreach my $Price ( $Service->prices() ) {
		if ( $Price->units() eq 'Per Page' ) {
			$Price->units('Per Imposition');
			$Price->save();
		} # end if
	} # end foreach
} # end foreach
