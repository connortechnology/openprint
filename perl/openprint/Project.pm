use strict;
package openprint::Project;
our @ISA = qw(openprint::Object);

use openprint ();

use vars qw( $log $dbh %config $debug $table $serial %fields %find_fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

use openprint::Currency;
use openprint::ProjectType;
use openprint::Company;
use openprint::Order;
use openprint::logs;
require openprint::print;
require Math::Units;

require sql;
require openprint::JDF;
require openprint::OrderedProduct;
require openprint::ScheduledJob;
require openprint::Project_Service;
require openprint::Todo;
require openprint::Bug;

$debug = 1;

$table = 'projects';
$serial = 'lngProjectIndex_seq';

%fields = (
	'id'	=>	'id',
	'docket'	=>	'lngdocketnumber',
	'company_id'	=>	'company_id',
	'user_id'		=>	'user_id',
	'reference'		=>	'strprojectreference',
	'comments'		=>	'strcomments',
	'design'		=>	'strdesign',
	'created_on'	=>	'dtmcreationdate',
	'updated_on'	=>	'dtmlastmodified',
	'quantity1'		=>	'intquantity1',
	'quantity2'		=>	'intquantity2',
	'quantity3'		=>	'intquantity3',
	'status'		=>	'strstatus',
	'mode'			=>	'strmode',
	'programs'		=>	'strprograms',
	'other_programs'	=>	'strotherprograms',
	'currency_id'	=>	'currency_id',
	'type_id'		=>	'type_id',
	'price1'		=>	'price1',
	'price2'		=>	'price2',
	'price3'		=>	'price3',
	'order_id'		=>	'order_id',
	'due_date'		=>	'due_date',
	'externalrefnumber'	=>	'externalrefnumber',
	'reprint_reason'	=>	'reprint_reason',
	'reprint'			=>	'reprint',
	'predefined'		=>	'predefined',
	'rush'				=>	'rush',
	'style_id'			=>	'style_id',
	'summary'			=>	'summary',
);
%defaults = (
	'created_on'	=>	q`'NOW()'`,
	'updated_on'	=>	q`'NOW()'`,
	'docket'		=>	undef,
	'quantity1'		=>	undef,
	'quantity2'		=>	undef,
	'quantity3'		=>	undef,
	'price1'		=>	undef,
	'price2'		=>	undef,
	'price3'		=>	undef,
	'order_id'		=>	undef,
	'due_date'		=>	undef,
);

%find_fields = (
	'take_over' => q{(SELECT MIN(starttime) FROM tbl_Project_Contents WHERE lngProjectIndex=id)},
	'ordered_on'	=>	q{(SELECT dtmOrderDate FROM Orders WHERE orders.id=order_id)},
	'salesrep_id'		=>	'(SELECT employeeindex FROM Orders WHERE orders.id=order_id)',
	'takenover_on'		=>	q{(SELECT MIN(dtmtimestamp) FROM Project_Log WHERE project_id=projects.id AND description LIKE 'Taken Over by%')},
	'csr_id'			=>	'(SELECT salesrep_id FROM Companies WHERE companies.id=company_id)',
);

sub delete {
	my $self = shift;
	sql::update( undef, undef, $table, ['id=?', $$self{'id'}], ['strStatus', 'Deleted'] );
} # end sub delete

sub destroy {
	my $self = shift;
	my $ac = sql::start_transaction( $openprint::dbh );
	foreach my $Product ( openprint::OrderedProduct->find( 'project_id'=>$$self{'id'} ) ) {
		$Product->save({'project_id'=>undef});
	} # end foreach Product
	foreach my $Todo ( openprint::Todo->find( 'project_id'=>$$self{'id'} ) ) {
		$Todo->save({'project_id'=>undef});
	} # end foreach Todo
	foreach my $B ( openprint::Bug->find( 'project_id'=>$$self{'id'} ) ) {
		$B->destroy();
	} # end foreach bug
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM tbl_Service_Specifications WHERE lngProjectIndex=?}, $$self{'id'} );
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $$self{'id'} );
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM Project_Log WHERE project_id=?}, $$self{'id'} );
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM Barcode_Log WHERE project_id=?}, $$self{'id'} );
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM Schedule WHERE projectindex=?}, $$self{'id'} );
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM Bindery_Schedule WHERE projectindex=?}, $$self{'id'} );
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM paper_allocations WHERE project_id=?}, $$self{'id'} );
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM Project_files WHERE project_id=?}, $$self{'id'} );
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM Order_Contents WHERE lngprojectindex=?}, $$self{'id'} );
	foreach my $quote_id ( sql::execute( undef, undef, q{SELECT quote_id FROM tbl_Quote_Details WHERE project_id=?}, $$self{'id'} ) ) {
		my $Quote = new openprint::Quote( $quote_id );
		$Quote->add_log('Deleted Project ' . $$self{'id'} );
	} # end foreach
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM PressActivities WHERE project_id=?}, $$self{'id'} );
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM projects WHERE id=?}, $$self{'id'} );
	sql::end_transaction( $openprint::dbh, $ac );
} # end sub destroy

sub Type {
	if ( @_ > 1 ) {
		$_[0]{'type_id'} = $_[1]->id();	
	} # end nif
	return new openprint::ProjectType( $_[0]{'type_id'} );
} # end sub Type

sub get_project_type_service_index {
	my ( $self ) = @_;
	my $services = $self->services();

	if ( $$services{''} ) {
		return $$services{''}[0];
	} # end if
	return;
} # end sub

sub JDF_ProductIntent {
	my ( $self ) = @_;

	my $services = $self->services();
	my $printing_specs = openprint::service::get_specs_ref( $self, $$services{''}[0] );
	
	my $doc = new XML::DOM::Document;
	$doc->setXMLDecl( $doc->createXMLDecl( '1.0' ) );
	foreach my $sig_id ( $self->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $self, $sig_id );
		$doc->appendChild( openprint::JDF::PrintingProcess( $doc, $self, $sig_id, $sig_specs ) );
	} # end foreach
	return $doc;
} # end sub JDF_ProductIntent

