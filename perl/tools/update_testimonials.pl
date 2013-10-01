#!/usr/bin/perl
use strict;
use lib '/var/www/testing/perl';
require sql;
require logger;
require openprint::Object;
require openprint::Article;
require openprint::User;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'warn' );
my %sql_server;
$sql_server{'database'} = $ARGV[0];
$sql_server{'database'} = 'topknotch' if ! $sql_server{'database'};
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = $ARGV[1];
$sql_server{'login'} = $sql_server{'database'} if ! $sql_server{'login'};
$sql_server{'password'} = $ARGV[2];
$sql_server{'password'} = $sql_server{'login'} if ! $sql_server{'password'};

$openprint::Object::no_cache = 1;
my $projects_count = 100;
my $project_id = 0;
my $company_id = 1;

$dbh = sql::open_sql( $log, %sql_server );
my $User = openprint::User->find_one(email=>'amin@topknotch.com');
die 'No User' if ! $User;

my $ac = sql::start_transaction( $dbh );

my @data = sql::execute( undef, undef, 'SELECT id,text FROM testimonials' );
while ( my ( $id, $text ) = splice @data, 0, 2 ) {
	my $Article = new openprint::Article();
	$_ = $Article->save({category=>'Testimonials', body=>$text, created_by=>$$User{id}, company_id=>$$User{company_id} });
	if ( $_ ) {
		$dbh->rollback();
		die $_;
	} # end if
} # end while
sql::end_transaction( $dbh, $ac );
$dbh->disconnect();
	
1;
__END__
