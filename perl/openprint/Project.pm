package openprint::Project;
@ISA = qw(openprint::Object);

# This is the object-oriented version of the project module

use strict;
use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

use openprint::Currency;
use openprint::ProjectType;
use openprint::Company;
use openprint::Order;
use openprint::logs;
require openprint::print;
require Math::Units;

require sql;
require openprint::JDF;

my $debug = 1;

sub delete {
	my $self = shift;
	sql::update( undef, undef, 'tbl_Projects', ['Index=?', $$self{'id'}], ['strStatus', 'Deleted'] );
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
	foreach my $quote_id ( sql::execute( undef, undef, q{SELECT QuoteIndex FROM tbl_Quote_Details WHERE projectindex=?}, $$self{'id'} ) ) {
		my $Quote = new openprint::Quote( $quote_id );
		$Quote->add_log('Deleted Project ' . $$self{'id'} );
	} # end foreach
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM PressActivities WHERE project_id=?}, $$self{'id'} );
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM tbl_projects WHERE Index=?}, $$self{'id'} );
	sql::end_transaction( $openprint::dbh, $ac );
} # end sub delete

sub get_project_type {
	my ( $log, $dbh, $project_index ) = @_;
	$_ = "SELECT strValue FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName=?";
	( $_ ) = sql::execute( $log, $dbh, $_, $project_index, 'ProjectType' );
	return $_;
} # end sub

sub Type {
	my $self = shift;
	if ( @_ ) {
		my $ProjectType = shift;
		$$self{'type_id'} = $ProjectType->id();	
	} # end nif
	return new openprint::ProjectType( $$self{'type_id'} );
} # end sub Type

