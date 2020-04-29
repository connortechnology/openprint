#!/usr/bin/perl
use lib '/var/www/testing/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Company;
require openprint::User;
require openprint::Project;

use openprint ();
use vars qw( $log $dbh %session );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;
@session{'company_id','user_id'} = ( 6, 1085 );

$log = new logger( 'warn' );

$openprint::Object::no_cache = 1;
$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>$ARGV[3]) );
	
foreach my $Project ( openprint::Project->find( order=>'id desc',
			status=>['In Prepress','Proofs Out', 'Waiting For Customer Approval','Waiting For QA Approval','Approved','Printed','Pending Deposit'],
			'created_on <='=>'2017-12-31 23:59:59' ) ) {
#sprintf('%.4d-%.2d-%.2d 00:00:00', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -30 ) ), 'order'=>'index desc' ) ) {
	
	print $Project->id() . ' status:'.$Project->status().' company:' . $Project->Company()->name() . ' ' . $Project->updated_on() . ' ' . $Project->shippingtype() . " " . $Project->due_date() . "\n";
	if ( openprint::ScheduledJob->find(project_id=>$Project->id(),'starttime is null'=>0) ) {
			print "Scheduled, skipping \n";
			next;
	} # end if
	
	#if ( $Project->due_date() ) {
		#next;
	#} # end if
	if ( $Project->shippingtype() eq 'CustomerPickup' ) {
		$Project->status_change(6,1085,'PickedUp');
	} elsif ( $Project->shippingtype() eq 'Delivery' ) {
		$Project->status_change(6,1085,'Shipped');
	} else {
		$Project->status_change(6,1085,'Complete');
	} # end if
	sleep 1;
	
} # end foreach Product
$dbh->disconnect();
1;
__END__
