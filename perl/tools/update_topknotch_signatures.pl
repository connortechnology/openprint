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
$sql_server{'database'} = 'topknotch';
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = 'topknotch';
$sql_server{'password'} = 'topknotch';

$dbh = sql::open_sql( $log, %sql_server );
