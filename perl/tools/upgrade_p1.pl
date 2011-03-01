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
require openprint::Equipment;

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

if ( ! $path ) {
	my ( $year, $month, $day ) = Date::Calc::Add_Delta_Days( Date::Calc::Today(), -1 );

	if ( ! -e "/media/Storage/Backups/www4/$src_db/$year-$month-$day.sql.bz2" ) {
		print "Getting db backup $year-$month-$day\n";
	} # end if
	if ( ! -e "/media/Storage/Backups/www4/$src_db/$year-$month-$day.sql.bz2" ) {
		die "No db dump /tmp/$src_db-$month-$day-$year.sql.bz2";
	}
	print "Dropping db...";
	`su postgres -c "dropdb $dst_db"`;
	print "done\n";
	print "Create db...";
	`su postgres -c "createdb $dst_db"`;
	print "done\n";
	print "Loading db... from /media/Storage/Backups/www4/$src_db/$year-$month-$day.sql.bz2";
	`su postgres -c "bunzip2 < /media/Storage/Backups/www4/$src_db/$year-$month-$day.sql.bz2 | psql $dst_db"`;
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
	`su postgres -c "bunzip2 < $path | psql $dst_db"`;
	#if ( $src_host ) {
		#`su postgres -c "ssh $src_host pg_dump -h $src_host point-one | psql $dst_db"`;
	#} else {
		#`su postgres -c "pg_dump $src_db | psql $dst_db"`;
	#} # end if
	print "done\n";

} # end if

`chmod +x $lib_path/tools/db_update.pl`;
print "upgrading structures 2...";
`$lib_path/tools/db_update.pl $dst_db point-one point-one > /tmp/db_update.log` or $log->error($!);
`$lib_path/tools/db_update2.pl $dst_db point-one point-one > /tmp/db_update.log` or $log->error($!);
print "upgrading signatures...";
`$lib_path/tools/update_p1_signatures.pl $dst_db point-one point-one >> /tmp/db_update.log` or $log->error($!);
print "done\n";
print 'Turning off backups...';
$dbh = sql::open_sql( $log, ('database'=>$dst_db, 'driver'=>'Pg','login'=>'point-one', 'password'=>'point-one') );
configuration::init_cache( $log, $dbh );
my ( $version, $updated_on, $backup ) = sql::execute( undef, undef, q{SELECT version,updated_on, backup FROM database_info ORDER BY updated_on DESC LIMIT 1} );
sql::insert( undef, undef, 'database_info', 'version', $version+1, 'backup', 'false' );
print "done\n";

foreach my $Service ( openprint::Service->find('name'=>'Imposition') ) {
	foreach my $Price ( $Service->prices() ) {
		if ( $Price->units() eq 'Per Page' ) {
			$Price->units('Per Imposition');
			$Price->save();
		} # end if
	} # end foreach
} # end foreach