sub get_project_type_service_index {
	my ( $log, $dbh, $project_index ) = @_;
	$_ = "SELECT lngServiceIndex FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName=?";
	( $_ ) = sql::execute( $log, $dbh, $_, $project_index, 'ProjectType' );
	return $_;
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
	my %services = $self->get_services();
	my $printing_specs = openprint::service::get_specs_ref( $$self{'id'}, $services{''}[0] );
	
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

		my $Pages = $$sig_specs{'txtSpreadSize'}*$$sig_specs{'txtSignatureSpreadQuantity'.$self->ordered_quantity_index()};
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
		return 0 if $statuses{$_} eq 'Ordered';
	} # end foreac
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
				} else {
					$new_status = 'In Prepress';
				} # end if
			} # end if
		} else { # there isn't any ordered services
			if ( $$self{'shipping_type'} eq 'Customer Pickup' ) {
				if ( $$self{'status'} ne 'Picked Up' ) {
					$new_status = 'Waiting For Pickup';
				} # end if
			} elsif ( $$self{'shipping_type'} eq 'Delivery' ) {
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
			foreach my $qty_index ( 1 .. 3 ) {
				next if ! $$self{'quantity'.$qty_index};
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
	my %params = @_;
	my $sql = q{SELECT * FROM tbl_Projects WHERE 1>0};
	my @values;
	if ( $params{'id'} ) {
        if ( ref $params{'id'} eq 'ARRAY' ) {
            $sql .= ' AND Index IN ('.join(',', map {'?'} @{$params{'id'}} ) . ')';
            push @values, @{$params{'id'}};
        } else {
            $sql .= ' AND Index=?';
            push @values, $params{'id'};
        } # end if
    } # end if
	if ( $params{'id_start'} and $params{'id_end'} ) {
            $sql .= ' AND (Index BETWEEN ? AND ?)';
            push @values, @params{'id_start','id_end'};
	} elsif ( $params{'id_start'} ) {
            $sql .= ' AND Index >= ?';
            push @values, $params{'id_start'};
	} elsif ( $params{'id_end'} ) {
            $sql .= ' AND Index <= ?';
            push @values, $params{'id_end'};
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
				$sql .= q{ AND companyIndex IN (} . join(',', map {'?'} @{$params{'company_id'}}). ')';
				push @values, @{$params{'company_id'}};
			} else {
				$openprint::log->warn("EMpty company array passed to openprint::Project::find");
			} # end if
		} elsif ( ! defined $params{'company_id'} ) {
			$sql .= q{ AND companyindex IS NULL};
		} else {
			$sql .= q{ AND companyindex=?};
			push @values, $params{'company_id'};
		} # end if
	} # end if
	if ( $params{'user_id'} ) {
		if ( $params{'user_id'} =~ /\D/ ) {
			$sql .= " AND (UserIndex $params{'user_id'})";
		} else {
			$sql .= q{ AND (UserIndex=?)};
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
		$sql .= ' AND companyindex IN (SELECT index FROM Company WHERE lngsalesperson)=?';
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
				$sql .= q{ AND strStatus IN (} . join(',', map {'?'} @{$params{'status'}}). ')';
						push @values, @{$params{'status'}};
			} # end if
		} else {
			$sql .= q{ AND (strStatus=?)};
			push @values, $params{'status'};
		} # end if
	} # end if
	if ( $params{'used_press_name'} ) {
		if ( ref $params{'used_press_name'} eq 'ARRAY' ) {
			if ( @{$params{'used_press_name'}} ) {
				$sql .= ' AND (';
				$sql .= join(' OR ', map { q{(? IN (SELECT strValue FROM tbl_Service_Specifications WHERE lngProjectIndex=Index AND strName IN ( 'UsePress','ddmPress1','ddmPress2','ddmPress3')))} } @{$params{'used_press_name'}} );
				$sql .= ')';
				push @values, @{$params{'used_press_name'}};
			} else {
$openprint::log->debug("No presses in used_press_name");
			} # end if
		} else {
			$sql .= q{ AND ?::text IN (SELECT strValue FROM tbl_Service_Specifications WHERE lngProjectIndex=Index AND strName='UsePress')};
			push @values, $params{'used_press_name'};
		} # end if
    } # end if
    if ( $params{'estimated_press_name'} ) {
        $sql .= q{ AND ?::text IN (SELECT strValue FROM tbl_Service_Specifications WHERE lngProjectIndex=Index AND strName IN ('ddmPress1','ddmPress2','ddmPress3') )};
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
		$sql .= q{ AND (due_date >= ?};
		push @values, $params{'due_date_start'};
	} elsif ( $params{'due_date_end'} ) {
		$sql .= q{ AND (due_date <= ?};
		push @values, $params{'due_date_end'};
	} # end if
	if ( $params{'docket'} ) {
		$sql .= ' AND lngdocketnumber=?';
		push @values, $params{'docket'};
	} # end if
	$sql .= $params{'misc'} if $params{'misc'};
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " LIMIT $params{'limit'}" if $params{'limit'};
	
	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug("Error loading Projects ($sql) (@values) Reason: " . $openprint::dbh->errstr );
	} elsif ( ! @$data ) {
		$openprint::log->debug("No  Projects ($sql) (@values) " );
	} elsif ( $debug ) {
		$openprint::log->debug("Loading Projects ($sql) (@values) # of results:" . @$data );
	} # end if
	return map { new openprint::Project( $_->{index}, $_ ) } @$data;
} # end sub find

sub save {
	my ( $self, %hash ) = @_;

	@$self{ keys %hash } = @hash{keys %hash};

	$$self{'currency_id'} = $openprint::session{'Currency_id'} if ! $$self{'currency_id'};
	$$self{'company_id'} = $openprint::session{'company_id'} if ! $$self{'company_id'};
	$$self{'user_id'} = $openprint::session{'user_id'} if ! $$self{'user_id'};
	$$self{'status'} = 'uncalculated' if ! $$self{'status'};
	$$self{'predefined'} = '0' if $$self{'predefined'} != 1;
	my @sql = (
				'strProjectReference',	$$self{'reference'},
				'strComments',			$$self{'comments'},
				'CompanyIndex',		 	$$self{'company_id'},
				'UserIndex',			$$self{'user_id'},
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
				'predefined',			$$self{'predefined'} ? $$self{'predefined'} : 'N',
				'rush',					$$self{'rush'},
	);
	if ( ! $$self{'created_on'} ) {
		push @sql, 'dtmCreationDate','NOW()';
	} # end if

	my $ac = sql::start_transaction( $openprint::dbh );

	if ( ! $$self{'id'} ) {

		@$self{'id'} = sql::execute( $openprint::log, $openprint::dbh, q{SELECT nextval('lngProjectIndex_seq'::text)} );

		if ( my $e = sql::insert( $openprint::log, $openprint::dbh, 'tbl_Projects', 'Index',	@$self{'id'}, @sql ) ) {
			$openprint::dbh->rollback;
			sql::end_transaction( $openprint::dbh, $ac );
			return $e;
		} # end if
	} elsif ( $hash{'force_install'} ) {
		if ( my $e = sql::insert( $openprint::log, $openprint::dbh, 'tbl_Projects', 'Index',	@$self{'id'}, @sql ) ) {
			$openprint::dbh->rollback;
			sql::end_transaction( $openprint::dbh, $ac );
			return $e;
		} # end if
	} else {
		if ( my $e = sql::update( $openprint::log, $openprint::dbh, 'tbl_Projects', "Index=$$self{'id'}", @sql ) ) {
			$openprint::dbh->rollback;
			sql::end_transaction( $openprint::dbh, $ac );
			return $e;
		} # end if
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
	my @indexes;
	foreach my $qty_index ( 1 .. 3 ) {
		push @indexes, $qty_index if $$self{"quantity$qty_index"};
	} # end foreach qty_index
	return @indexes;
} # end sub quantity_indexes

sub quantities {
	my $self = shift;
	return @$self{'quantity1','quantity2','quantity3'};
} # end sub quantities

sub quantity {
	my ( $self, $index ) = @_;
	if ( $index eq 'Used' ) {
		return $self->ordered_quantity();
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
	} # end if
	return $$self{'quantity3'};
} # end sub quantity2

sub get {
	my $self = shift;
	return @$self{@_};
} # end sub get

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

		my $specs = openprint::service::get_specs_ref( $self->id(), $service_index );
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
		$data = $openprint::dbh->selectrow_hashref(
				q{SELECT *,daterequired, due_date, intquantityindex, cursalesprice FROM tbl_Projects LEFT OUTER JOIN Order_Contents ON OrderIndex=order_id AND lngProjectIndex=Index WHERE Index=?}
				, {}, $$self{'id'} );
		if ( ! $data ) {
			$openprint::log->error("Error loading Project $$self{'id'}: ".$openprint::dbh->errstr() );
		} # end if
	} # endif
	@$self{qw/id docket order_id company_id user_id reference comments design created_on updated_on quantity1 quantity2 quantity3 status mode programs otherprograms printingtype currency_id type_id price1 price2 price3 requested_date ordered_quantity_index ordered_price due_date predefined rush/} =
		@$data{qw/index lngdocketnumber order_id companyindex userindex strprojectreference strcomments strdesign dtmcreationdate dtmlastmodified intquantity1 intquantity2 intquantity3 strstatus strmode strprograms strotherprograms printingtype currency_id type_id price1 price2 price3 daterequired intquantityindex cursalesprice due_date predefined rush/};
	return;
} # end sub load

sub type {
	my $self = shift;
	return new openprint::ProjectType( $$self{'type_id'} );
} # end sub type

sub get_log {
	my ( $log, $dbh, $project_id ) = @_;

	$_ = q{SELECT Company_id, (SELECT strName FROM Company WHERE Index=Company_ID),
		User_Id, (SELECT strFirstName || ' ' || strLastName FROM Users
				WHERE Index=User_Id), to_char(dtmTimestamp,'HH12:MIpm MM/DD/YYYY'), Description FROM Project_Log WHERE Project_Id=? ORDER BY dtmTimestamp};
	return sql::execute( $log, $dbh, $_, $project_id );
} # end sub get_log

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
		my @data = sql::execute( $openprint::log, $openprint::dbh, q{SELECT (SELECT name FROM Service_Types WHERE id=servicetype_id), lngServiceIndex FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $$self{'id'} );
		while ( my ( $id, $index ) = splice @data, 0, 2 ) {
			push @{$results{$id}}, $index;
		} # end while
		$$self{'Services'} = \%results;
	} # end if
	return %{$$self{'Services'}};
} # end sub get_service_hash

