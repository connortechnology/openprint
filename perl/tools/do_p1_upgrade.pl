#!/usr/bin/perl
use strict;
my $lib_path = '/var/www/testing/perl';
use lib '/var/www/testing/perl';
require sql;
require logger;
require openprint::Object;
require configuration;
require openprint::Service;
require openprint::Fold;
require openprint::FoldSpecification;
require openprint::Equipment;
require openprint::EquipmentSpecification;
require openprint::ServiceType_Category;
require openprint::ProjectType;
require openprint::SRED_Asset;
require openprint::Claim_Asset;
require openprint::Object_Asset;

use openprint ();
use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;


$log = new logger( 'debug' );

my $dst_db = 'point-one';

$dbh = sql::open_sql( $log, ('database'=>$dst_db, 'driver'=>'Pg','login'=>'point-one', 'password'=>'point-one') );
configuration::init( $log, $dbh );

my $BrochureType = openprint::ProjectType->find_one('name'=>'Brochures');
if ( $BrochureType ) {
	my $need_update = 0;
	foreach my $PT ( openprint::ProjectType_Template->find( 'projecttype_id'=>$BrochureType->id(), 'type'=>'8PageSignatureFold') ) {
		$_ = $PT->save({'type'=>'8 Page Fold'});
		$log->error($_) if $_;
	$need_update = 1;
	}
	if ( $need_update ) {
	sql::update( undef, undef, 'tbl_service_specifications', [ 'strvalue=?', '8PageSignatureFold' ], 'strvalue', '8 Page Fold' );
	} # end if

	my %templates = (
		'NoFold' => 'No Fold',
		'2PanelFold' => '2 Panel Fold',
		'3PanelFold' => '3 Panel Fold',
		'3PanelZFold' => '3 Panel Z Fold',
		'4PanelFold' => '4 Panel Fold',
		'4PanelZFold' => '4 Panel Z Fold',
		'5PanelFold' => '5 Panel Fold',
		'5PanelZFold' => '5 Panel Z Fold',
		'6PanelFold' => '6 Panel Fold',
		'6PanelZFold' => '6 Panel Z Fold',
		'8PageFold' => '8 Page Fold',
		'12pg3PanelRollFold' => '12pg 3 Panel Roll',
		'12pg3PanelZFold' => '12pg 3 Panel Z',
		'DoubleGateFold' => 'Double Gate Fold',
		'SingleGateFold' => 'Single Gate Fold',
		'AdditionalFoldTypes'	=>	'Additional Fold Types',
	);
	foreach my $key ( keys %templates ) {
		sql::update( $log, undef, 'projecttemplate', [ 'type=?', $key ], 'name', $templates{$key} );
	}

} else {
	$log->error("No Brochures");
	die;
}
if ( 1 ) {
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
	sql::insert( undef, undef, 'configuration', 'name', 'SimpleButtons','value','Y', 'category'=>'Miscellaneous Settings', 'type'=>'yes/no', 'description'=>'SimpleButtons: When true, will use a simple anchor tag instead of one with left right and centre sections. This reduces page size and speeds up rendering.') if ! $config{SimpleButtons};
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
'category','Required Fields', 'description', 'Comma-separated list of fields on the registration page which must be filled in.') if ! $config{'RegistrationRequiredFields'};

my ( $version, $updated_on, $backup ) = sql::execute( undef, undef, q{SELECT version,updated_on, backup FROM database_info ORDER BY updated_on DESC LIMIT 1} );
sql::insert(undef, undef, 'database_info', 'version', $version+1, 'updated_on', 'NOW()', 'backup', 0 );



	if ( my $STC = openprint::ServiceType_Category->find_one( 'name'=>'Printing','sorting'=>undef ) ) {
		$STC->save({'sorting'=>1}) if ! $STC->sorting();
	} # end if
	if ( my $STC = openprint::ServiceType_Category->find_one( 'name'=>'Prepress','sorting'=>undef ) ) {
		$STC->save({'sorting'=>3}) if ! $STC->sorting();
	} # end if
	if ( my $STC = openprint::ServiceType_Category->find_one( 'name'=>'Bindery','sorting'=>undef ) ) {
		$STC->save({'sorting'=>4}) if ! $STC->sorting();
	} # end if
	if ( my $STC = openprint::ServiceType_Category->find_one( 'name'=>'Specialty','sorting'=>undef ) ) {
		$STC->save({'sorting'=>5}) if ! $STC->sorting();
	} # end if
	if ( my $STC = openprint::ServiceType_Category->find_one( 'name'=>'Packaging','sorting'=>undef ) ) {
		$STC->save({'sorting'=>6}) if ! $STC->sorting();
	} # end if
	if ( my $STC = openprint::ServiceType_Category->find_one( 'name'=>'Shipping','sorting'=>undef ) ) {
		$STC->save({'sorting'=>7}) if ! $STC->sorting();
	} # end if
	if ( my $STC = openprint::ServiceType_Category->find_one( 'name'=>'Materials','sorting'=>undef ) ) {
		$STC->save({'sorting'=>8}) if ! $STC->sorting();
	} # end if
	if ( my $STC = openprint::ServiceType_Category->find_one( 'name'=>'Custom Services','sorting'=>undef ) ) {
		$STC->save({'sorting'=>10}) if ! $STC->sorting();
	} # end if
