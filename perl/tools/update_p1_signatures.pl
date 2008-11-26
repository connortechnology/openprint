#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use Date::Calc;
use strict;
require sql;
require logger;
require openprint::Object;
require openprint::Project;
require openprint::service;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'debug' );
my %sql_server;
$sql_server{'database'} = $ARGV[0];
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = 'point-one';
$sql_server{'password'} = 'point-one';

$openprint::Object::no_cache = 1;

$dbh = sql::open_sql( $log, %sql_server );
my @projects;

sql::update( undef, undef, 'tbl_Equipment_SPecifications', ['strvalue=?',9.488], 'strvalue',37.952);
sql::update( undef, undef, 'tbl_Equipment_SPecifications', ['strvalue=?',9.528], 'strvalue',37.952);
sql::update( undef, undef, 'tbl_Equipment_SPecifications', ['strvalue=?',4.724], 'strvalue',18.896);
sql::update( undef, undef, 'tbl_Equipment_SPecifications', ['strvalue=?',7.598], 'strvalue',37.990);
sql::update( undef, undef, 'tbl_Equipment_SPecifications', ['strvalue=?',7.598], 'strvalue',37.990);