sub services {
	my $self = shift;
	if ( ! exists $$self{'Services'} ) {
		my %results;
		my @data = sql::execute( $openprint::log, $openprint::dbh, q{SELECT (SELECT name FROM Service_Types WHERE id=servicetype_id), lngServiceIndex FROM tbl_Project_Contents WHERE lngProjectIndex=?}, $$self{'id'} );
		while ( my ( $id, $index ) = splice @data, 0, 2 ) {
			push @{$results{$id}}, $index;
		} # end while
		$$self{'Services'} = \%results;
	} # end if
	return $$self{'Services'};
} # end sub services

sub summary {
	my $self = shift;

	my $summary = $self->Type()->name() . ' ';

	my %services = $self->get_services();
	if ( $services{''} ) {
		my %specs = %{openprint::service::get_specs_ref( $self, $services{''}[0] )};
		if ( $specs{'Versions'} ) {
			$summary .= $specs{'Versions'} .= ' versions ';
		} # end if

		$specs{'txtFinalWidth'} *= 1;
		$specs{'txtFinalHeight'} *= 1;
		if ( $specs{'txtTotalPageQuantity'} ) {
			$summary .= sprintf( '%s&quot;x%s&quot; ', @specs{'txtFinalWidth','txtFinalHeight'});
			if ( $specs{'rdbCover'} eq 'Different' ) {
			$summary .= sprintf('%dpg+Cover ', $specs{'txtTotalPageQuantity'}-4 );
			} else {
			$summary .= sprintf('%dpg ', $specs{'txtTotalPageQuantity'} );
			$summary .= $specs{'rdbCover'}.' Cover';
			} # end if
		} else {
# normal printing services
			$specs{'txtWidth'} *= 1;
			$specs{'txtHeight'} *= 1;
			if ( $specs{'txtFinalWidth'} != $specs{'txtWidth'} or $specs{'txtFinalHeight'} != $specs{'txtHeight'} ) {
				if ( $services{'Folding'} ) {
				$summary .= sprintf( '%s&quot;x%s&quot; folded to %s&quot;x%s&quot; ',
						@specs{'txtWidth','txtHeight','txtFinalWidth','txtFinalHeight'});
				} else {
				$summary .= sprintf( '%s&quot;x%s&quot; -> %s&quot;x%s&quot; ',
						@specs{'txtWidth','txtHeight','txtFinalWidth','txtFinalHeight'});
				} # end if
			} else {
				$summary .= sprintf( '%s&quot;x%s&quot; ', @specs{'txtFinalWidth','txtFinalHeight'});
			} # end if
			$summary .= sprintf('%d%s%s/%d%s%s ',
					scalar openprint::Estimating::Printing::get_colours( \%specs, 'SideOne' ),
					$specs{'rdbAqueousSideOne'} ne 'None' ? '+AQ' : '',
					($specs{'SideOneUVCoatingType'} and $specs{'SideOneUVCoatingType'} ne 'None' ? '+UV' : ''),
					scalar openprint::Estimating::Printing::get_colours( \%specs, 'SideTwo' ),
					$specs{'rdbAqueousSideTwo'} ne 'None' ? '+AQ' : '',
					($specs{'SideTwoUVCoatingType'} and $specs{'SideTwoUVCoatingType'} ne 'None' ? '+UV' : ''),
 );
			if ( $specs{'rdbSuppliedStock'} eq 'Y' ) {
				$summary .= 'Customer Supplied Stock';
			} elsif ( $specs{'rdbSpecificStock'} eq 'Y' ) {
				$summary .= sprintf( 'on %s, %s, %s, %s', @specs{'txtSpecificStockBrand','txtSpecificStockFinish','txtSpecificStockColour','txtSpecificStockWeight'} );
			} else {
				$summary .= sprintf( 'on %s, %s, %s, %s', @specs{'ddmStockBrand','ddmStockFinish','ddmStockColour','ddmStockWeight'} );
			} # end if
		} # end if
		if ( $specs{'PrintingType'} ) {
			$summary .= ' printed ' . $specs{'PrintingType'};
		} elsif ( $specs{'chkOverridePrintingType1'} ) {
			$summary .= ' printed ' . $specs{'PrintingType1'};
		} elsif ( $specs{'chkOverridePrintingType2'} ) {
			$summary .= ' printed ' . $specs{'PrintingType2'};
		} elsif ( $specs{'chkOverridePrintingType3'} ) {
			$summary .= ' printed ' . $specs{'PrintingType3'};
		} # end if
	} # end if
	if ( $services{'Cutting'} ) {
		$summary .= ' Trim ';
	} # end if
	if ( $services{'SaddleStitching'} or $services{'LoopStitching'} ) {
		$summary .= ' Stitch ';
	} # end if
	if ( $services{'PlainCartons'} ) {
		$summary .= ' Boxes';
	} # end if
	if ( $services{'BulkSkids'} ) {
		$summary .= ' Skids';
	} # end if
	if ( $services{'Turnaround'} ) {
		my %specs = openprint::service::get_specifications_pairs( $openprint::log, $openprint::dbh, $$self{'id'}, $services{'Turnaround'}[0] );
		$summary .= sprintf(' in %ddays', $specs{'TurnaroundDays'} );
	} # end if
	return $summary;
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
	if ( ! exists $$self{'requested_date'} ) {
		@$self{'requested_date','ordered_quantity_index','shippingtype','ordered_price'} = sql::execute( undef, undef, q{SELECT daterequired, intquantityindex, shippingtype, cursalesprice FROM Order_Contents WHERE OrderIndex=? AND lngProjectIndex=?}, @$self{'order_id','id'} );
	} # end if
	return $$self{'requested_date'};
} # end sub requested_date