foreach my $qty_index ( 1 .. 3 ) {
	if ( !( my $STD = openprint::ServiceType_Default->find_one('name'=>'MatchGrain'.$qty_index, 'servicetype'=>'Signature') ) ) {
		my $STD = new openprint::ServiceType_Default();
		$STD->save({'name'=>'MatchGrain'.$qty_index, 'value'=>'Y', 'servicetype'=>'Signature' });
	} # end if
} # end foreach
$dbh->do(q`DELETE FROM projecttype_defaults where name='rdbAqueousSideOne'`);
$dbh->do(q`DELETE FROM projecttype_defaults where name='rdbAqueousSideTwo'`);
$dbh->do(q`DELETE FROM projecttype_defaults where name='rdbGripHeight'`);
$dbh->do(q`DELETE FROM projecttype_defaults where name='rdbGripWidth'`);
$dbh->do(q`DELETE FROM projecttype_defaults where name='rdbWaxFree'`);
require openprint::ProjectType_Default;
require openprint::ServiceType_Default;
my $ServiceType = openprint::ServiceType->find_one('name'=>'Signature');
if ( ! $ServiceType ) {
	die 'Should have Signature by now';
}
foreach my $Default ( openprint::ProjectType_Default->find('projecttype'=>'Letterhead') ) {
	my $SD = new openprint::ServiceType_Default();
	$SD->save({	
			name			=>	$Default->name(),
			value			=>	$Default->value(),
			projecttype_id	=>	$Default->projecttype_id(),
			servicetype_id	=>	$ServiceType->id(),
			} );
	$Default->destroy();
} # end foreach
foreach my $Default ( openprint::ProjectType_Default->find('projecttype'=>undef) ) {
	if ( ! openprint::ServiceType_Default->find_one('name'=>$Default->name(), 'value'=>$Default->value(), 'projecttype_id'=>$Default->projecttype_id(), 'servicetype_id'=>$ServiceType->id()) ) {
		my $SD = new openprint::ServiceType_Default();
		$SD->save({	
				'name'			=>	$Default->name(),
				'value'			=>	$Default->value(),
				'projecttype_id'=>	$Default->projecttype_id(),
				'servicetype_id'	=>	$ServiceType->id(),
				} );
	} # end if
	$Default->destroy();
} # end foreach
foreach my $D ( openprint::ServiceType_Default->find('name'=>'rdbColourBar','value'=>'') ) {
	$D->destroy();
}
foreach my $D ( openprint::ProjectType_Default->find('projecttype'=>'ScratchPads', 'name'=>'rdbPageQuantity') ) {
	$D->save({'name'=>'PageQuantity'});
}

