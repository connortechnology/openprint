#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Company;

use openprint ();
use vars qw( $log $dbh %session );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;
$session{'user_id'} = 1085;

$log = new logger( 'debug' );

$openprint::Object::no_cache = 1;
$dbh = sql::open_sql( $log, ('database'=> 'penultima', 'driver'=>'Pg',login=>'penultima', 'password'=>'penultima', host=>'database' ) );
die if ! $dbh;

my $Company = openprint::Company->find_one(name=>'ConnorTechnology');
$Company->save();

$dbh->disconnect();
1;
__END__
