#!/usr/bin/perl
use strict;
my $lib_path = '/var/www/testing/perl';
use lib '/var/www/testing/perl';
use Date::Calc;
require sql;
require logger;
require openprint::Object;
require configuration;
require openprint::Service;
require openprint::Location;
require openprint::Equipment;
require openprint::ServiceType_Category;

use openprint ();
use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;


$log = new logger( 'warn' );

my ( $src_db, $dst_db, $path ) = @ARGV;
$src_db = 'point-one' if ! $src_db;
$dst_db = 'point-one' if ! $dst_db;
`/etc/init.d/apache2 reload`;

if ( 0 ) {
if ( ! $path ) {
	my ( $year, $month, $day ) = Date::Calc::Add_Delta_Days( Date::Calc::Today(), -1 );
	$path = "/media/ARCHIVE/Backups/database/$src_db/$year-$month-$day.sql.bz2";

	if ( ! -e $path ) {
		die "No db dump $path";
	}
	print "Dropping db...";
	`su postgres -c "dropdb $dst_db"`;
	print "done\n";
	print "Create db...";
	`su postgres -c "createdb $dst_db"`;
	print "done\n";
	print "Loading db... from $path";
	`su postgres -c "bunzip2 < $path | pg_restore -Fc -d $dst_db"`;
	print "done\n";
} else {
#grab direclty
	print "Dropping db...";
	`su postgres -c "dropdb $dst_db"`;
	print "done\n";
	print "Create db...";
	`su postgres -c "createdb -E UTF8 $dst_db"`;
	print "done\n";
	print "Loading db... directly";
	`su postgres -c "bunzip2 < $path | pg_restore -Fc -d $dst_db"`;
	#if ( $src_host ) {
		#`su postgres -c "ssh $path pg_dump point-one | psql $dst_db"`;
	#} else {
		#`su postgres -c "pg_dump $src_db | psql $dst_db"`;
	#} # end if
	print "done\n";

} # end if
} # end if

`chmod +x $lib_path/tools/db_update.pl`;
print "upgrading structures 1...\n";
`$lib_path/tools/db_update.pl $dst_db point-one point-one ` or $log->error($!);
print "upgrading folding...\n";
`$lib_path/tools/fold_update.pl $dst_db point-one point-one ` or $log->error($!);
print "upgrading structures 2...\n";
`$lib_path/tools/db_update2.pl $dst_db point-one point-one ` or $log->error($!);
print "upgrading structures 3...\n";
`$lib_path/tools/db_update3.pl $dst_db point-one point-one ` or $log->error($!);
print "upgrading signatures...";
`$lib_path/tools/update_p1_signatures.pl $dst_db point-one point-one ` or $log->error($!);
`$lib_path/tools/do_p1_upgrade.pl $dst_db point-one point-one ` or $log->error($!);
print "done\n";
print 'Turning off backups...';
$dbh = sql::open_sql( $log, ('database'=>$dst_db, 'driver'=>'Pg','login'=>'point-one', 'password'=>'point-one') );
configuration::init( $log, $dbh );
my ( $version, $updated_on, $backup ) = sql::execute( undef, undef, q{SELECT version,updated_on, backup FROM database_info ORDER BY updated_on DESC LIMIT 1} );
#sql::insert( undef, undef, 'database_info', 'version', $version+1, 'backup', 'false' );
print "done\n";
map { $_->save({type=>'place'}) } openprint::Location->find(name=>['POGI','Metro','Missing','Trigistrix', 'On Order']);

if ( 0 ) {
foreach my $Project ( openprint::Project->find('created_on >'=>sprintf('%.4d-%.2d-%.2d 00:00:00', Date::Calc::Add_Delta_Days( Date::Calc::Today(), '7 days') ) ) ) {
	my @qtys = $Project->quantities();
	$Project->recalculate();
	foreach my $qty_index ( $Project->quantity_indexes() ) {
		if ( ($Project->quantity($qty_index) < $qtys[$qty_index-1]-10) or ( $Project->quantity($qty_index)>$qtys[$qty_index-1]+10) ) {
			print 'Project: '.$Project->id().' has changed by more than $10'."\n";
		} # end if
	} # end foreach qty_index
} # end foreach Project
}
$dbh->disconnect();
#`/etc/init.d/postgresql restart`;
#`su postgres -c /usr/lib/postgresql/9.1/bin/vacuumdb`;
0;
__END__