require openprint::ServiceType_Default;
if ( ! openprint::ServiceType_Default->find_one('name'=>'MatchGrain1') ) {
    (new openprint::ServiceType_Default())->save({'name'=>'MatchGrain1', 'value'=>'Y', 'servicetype'=>'Signature','projecttype'=>'MultiPage'});
    (new openprint::ServiceType_Default())->save({'name'=>'MatchGrain2', 'value'=>'Y', 'servicetype'=>'Signature','projecttype'=>'MultiPage'});
    (new openprint::ServiceType_Default())->save({'name'=>'MatchGrain3', 'value'=>'Y', 'servicetype'=>'Signature','projecttype'=>'MultiPage'});
} # end if
foreach my $Template ( openprint::ProjectType_Template->find(projecttype=>'Posters',type=>'PostersLandscape' ) ) {
	$Template->save({type=>'Landscape'});
}
foreach my $Template ( openprint::ProjectType_Template->find(projecttype=>'Posters',type=>'PostersPortrait' ) ) {
	$Template->save({type=>'Portrait'});
}
sql::update( undef, undef, 'configuration', [ 'name=?', 'Add Default Press Proof' ], 'name', 'Add_Default_Press_Proof' );
sql::update( undef, undef, 'configuration', [ 'name=?', 'Add Default Colour Proof' ], 'name', 'Add_Default_Colour_Proof' );
sql::update( undef, undef, 'configuration', [ 'name=?', 'Add Default Layout Proof' ], 'name', 'Add_Default_Layout_Proof' );
$dbh->do(q`INSERT INTO configuration VALUES ('Small_Asset_Height', NULL, 'text', '', 'Asset Settings');`) if ! $config{Small_Asset_Height};
$dbh->do(q`INSERT INTO configuration VALUES ('Medium_Asset_Height', NULL, 'text', '', 'Asset Settings');`) if ! $config{Medium_Asset_Height};
$dbh->do(q`INSERT INTO configuration VALUES ('Large_Asset_Height', NULL, 'text', '', 'Asset Settings');`) if ! $config{Large_Asset_Height};
$dbh->do(q`INSERT INTO configuration VALUES ('Large_Asset_Width', '800', 'text', '', 'Asset Settings');`) if ! $config{Large_Asset_Width};
$dbh->do(q`INSERT INTO configuration VALUES ('Medium_Asset_Width', '300', 'text', '', 'Asset Settings');`) if ! $config{Medium_Asset_Width};
$dbh->do(q`INSERT INTO configuration VALUES ('Small_Asset_Width', '50', 'text', '', 'Asset Settings');`) if ! $config{Small_Asset_Width};

foreach my $SRED_Asset ( openprint::SRED_Asset->find() ) {
	my $Object_Asset = new openprint::Object_Asset();
	$Object_Asset->save({ object_id=>$SRED_Asset->content_id(), asset_id=>$SRED_Asset->asset_id(), object_type=>'openprint::SRED_Content' });
	$SRED_Asset->delete();
} # end foreach my $SRED_Asset
foreach my $Claim_Asset ( openprint::Claim_Asset->find() ) {
	my $Object_Asset = new openprint::Object_Asset();
	$Object_Asset->save({ object_id=>$Claim_Asset->claim_id(), asset_id=>$Claim_Asset->asset_id(), object_type=>'openprint::Claim' });
	$Claim_Asset->delete();
} # end foreach my $SRED_Asset
$dbh->do('UPDATE users SET deleted=false WHERE deleted IS NULL');

foreach my $E ( openprint::Equipment->find( Specifications => {'Stitching Capable'=>'Y'}, useinestimating=>1,order=>'lower(strName)') ) {
	my $Spec = $E->Specification('Folding Capable');
	if ( ! $Spec ) {
		$Spec = new openprint::EquipmentSpecification();
		$Spec->save({equipment_id=>$E->id(), name=>'Folding Capable', value=>'When Stitching'});
	} elsif ( $Spec->value() ne 'When Stitching' ) {
		$Spec->save({value=>'When Stitching'});
	} # end if
	my $Spec = $E->Specification('Fold Covers Only');
	if ( ! $Spec ) {
		$Spec = new openprint::EquipmentSpecification();
		$Spec->save({equipment_id=>$E->id(), name=>'Fold Covers Only', value=>'Y'});
	} elsif ( $Spec->value() ne 'When Stitching' ) {
		$Spec->save({value=>'Y'});
	} # end if
	my $Fold = openprint::Fold->find_one(equipment_id=>$E->id(), pages=>4);
	if ( ! $Fold ) {
		$Fold = new openprint::Fold();
		$Fold->save({ equipment_id=>$E->id(), pages=>4, stitching=>1, type=>'4PageFold' });
	} elsif ( ! $Fold->type() ) {
		$Fold->save({type=>'4PageFold'});
	} # end if
		my $FoldSpec = openprint::FoldSpecification->find_one(fold_id=>$Fold->id());
		if ( ! $FoldSpec ) {
			$FoldSpec = new openprint::FoldSpecification();
			$FoldSpec->save({fold_id=>$Fold->id()});
		} # end if
} # end foreach

my $Folder = openprint::Equipment->find_one(strid=>'Folder-1' );
foreach my $ServicePrice ( openprint::ServicePrice->find(equipment_id=>$$Folder{id}, 'service_name like' => '%PanelFoldMakeReady' ) ) {
	if ( ! $ServicePrice->min() ) {
		$ServicePrice->save({units=>'', min=>1, max=>1 });
		foreach my $i ( 2 .. 6 ) {
		my $Two = $ServicePrice->copy();
		$Two->save({min=>$i,max=>$i, markup=>12*($i-1), price=>undef } );
		} # end foreach
	} # end if
} # end foreach
$dbh->disconnect();
0;
__END__