sub jdf {
	my ( $self, $version ) = @_;
	$version = 1.3 if ! $version;
	my $ppi = 1;

	my $services = $self->services();
	my $printing_specs = openprint::service::get_specs_ref( $self, $$services{''}[0] );
	
	my $doc = new XML::DOM::Document;
	$doc->setXMLDecl( $doc->createXMLDecl( '1.0' ) );
	my $project = $doc->appendChild($doc->createElement('JDF'));
	$project->setAttribute('xmlns','http://www.CIP4.org/JDFSchema_1_1');
	$project->setAttribute('xmlns:xsi','http://www.w3.org/2001/XMLSchema-instance');
	$project->setAttribute('xsi:type','Product');
	$project->setAttribute('Status','Waiting');
	$project->setAttribute('Version', $version );
	$project->setAttribute('MaxVersion', $version );
	$project->setAttribute('JobID',$self->docket());
	$project->setAttribute('JobPartID',$self->id());
	$project->setAttribute('Type', 'Product' );
	$project->setAttribute('ID', 'Docket'.$self->docket() );
	$project->setAttribute('DescriptiveName', $self->summary() );
#my $FinalResourcePool = $project->appendChild( $doc->createElement('ResourcePool') );
#my $FinalResourceLinkPool = $Product->appendChild( $doc->createElement('ResourceLinkPool') );

	my $Product = $project;

	if ( $ppi ) {
		$project->setAttribute('xmlns:ppi','http://www.ppimedia.de/namespaces/printbase');
		my $ppiOrderInfo = $Product->appendChild( $doc->createElement('ppi:OrderInfo') );
		$ppiOrderInfo->setAttribute( 'OrderType', $self->docket() ? 'Order' : 'Offer' );
		$ppiOrderInfo->setAttribute( 'Handling', 'Normal' ); # RushOrder, StockOrder
		$ppiOrderInfo->setAttribute( 'Client', $self->Company()->name() );
	} # end if
#my $Product = $project->appendChild($doc->createElement('JDF'));
#$Product->setAttribute('Status','Waiting');
#$Product->setAttribute('ID', 'Product'.$self->id() );
	my $ProductResourcePool = $Product->appendChild( $doc->createElement('ResourcePool') );
	my $ProductResourceLinkPool = $Product->appendChild( $doc->createElement('ResourceLinkPool') );

	my $Component = $ProductResourcePool->appendChild( $doc->createElement('Component') );
	$Component->setAttribute('Class', 'Quantity');
	$Component->setAttribute('ComponentType', 'FinalProduct Sheet');
	$Component->setAttribute('DescriptiveName', $self->Type()->name() );
	$Component->setAttribute('ID', 'Product'.$self->id() );
	$Component->setAttribute('Status','Unavailable');
	$Component->setAttribute('isWaste','false');
	$Component->setAttribute('AmountRequired',$self->ordered_quantity());
	$Component->setAttribute('ResourceWeight',openprint::print::get_finished_weight( $self->id() ) );
	## THese are crucial for Metrix
	#$Component->setAttribute('ProductType','Body');
	$Component->setAttribute('Dimensions',join(' ', 
				72*$$printing_specs{'txtFinalWidth'},
				72*$$printing_specs{'txtFinalHeight'}, 
				72*openprint::print::get_finished_calliper( $$self{'id'} )
				));

	my $Layout = $ProductResourcePool->appendChild( openprint::JDF::Layout( $doc, $self, undef, undef, undef, $version ) );
	
	#$Component->setAttribute('ReaderPageCount','2');

	my $ComponentLink = $ProductResourceLinkPool->appendChild( $doc->createElement('ComponentLink') );
	$ComponentLink->setAttribute('Usage','Output');
	$ComponentLink->setAttribute('rRef', 'Product'.$$self{'id'} );
	$ComponentLink->setAttribute('Amount', $self->ordered_quantity() );

#my $Ink = $doc->createElement( 'Ink' );
	my $Ink = $ProductResourcePool->appendChild( $doc->createElement( 'Ink' ));
	$Ink->setAttribute( 'Class','Consumable' );
	$Ink->setAttribute( 'DescriptiveName','Printing Inks');
	$Ink->setAttribute( 'PartIDKeys','SignatureName SheetName Side Separation');
	$Ink->setAttribute( 'ID','INK' );
	$Ink->setAttribute( 'Status', 'Available' );

# Hack: Add a PlateMaker
	if ( 0 ) {
		my $Device = openprint::JDF::getNode( $doc, 'Device','DeviceID'=>'PLA1001' );
		if ( ! $Device ) {
			$Device = $ProductResourcePool->appendChild( $doc->createElement('Device') );
			$Device->setAttribute('Class','Implementation' );
			$Device->setAttribute('DescriptiveName','Temporary Platemaker' );
			$Device->setAttribute('DeviceID', 'PLA1001' );
			$Device->setAttribute('ID', 'PLA1001' );
			$Device->setAttribute('Status', 'Available' );
		} # end if
	} # end if

# Each part of a project is a signature, and has it's own Product Node
	foreach my $sig_id ( $self->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $$self{'id'}, $sig_id );

		my $Component = $ProductResourcePool->appendChild( $doc->createElement('Component') );
		$Component->setAttribute('Class', 'Quantity');
		$Component->setAttribute('ComponentType', 'PartialProduct');
		$Component->setAttribute('DescriptiveName', $self->Type()->name() );
		$Component->setAttribute('ID', 'SUB'.$$sig_specs{'SignatureIndex'} );
		$Component->setAttribute('Status','Unavailable');
		$Component->setAttribute('ProductType', openprint::JDF::ProductType( $self, $sig_specs, $version ) );

		my $Pages = $$sig_specs{'PageQuantity'.$self->ordered_quantity_index()};
		$Pages = 2 if ! $Pages;
		$Component->setAttribute('ReaderPageCount',$Pages );
		my $SignatureIntent = openprint::JDF::JDF_SignatureIntent( $doc, $self, $sig_id, $sig_specs, $version );
		$Product->appendChild( $SignatureIntent );

# Add the printing Process for this sig
		$SignatureIntent->appendChild( openprint::JDF::JDF_PrintingGreyBox( $doc, $self, $sig_id, $sig_specs, $version ) );
		#$SignatureIntent->appendChild( openprint::JDF::JDF_PrintingProcess( $doc, $self, $sig_id, $sig_specs, $version ) );
		#openprint::JDF::JDF_PrintingProcess( $doc, $self, $sig_id, $sig_specs );
		my $SI_ResourceLinkPool = openprint::JDF::getNode( $SignatureIntent, 'ResourceLinkPool' );

		my $FinalInputComponentLink = $ProductResourceLinkPool->appendChild( $doc->createElement('ComponentLink') );
		$FinalInputComponentLink->setAttribute('Usage','Input');
		$FinalInputComponentLink->setAttribute('Amount',$self->ordered_quantity() );
		$FinalInputComponentLink->setAttribute('rRef','SUB'.$$sig_specs{'SignatureIndex'} );

		my @side_one_colours = openprint::Estimating::Printing::get_colours( $sig_specs,'SideOne' );
		my @side_two_colours = openprint::Estimating::Printing::get_colours( $sig_specs,'SideTwo' );
		my %SideColours = (
				'Front'=>\@side_one_colours,
				'Back'=>\@side_two_colours,
				);

		my $SigInk = $Ink->appendChild( $doc->createElement('Ink') );
		$SigInk->setAttribute('SignatureName','Sig#'.$$sig_specs{'SignatureIndex'});

		my $SigInkSheetName = $SigInk->appendChild( $doc->createElement('Ink') );
		$SigInkSheetName->setAttribute('SheetName','Sheet 1');

		foreach my $side ( 'Front','Back' ) {
			if ( @{$SideColours{$side}} ) {
				my $SigInkFront = $SigInkSheetName->appendChild( $doc->createElement('Ink') );
				$SigInkFront->setAttribute('Side',$side);
				foreach my $color ( @{$SideColours{$side}} ) {
					my $Separation = $SigInkFront->appendChild($doc->createElement('Ink'));
					$Separation->setAttribute('Separation',$color);
				} # end foreach
			} # end if
		} # end foreach Side
		#$SignatureIntent->appendChild( openprint::JDF::JDF_PrintingProcess( $doc, $self, $sig_id, $sig_specs ) );
		#$SignatureIntent->appendChild( openprint::JDF::JDF_ImpositionIntent( $doc, $self, $sig_id, $sig_specs ) );
		$SignatureIntent->appendChild( openprint::JDF::Prepress( $doc, $self, $sig_id, $sig_specs, $version ) );
		#my $ImpositionIntentLink = $SI_ResourceLinkPool->appendChild( $doc->createElement( 'ImpositionLink' ) );
		#$ImpositionIntentLink->setAttribute('Usage','Input');
		#$ImpositionIntentLink->setAttribute('rRef','Imposition'.$sig_id);
		
	} # end foreach Signature

	# Add Binding Info
	if ( my $binding = openprint::print::get_book_type( $self->id() ) ) {
		my $BindingIntent = $ProductResourcePool->appendChild( $doc->createElement('BindingIntent') );
		$BindingIntent->setAttribute('ID','BI'.$self->id() ); # FInal Binding
		$BindingIntent->setAttribute('Class','Intent' );
		$BindingIntent->setAttribute('Status','Available' );
		my $BindingType = $BindingIntent->appendChild( $doc->createElement('BindingType') );
		$BindingType->setAttribute('DataType','EnumerationSpan');
		$BindingType->setAttribute('Actual',$openprint::JDF::bindingtypes{$binding});
		$BindingType->setAttribute('Preferred',$openprint::JDF::bindingtypes{$binding});

		my $BindingIntentLink = $ProductResourceLinkPool->appendChild( $doc->createElement('BindingIntentLink') );
		$BindingIntentLink->setAttribute('Usage','Input');
		$BindingIntentLink->setAttribute('rRef','BI'.$self->id());
	} # end if


