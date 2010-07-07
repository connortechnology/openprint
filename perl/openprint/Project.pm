package openprint::Project;
@ISA = qw(openprint::Object);

# This is the object-oriented version of the project module

use strict;
use openprint ();

use vars qw( $log $dbh %config $table $serial %fields );
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

my $debug = 1;

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
	'printingtype'	=>	'printingtype',
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

sub delete {
	my $self = shift;
	sql::update( undef, undef, $table, ['id=?', $$self{'id'}], ['strStatus', 'Deleted'] );
} # end sub delete

sub destroy {
	my $self = shift;
	my $ac = sql::start_transaction( $openprint::dbh );
	sql::update( undef, undef, 'Ordered_Products', ['project_id=?', $$self{'id'}], 'project_id', undef );
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
	my $self = shift;
	if ( @_ ) {
		my $ProjectType = shift;
		$$self{'type_id'} = $ProjectType->id();	
	} # end nif
	return new openprint::ProjectType( $$self{'type_id'} );
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
				if ( openprint::Estimating::Multipage::status( $$self{'id'}, undef, $qty_index ) ) {
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

sub find {
	my $self = shift;
	my %params = @_;
	my $sql = q{SELECT * FROM Projects WHERE 1>0};
	my @values;
	if ( $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('.join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( $params{'id_start'} and $params{'id_end'} ) {
			$sql .= ' AND (id BETWEEN ? AND ?)';
			push @values, @params{'id_start','id_end'};
	} elsif ( $params{'id_start'} ) {
			$sql .= ' AND id >= ?';
			push @values, $params{'id_start'};
	} elsif ( $params{'id_end'} ) {
			$sql .= ' AND id <= ?';
			push @values, $params{'id_end'};
	} # end if
	if ( $params{'id_like'} ) {
		$sql .= " AND id::text LIKE '$params{'id_like'}%'";
	} # end if

	if ( $params{'type_id'} ) {
		$sql .= ' AND type_id=?';
		push @values, $params{'type_id'};
    } # end if
	if ( exists $params{'predefined'} ) {
		if ( $params{'predefined'} ne '' ) {
			$sql .= ' AND predefined=?';
			push @values, $params{'predefined'};
		} # end if
	} # end if

	if ( $params{'reference'} ) {
		$sql .= q{ AND strprojectreference LIKE ?};
		push @values, '%'.$params{'reference'}.'%';
	} # en dif
	if ( exists $params{'company_id'} ) {
		if ( ref $params{'company_id'} eq 'ARRAY' ) {
			if ( @{$params{'company_id'}} ) {
				$sql .= q{ AND company_id IN (} . join(',', map {'?'} @{$params{'company_id'}}). ')';
				push @values, @{$params{'company_id'}};
			} else {
				$openprint::log->warn("EMpty company array passed to openprint::Project->find");
			} # end if
		} elsif ( ! defined $params{'company_id'} ) {
			$sql .= q{ AND company_id IS NULL};
		} else {
			$sql .= q{ AND company_id=?};
			push @values, $params{'company_id'};
		} # end if
	} # end if
	if ( $params{'user_id'} ) {
		if ( $params{'user_id'} =~ /\D/ ) {
			$sql .= " AND (user_id $params{'user_id'})";
		} else {
			$sql .= q{ AND (user_id=?)};
			push @values, $params{'user_id'};
		} # end if
	} # end if
	if ( $params{'created_on_start'} and $params{'created_on_end'} ) {
		$sql .= q{ AND (dtmcreationdate BETWEEN ? AND ?)};
		push @values, @params{'created_on_start','created_on_end'};
	} elsif ( $params{'created_on_start'} ) {
		$sql .= q{ AND (dtmcreationdate >= ?)};
		push @values, $params{'created_on_start'};
	} elsif ( $params{'created_on_end'} ) {
		$sql .= q{ AND (dtmcreationdate <= ?)};
		push @values, $params{'created_on_end'};
	} # end if
	if ( $params{'updated_on_start'} and $params{'updated_on_end'} ) {
		$sql .= q{ AND (dtmlastmodified BETWEEN ? AND ?)};
		push @values, @params{'updated_on_start','updated_on_end'};
	} elsif ( $params{'updated_on_start'} ) {
		$sql .= q{ AND (dtmlastmodified >= ?)};
		push @values, $params{'updated_on_start'};
	} elsif ( $params{'updated_on_end'} ) {
		$sql .= q{ AND (dtmlastmodified <= ?)};
		push @values, $params{'updated_on_end'};
	} # end if
	if ( $params{'updated_on_>='} ) {
		$sql .= q{ AND (dtmlastmodified >= ?)};
		push @values, $params{'updated_on_>='};
	} # end if
	if ( $params{'updated_on_<='} ) {
		$sql .= q{ AND (dtmlastmodified <= ?)};
		push @values, $params{'updated_on_<='};
	} # end if

	if ( $params{'take_over_start'} and $params{'take_over_end'} ) {
		$sql .= q{ AND ((SELECT MIN(starttime) FROM tbl_Project_Contents WHERE lngProjectIndex=id) BETWEEN ? AND ?)};
		push @values, @params{'take_over_start','take_over_end'};
	} elsif ( $params{'take_over_start'} ) {
		$sql .= q{ AND ((SELECT MIN(starttime) FROM tbl_Project_Contents WHERE lngProjectIndex=id) >= ?)};
		push @values, $params{'take_over_start'};
	} elsif ( $params{'take_over_end'} ) {
		$sql .= q{ AND ((SELECT MIN(starttime) FROM tbl_Project_Contents WHERE lngProjectIndex=id) <= ?)};
		push @values, $params{'take_over_end'};
	} # end if
	
	if ( $params{'ordered_on_start'} and $params{'ordered_on_end'} ) {
		$sql .= q{ AND ((SELECT dtmOrderDate FROM Orders WHERE Index=order_id) BETWEEN ? AND ?)};
		push @values, @params{'ordered_on_start','ordered_on_end'};
	} elsif ( $params{'ordered_on_start'} ) {
		$sql .= q{ AND ((SELECT dtmOrderDate FROM Orders WHERE Index=order_id) >= ?)};
		push @values, $params{'ordered_on_start'};
	} elsif ( $params{'ordered_on_end'} ) {
		$sql .= q{ AND ((SELECT dtmOrderDate FROM Orders WHERE Index=order_id) <= ?)};
		push @values, $params{'ordered_on_end'};
	} # end if

	if ( $params{'salesrep_id'} ) {
		$sql .= ' AND (SELECT employeeindex FROM Orders WHERE Index=order_id)=?';
		push @values, $params{'salesrep_id'};
	} # end if
	if ( $params{'csr_id'} ) {
		$sql .= ' AND ( company_id IN (SELECT id FROM Companies WHERE salesrep_id=?) )';
		push @values, $params{'csr_id'};
	} # end if

	if ( $params{'value_start'} and $params{'value_end'} ) {
		$sql .= q{ AND ( (price1 BETWEEN ? AND ? ) OR (price2 BETWEEN ? AND ?) OR (price3 BETWEEN ? AND ? ) )};
		push @values, @params{'value_start','value_end','value_start','value_end','value_start','value_end'};
	} elsif ( $params{'value_start'} ) {
		$sql .= q{ AND (price1 >= ? OR price2 >= ? OR price3 >= ?)};
		push @values, @params{'value_start','value_start','value_start'};
	} elsif ( $params{'value_end'} ) {
		$sql .= q{ AND (price1 <= ? OR price2 <= ? OR price3 <= ?)};
		push @values, @params{'value_end','value_end','value_end'};
	} # end if
	if ( $params{'status'} ) {
		if ( ref $params{'status'} eq 'ARRAY' ) {
			if ( @{$params{'status'}} ) {
				$sql .= q{ AND (strStatus IN (} . join(',', map {'?'} @{$params{'status'}}). ') )';
						push @values, @{$params{'status'}};
			} # end if
		} else {
			$sql .= q{ AND (strStatus=?)};
			push @values, $params{'status'};
		} # end if
	} # end if
	if ( exists $params{'reprint'} ) {
		if ( ref $params{'reprint'} eq 'ARRAY' ) {
			if ( @{$params{'reprint'}} ) {
				$sql .= q{ AND (reprint IN (} . join(',', map {'?'} @{$params{'reprint'}}). ') )';
						push @values, @{$params{'reprint'}};
			} # end if
		} elsif ( ! defined $params{'reprint'} ) {
			$sql .= q{ AND (reprint IS NULL)};
		} else {
			$sql .= q{ AND (reprint=?)};
			push @values, $params{'reprint'};
		} # end if
	} # end if
	if ( $params{'used_press_name'} ) {
		if ( ref $params{'used_press_name'} eq 'ARRAY' ) {
			if ( @{$params{'used_press_name'}} ) {
				$sql .= ' AND (';
				$sql .= join(' OR ', map { q{(? IN (SELECT strValue FROM tbl_Service_Specifications WHERE lngProjectIndex=Projects.id AND strName IN ( 'UsePress','ddmPress1','ddmPress2','ddmPress3')))} } @{$params{'used_press_name'}} );
				$sql .= ')';
				push @values, @{$params{'used_press_name'}};
			} else {
$openprint::log->debug("No presses in used_press_name");
			} # end if
		} else {
			$sql .= q{ AND ?::text IN (SELECT strValue FROM tbl_Service_Specifications WHERE lngProjectIndex=Projects.id AND strName='UsePress')};
			push @values, $params{'used_press_name'};
		} # end if
	} # end if
	if ( $params{'estimated_press_name'} ) {
		$sql .= q{ AND ?::text IN (SELECT strValue FROM tbl_Service_Specifications WHERE lngProjectIndex=Projects.id AND strName IN ('ddmPress1','ddmPress2','ddmPress3') )};
		push @values, $params{'estimated_press_name'};
	} # end if

	if ( $params{'due_date_start'} and $params{'due_date_end'} ) {
		$sql .= q{ AND (due_date BETWEEN ? AND ?};
		push @values, @params{'due_date_start','due_date_end'};
		if ( exists $params{'due_date'} and ! $params{'due_date'} ) {
			$sql .= q{ OR due_date IS NULL};
		} # end if
		$sql .= ')';
	} elsif ( $params{'due_date_start'} ) {
		$sql .= q{ AND due_date >= ?};
		push @values, $params{'due_date_start'};
	} elsif ( $params{'due_date_end'} ) {
		$sql .= q{ AND due_date <= ?};
		push @values, $params{'due_date_end'};
	} # end if
	if ( $params{'due_date_>='} ) {
		$sql .= q{ AND due_date >= ?};
		push @values, $params{'due_date_>='};
	} # end if
	if ( $params{'due_date_<='} ) {
		$sql .= q{ AND due_date <= ?};
		push @values, $params{'due_date_<='};
	} # end if
	if ( $params{'takenover_on_>='} ) {
		$sql .= q{ AND (SELECT MIN(dtmtimestamp) FROM Project_Log WHERE project_id=index AND description LIKE 'Taken Over by%') >= ?};
		push @values, $params{'takenover_on_>='};
	} # end if
	if ( $params{'takenover_on_<='} ) {
		$sql .= q{ AND (SELECT MAX(dtmtimestamp) FROM Project_Log WHERE project_id=index AND description LIKE 'Taken Over by%') <= ?};
		push @values, $params{'takenover_on_<='};
	} # end if
	if ( $params{'docket'} ) {
		$sql .= ' AND lngdocketnumber=?';
		push @values, $params{'docket'};
	} # end if
	if ( $params{'docket_>='} and $params{'docket_<='} ) {
		$sql .= ' AND ( lngdocketnumber BETWEEN ? AND ? )';
		push @values, @params{'docket_>=','docket_<='};
	} elsif ( $params{'docket_>='} ) {
		$sql .= ' AND lngdocketnumber >= ?';
		push @values, $params{'docket_>='};
	} elsif ( $params{'docket_<='} ) {
		$sql .= ' AND lngdocketnumber <= ?';
		push @values, $params{'docket_<='};
	} # end if
	$sql .= $params{'misc'} if $params{'misc'};
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " LIMIT $params{'limit'}" if $params{'limit'};
	
	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug("Error loading Projects ($sql) (@values) Reason: " . $openprint::dbh->errstr );
	} elsif ( ! @$data ) {
		$openprint::log->debug("No	Projects ($sql) (@values) " );
	} elsif ( $debug ) {
		$openprint::log->debug("Loading Projects ($sql) (@values) # of results:" . @$data );
	} # end if
	return map { new openprint::Project( $_->{id}, $_ ) } @$data;
} # end sub find

sub save {
	my ( $self, $hash ) = @_;

	@$self{ keys %{$hash} } = @$hash{keys %{$hash} };
	foreach my $qty_index ( $self->quantity_indexes() ) {
		$self->price( $qty_index, undef );
	} # end foreach

	$$self{'currency_id'} = $openprint::session{'Currency_id'} if ! $$self{'currency_id'};
	$$self{'company_id'} = $openprint::session{'company_id'} if ! $$self{'company_id'};
	$$self{'user_id'} = $openprint::session{'user_id'} if ! $$self{'user_id'};
	$$self{'status'} = 'uncalculated' if ! $$self{'status'};
	$$self{'predefined'} = '0' if $$self{'predefined'} != 1;
	my @sql = (
				'strProjectReference',	$$self{'reference'},
				'strComments',			$$self{'comments'},
				'company_id',		 	$$self{'company_id'},
				'user_id',				$$self{'user_id'},
				'intQuantity1',		 	( $$self{'quantity1'} ? $$self{'quantity1'} : undef ),
				'intQuantity2',		 	( $$self{'quantity2'} ? $$self{'quantity2'} : undef ),
				'intQuantity3',		 	( $$self{'quantity3'} ? $$self{'quantity3'} : undef ),
				'strStatus',			$$self{'status'},
				'strMode',				$$self{'mode'},
				'strDesign',			$$self{'design'},
				'dtmLastModified',		'NOW()',
				'currency_id',			$$self{'currency_id'},
				'type_id',				$$self{'type_id'},
				'price1',				$$self{'price1'},
				'price2',				$$self{'price2'},
				'price3',				$$self{'price3'},
				'strOtherPrograms',		$$self{'other_programs'},
				'strPrograms',			$$self{'programs'},
				'order_id',				$$self{'order_id'} ? $$self{'order_id'} : undef,
				'lngdocketnumber',		$$self{'docket'} ? $$self{'docket'} : undef,
				'due_date',				$$self{'due_date'} ? $$self{'due_date'} : undef,
				'style_id',			 $$self{'style_id'} ? $$self{'style_id'} : undef,
				'predefined',			$$self{'predefined'} ? $$self{'predefined'} : 'N',
				'rush',					$$self{'rush'},
				'summary',				$$self{'summary'},
				'reprint',				$$self{'reprint'},
				'reprint_reason',		$$self{'reprint_reason'},
	);
	if ( ! $$self{'created_on'} ) {
		push @sql, 'dtmCreationDate','NOW()';
	} # end if

	my $ac = sql::start_transaction( $openprint::dbh );

	if ( ! $$self{'id'} ) {

		@$self{'id'} = sql::execute( $openprint::log, $openprint::dbh, q{SELECT nextval('lngProjectIndex_seq'::text)} );

		if ( my $e = sql::insert( $openprint::log, $openprint::dbh, 'Projects', 'id',	@$self{'id'}, @sql ) ) {
			$openprint::dbh->rollback;
			sql::end_transaction( $openprint::dbh, $ac );
			return $e;
		} # end if
	} elsif ( $$hash{'force_install'} ) {
		if ( my $e = sql::insert( $openprint::log, $openprint::dbh, 'Projects', 'id',	@$self{'id'}, @sql ) ) {
			$openprint::dbh->rollback;
			sql::end_transaction( $openprint::dbh, $ac );
			return $e;
		} # end if
	} else {
		if ( my $e = sql::update( $openprint::log, $openprint::dbh, 'Projects', ['id=?', $$self{'id'}], \@sql ) ) {
			$openprint::dbh->rollback;
			sql::end_transaction( $openprint::dbh, $ac );
			return $e;
		} # end if
	} # end if
	if ( $$self{'order_id'} ) {
		sql::update( $log, $dbh, 'Order_Contents', ['OrderIndex=? AND lngProjectIndex=?', @$self{'order_id','id'} ], {
			'shippingtype'	=>	$$self{'shippingtype'},
			'daterequired'	=>	$$self{'requested_date'},
			'intquantity'	=>	$$self{'ordered_quantity_index'},
			'cursalesprice'	=>	$$self{'ordered_price'},
} );
			
	} # end if
	$self->load();
	sql::end_transaction( $openprint::dbh, $ac );
	return;
} # eend sub save

sub Currency {
	my $self = shift;
	if ( @_ ) {
		$$self{'currency_id'} = (shift)->id();
	} # end if
	return new openprint::Currency( $$self{'currency_id'} );
} # end sub Currency

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
	delete $$new{'id'};
	delete $$new{'created_on'};
	$new->save();

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
	@$self{qw/id summary docket order_id company_id user_id reference comments design created_on updated_on quantity1 quantity2 quantity3 status mode programs otherprograms printingtype currency_id type_id style_id price1 price2 price3 requested_date ordered_quantity_index ordered_price due_date predefined rush reprint reprint_reason/} =
		@$data{qw/id summary lngdocketnumber order_id company_id user_id strprojectreference strcomments strdesign dtmcreationdate dtmlastmodified intquantity1 intquantity2 intquantity3 strstatus strmode strprograms strotherprograms printingtype currency_id type_id style_id price1 price2 price3 daterequired intquantityindex cursalesprice due_date predefined rush reprint reprint_reason/};
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
	if ( ! $$self{ordered_quantity_index} ) {
		my @qtys = $self->quantity_indexes();
#$openprint::log->debug("Project ordered_qty_index @qtys ");
		if ( 1 == @qtys ) {
			return $qtys[0];
		} # end if
	} # end if
	return $$self{ordered_quantity_index};
} # end sub ordered_quantity_index

sub ordered_price {
	my $self = shift;
	return $$self{'ordered_price'} if $$self{'ordered_price'};
$openprint::log->debug("Ordered price: $$self{'ordered_price'}");
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
	if ( ! exists $$self{'signatures'} ) {
		my $services = $self->services();
		if ( ! sets::isin( $self->Type()->name(), [ 'MultiPagePublication', 'Newsletters','Magazines','Calendars' ] ) ) {
$openprint::log->debug("Project Type: " . $self->Type()->name() );
			@{$$self{'signatures'}} = @{$$services{''}} if $$services{''};
		} # end if
		if ( $$services{'AdditionalSignature'} ) {
			push @{$$self{'signatures'}}, @{$$services{'AdditionalSignature'}};
		} # end if
	} # end if

	if ( $params ) {
		my @sigs;
		foreach my $s_id ( @{$$self{'signatures'}} ) {
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

	if ( $$self{'signatures'} ) {
		return @{$$self{'signatures'}};
	} # end if
	return ();
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
	my ($print_service_index) = openprint::print_project::insert_service( $log, $dbh, $self->id(), 'AdditionalSignature' );
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
    my $new_specs = openprint::service::get_specs_ref( $self, $new_service_index );

	my $ac = sql::start_transaction( $dbh );
    foreach my $key ( openprint::Estimating::Printing::variables() ) {
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

	# Make it business days
	my ( $year, $month, $day ) = Date::Calc::Today();
	while ($duedatedays) {
		( $year, $month, $day ) = Date::Calc::Add_Delta_Days( $year, $month, $day, 1 );
		while ( 6 <= Date::Calc::Day_of_Week( $year, $month, $day ) ) {
			( $year, $month, $day ) = Date::Calc::Add_Delta_Days( $year, $month, $day, 1 );
		} # end while
		$duedatedays -= 1;
	} # end while

	return sprintf('%.4d-%.2d-%.2d', $year, $month, $day );

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
        if ( my @ServiceTypes = openprint::ServiceType->find('name'=>$type) ) {
            $ServiceType = $ServiceTypes[0];
        } else {
            $log->warn("Service $type IS NOT in the system.");
            return;
        } # end if
    } else {
        $ServiceType = $type;
    } # end if

    # Make this all one transaction...
    my $ac = sql::start_transaction( $dbh );

    sql::insert( $log, $dbh, 'tbl_Project_Contents', 'lngProjectIndex', $$self{'id'}, 'strStatus', 'uncalculated', 'servicetype_id', $ServiceType->id() );
    ( $service_index ) = sql::execute( $log, $dbh, q{SELECT MAX(lngServiceIndex) FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $$self{'id'} );
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
	return new openprint::Project_Service( {'project_id'=>$$self{'id'}, 'id'=>$service_id} );
} # end sub Service

1;
__END__
