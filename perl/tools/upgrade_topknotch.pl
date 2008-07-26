#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use Date::Calc;
use strict;
require sql;
require logger;
require openprint::Object;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'warn' );

my ( $src_db, $dst_db, $src_host, $year, $month, $day ) = @ARGV;
$src_db = 'topknotch' if ! $src_db;
$dst_db = 'topknotch' if ! $dst_db;
$src_host = 'topknotch.com' if ! $src_host;

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

`chmod +x /etc/apache2/lib/perl/tools/db_update.pl`;
print "upgrading db ...";
`/etc/apache2/lib/perl/tools/db_update.pl $dst_db topknotch topknotch` or $log->error($!);
print "done\n";
$dbh = sql::open_sql( $log, ('database'=>$dst_db, 'driver'=>'Pg','login'=>'topknotch', 'password'=>'topknotch') );
$dbh->do( 'update products set project_id=41789 where id=1');
$dbh->do( 'update products set project_id=41791 where id=24');
$dbh->do( 'update products set project_id=41793 where id=27');
$dbh->do( 'update products set project_id=41795 where id=33');
$dbh->do( 'update products set project_id=41796 where id=34');
$dbh->do( 'update products set project_id=41783 where id=43');
$dbh->do( 'update products set project_id=41781 where id=45');
$dbh->do( 'update products set project_id=41771 where id=74');
$dbh->do( 'update products set project_id=41772 where id=76');
$dbh->do( 'update products set project_id=41774 where id=77');
$dbh->do( 'update products set project_id=41798 where id=78');
$dbh->do( 'update products set project_id=41799 where id=79');
$dbh->do( 'update products set project_id=41782 where id=82');
$dbh->do( 'update products set project_id=41792 where id=87');
$dbh->do( 'update products set project_id=41797 where id=89');
$dbh->do( 'update products set project_id=41784 where id=107');
$dbh->do( 'update products set project_id=41787 where id=109');
$dbh->do( 'update products set project_id=41794 where id=110');
$dbh->do( 'update products set project_id=41788 where id=111');
$dbh->do( 'update products set project_id=41785 where id=112');
$dbh->do( "update service_types set strdetailedurl='shipping/CustomerPickup.html', view_visible=true where name='CustomerPickUp'");