if ( 1 ) {
	require XML::DOM;
	require JMF;
	# THis is where we stick JMF Subscriptions
	#my $NodeInfo = $ProductResourcePool->appendChild( $doc->createElement('NodeInfo') );
	#$NodeInfo->setAttribute('ID','NI'.$self->id());
	#$NodeInfo->setAttribute('Class','Parameter');
	##$NodeInfo->setAttribute('Status','Available');
	#$NodeInfo->setAttribute('JobPriority','50');
	#my $JMF = $NodeInfo->appendChild( JMF::QuerySetupPersistentChannel( $doc ) );
	#my $NodeInfoLink = $ProductResourceLinkPool->appendChild( $doc->createElement('NodeInfoLink') );
	#$NodeInfoLink->setAttribute('rRef','NI'.$self->id());
	#$NodeInfoLink->setAttribute('Usage','Input');

	#my $JMF = $NodeInfo->appendChild( JMF::JMFNode($doc));
	#my $QueryStatusChannel = $JMF->appendChild( JMF::QuerySetupPersistentChannel($doc, 'Status') );
	#my $QueryStatusChannel = $JMF->appendChild( JMF::QuerySetupPersistentChannel($doc, 'Notification') );

	# Add Company Information
	#my $ResourcePool = $project->appendChild( $doc->createElement('ResourcePool') );
	my $CustomerInfo;
	if ( $version == 1.3 ) {
		$CustomerInfo = $ProductResourcePool->appendChild( $doc->createElement('CustomerInfo') );
		$CustomerInfo->setAttribute('ID', 'CustInfo' );
		my $CustomerInfoLink = $ProductResourceLinkPool->appendChild( $doc->createElement('CustomerInfoLink') );
		$CustomerInfoLink->setAttribute('Usage','Input');
		$CustomerInfoLink->setAttribute('rRef','CustInfo');
	} else {
		$CustomerInfo = $project->appendChild( $doc->createElement('CustomerInfo') );
	} # end if
	$CustomerInfo->setAttribute('CustomerID',$self->Company->id() );
	#$CustomerInfo->setAttribute('Class', 'Parameter' );
	#$CustomerInfo->setAttribute('Status', 'Available' );
	#$CustomerInfo->setAttribute('DescriptiveName', $self->Company->name() );
	$CustomerInfo->setAttribute('CustomerJobName', $self->reference() );


	my $Contact = $CustomerInfo->appendChild( $doc->createElement('Contact') );
	$Contact->setAttribute('ContactTypes', 'Customer' );
	my $Person = $Contact->appendChild( $doc->createElement('Person') );
	$Person->setAttribute('FamilyName', $self->Order()->last_name() );
	$Person->setAttribute('FirstName', $self->Order()->first_name() );
	if ( $self->Order()->email() ) {
		my $ComChannel = $Person->appendChild( $doc->createElement('ComChannel') );
		$ComChannel->setAttribute('ChannelType','Email');
		$ComChannel->setAttribute('Locator',$self->Order()->email());
	} # end if
	if ( $self->Order()->phone() ) {
		my $ComChannel = $Person->appendChild( $doc->createElement('ComChannel') );
		$ComChannel->setAttribute('ChannelType','Phone');
		$ComChannel->setAttribute('Locator',$self->Order()->phone());
	} # end if
	if ( $self->Order()->fax() ) {
		my $ComChannel = $Person->appendChild( $doc->createElement('ComChannel') );
		$ComChannel->setAttribute('ChannelType','Fax');
		$ComChannel->setAttribute('Locator',$self->Order()->fax());
	} # end if
} # end if

	my $AuditPool = $project->appendChild( $doc->createElement('AuditPool') );
	my $Created = $AuditPool->appendChild( $doc->createElement('Created') );
	$Created->setAttribute('Author', 'IntelligentQuote' );
	my @gmtime = gmtime(time);
	$Created->setAttribute('TimeStamp', sprintf('%.4d-%.2d-%.2dT%.2d:%.2d:%.2dZ', $gmtime[5]+1900, $gmtime[4]+1, $gmtime[3]+1,$gmtime[2],$gmtime[1],$gmtime[0] ) );

	return $doc;
} # end sub xml

sub get_quantities {
	my $self = shift;
	return @$self{'quantity1','quantity2','quantity3'};
} # end sub get_quantities