if ( 0 ) {
sql::update( undef, undef, 'Configuration', ['name=?', 'Press Run Overs Rate'], 'name','MakeReady Overs Rate' );
foreach my $E ( openprint::Equipment->find('strid'=>'Web1') ) {
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
	sql::insert( undef, undef, 'configuration', 'name', 'ProjectViewDisclaimer','value','All CTP quotes must include a digital proof.
All prices are subject to the viewing of artwork, film or electronic file.
Please check specifications for accuracy.
Due to technical limitations, perfecting orders may be subject to a revision if it is necessary to run sheetwork.
If administrative changes are required you will be notified prior to production approval.
This quote is valid for 30 days subject to paper price increase and availability.
Heavy ink coverage will be billed as an extra unless indicated.
Quantities of +/- 5% will represent completion of order and will be charged or credited accordingly.
<br/>
<br/>
If you would like to match our press profiles for proofing purposes the ICC profiles can
be found at:<br/>
<br/>
<a href="http://www.idealliance.org/industry_resources/branding_media_and_color/gracol">
http://www.idealliance.org/industry_resources/branding_media_and_color/gracol</a><br/>
<a href="http://files.idealliance.org/GRACoL/ICC/2006%20GRACoL%20&amp;%20SWOP%20Profiles.zip">
http://files.idealliance.org/GRACoL/ICC/2006%20GRACoL%20&amp;%20SWOP%20Profiles.zip</a><br/>'
,'description', 'Disclaimer to show at bottom of project.', 'category','Miscellaneous Settings' ) if ! exists $config{'ProjectViewDisclaimer'};
	sql::insert( undef, undef, 'configuration', 'name', 'OrderViewDisclaimer','value',
'
<div class="Terms">
<h1>Terms and Conditions</h1>
<h2>Please read carefully</h2>
<p>
The following terms and conditions apply to all customer quotations and purchase orders accepted by PointOne Graphics Inc and PointOne Web Inc.
</p>
<fieldset><legend>Acceptance by Customer</legend>
By placing an order for products and services with PointOne, you, the customer, agree to be legally bound by these terms and conditions.
</fieldset>

<fieldset><legend>Pricing</legend>
All prices are quoted in Canadian currency, unless specified otherwise

Prices quoted will include federal and provincial sales taxes

Prices quoted don’t include shipping costs unless itemized in quote; you will be responsible for paying all shipping and handling charges and customs duties or fees if applicable.
</fieldset>
<fieldset><legend>Quotation</legend>
Quotations are only valid (30) days from the date of the quotation. Quotations are based on the cost of production prevailing at the date of quotation, and are subject to variation on or after acceptance of any order to meet any rise or fall in such costs. Quotations are also based on the accuracy of the specifications provided by you (customer), they are subject to change if artwork, plates, disks or other input materials do not conform to the information, if happens PointOne will exert reasonable effort to notify Customer of price increase in advance before production starts.
</fieldset>
To confirm your acceptance of PointOne quotation, you must complete and submit a PointOne Purchase Order
 
 All purchase orders are subject to acceptance by PointOne and PointOne reserves the right to reject any purchase order without cause. If your purchase order is accepted, PointOne will issue an order confirmation either in writing or via email.

It is your responsibility to review and verify the accuracy of your purchase order and ensure it is consistent with and conform to your original request for quotation.
</fieldset>
<fieldset><legend>Payment</legend>
PointOne accepts payment by cheque, wire transfer, bank draft and most popular credit cards. If payment is made by credit card, it must be processed withing 10 days of invoice date.

C.O.D (Cash on Delivery): order must be paid either by wire transfer, bank draft, certified cheque and/or credit cards in full prior to release of finished printing product from PointOne premises.

PointOne reserves the right to request 50% deposit on C.O.D jobs prior to production.

PointOne Web invoices will not accept credit card payment without prior approval.

PointOne reserves the right to request a 50% deposit on any order over $50,000 prior to production.

All printed products shall remain the property of PointOne until they are paid in full.
PointOne reserves the right to charge 2% per month on invoices dated more than 45 days.
</fieldset>
<fieldset><legend>Changes &amp; Additional Charges</legend>
PointOne will notify you of any additional charges for time and materials in the event your order is modified during the production process.

PointOne may at its discretion propose modifications to the size and/or specifications of your order in efforts to avoid excess waste and / or improve the final product of your order.

Unless indicated in your quotation the following may be added to your order as an additional charge:
Heavy ink coverage and/or print jobs requiring more ink and longer drying times
Die and Litho
Additional press time
Any necessary sheetwork

</fieldset>
<fieldset><legend>Cancellations</legend>
Cancellations will not be accepted after PointOne has issued and sent order confirmation. PointOne reserves the right to charge you for all cost incurred as a result of cancellation subsequently.
</fieldset>
<fieldset><legend>Complaints, Refunds &amp; Credits</legend>
All complaints must be reported to PointOne in writing within 5 business days from date of delivery or pick up of finished printing materials from PointOne premises. PointOne will investigate and respond to the complaint which may or may not result to a refund or credit depending on the findings of the investigation.

Refunds and credits are provided at PointOne’s sole discretion and will only be considered if you return your printed product to PointOne within 7 business days after notifying PointOne of your complaints as prescribed above.
</fieldset>
<fieldset><legend>Errors and Omissions</legend>
You must sign-off on all final proofs before the printing process commences. Under no circumstance will PointOne be responsible for any errors or omissions overlooked during the proofing process.
</fieldset>
<fieldset><legend>Proofing, Colour Matching & Print Quality</legend>
All reasonable efforts shall be made to obtain the best possible colour reproduction on final printed products but variation is inherit in the print process. It is understood and accepted as reasonable that PointOne Shall not be required to guarantee an exact match in colour or texture between the customer’s photograph, transparency, proof, electronic graphics file, previously printed matter (whether printed by PointOne or external subcontracting) or any materials supplied by the customer and the customer’s final printed product.

All print jobs require at the minimum a digital Dylex proof.

All supplied plates must have a contract proof and cut/folded mockup.

Scoring price shall mean folder scoring only.
</fieldset>
<fieldset><legend>Press Approvals</legend>
Press approvals are available upon request and limited to 20 minutes. While PointOne will try to accommodate customer availability when scheduling press approval, scheduling cannot be guaranteed. Under no circumstance shall PointOne be held liable for any loss incurred as a result of any press approval delay or cancellation.

If you decline the press approval stage PointOne will proceed to print to standard ink densities where applicable.

</fieldset>
<fieldset><legend>Over-Runs or Under-Runs</legend>
You agree to accept 5% over-run or 5%under-run of ordered quantities. PointOne will bill or credit you accordingly for any quantities beyond this tolerance limit.
</fieldset>
<fieldset><legend>Delivery &amp; Shipping</legend>
Any period or date for delivery of goods or provision of services is intended as an estimate only and is not a contractual commitment. While PointOne will make every effort to meet its estimated delivery times, under no circumstances will PointOne be liable for any costs or damages resulting from delay.

PointOne will deliver products according to your shipping instructions. Delays or damages during shipping process are sole responsibility of the carrier providing delivery services. PointOne is not responsible for delays or damages caused during shipping.

</fieldset>
<fieldset><legend>Archival of Customer Work</legend>
PointOne assumes no responsibility for the archival of customer orders, electronic or otherwise.


</fieldset>
<fieldset><legend>Failure to Retrieve Completed Order</legend>
Where you fail to collect an order within (45) business days from notification of completion of the order, PointOne shall be entitled, at its discretion, to either store the order until actual delivery or collection is made and charge you for the costs (including insurance) of storage or to destroy the order (provided that you shall nevertheless remain liable for payment in respects of the order).

PointOne assumes no responsibility for any artwork, plates, disks or other input materials that you may provide in connection with an order (7) business days after completion of an order.
</fieldset>
<fieldset><legend>Limitation of Liability</legend>
PointOne shall not be liable for any indirect, special or consequential damages, loss of profits, economic loss, loss of goodwill or loss of anticipated savings or loss of data. The total aggregate liability of PointOne in respect of any and all causes of action arising out of or in connection with a customer’s order and PointOne’s performance of services pursuant to such order (weather for breach of contract, strict liability, tort (including, without limitation, negligence), misrepresentation or otherwise) shall be limited to the sums paid to PointOne by the customer in respect of the order pursuant to which liability has arisen.
</fieldset>
<fieldset><legend>Indemnity</legend>

You agree to indemnify and hold harmless PointOne from any claim, loss, expense, and /or damages arising out of the violation of copyright or trademark laws from the illegal use of images, photographs, slogans, trademarks, or graphical work supplied by you.
</fieldset>
<fieldset><legend>Force Majeure</legend>
PointOne shall not be liable for any losses or damages, and shall be excused from any delay or failure in performance hereunder, caused by any labour dispute or disturbances, governmental order or requirements, acts of God, casualty, disaster, inability to secure materials and transportation facilities, wars and other civil disturbances, and other circumstances beyond its control including the failure of its supplier(s) and/or subcontractors to perform.
</fieldset>
<fieldset><legend>Governing Law and Jurisdiction</legend>
These terms and conditions shall be interpreted under and governed by the laws in the Province Ontario.
</fieldset>
','description', 'Disclaimer to show at bottom of an order.', 'category','Miscellaneous Settings' ) if ! exists $config{'OrderViewDisclaimer'};
	sql::insert( undef, undef, 'configuration', 'name', 'QuoteViewDisclaimer','value',
'
<div class="Terms">
<h1>Terms and Conditions</h1>
<h2>Please read carefully</h2>
<p>
The following terms and conditions apply to all customer quotations and purchase orders accepted by PointOne Graphics Inc and PointOne Web Inc.
</p>
<fieldset><legend>Acceptance by Customer</legend>
By placing an order for products and services with PointOne, you, the customer, agree to be legally bound by these terms and conditions.
</fieldset>

<fieldset><legend>Pricing</legend>
All prices are quoted in Canadian currency, unless specified otherwise

Prices quoted will include federal and provincial sales taxes

Prices quoted don’t include shipping costs unless itemized in quote; you will be responsible for paying all shipping and handling charges and customs duties or fees if applicable.
</fieldset>
<fieldset><legend>Quotation</legend>
Quotations are only valid (30) days from the date of the quotation. Quotations are based on the cost of production prevailing at the date of quotation, and are subject to variation on or after acceptance of any order to meet any rise or fall in such costs. Quotations are also based on the accuracy of the specifications provided by you (customer), they are subject to change if artwork, plates, disks or other input materials do not conform to the information, if happens PointOne will exert reasonable effort to notify Customer of price increase in advance before production starts.
</fieldset>
To confirm your acceptance of PointOne quotation, you must complete and submit a PointOne Purchase Order
 
 All purchase orders are subject to acceptance by PointOne and PointOne reserves the right to reject any purchase order without cause. If your purchase order is accepted, PointOne will issue an order confirmation either in writing or via email.

It is your responsibility to review and verify the accuracy of your purchase order and ensure it is consistent with and conform to your original request for quotation.
</fieldset>
<fieldset><legend>Payment</legend>
PointOne accepts payment by cheque, wire transfer, bank draft and most popular credit cards. If payment is made by credit card, it must be processed withing 10 days of invoice date.

C.O.D (Cash on Delivery): order must be paid either by wire transfer, bank draft, certified cheque and/or credit cards in full prior to release of finished printing product from PointOne premises.

PointOne reserves the right to request 50% deposit on C.O.D jobs prior to production.

PointOne Web invoices will not accept credit card payment without prior approval.

PointOne reserves the right to request a 50% deposit on any order over $50,000 prior to production.

All printed products shall remain the property of PointOne until they are paid in full.
PointOne reserves the right to charge 2% per month on invoices dated more than 45 days.
</fieldset>
<fieldset><legend>Changes &amp; Additional Charges</legend>
PointOne will notify you of any additional charges for time and materials in the event your order is modified during the production process.

PointOne may at its discretion propose modifications to the size and/or specifications of your order in efforts to avoid excess waste and / or improve the final product of your order.

Unless indicated in your quotation the following may be added to your order as an additional charge:
Heavy ink coverage and/or print jobs requiring more ink and longer drying times
Die and Litho
Additional press time
Any necessary sheetwork

</fieldset>
<fieldset><legend>Cancellations</legend>
Cancellations will not be accepted after PointOne has issued and sent order confirmation. PointOne reserves the right to charge you for all cost incurred as a result of cancellation subsequently.
</fieldset>
<fieldset><legend>Complaints, Refunds &amp; Credits</legend>
All complaints must be reported to PointOne in writing within 5 business days from date of delivery or pick up of finished printing materials from PointOne premises. PointOne will investigate and respond to the complaint which may or may not result to a refund or credit depending on the findings of the investigation.

Refunds and credits are provided at PointOne’s sole discretion and will only be considered if you return your printed product to PointOne within 7 business days after notifying PointOne of your complaints as prescribed above.
</fieldset>
<fieldset><legend>Errors and Omissions</legend>
You must sign-off on all final proofs before the printing process commences. Under no circumstance will PointOne be responsible for any errors or omissions overlooked during the proofing process.
</fieldset>
<fieldset><legend>Proofing, Colour Matching & Print Quality</legend>
All reasonable efforts shall be made to obtain the best possible colour reproduction on final printed products but variation is inherit in the print process. It is understood and accepted as reasonable that PointOne Shall not be required to guarantee an exact match in colour or texture between the customer’s photograph, transparency, proof, electronic graphics file, previously printed matter (whether printed by PointOne or external subcontracting) or any materials supplied by the customer and the customer’s final printed product.

All print jobs require at the minimum a digital Dylex proof.

All supplied plates must have a contract proof and cut/folded mockup.

Scoring price shall mean folder scoring only.
</fieldset>
<fieldset><legend>Press Approvals</legend>
Press approvals are available upon request and limited to 20 minutes. While PointOne will try to accommodate customer availability when scheduling press approval, scheduling cannot be guaranteed. Under no circumstance shall PointOne be held liable for any loss incurred as a result of any press approval delay or cancellation.

If you decline the press approval stage PointOne will proceed to print to standard ink densities where applicable.

</fieldset>
<fieldset><legend>Over-Runs or Under-Runs</legend>
You agree to accept 5% over-run or 5%under-run of ordered quantities. PointOne will bill or credit you accordingly for any quantities beyond this tolerance limit.
</fieldset>
<fieldset><legend>Delivery &amp; Shipping</legend>
Any period or date for delivery of goods or provision of services is intended as an estimate only and is not a contractual commitment. While PointOne will make every effort to meet its estimated delivery times, under no circumstances will PointOne be liable for any costs or damages resulting from delay.

PointOne will deliver products according to your shipping instructions. Delays or damages during shipping process are sole responsibility of the carrier providing delivery services. PointOne is not responsible for delays or damages caused during shipping.

</fieldset>
<fieldset><legend>Archival of Customer Work</legend>
PointOne assumes no responsibility for the archival of customer orders, electronic or otherwise.


</fieldset>
<fieldset><legend>Failure to Retrieve Completed Order</legend>
Where you fail to collect an order within (45) business days from notification of completion of the order, PointOne shall be entitled, at its discretion, to either store the order until actual delivery or collection is made and charge you for the costs (including insurance) of storage or to destroy the order (provided that you shall nevertheless remain liable for payment in respects of the order).

PointOne assumes no responsibility for any artwork, plates, disks or other input materials that you may provide in connection with an order (7) business days after completion of an order.
</fieldset>
<fieldset><legend>Limitation of Liability</legend>
PointOne shall not be liable for any indirect, special or consequential damages, loss of profits, economic loss, loss of goodwill or loss of anticipated savings or loss of data. The total aggregate liability of PointOne in respect of any and all causes of action arising out of or in connection with a customer’s order and PointOne’s performance of services pursuant to such order (weather for breach of contract, strict liability, tort (including, without limitation, negligence), misrepresentation or otherwise) shall be limited to the sums paid to PointOne by the customer in respect of the order pursuant to which liability has arisen.
</fieldset>
<fieldset><legend>Indemnity</legend>

You agree to indemnify and hold harmless PointOne from any claim, loss, expense, and /or damages arising out of the violation of copyright or trademark laws from the illegal use of images, photographs, slogans, trademarks, or graphical work supplied by you.
</fieldset>
<fieldset><legend>Force Majeure</legend>
PointOne shall not be liable for any losses or damages, and shall be excused from any delay or failure in performance hereunder, caused by any labour dispute or disturbances, governmental order or requirements, acts of God, casualty, disaster, inability to secure materials and transportation facilities, wars and other civil disturbances, and other circumstances beyond its control including the failure of its supplier(s) and/or subcontractors to perform.
</fieldset>
<fieldset><legend>Governing Law and Jurisdiction</legend>
These terms and conditions shall be interpreted under and governed by the laws in the Province Ontario.
</fieldset>
'
,'description', 'Disclaimer to show at bottom of a quote.', 'category','Miscellaneous Settings' ) if ! exists $config{'QuoteViewDisclaimer'};
	sql::insert( undef, undef, 'configuration', 'name', 'RegistrationRequiredFields','value',
'company_name,firstname,lastname,email,Captcha,address1,country,state,city,postalcode,phone,password,verifypassword',
'category','Required Fields', 'description', 'Comma-separated list of fields on the registration page which must be filled in.');
	sql::update( undef, undef, 'tbl_equipment_specifications', [ 'strname=?', 'Press Standard Run Speed'], 'strname','Run Speed' );
	sql::execute( undef, undef, "delete from tbl_equipment_specifications WHERE lngequipmentindex=28 and strname='Press Additional Run Speed'" );
	sql::update( undef, undef, 'tbl_equipment_specifications', [ 'strname=?', 'Press Additional Run Speed' ], 'strname','Run Speed' );
	sql::insert( undef, undef, 'tbl_equipment_specifications', 'lngequipmentindex', 1, 'strname','Run Speed', 'dblmin', 0.0031, 'dblmax', 0.0120, 'strvalue', 9000, 'interpolate', 0, 'strunits', 'Calliper' );
	sql::insert( undef, undef, 'tbl_equipment_specifications', 'lngequipmentindex', 4, 'strname','Run Speed', 'dblmin', 0.0029, 'dblmax', 0.0099, 'strvalue', 9000, 'interpolate', 0, 'strunits', 'Calliper' );
	sql::insert( undef, undef, 'tbl_equipment_specifications', 'lngequipmentindex', 27, 'strname','Run Speed', 'dblmin', 0.0029, 'dblmax', 0.0099, 'strvalue', 9000, 'interpolate', 0, 'strunits', 'Calliper' );
	sql::insert( undef, undef, 'tbl_equipment_specifications', 'lngequipmentindex', 25, 'strname','Run Speed', 'dblmin', 0.0029, 'dblmax', 0.0099, 'strvalue', 9000, 'interpolate', 0, 'strunits', 'Calliper' );
	sql::insert( undef, undef, 'tbl_equipment_specifications', 'lngequipmentindex', 30, 'strname','Run Speed', 'dblmin', 0.0029, 'dblmax', 0.0099, 'strvalue', 9000, 'interpolate', 0, 'strunits', 'Calliper' );
my ( $version, $updated_on, $backup ) = sql::execute( undef, undef, q{SELECT version,updated_on, backup FROM database_info ORDER BY updated_on DESC LIMIT 1} );
sql::insert(undef, undef, 'database_info', 'version', $version+1, 'updated_on', 'NOW()', 'backup', 0 );
$dbh->disconnect();