sub shippingtype {
	my $self = shift;
	if ( ! exists $$self{'shippingtype'} ) {
		@$self{'requested_date','ordered_quantity_index','shippingtype','ordered_price'} = sql::execute( undef, undef, q{SELECT daterequired, intquantityindex, shippingtype, cursalesprice FROM Order_Contents WHERE OrderIndex=? AND lngProjectIndex=?}, @$self{'order_id','id'} );
	} # end if
	return $$self{'shippingtype'};
} # end sub shippingtype
sub ordered_quantity {
	my $self = shift;
	if ( (! exists $$self{'ordered_quantity_index'}) and $$self{'order_id'} ) {
		@$self{'requested_date','ordered_quantity_index','shippingtype','ordered_price'} = sql::execute( undef, undef, q{SELECT daterequired, intquantityindex, shippingtype, cursalesprice FROM Order_Contents WHERE OrderIndex=? AND lngProjectIndex=?}, @$self{'order_id','id'} );
	} # end if
	return $$self{'quantity'.$self->ordered_quantity_index()};
} # end sub ordered_quantity
sub ordered_quantity_index {
	my $self = shift;
	if ( (! $$self{'ordered_quantity_index'}) and $$self{'order_id'} ) {
		@$self{'requested_date','ordered_quantity_index','shippingtype','ordered_price'} = sql::execute( undef, undef, q{SELECT daterequired, intquantityindex, shippingtype, cursalesprice FROM Order_Contents WHERE OrderIndex=? AND lngProjectIndex=?}, @$self{'order_id','id'} );
	} # end if
	if ( ! $$self{ordered_quantity_index} ) {
		my @qtys = $self->quantity_indexes();
$openprint::log->debug("Project ordered_qty_index @qtys ");
		if ( 1 == @qtys ) {
			return $qtys[0];
		} # end if
	} # end if
	return $$self{ordered_quantity_index};
} # end sub ordered_quantity_index
sub ordered_price {
	my $self = shift;
	if ( ! exists $$self{'ordered_price'} ) {
		@$self{'requested_date','ordered_quantity_index','shippingtype','ordered_price'} = sql::execute( undef, undef, q{SELECT daterequired, intquantityindex, shippingtype, cursalesprice FROM Order_Contents WHERE OrderIndex=? AND lngProjectIndex=?}, @$self{'order_id','id'} );
	} # end if
	return $$self{'ordered_price'} if $$self{'ordered_price'};
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
	my ( $self, $index ) = @_;
	return $$self{'price'.$index};
} # end sub price

