#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use Date::Calc;
require sql;
require logger;
use strict;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'warn' );
`/etc/init.d/apache2 reload`;
my ( $year, $month, $day ) = @ARGV;
( $year, $month, $day ) = Date::Calc::Add_Delta_Days( Date::Calc::Today(), -1 ) if ! $year;
if ( ! -e "/tmp/topknotch-$year-$month-$day.sql.bz2" ) {
print "scp topknotch.com:/media/Storage/Backups/Database/topknotch/$year-$month-$day.sql.bz2 /tmp/topknotch-$year-$month-$day.sql.bz2";
`su postgres -c "scp topknotch.com:/media/Storage/Backups/Database/topknotch/$year-$month-$day.sql.bz2 /tmp/topknotch-$year-$month-$day.sql.bz2"`;
}
print "dropdb topknotch";
`su postgres -c "dropdb topknotch"`;
print "createdb topknotch";
`su postgres -c "createdb -E SQL_ASCII topknotch"`;
`su postgres -c "bunzip2 < /tmp/topknotch-$year-$month-$day.sql.bz2 | psql topknotch"`;

my %sql_server;
$sql_server{'database'} = 'topknotch';
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = 'topknotch';
$sql_server{'password'} = 'topknotch';

$dbh = sql::open_sql( $log, %sql_server );
#sql::update(undef,undef,'tbl_equipment', ['strid=?','Komori8Perfector'], 'useinestimating', 1 );
`chmod +x /etc/apache2/lib/perl/tools/db_update.pl`;
`/etc/apache2/lib/perl/tools/db_update.pl topknotch topknotch topknotch`;
my ( $version, $updated_on, $backup ) = sql::execute( undef, undef, q{SELECT version,updated_on, backup FROM database_info ORDER BY updated_on DESC LIMIT 1} );

sql::insert(undef,undef,'database_info','version'=>$version,'backup'=>'false');

