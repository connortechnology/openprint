#!/usr/bin/perl
use strict;
my $lib_path = '/var/www/testing/perl';
use lib '/var/www/testing/perl';
use Date::Calc;
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
$src_db = 'point-one' if ! $src_db;
$dst_db = 'point-one' if ! $dst_db;
`/etc/init.d/apache2 reload`;
if ( $year ) {
	( $year, $month, $day ) = Date::Calc::Add_Delta_Days( Date::Calc::Today(), -1 ) if ! $month;

	if ( ! -e "/tmp/$src_db-$month-$day-$year.sql.bz2" ) {
		print "Getting db backup $month-$day-$year\n";
		if ( $src_host ne 'localhost' ) {
			`su postgres -c "scp $src_host:/media/Storage/backups/localhost/$src_db/$year-$month-$day.sql.bz2 /tmp/$src_db-$month-$day-$year.sql.bz2 "`;
		} else {
			`ln -s /media/Storage/backups/localhost/$src_db/$year-$month-$day.sql.bz2 /tmp/$src_db-$month-$day-$year.sql.bz2`;
		} 
	} # end if
	if ( ! -e "/tmp/$src_db-$month-$day-$year.sql.bz2" ) {
		die "No db dump";
	}
	print "Dropping db...";
	`su postgres -c "dropdb $dst_db"`;
	print "done\n";
	print "Create db...";
	`su postgres -c "createdb $dst_db"`;
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
	if ( $src_host ) {
		`su postgres -c "ssh $src_host pg_dump -h $src_host point-one | psql $dst_db"`;
	} else {
		`su postgres -c "pg_dump $src_db | psql $dst_db"`;
	} # end if
	print "done\n";

} # end if

`chmod +x $lib_path/tools/db_update.pl`;
print "upgrading structures 2...";
`$lib_path/tools/db_update.pl $dst_db point-one point-one > /tmp/db_update.log` or $log->error($!);
print "upgrading signatures...";
`$lib_path/tools/update_p1_signatures.pl $dst_db point-one point-one >> /tmp/db_update.log` or $log->error($!);
print "done\n";
print 'Turning off backups...';
$dbh = sql::open_sql( $log, ('database'=>$dst_db, 'driver'=>'Pg','login'=>'point-one', 'password'=>'point-one') );
my ( $version, $updated_on, $backup ) = sql::execute( undef, undef, q{SELECT version,updated_on, backup FROM database_info ORDER BY updated_on DESC LIMIT 1} );
sql::insert( undef, undef, 'database_info', 'version', $version+1, 'backup', 'false' );
print "done\n";

foreach my $Service ( openprint::Service::find('name'=>'Imposition') ) {
	foreach my $Price ( $Service->prices() ) {
		if ( $Price->units() eq 'Per Page' ) {
			$Price->units('Per Imposition');
			$Price->save();
		} # end if
	} # end foreach
} # end foreach

if ( 0 ) {
sql::update( undef, undef, 'Configuration', ['name=?', 'Press Run Overs Rate'], 'name','MakeReady Overs Rate' );
foreach my $E ( openprint::Equipment::find('strid'=>'Web1') ) {
	foreach my $Spec ( $E->Specifications() ) {
		next if $Spec->name() ne 'Press Run Overs';
		if ( $Spec->value() != 0.05 ) {
			$Spec->delete();
			next;
		} else {
			$Spec->min(undef);
			$Spec->max(undef);
			$Spec->interpolate(0);
			$Spec->save();
		} # end if
	} # end foreach
} # end foreach
}
if ( 0 ) {
new openprint::ProjectType_Template()->save({
	'projecttype_id'	=>	1,
	'type'				=>	'Unbound',
	'description'		=>	'5.375 x 8.375 Finished',
	'finished_width'	=>	5.375,
	'finished_height'	=>	8.375,
	'flat_width'		=>	10.75,
	'flat_height'		=>	8.375,
});
new openprint::ProjectType_Template()->save({
	'projecttype_id'	=>	1,
	'type'				=>	'Unbound',
	'description'		=>	'5.5 x 8.5 Finished',
	'finished_width'	=>	5.5,
	'finished_height'	=>	8.5,
	'flat_width'		=>	11,
	'flat_height'		=>	8.5,
});
new openprint::ProjectType_Template()->save({
	'projecttype_id'	=>	1,
	'type'				=>	'Unbound',
	'description'		=>	'8.5 x 11 Finished',
	'finished_width'	=>	8.5,
	'finished_height'	=>	11,
	'flat_width'		=>	17,
	'flat_height'		=>	11,
});
}
$dbh->disconnect();