sub Price {
	my ( $self, $index ) = @_;
	return { 'Cost'=>$$self{'price'.$index}, 'currency_id'=>$$self{'currency_id'}, 'Price'=>$$self{'price'.$index} };
} # end sub price

sub Order {
	my $self = shift;
	return new openprint::Order( $$self{'order_id'} );
}

sub signatures {
	my $self = shift;
	if ( ! exists $$self{'signatures'} ) {
		my $services = $self->services();
		#if ( $self->Type()->name() ne 'MultiPagePublication' ) {
		#} # end if
		if ( $$services{'AdditionalSignature'} ) {
			push @{$$self{'signatures'}}, @{$$services{'AdditionalSignature'}};
		} else {
			@{$$self{'signatures'}} = @{$$services{''}} if $$services{''};
		} # end if
	} # end if
	if ( @_ ) {
		my @sigs;
		my $type = shift;
		foreach my $s_id ( @{$$self{'signatures'}} ) {
			my $specs = openprint::service::get_specs_ref( $$self{'id'}, $s_id );
			push @sigs, $s_id if $$specs{'txtSignatureType'} eq $type;
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
        sql::execute( undef, undef, q{DELETE FROM Schedule WHERE ProjectIndex=?}, $self->id() );
		foreach my $PA ( openprint::PaperAllocation::find('project_id'=>$$self{'id'}) ) {
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
		sql::execute( undef, undef, q{DELETE FROM Schedule WHERE ProjectIndex=?}, $$self{'id'} );
		sql::execute( undef, undef, q{DELETE FROM Bindery_Schedule WHERE ProjectIndex=?}, $$self{'id'} );
		$self->update_status();
		foreach my $PA ( openprint::PaperAllocation::find('project_id'=>$$self{'id'}) ) {
			$PA->delete();
		} # end foreach AP

	} elsif ( sets::isin( $new_status, ['Shipped','Picked Up', 'Complete'] ) ) {
		sql::update( undef, undef, 'tbl_Project_Contents', ["lngProjectIndex=? AND strStatus != ''", $$self{id}], 'strStatus', 'Complete' );
# Remove jobs from the Schedule when marked complete.
		sql::execute( undef, undef, q{DELETE FROM Schedule WHERE ProjectIndex=?}, $$self{'id'} );
		sql::execute( undef, undef, q{DELETE FROM Bindery_Schedule WHERE ProjectIndex=?}, $$self{'id'} );
		$self->status($new_status);
		foreach my $PA ( openprint::PaperAllocation::find('project_id'=>$$self{'id'}) ) {
			$PA->delete();
		} # end foreach AP
	} # end if
	$self->save();
	$self->Order()->update_status();
} # end sub status_change

sub add_signature {
	my ( $self, $sig_index, $status, $data ) = @_;
	
	my $ac = sql::start_transaction( $dbh );
	$dbh->do( 'LOCK TABLE tbl_Service_Specifications IN SHARE ROW EXCLUSIVE MODE' ) or $log->error( $dbh->errstr() );
	my ($print_service_index) = openprint::print_project::insert_service( $log, $dbh, $self->id(), 'AdditionalSignature' );
	openprint::service::status( $self->id(), $print_service_index, $status );
	if ( ! $sig_index ) {
		$_ = q{SELECT MAX(strValue::integer) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
		my ( $sig_index ) = sql::execute( undef, undef, $_, $self->id() );
		$sig_index += 1;
	} # end if
	openprint::service::insert_service_spec( $log, $dbh, $self->id(), $print_service_index, 'SignatureIndex', $sig_index );
	sql::end_transaction( $dbh, $ac );

} # end sub add_signature

sub copy_signature {
    my ( $self, $sig_specs, $data ) = @_;
    my $new_service_index = openprint::print_project::insert_service( $log, $dbh, $self->id(), 'AdditionalSignature' );
    my $new_specs = openprint::service::get_specs_ref( $self, $new_service_index );
    my $ac = sql::start_transaction( $dbh );
    $dbh->do( 'LOCK TABLE tbl_Service_Specifications IN SHARE ROW EXCLUSIVE MODE' ) or $log->error( DBI->errstr );
    $_ = q{SELECT MAX(strValue::integer) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
    my ( $sig_index ) = sql::execute( undef, undef, $_, $self->id() );
    $sig_index += 1;
    openprint::service::insert_service_spec( $log, $dbh, $self->id(), $new_service_index, 'SignatureIndex', $sig_index );

    # Releases the lock
    $dbh->commit();

    foreach my $key ( openprint::Estimating::Printing::variables() ) {
		next if $key eq 'SignatureIndex';
        openprint::service::insert_service_spec( $log, $dbh, $self->id(), $new_service_index, $key, $$sig_specs{$key}, ! exists $$new_specs{$key} );
    } # end foreach

	if ( $data ) {
		foreach my $k ( keys %{$data} ) {
			openprint::service::insert_service_spec( $log, $dbh, $self->id(), $new_service_index, $k, $$data{$k} );
		} # end foreach k
	} # end if data

    sql::end_transaction( $dbh, $ac );
    return $new_service_index;
} # end sub copy_signature



1;

__END__
~		
