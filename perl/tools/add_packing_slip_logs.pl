#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Project;
require openprint::Label;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'warn' );

$openprint::Object::no_cache = 1;
$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2]) );
	
foreach my $L ( openprint::Label::find() ) {
	if ( $L->docket() ) {
		foreach my $P ( openprint::Project::find('docket'=>$L->docket() ) ) {
		  sql::insert( undef, undef, 'Project_Log',[
					'project_id',   $$P{'id'},
					'dtmTimestamp', $L->created_on(),
					'company_id',   6,
					'user_id',      1085,
					'description',  'Added Label/Packing Slip',
					] );
		} # end foreach P
	} # end if

} # end foreach Label


$dbh->disconnect();
1;
__END__
