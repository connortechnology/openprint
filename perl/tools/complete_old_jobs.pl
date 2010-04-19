#!/usr/bin/perl
use lib '/var/www/p1/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Company;
require openprint::User;
require openprint::Project;
require openprint::Quote;
require openprint::Order;

use openprint ();
use vars qw( $log $dbh %session );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;
@session{'company_id','user_id'} = ( 6, 1085 );

$log = new logger( 'warn' );

$openprint::Object::no_cache = 1;
$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>$ARGV[3]) );
	
foreach my $Project ( openprint::Project::find( 'status'=>'In Prepress', 'updated_on_<='=>sprintf('%.4d-%.2d-%.2d 00:00:00', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -30 ) ), 'order'=>'index desc' ) ) {
	
	print $Project->id() . ' ' . $Project->Company()->name() . ' ' . $Project->updated_on() . ' ' . $Project->shippingtype() . "\n";
	if ( my $Job = openprint::ScheduledJob::find_one('project_id'=>$Project->id()) ) {
		if ( $Job->starttime() ) {
			print "Scheduled, skipping " . $Job->starttime() . "\n";
			next;
		} # end if
	} # end if
	if ( $Project->due_date() ) {
		next;
	} # end if
	#if ( $Project->shippingtype() eq 'CustomerPickup' ) {
		#$Project->status_change(6,1085,'Complete');
	#} elsif ( $Project->shippingtype() eq 'CustomerPickup' ) {
		#$Project->status_change(6,1085,'e');
	#} else {
		$Project->status_change(6,1085,'Complete');
	#} # end if
	
} # end foreach Product
$dbh->disconnect();
1;
__END__