sub is_printed {
	my $self = shift;
	
	my %statuses = sql::execute( undef, undef, q{SELECT lngServiceIndex, strStatus FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $$self{id} );
	foreach ( $self->signatures() ) {
		return 0 if sets::isin( $statuses{$_}, ['Ordered','In Production','uncalculated'] );
	} # end foreach
	return 1;
} # end sub is_printed

# This is sortof a state engine.	This function should update a project's status to whatever it should be.
sub update_status {
	my ( $self ) = @_;

	my %services = $self->get_services();
	my @statuses = sql::execute( $openprint::log, $openprint::dbh, q{SELECT DISTINCT strStatus FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $$self{'id'} );
	my $new_status = $$self{'status'};

	# The Pending Deposit to In Prepress trnasition is a manual one.
	return if $$self{'status'} eq 'Pending Deposit';

	my $Order = new openprint::Order( $$self{'order_id'} );
	if ( $$self{'order_id'} and $Order->status() ne 'Incomplete' ) {

# This fixes the damage caused by re-opening an order
		if ( sets::isin( 'calculated', \@statuses ) ) {
			sql::update( $openprint::log, $openprint::dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND strStatus=?', $$self{id}, 'calculated'], 'strStatus', 'Ordered' );
			@statuses = sql::execute( $openprint::log, $openprint::dbh, q{SELECT DISTINCT strStatus FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $$self{'id'} );
		} # end if

# We now know that it has been ordered.

		if ( sets::isin( 'Waiting For Customer Approval', \@statuses ) ) {
			if ( $$self{status} ne 'Waiting For Customer Approval' ) {
				$self->add_to_log( @openprint::session{'company_id','user_id'}, "Marked Waiting For Customer Approval from $$self{'status'}" );
				$$self{'status'} = 'Waiting For Customer Approval';
				$self->save();
            } # end if
            return $$self{status};
		} elsif ( sets::isin( 'Waiting For QA Approval', \@statuses ) ) {
            if ( $$self{status} ne 'Waiting For QA Approval' ) {
				$self->add_to_log( @openprint::session{'company_id','user_id'}, "Marked Waiting For QA Approval from $$self{'status'}" );
				$$self{'status'} = 'Waiting For QA Approval';
				$self->save();
            } # end if
            return $$self{status};
		} elsif ( sets::isin( 'Proofs Out', \@statuses ) and ( $$self{'status'} ne 'Proofs Out' ) ) {
			$self->add_to_log( @openprint::session{'company_id','user_id'}, "Marked Proofs Out from $$self{'status'}" );
			$$self{'status'} = 'Proofs Out';
			$self->save();
			return $$self{'status'};
		} # end if

# At this point, we know that the project is ordered
		if ( sets::isin( 'Ordered', \@statuses ) ) {
			if ( sets::isin( 'Approved', \@statuses ) ) {
				if ( $self->is_printed() ) {
					$new_status = 'Printed';
				} else {
					$new_status = 'Approved';
				} # end if
			} else {
				if ( $self->is_printed() ) {
					$new_status = 'Printed';
					my $changed = 0;

					if ( $$self{'status'} eq 'In Prepress' ) {
# Check prepress services and mark complete
						my @prepress = openprint::print_project::get_services_in_category( $openprint::log, $openprint::dbh, $$self{'id'}, 'Prepress' );
						foreach my $s_id ( @prepress ) {
							if ( openprint::service::status( $$self{id}, $s_id ) ne 'Complete' ) {
								openprint::service::status( $$self{id}, $s_id, 'Complete' );
								$changed = 1;
							} # end if
						} # end foreach
						if ( $services{'Proofs'} ) {
							foreach my $s_id ( @{$services{'Proofs'}} ) {
								if ( openprint::service::status( $$self{id}, $s_id ) ne 'Approved' ) {
									openprint::service::status( $$self{id}, $s_id, 'Approved' );
									$changed = 1;
								} # end if
							} # end foreach
						} elsif ( $services{'FilmStripping'} ) {
							foreach my $s_id ( @{$services{'FilmStripping'}} ) {
								if ( openprint::service::status( $$self{id}, $s_id ) ne 'Approved' ) {
									openprint::service::status( $$self{id}, $s_id, 'Approved' );
									$changed = 1;
								} # end if
							} # end foreach
						} # end if
					} elsif ( $$self{'status'} eq 'Proofs Out' ) {
						if ( $services{'Proofs'} ) {
							foreach my $s_id ( @{$services{'Proofs'}} ) {
								if ( openprint::service::status( $$self{id}, $s_id ) ne 'Approved' ) {
									openprint::service::status( $$self{id}, $s_id, 'Approved' );
									$changed = 1;
								} # end if
							} # end foreach
						} # end if
					} elsif ( $$self{'status'} eq 'Approved' ) {
# normal
					} # end if
					if ( $services{'NoBindery'} ) {
						foreach my $s_id ( @{$services{'NoBindery'}} ) {
							if ( 'Complete' ne openprint::service::status( $$self{id}, $s_id ) ) {
								openprint::service::status( $$self{id}, $s_id, 'Complete' );
								$changed = 1;
							} # end if
						} # end foreach
					} # end if
					if ( $changed ) {
						return $self->update_status( );
					} # end if
				} else { # is printed
					$new_status = 'In Prepress';
				} # end if
			} # end if
		} else { # there isn't any ordered services
			if ( $$self{'shippingtype'} eq 'CustomerPickup' ) {
				if ( $$self{'status'} ne 'Picked Up' ) {
					$new_status = 'Waiting For Pickup';
				} # end if
			} elsif ( $$self{'shippingtype'} eq 'Delivery' ) {
				$new_status = 'Shipped';
			} else {
				if ( ! sets::isin( $$self{'status'}, [ 'Shipped', 'Picked Up' ] ) ) {
					$new_status = 'Complete';
				} # end if
			} # end if
		} # end if
	} else {
# Project is UnOrdered
		if ( sets::isin( 'Ordered', \@statuses ) ) {
			sql::update( $openprint::log, $openprint::dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND strStatus=?', $$self{'id'},'Ordered'], 'strStatus', 'calculated' );
			@statuses = sql::execute( $openprint::log, $openprint::dbh, q{SELECT DISTINCT strStatus FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $$self{'id'} );
		} # end if
		if ( sets::isin( 'uncalculated', \@statuses ) ) {
			$new_status = 'uncalculated';
		} elsif ( sets::isin( 'calculated', \@statuses ) ) { # This works because we have already checked for uncalculated
			$new_status = 'Unordered';
			foreach my $qty_index ( $self->quantity_indexes() ) {
				if ( openprint::Estimating::MultiPage::status( $$self{'id'}, undef, $qty_index ) ) {
					$new_status = 'uncalculated';
					last;
				} # end if
			} # end foreach
		} # end if
	} # end if

	if ( $$self{'status'} ne $new_status ) {
		$$self{'status'} = $new_status;
		$self->save();
		$self->add_to_log( @openprint::session{'company_id','user_id'}, "Marked $new_status" );
	} # end if
	return $$self{'status'};

} # end sub update_project_status

sub save {
	my ( $self, $hash ) = @_;

	$self->set( $hash );
	foreach my $qty_index ( $self->quantity_indexes() ) {
		$self->price( $qty_index, undef );
	} # end foreach

	$$self{'currency_id'} = $openprint::session{'Currency_id'} if ! $$self{'currency_id'};
	$$self{'company_id'} = $openprint::session{'company_id'} if ! $$self{'company_id'};
	$$self{'user_id'} = $openprint::session{'user_id'} if ! $$self{'user_id'};
	$$self{'status'} = 'uncalculated' if ! $$self{'status'};
	$$self{'predefined'} = '0' if $$self{'predefined'} != 1;

	my $rc = $self->SUPER::save( $hash );

	# I'm not sure we should be doing this.
	if ( (!$rc) and $$self{'order_id'} ) {
		sql::update( $log, $dbh, 'Order_Contents', ['OrderIndex=? AND lngProjectIndex=?', @$self{'order_id','id'} ], {
			'shippingtype'		=>	$$self{'shippingtype'},
			'daterequired'		=>	$$self{'requested_date'},
			'intquantityindex'	=>	$$self{'ordered_quantity_index'},
			'cursalesprice'		=>	$$self{'ordered_price'},
			} );
	} # end if
	return $rc;
} # eend sub save

sub quantity_indexes {
	my ( $self ) = @_;
	if ( ! exists $$self{'quantity_indexes'} ) {
		@{$$self{'quantity_indexes'}} = ();
		foreach my $qty_index ( 1 .. 3 ) {
			push @{$$self{'quantity_indexes'}}, $qty_index if $$self{"quantity$qty_index"};
		} # end foreach qty_index
	} # end if
	return @{$$self{'quantity_indexes'}};
} # end sub quantity_indexes

sub quantities {
	my $self = shift;
	return @$self{'quantity1','quantity2','quantity3'};
} # end sub quantities

sub quantity {
	my ( $self, $index, $qty ) = @_;
	if ( $index eq 'Used' ) {
		return $self->ordered_quantity();
	} elsif ( defined $qty ) {
		$$self{"quantity$index"} = $qty;
		if ( exists $$self{'quantity_indexes'} ) {
			$$self{'quantity_indexes'}[$index-1] = $index;
		} # end if
	} # end if
	return $$self{'quantity'.$index};
} # end sub quanitty

sub quantity1 {
	my $self = shift;
	if ( @_ ) {
		my $new_qty = shift;
		if ( $new_qty != $$self{'quantity1'} ) {
			$$self{'quantity1'} = $new_qty;
		} # end if
		delete $$self{'quantity_indexes'};
	} # end if
	return $$self{'quantity1'};
} # end sub quantity1
sub quantity2 {
	my $self = shift;
	if ( @_ ) {
		my $new_qty = shift;
		if ( $new_qty != $$self{'quantity2'} ) {
			$$self{'quantity2'} = $new_qty;
		} # end if
		delete $$self{'quantity_indexes'};
	} # end if
	return $$self{'quantity2'};
} # end sub quantity2
sub quantity3 {
	my $self = shift;
	if ( @_ ) {
		my $new_qty = shift;
		if ( $new_qty != $$self{'quantity3'} ) {
			$$self{'quantity3'} = $new_qty;
		} # end if
		delete $$self{'quantity_indexes'};
	} # end if
	return $$self{'quantity3'};
} # end sub quantity2

sub copy {
	my $self = shift;
	my $new = new openprint::Project();
	foreach my $key ( keys %$self ) {
		$$new{$key} = $$self{$key};
	} # end foreach
	$new->save({'id'=>undef, 'created_on'=>undef,'Services'=>undef} );

	my @dont_copy = (
			'ServiceIndex','ProjectIndex','TemplateType',
			'txtEmployeeComments','rdbComplete','rdbApproved','ddmApprovalDateMonth','ddmApprovalDateDay','ddmApprovalDateYear',
			'ddmCompletionDate.*','txtRunHours','txtDowntimeHours',
			'ddmPressCompletionDate.*', 'UsePress.*', 'rdbPressComplete.*',
			'UsedPaper.*',
			'txtMakeReadySetupHours', 'txtStartQuantity','txtFinalQuantity','txtWasteQuantity','txtEmployeeName',
			'.*Used',
			);

# Make this all one transaction... Don't need locking because a reload would get a different projectindex
	my $ac = sql::start_transaction( $openprint::dbh );
	my @contents = sql::execute( undef, undef, q{SELECT lngServiceIndex, servicetype_id, strStatus FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $$self{'id'} );

	while ( @contents ) {
		my ( $service_index, $servicetype_id, $status ) = splice @contents, 0, 3;

# uncalc->uncalc,   *->calc
		if ( $status ne '' and sets::isin( $status, [ 'Pending Deposit', 'Ordered', 'Proofs Out', 'Approved', 'Complete' ] ) ) {
			$status = 'calculated';
		} # end if

		my ( $new_service_index ) = sql::execute( undef, undef, q{SELECT nextval('ContentsServiceIndex_seq')} );
		sql::insert( undef, undef, 'tbl_Project_Contents',[
				'lngProjectIndex',  $$new{id},
				'lngServiceIndex', $new_service_index,
				'servicetype_id',   $servicetype_id,
				'strStatus',    $status
				] );
		openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $new->id(), $new_service_index, 'ProjectIndex', $new->id(), 1 );
		openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $new->id(), $new_service_index, 'ServiceIndex', $new_service_index, 1 );

		my $specs = openprint::service::get_specs_ref( $self, $service_index );
		foreach my $key ( keys %$specs ) {
			if ( ! sets::isin_regx( $key, @dont_copy ) ) {
				openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $new->id(), $new_service_index, $key, $$specs{$key}, 1 );
			} # end if
		} # end foreach
	} # end while contents
	sql::end_transaction( $openprint::dbh, $ac );

	return $new;
} # end sub copy

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $dbh->selectrow_hashref( q{SELECT * FROM Projects WHERE id=?}, {}, $$self{'id'} );
		if ( ! $data ) {
			$openprint::log->error("Error loading Project $$self{'id'}: ".$openprint::dbh->errstr() );
		} # end if
	} # endif
	@$self{qw/id summary docket order_id company_id user_id reference comments design created_on updated_on quantity1 quantity2 quantity3 status mode programs otherprograms printingtype currency_id type_id style_id price1 price2 price3 requested_date ordered_quantity_index ordered_price due_date predefined rush reprint reprint_reason markup/} =
		@$data{qw/id summary lngdocketnumber order_id company_id user_id strprojectreference strcomments strdesign dtmcreationdate dtmlastmodified intquantity1 intquantity2 intquantity3 strstatus strmode strprograms strotherprograms printingtype currency_id type_id style_id price1 price2 price3 daterequired intquantityindex cursalesprice due_date predefined rush reprint reprint_reason markup/};
	if ( $$self{'order_id'} ) {
		@$self{'requested_date','ordered_quantity_index','shippingtype','ordered_price'} = sql::execute( undef, undef, q{SELECT daterequired, intquantityindex, shippingtype, cursalesprice FROM Order_Contents WHERE OrderIndex=? AND lngProjectIndex=?}, @$self{'order_id','id'} );
	} # end if
	return;
} # end sub load

sub type {
	my $self = shift;
	return new openprint::ProjectType( $$self{'type_id'} );
} # end sub type

sub add_to_log {
	my ( $self, $cust_id, $user_id, $text ) = @_;
	sql::insert( undef, undef, 'Project_Log',[
			'project_id',	$$self{'id'},
			'dtmTimestamp',	'NOW()',
			'company_id',	$cust_id,
			'user_id',		$user_id,
			'description',	$text,
			] );
} # end sub add_to_log

sub get_services {
	my $self = shift;
	if ( ! exists $$self{'Services'} ) {
		my %results;
		my @data = sql::execute( undef, undef, q{SELECT (SELECT name FROM Service_Types WHERE id=servicetype_id), lngServiceIndex FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $$self{'id'} );
		while ( my ( $id, $index ) = splice @data, 0, 2 ) {
			push @{$results{$id}}, $index;
		} # end while
		$$self{'Services'} = \%results;
	} # end if
	return %{$$self{'Services'}};
} # end sub get_service_hash

sub servicetype_id {
	my ( $self, $s_id ) = @_;
	if ( ! exists $$self{'service_types'} ) {
		my %results;
		%{$$self{'service_types'}} = sql::execute( undef, undef, q{SELECT lngserviceindex, servicetype_id FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $$self{'id'} );
	} # end if
	return $$self{'service_types'}{$s_id};
} # end sub servicetype_id

sub ServiceType {
	my ( $self, $s_id ) = @_;
	return new openprint::ServiceType( $self->servicetype_id( $s_id ) );
} # end sub ServiceType

sub services {
	my ( $self, $name ) = shift;
	if ( $$self{'id'} and ! exists $$self{'Services'} ) {
		my %results;
		my @data = sql::execute( $openprint::log, $openprint::dbh, q{SELECT (SELECT name FROM Service_Types WHERE id=servicetype_id), lngServiceIndex FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $$self{'id'} );
		while ( my ( $id, $index ) = splice @data, 0, 2 ) {
			push @{$results{$id}}, $index;
		} # end while
		$$self{'Services'} = \%results;
	} # end if
	if ( $name ) {
		if ( $$self{'Services'}{$name} ) {
			return @{$$self{'Services'}{$name}};
		} # end if
		return;
	} # end if
	return $$self{'Services'};
} # end sub services

sub summary {
	my $self = shift;

	if ( @_ ) {
		$$self{'summary'} = shift;
	} # end if
	if ( ! $$self{'summary'} ) {
		my $summary = $self->Type()->name() . ' ';

		my $services = $self->services();
		if ( $$services{''} ) {
			my $printing_specs = openprint::service::get_specs_ref( $self, $$services{''}[0] );
			if ( $$printing_specs{'Versions'} ) {
				$summary .= $$printing_specs{'Versions'} .= ' versions ';
			} # end if
			if ( $$printing_specs{'PageQuantity'} ) {
				$summary .= $$printing_specs{'PageQuantity'} .= 'pg ';
			} # end if

			if ( $self->Type()->name() eq 'PresentationFolders' ) {
				$summary .= $$printing_specs{'rdbPanels'} . ' Panel ' . $$printing_specs{'PocketSize'} . '&quot; ';
			} # end if

			if ( $$printing_specs{'txtTotalPageQuantity'} ) {
				$summary .= sprintf( '%s&quot;x%s&quot; ', 1*$$printing_specs{'txtFinalWidth'},1*$$printing_specs{'txtFinalHeight'});
				if ( $$printing_specs{'rdbCover'} eq 'Different' ) {
					my $cover_pages = 0;
					foreach my $ss_id ( $self->signatures({'Group'=>1}) ) {
						my $sig_specs = openprint::service::get_specs_ref( $self, $ss_id );
						$cover_pages += $$sig_specs{'GroupPageQuantity'};
						last;
					} # end foreach
					$summary .= sprintf('%dpg+Cover ', $$printing_specs{'txtTotalPageQuantity'} - $cover_pages );
				} else {
					$summary .= sprintf('%dpg ', $$printing_specs{'txtTotalPageQuantity'} );
					$summary .= $$printing_specs{'rdbCover'}.' Cover';
				} # end if

				$summary .= '<br/>';
			} # end if
			my @groups = sql::execute( undef, undef, 'SELECT DISTINCT strvalue FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName=?', $$self{'id'}, 'Group' );

# I believe the point of this is to stick the Printed Web or Sheetfred into the summary.  Nastily executed.
# The logic is, each group has to be either all sheetfed, or all web (or digital, etc).  
			foreach my $group_id ( sort @groups ) {
				my @sigs = $self->signatures({'Group'=>$group_id});

				my $sig_specs = openprint::service::get_specs_ref( $self, $sigs[0] );
				$summary .= openprint::Estimating::Printing::summary( $self, $sigs[0], $sig_specs );
				foreach my $k ( keys %$sig_specs ) {
					if ( $k =~ /^PrintingType/i ) {
						if ( $$sig_specs{'Group'} eq $group_id ) {
							if ( $$sig_specs{$k} eq 'Web' ) { 
								$summary .= ', '. 'Printed Web,<br/>';
							} else {
								$summary .= ', '. 'Printed Sheetfed,<br/>';
							} #endif Web
							last;
						} # end if group_id
					} # end if $prn
				} # end foreach $prn	
			} # end foreach Group
		} # end if

		foreach my $Category ( openprint::ServiceType_Category->find('order'=>'sorting') ) {
			next if sets::isin( $Category->name(), [ 'Printing','Coatings' ] );
			foreach my $ServiceType ( openprint::ServiceType->find('category_id'=>$Category->id()) ) {
				next if ! $$services{$ServiceType->name()};
				foreach my $service_id ( @{$$services{$ServiceType->name()}} ) {
					my $service_specs = openprint::service::get_specs_ref( $self, $service_id );
					my $project_summary = eval( 'openprint::Estimating::'.$ServiceType->type().'::project_summary( $self, $service_id, $service_specs );' );
					if ( $project_summary ) {
						$summary .= $project_summary;
					} else {
						$summary .= ' ' . $ServiceType->description();
						if ( $_ = eval( 'openprint::Estimating::'.$ServiceType->type().'::summary( $self, $service_id, $service_specs );' ) ) {
							if ( ref $_ eq 'ARRAY' ) {
							$summary .= ' :'.$$_[0] . '<br/> ';
							} else {
							$summary .= ' :'.$_ . '<br/> ';
							} # end if
						} else {
							$summary .= ',';
						} # end if
					} # end if
				} # end foreach service
			} # end foreach ServiceType
		} # end foreach category
		$summary =~ s/(.*),$/$1/m;
		$$self{'summary'} = $summary;
	} # end if
	
	return $$self{'summary'};
} # end sub summary

sub company {
	my $self = shift;
	return new openprint::Company( $$self{'company_id'} );
} # end sub company
sub Company {
	my $self = shift;
	return new openprint::Company( $$self{'company_id'} );
} # end sub company

sub requested_date {
	my $self = shift;
	if ( @_ ) {
		$$self{'requested_date'} = $_[0];
	} # end if
	return $$self{'requested_date'};
} # end sub requested_date

sub shippingtype {
	my ( $self, $new ) = @_;
	if ( $new ) {
		$$self{'shippingtype'} = $new;
	} # end if
	return $$self{'shippingtype'};
} # end sub shippingtype
sub ordered_quantity {
	my $self = shift;
	return $$self{'quantity'.$self->ordered_quantity_index()};
} # end sub ordered_quantity

sub ordered_quantity_index {
	my $self = shift;
	if ( @_ ) {
		$$self{ordered_quantity_index} = $_[1];
	} # end if
	if ( ! $$self{ordered_quantity_index} ) {
		my @qtys = $self->quantity_indexes();
#$openprint::log->debug("Project ordered_qty_index @qtys ");
		if ( 1 == @qtys ) {
			$$self{ordered_quantity_index} = $qtys[0];
		} # end if
	} # end if
	return $$self{ordered_quantity_index};
} # end sub ordered_quantity_index

sub ordered_price {
	my $self = shift;
	return $$self{'ordered_price'} if $$self{'ordered_price'};
$openprint::log->debug("Ordered price: ($$self{'ordered_price'}) " . $$self{'price'.$self->ordered_quantity_index()});
	return $$self{'price'.$self->ordered_quantity_index()};
} # end sub ordered_price

sub ordered_Price {
	my ( $self ) = @_;
	my $price = $self->ordered_price();
	return { 'Cost'=>$price, 'currency_id'=>$$self{'currency_id'}, 'Price'=>$price };
} # end sub ordered_Price

sub prices {
	my $self = shift;
	return @$self{'price1','price2','price3'};
}
sub price {
	my ( $self, $qty_index, $new ) = @_;
	if ( @_ == 3 ) {
		$$self{'price'.$qty_index} = $new;
	} # end if
	if ( ! defined $$self{'price'.$qty_index} ) {
		my $services = $self->services();
		foreach my $k ( keys %$services ) {
			foreach ( @{$$services{$k}} ) {
				my $specs = openprint::service::get_specs_ref( $self, $_ );
				$$self{'price'.$qty_index} += $$specs{'txtPrice'.$qty_index} ? $$specs{'txtPrice'.$qty_index} : $$specs{'txtPrice1'};
			} # end foreach
		} # end foreach
	} # end if
#$openprint::log->debug("Price $qty_index " . $$self{'price'.$qty_index} );
	return sprintf( $config{'ProjectMoneyFormat'}, $$self{'price'.$qty_index} );
} # end sub price
sub unit_price {
	my ( $self, $qty_index ) = @_;
#$openprint::log->debug("Unit Price: ".$$self{'price'.$qty_index}."/".$$self{'quantity'.$qty_index}." = " . $$self{'price'.$qty_index}/$$self{'quantity'.$qty_index} );
	return sprintf( $config{'UnitPriceFormat'}, $self->price($qty_index)/$$self{'quantity'.$qty_index} );
} # end sub unit_price
sub m_price {
	my ( $self, $qty_index ) = @_;
	my $m_price = 0;
	my $services = $self->services();
	foreach my $type ( keys %$services ) {
		foreach my $service_id ( @{$$services{$type}} ) {
			my $specs = openprint::service::get_specs_ref( $self, $service_id );
			$m_price += $$specs{'MPrice'.$qty_index};	
		} # end foreach service_id
	} # end foreach type
	return sprintf( $config{'UnitPriceFormat'}, $m_price );
} # end sub m_price


sub Price {
	my ( $self, $index ) = @_;
	return { 'Cost'=>$$self{'price'.$index}, 'currency_id'=>$$self{'currency_id'}, 'Price'=>$$self{'price'.$index} };
} # end sub price

sub Order {
	my $self = shift;
	return new openprint::Order( $$self{'order_id'} );
}

sub signatures {
	my ( $self, $params ) = @_;

	my $services = $self->services();

	if ( $params and $$services{'Signature'} ) {
		my @sigs;
		foreach my $s_id ( @{$$services{'Signature'}} ) {
			my $specs = openprint::service::get_specs_ref( $self, $s_id );

			if ( $$params{'type'} ) {
				next if $$specs{'txtSignatureType'} ne $$params{'type'};
			} # end if
			if ( exists $$params{'Group'} ) {
				next if $$specs{'Group'} != $$params{'Group'};
			} # end if
			push @sigs, $s_id;
		} # end foreach signatures
		return @sigs;
	} # end if
	return @{$$services{'Signature'}} if $$services{'Signature'} and @{$$services{'Signature'}};

	return;
} # end sub signatures

sub status_change {
	my ( $self, $company_id, $user_id, $new_status ) = @_;
	$company_id = $openprint::session{'company_id'} if ! $company_id;
	$user_id = $openprint::session{'user_id'} if ! $user_id;

	$self->add_to_log( $company_id,$user_id, 'Marked '.$new_status );
	if ( $new_status eq 'Printed' ) {
		foreach $_ ( $self->signatures() ) {
			openprint::service::status( $$self{'id'}, $_, 'Complete' );
		} # end foreach signature
		foreach my $Job ( openprint::ScheduledJob->find('project_id'=>$$self{'id'}) ) {
			$Job->delete();
		} # end foreach
		foreach my $PA ( openprint::PaperAllocation->find('project_id'=>$$self{'id'}) ) {
			$PA->delete();
			$self->add_to_log( $company_id, $user_id, 'Freeing allocated paper: ' . $PA->quantity() . $PA->units() );
		} # end foreach AP
	} elsif ( sets::isin( $new_status, ['Bindery Complete' ] ) ) {
		foreach my $s_id ( $self->signatures() ) {
			openprint::service::status( $$self{'id'}, $s_id, 'Complete' );
		} # end foreach
		my $services = $self->services();
		openprint::service::status( $$self{'id'}, $$services{''}[0], 'Complete' ) if $$services{''};
		foreach my $s_id ( openprint::print_project::get_services_in_category( $openprint::log, $openprint::dbh, $$self{'id'}, 'Bindery' ) ) {
			openprint::service::status( $$self{'id'}, $s_id, 'Complete' );
		} # end foreach
		foreach my $Job ( openprint::ScheduledJob->find('project_id'=>$$self{'id'}) ) {
			$Job->delete();
		} # end foreach
		sql::execute( undef, undef, q{DELETE FROM Bindery_Schedule WHERE ProjectIndex=?}, $$self{'id'} );
		$self->update_status();
		foreach my $PA ( openprint::PaperAllocation->find('project_id'=>$$self{'id'}) ) {
			$PA->delete();
		} # end foreach AP

	} elsif ( sets::isin( $new_status, ['Shipped','Picked Up', 'Complete'] ) ) {
		sql::update( undef, undef, 'tbl_Project_Contents', ["lngProjectIndex=? AND strStatus != ''", $$self{id}], 'strStatus', 'Complete' );
# Remove jobs from the Schedule when marked complete.
		foreach my $Job ( openprint::ScheduledJob->find('project_id'=>$$self{'id'}) ) {
			$Job->delete();
		} # end foreach
		sql::execute( undef, undef, q{DELETE FROM Bindery_Schedule WHERE ProjectIndex=?}, $$self{'id'} );
		$self->status($new_status);
		foreach my $PA ( openprint::PaperAllocation->find('project_id'=>$$self{'id'}) ) {
			$PA->delete();
		} # end foreach AP
	} # end if
	$self->save();
	$self->Order()->update_status() if $self->order_id();
} # end sub status_change

sub User {
	return new openprint::User( $_[0]{'user_id'} );	
} # end sub User

# Was added when writing the PPF Monnitor, can be used to add a specific signature
sub add_signature {
	my ( $self, $sig_index, $status, $data ) = @_;
	
	my $ac = sql::start_transaction( $dbh );
	$dbh->do( 'LOCK TABLE tbl_Service_Specifications IN SHARE ROW EXCLUSIVE MODE' ) or $log->error( $dbh->errstr() );
	my ($print_service_index) = $self->add_service( 'Signature' );
	if ( ! $print_service_index ) {
		$log->error("Error adding Signature!");
		return;
	} # end if
	openprint::service::status( $self->id(), $print_service_index, $status );
	if ( ! $sig_index ) {
		$_ = q{SELECT MAX(strValue::integer) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
		( $sig_index ) = sql::execute( undef, undef, $_, $self->id() );
		$sig_index += 1;
	} # end if
	openprint::service::insert_service_spec( $log, $dbh, $self->id(), $print_service_index, 'SignatureIndex', $sig_index );
	sql::end_transaction( $dbh, $ac );
	return $print_service_index;
} # end sub add_signature

sub copy_signature {
    my ( $self, $sig_specs, $data, $status ) = @_;
    my $new_service_index = $self->add_signature( undef, $status );
	if ( ! $new_service_index ) {
		$log->error('Error copying signature.');
		return;
	} # end if
    my $new_specs = openprint::service::get_specs_ref( $self, $new_service_index );

	my $ac = sql::start_transaction( $dbh );
    foreach my $key ( openprint::Estimating::Printing::variables( $$self{'id'} ) ) {
		next if $key eq 'SignatureIndex';
		if ( exists $$data{$key} ) {
			openprint::service::insert_service_spec( $log, $dbh, $self->id(), $new_service_index, $key, $$data{$key}, ! exists $$new_specs{$key} );
		} else {
			openprint::service::insert_service_spec( $log, $dbh, $self->id(), $new_service_index, $key, $$sig_specs{$key}, ! exists $$new_specs{$key} );
		} # end if
    } # end foreach
    sql::end_transaction( $dbh, $ac );
    return $new_service_index;
} # end sub copy_signature

sub Template {
	return new openprint::QuoteLevel( $_[0]{'style_id'} );
} # end sub Template

sub get_due_date {
	my ( $self ) = @_;
	my $duedatedays = 0;
	foreach my $signature_service_index ( $self->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $self, $signature_service_index );
# Lookup how many days to add to due date
		if ( my @Equipment = openprint::Equipment->find( 'strid'=>$$sig_specs{'UsePress'} ) ) {
			( $_ ) = $Equipment[0]->specification('DueDateDays');
			if ( $_ > $duedatedays ) {
				$duedatedays = int $_;
			} # end if
		} # end if
	} # end foreach signature_service_index

	if ( ! $duedatedays ) {
		$duedatedays = 5;
	} # end if

	my $runtime = 0;
	foreach ( $self->signatures() ) {
		$runtime += openprint::service::get_runtime( $self, $_ );
	} # end foreach
	$duedatedays += int( $runtime / ( 24*60 ) );
	
	return sprintf('%.4d-%.2d-%.2d', misc::add_delta_business_days( Date::Calc::Today(), $duedatedays ) );
} # end sub get_due_date

sub Ordered_Product {
	my ( $self ) = @_;
	if ( ! exists $$self{'Ordered_Product'} ) {
		my @Products = openprint::OrderedProduct->find( 'project_id'=>$$self{'id'} );
		if ( @Products == 1 ) {
			$$self{'Ordered_Product'} = $Products[0];
		} elsif ( @Products ) {
			$log->error("More than 1 OrderedProduct returned in Project::OrderedProduct");
		} # end if
	} # end if
	return $$self{'Ordered_Product'};
} # end sub Ordered_Product

sub add_service {
	my ( $self, $type ) = @_;
    my $service_index = 0;

    my $ServiceType;
    if ( ref $type ne 'openprint::ServiceType' ) {
        if ( ! ( $ServiceType = openprint::ServiceType->find_one('name'=>$type) ) ) {
            $log->error("Service $type IS NOT in the system.");
            return;
        } # end if
    } else {
        $ServiceType = $type;
    } # end if

    # Make this all one transaction...
    my $ac = sql::start_transaction( $dbh );

    sql::insert( $log, $dbh, 'tbl_Project_Contents', 'lngProjectIndex', $$self{'id'}, 'strStatus', 'uncalculated', 'servicetype_id', $ServiceType->id() );
    ( $service_index ) = sql::execute( $log, $dbh, q{SELECT MAX(lngServiceIndex) FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $$self{'id'} );
	# Do this so that it doesn't try to load the specs, saving 1 db call.
	$openprint::service::specs_cache{$service_index} = {};
    openprint::service::insert_service_spec( $log, $dbh, $$self{'id'}, $service_index, 'ServiceType', $ServiceType->name(), 1 );
    $_ = q{SELECT strFieldName, strDefaultValue FROM tbl_Service_Defaults WHERE lngServiceTypeIndex=? OR lngServiceTypeIndex IS NULL ORDER BY lngServiceTypeIndex};
    my @defaults = sql::execute( $log, $dbh, $_, $ServiceType->id() );
    $_ = q{SELECT name, value FROM User_Service_Defaults WHERE servicetype_id=? AND user_id=?};
    push @defaults, sql::execute( $log, $dbh, $_, $ServiceType->id(), $openprint::session{'user_id'} );
    while ( @defaults ) {
        openprint::service::insert_service_spec( $log, $dbh, $$self{'id'}, $service_index, shift @defaults, shift @defaults, 1 );
    } # end while
    foreach my $qty_index ( $self->quantity_indexes() ) {
        openprint::service::insert_service_spec( $log, $dbh, $$self{'id'}, $service_index, "txtQuantity$qty_index", $self->quantity($qty_index), 1 );
    } # end foreach

    sql::end_transaction( $dbh, $ac );
    delete $$self{'Services'};
    delete $$self{'service_types'};
    delete $$self{'signatures'};
    return $service_index;
} # end sub add_service

sub started_on {
	my ( $self ) = @_;
	return sql::execute( undef, undef, q{ SELECT MIN(starttime) FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $$self{'id'} );
} # end sub started_on

sub takeover_on {
	my ( $self ) = @_;
	if ( ! $$self{'takeover_on'} ) {
		@$self{'takeover_on'} = sql::execute( undef, undef, q`SELECT MIN(dtmtimestamp) FROM Project_Log WHERE project_id=? AND (description LIKE 'Assigning%' OR description LIKE 'Taken Over by%' OR description LIKE 'Marked Approved' OR description LIKE 'Marked Proofs Out%' OR description LIKE 'Added Proof%' OR description LIKE 'Additional Charges%')`, $$self{'id'} );
	} # end if
	return $$self{'takeover_on'};
} # end sub takeover_on
sub takeover_on_seconds {
	return Date::Parse::str2time( $_[0]->takeover_on() );
} # end sub takeover_on_seconds

sub prepress_start_on {
	my ( $self ) = @_;
	if ( ! $$self{'prepress_start_on'} ) {
	@$self{'prepress_start_on'} = sql::execute( undef, undef, q`SELECT MIN(dtmtimestamp) FROM Project_Log WHERE project_id=? AND ( description IN ('Marked In Prepress') OR description LIKE 'Add to Order%' )`, $$self{'id'} );
	} # end if
	return $$self{'prepress_start_on'};
} # end sub prepress_start_on
sub prepress_start_on_seconds {
	return Date::Parse::str2time( $_[0]->prepress_start_on() );
} # end sub prepress_start_on_seconds

sub ordered_on {
	my ( $self ) = @_;
	if ( ! exists $$self{'ordered_on'} ) {
		@$self{'ordered_on'} = sql::execute( undef, undef, q`SELECT MAX(dtmtimestamp) FROM Project_Log WHERE project_id=? AND description LIKE 'Add to Order%'`, $$self{'id'} );
		if ( ! $$self{'ordered_on'} ) {
			$$self{'ordered_on'} = $self->Order()->created_on();
		} # end if
	} # end if
	return $$self{'ordered_on'};
} # end sub ordered_on

sub ordered_on_seconds {
	return Date::Parse::str2time( $_[0]->ordered_on() );
} # end sub ordered_on_seconds

sub completed_on {
	my ( $self ) = @_;
	if ( ! exists $$self{'completed_on'} ) {
		@$self{'completed_on'} = sql::execute( undef, undef, q`SELECT MAX(dtmtimestamp) FROM Project_Log WHERE project_id=? AND description IN ('Marked Waiting For Pickup','Marked Shipped','Marked Picked Up')`, $$self{'id'} );
	} # end if
	return $$self{'completed_on'};
} # end sub completed_on
sub completed_on_seconds {
	return Date::Parse::str2time( $_[0]->completed_on() );
} # end sub completed_on_seconds

sub printed_on {
	my ( $self ) = @_;
	if ( ! exists $$self{'printed_on'} ) {
		@$self{'printed_on'} = sql::execute( undef, undef, q`SELECT MAX(dtmtimestamp) FROM Project_Log WHERE project_id=? AND description IN ('Marked Printed')`, $$self{'id'} );
	} # end if
	return $$self{'printed_on'};
} # end sub printed_on

sub printed_on_seconds {
	return Date::Parse::str2time( $_[0]->printed_on() );
} # end sub printed_on_seconds

sub approved_on {
	my ( $self ) = @_;
	if ( ! exists $$self{'approved_on'} ) {
		@$self{'approved_on'} = sql::execute( undef, undef, q`SELECT MAX(dtmtimestamp) FROM Project_Log WHERE project_id=? AND description IN ('Marked Approved','Marked Proofs QA Approved')`, $$self{'id'} );
	} # end if
	return $$self{'approved_on'};
} # end sub approved_on
sub approved_on_seconds {
	return Date::Parse::str2time( $_[0]->approved_on() );
} # end sub approved_on_seconds

sub proofsout_on {
	my ( $self ) = @_;
	if ( ! exists $$self{'proofsout_on'} ) {
		@$self{'proofsout_on'} = sql::execute( undef, undef, q`SELECT MAX(dtmtimestamp) FROM Project_Log WHERE project_id=? AND description LIKE ('Marked Proofs Out%')`, $$self{'id'} );
	} # end if
	return $$self{'proofsout_on'};
} # end sub completed_on

sub proofsout_on_seconds {
	return Date::Parse::str2time( $_[0]->proofsout_on() );
} # end sub proofsout_on_seconds
#
sub production_seconds {
	my ( $self ) = @_;
	return $self->completed_on_seconds() - $self->approved_on_seconds();
} # end sub production_seconds

sub ordered_to_takeover_seconds {
	return $_[0]->takeover_on_seconds() - $_[0]->ordered_on_seconds();
} # end sub ordered_to_takeover_seconds
sub takeover_to_approved_seconds {
	return $_[0]->approved_on_seconds() - $_[0]->takeover_on_seconds();
} # end sub ordered_to_takeover_seconds
sub ordered_to_printed_seconds {
	return $_[0]->printed_on_seconds() - $_[0]->ordered_on_seconds();
} # end sub ordered_to_takeover_seconds

sub first_scheduled {
	my ( $self ) = @_;
	if ( ! exists $$self{'first_scheduled'} ) {
		@$self{'first_scheduled'} = sql::execute( undef, undef, q`SELECT MIN(dtmtimestamp) FROM Project_Log WHERE project_id=? AND (description LIKE 'Scheduled%' OR description LIKE '%bumped%' )`, $$self{'id'} );
	} # end if
	return $$self{'first_scheduled'};
} # end sub first_scheduled
sub first_scheduled_seconds {
	return Date::Parse::str2time( $_[0]->first_scheduled() );
} # end sub first_scheduled_seconds

sub last_scheduled {
	my ( $self ) = @_;
	if ( ! exists $$self{'last_scheduled'} ) {
		@$self{'last_scheduled'} = sql::execute( undef, undef, q`SELECT MAX(dtmtimestamp) FROM Project_Log WHERE project_id=? AND (description LIKE 'Scheduled%' OR description LIKE '%bumped%')`, $$self{'id'} );
	} # end if
	return $$self{'last_scheduled'};
} # end sub last_schedule
sub last_scheduled_seconds {
	return Date::Parse::str2time( $_[0]->last_scheduled() );
} # end sub last_scheduled_seconds

sub operator_id {
    my ( $self ) = @_;

	if ( ! $$self{'operator_id'} ) {
		my $services = $self->services();
		@$self{'operator_id'} = sql::execute( $log, $dbh, q{SELECT operator_id FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex=?}, $$self{id}, ( $$services{'Proofs'} ? $$services{'Proofs'}[0] : $$services{'FilmStripping'}[0] ) );
	} # end if
    return $$self{'operator_id'};
} # end sub Operator

sub Operator {
    my ( $self ) = @_;

	if ( ! $$self{'Operator'} ) {
		$$self{'Operator'} = new openprint::User( $self->operator_id() );
	} # end if
    return $$self{'Operator'};
} # end sub Operator

sub delivery_cost {
	my ( $self ) = @_;

	if ( ! exists $$self{'delivery_cost'} ) {
		my $services = $self->services();
		foreach my $ServiceType ( openprint::ServiceType->find('category'=>'Shipping') ) {
			next if ! $$services{$ServiceType->name()};
			foreach ( @{$$services{$ServiceType->name()}} ) {
				my $specs = openprint::service::get_specs_ref( $self, $_ );
				$$self{'delivery_cost'} += $$specs{'txtPrice'.$self->ordered_quantity_index()};	
			} # end foreach
		} # end foreach
	} # end if
	return $$self{'delivery_cost'};
} # end sub delivery_cost

sub production_cost {
	my ( $self ) = @_;


	if ( ! exists $$self{'production_cost'} ) {
		my @Shipping_Services = map { $_->name() } openprint::ServiceType->find('category'=>'Shipping');
		my $services = $self->services();
		foreach my $ServiceType ( keys %$services ) {
			next if sets::isin( $ServiceType, \@Shipping_Services );
			foreach ( @{$$services{$ServiceType}} ) {
				my $specs = openprint::service::get_specs_ref( $self, $_ );
				$$self{'production_cost'} += $$specs{'txtPrice'.$self->ordered_quantity_index()};	
			} # end foreach
		} # end foreach
	} # end if
	return $$self{'production_cost'};
} # end sub production_cost
sub Service {
	my ( $self, $service_id ) = @_;
	return new openprint::Project_Service( {'project_id'=>$$self{'id'}, 'service_id'=>$service_id} );
} # end sub Service

sub used_press_names {
	my $self = $_[0];
	my @results;
	foreach my $service_id ( $self->signatures() ) {
		my $Service = new openprint::Project_Service( {'project_id'=>$$self{'id'}, 'id'=>$service_id} );
		my $sig_specs = $Service->specs();
		if ( ! $$sig_specs{'UsePress'} ) {
			push @results, $$sig_specs{'ddmPress'.$self->ordered_quantity_index()};
		} else {
			push @results, $$sig_specs{'UsePress'};
		} # end if
	} # end foreach
	return sets::union( @results );	
} # end sub used_press_names

sub add_Service {
	my $service_id = $_[0]->add_service( $_[1] );
	return new openprint::Project_Service( {'project_id'=>$_[0]{'id'},'service_id'=>$service_id} );
} # end sub add_Service
1;
__END__
