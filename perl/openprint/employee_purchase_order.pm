use strict;
package openprint::employee_purchase_order;
require sql;
require openprint::PurchaseOrder;
require openprint::PurchaseOrder_Item;
require openprint::PurchaseOrder_Content;
require openprint::PurchaseOrder_Tax;
require openprint::PurchaseOrder_Department;
require openprint::Company_Category;
require openprint::Object_Asset;
require openprint::Object_Payment;
require CGI;

use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

sub save_supplier {
	my ( $p ) = @_;

	my $Company;
	my $ac = sql::start_transaction( $dbh );
$openprint::log->error("Already in transaction") if $ac;
	$dbh->do( 'LOCK TABLE Companies IN SHARE ROW EXCLUSIVE MODE' ) or $log->error( DBI->errstr );

	my @Companies = openprint::Company->find( 'name lc'=> lc openprint::Company->transform('name', $$p{vendor_name} ) );
	if ( ! @Companies ) {
		$Company = new openprint::Company();
		$Company->save({
				supplier		=> 'Y',
				name			=> $$p{vendor_name},
				business_name	=> $$p{vendor_name},
				address1		=> $$p{vendor_address1},
				address2		=> $$p{vendor_address2},
				city			=> $$p{vendor_city},
				state			=> $$p{vendor_state},
				country			=> $$p{vendor_country},
				postalcode		=> $$p{vendor_postalcode},
				phone			=> $$p{vendor_phone},
				fax				=> $$p{vendor_fax},
				} );
	} else {
		foreach my $C ( @Companies ) {
			if ( $C->supplier() eq 'Y' ) {
				$Company = $C;
				last;
			} # end if
		} # end foreach
		if ( ! $Company ) {
			$Company = $Companies[0];
			$Company->save( {supplier=>'Y'} );
		} # end if
	} # end if
	sql::end_transaction( $dbh, $ac );
	return $Company->id() if $Company;
	return;
} # end sub save_supplier

sub save_contact {
	my ( $p ) = @_;

	my $ac = sql::start_transaction( $dbh );
	$dbh->do( 'LOCK TABLE Users IN SHARE ROW EXCLUSIVE MODE' ) or $log->error( DBI->errstr );
	my $User = openprint::User->find_one( company_id=>$$p{supplier_id}, email => openprint::User->transform('email', $$p{vendor_email} ) );
	if ( ! $User ) {
		$User = new openprint::User();
		my ( $first, $last ) = $$p{'vendor_contact'} =~ /(\S+)\s*(\S*)/;
		$User->save( {
				'company_id'=>	$$p{'supplier_id'},
				'email'		=>	$$p{'vendor_email'},
				'firstname'	=>	$first,
				'lastname'	=>	$last,
				'phone'		=>	$$p{'vendor_phone'},
				'fax'		=>	$$p{'vendor_fax'},
				'sms'		=>	$$p{'vendor_sms'},
				'change_password'	=>	'N',
				'administrator'	=>	'N',
				'ftp_active'	=>	0,
				'web_active'	=>	0,
				} );
	} # end if
	sql::end_transaction( $dbh, $ac );
	return $$User{id};
} # end sub save_contact

sub save_contents {
	my ( $PO, $p ) = @_;
	my %types;

	my $ac = sql::start_transaction( $dbh );
	$dbh->do( "LOCK TABLE $openprint::PurchaseOrder_Item::table IN EXCLUSIVE MODE" ) or $log->error( DBI->errstr );
	$dbh->do( "LOCK TABLE $openprint::PurchaseOrder_Department::table IN EXCLUSIVE MODE" ) or $log->error( DBI->errstr );
	$dbh->do( "LOCK TABLE $openprint::PurchaseOrder_Content::table IN EXCLUSIVE MODE" ) or $log->error( DBI->errstr );

	foreach my $content_id ( ( map { $_->id() } $PO->Contents() ), 'new' ) {
		next if ( $content_id eq 'new' ) and ! $param{'qty-'.$content_id};
		my $Item;
		if ( $$p{'item-'.$content_id} ) {
			$Item = new openprint::PurchaseOrder_Item( $$p{'item_id-'.$content_id} );
			if ( $$p{supplier_id} ) {
				if ( ( ! $Item->id() ) or ( lc $Item->name() ne lc openprint::PurchaseOrder_Item->transform('name', $$p{'item-'.$content_id}) ) ) {
					$log->debug("Looking up (" . $$p{'item-'.$content_id}.') (' . $Item->name() );
					$Item = openprint::PurchaseOrder_Item->find_one(
							'company_id'	=>	$PO->company_id(),
							'vendor_id'		=>	$$p{'supplier_id'},
							'type_id'		=>	$$p{'type_id-'.$content_id},
							'name lc'		=>	lc openprint::PurchaseOrder_Item->transform('name',$$p{'item-'.$content_id}),
							'product lc'	=>	lc openprint::PurchaseOrder_Item->transform('product',$$p{'product-'.$content_id}),
							);
					if ( ! $Item ) {
						$Item = new openprint::PurchaseOrder_Item();
						$Item->save({
								'company_id'	=>	$PO->company_id(),
								'vendor_id'		=>	$$p{'supplier_id'},
								'type_id'		=>	$$p{'type_id-'.$content_id},
								'name'			=>	$$p{'item-'.$content_id}, 
								'price'			=>	$$p{'price-'.$content_id},
								'product'		=>	$$p{'product-'.$content_id},
								});
					} # end if
				} else {
					$log->debug("Item is " . $Item->name() );
				} # end if
				if ( $Item->price() != $$p{'price-'.$content_id} ) {
	# Update the latest price
					$Item->save({'price'=>$$p{'price-'.$content_id}});
				} # end if
			} # end if PO has supplier_id
		} else {
			$log->debug("No item for $content_id");
		} # end if

		my $Dept;
		if ( ( $$p{'dept_id-'.$content_id} eq 'new' ) or ! $$p{'dept_id-'.$content_id} ) {
			$Dept = openprint::PurchaseOrder_Department->find_one( 
					'name lc' => lc openprint::PurchaseOrder_Department->transform('name',$$p{'dept-'.$content_id}),
					);
			if ( ! $Dept ) {
				$Dept = new openprint::PurchaseOrder_Department();
				$Dept->save({'name'=>$$p{'dept-'.$content_id}});
			} # end if
		} else {
			$Dept = new openprint::PurchaseOrder_Department( $$p{'dept_id-'.$content_id} );
		} # end if

		my $C = new openprint::PurchaseOrder_Content( $content_id );

		$variable{'error'} .= $C->save( {
				po_id		=>	$PO->id(),
				qty			=>	$$p{'qty-'.$content_id},
				product		=>	$$p{'product-'.$content_id},
				item_id		=>	$$Item{'id'},
				description	=>	$$p{'description-'.$content_id},
				docket		=>	$$p{'docket-'.$content_id},
				price		=>	$$p{'price-'.$content_id},
				total		=>	$$p{'total-'.$content_id},
				type_id		=>	$$p{'type_id-'.$content_id},
				( $Dept ? ( 'department_id'	=>	$Dept->id() ) : ( ) ),
				});

		$types{$C->Type()->name()} = 1;
		if ( $C->docket() and ! ( $C->docket() =~ /\D/ ) ) {
			foreach my $P ( openprint::Project->find('docket'=>$C->docket()) ) {
				$P->add_to_log( @session{'company_id','user_id'}, 
						sprintf('<a href="/employee/purchase_order/view.html?po_id=%1$d">%2$s%3$s %4$s ordered on PO%1$d</a>',
							$PO->id(), $C->qty(), $C->units(), $C->description() ) );
			} # end foreach Project
		} # end if docket
	} # end foreach Content id
	sql::end_transaction( $dbh, $ac );
	return %types;
} # end sub save_contents

sub view {

	my $Me = new openprint::User( $session{user_id} );

	if ( $param{po_id} ne openprint::PurchaseOrder->transform('id', $param{po_id} ) ) {
		$variable{error} .= 'Invalid PO # given: ' . $param{po_id}.'<br/>';
		$variable{PurchaseOrder} = new openprint::PurchaseOrder();
		return;
	} # end if
	
	my $PO = new openprint::PurchaseOrder->find( id=>$param{po_id} );
	if ( ! $PO ) {
		$variable{error} .= 'Invalid PO # given: ' . $param{'po_id'}.'<br/>';
		$variable{PurchaseOrder} = new openprint::PurchaseOrder();
		return;
	} # end if
	if ( $param{'btnFunction'} eq 'Delete' ) {
		$variable{'error'} .= $PO->delete();
		if ( ! $variable{'error'} ) {
			my $L = new openprint::PurchaseOrder_Log();
			$L->save({
					'user_id'	=>	$session{'user_id'},
					'po_id'		=>	$PO->id(),
					'reason'	=>	'deleted.' . $param{'reason'},
					});
			delete $param{'po_id'};
			delete $param{'btnFunction'};
			$variable{'ExternalRedirect'} = '/employee/purchase_order/history.html';
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Cancel' ) {
		$variable{'error'} .= $PO->save({'cancelled'=>1});
		if ( ! $variable{'error'} ) {
			my $L = new openprint::PurchaseOrder_Log();
			$L->save({
					'user_id'	=>	$session{'user_id'},
					'po_id'		=>	$PO->id(),
					'reason'	=>	'Cancelled: '. $param{'reason'},
					});
			delete $param{'po_id'};
			delete $param{'btnFunction'};
			$variable{'ExternalRedirect'} = '/employee/purchase_order/history.html';
		} # end if
	} elsif ( $param{'btnFunction'} eq 'UnCancel' ) {
		$variable{'error'} .= $PO->save({'cancelled'=>0});
		if ( ! $variable{'error'} ) {
			my $L = new openprint::PurchaseOrder_Log();
			$L->save({
					'user_id'	=>	$session{'user_id'},
					'po_id'		=>	$PO->id(),
					'reason'	=>	'Un-Cancelled: '. $param{'reason'},
					});
			delete $param{'po_id'};
			delete $param{'btnFunction'};
			$variable{'ExternalRedirect'} = '/employee/purchase_order/history.html';
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Undelete' ) {
		$variable{'error'} .= $PO->undelete();
		if ( ! $variable{'error'} ) {
			my $L = new openprint::PurchaseOrder_Log();
			$L->save({
					'user_id'	=>	$session{'user_id'},
					'po_id'		=>	$PO->id(),
					'reason'	=>	'undeleted.',
					});
			delete $param{'po_id'};
			delete $param{'btnFunction'};
			$variable{'ExternalRedirect'} = '/employee/purchase_order/history.html';
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Authorize' ) {
		if ( $PO->can_authorize() ) {
			if ( $_ = $PO->authorize() ) {
				$variable{error} .= $_ . '<br/>';
			} else {
				$variable{information} .= 'PO ' . $$PO{id} . ' has been authorized.<br/>';
			} # end if
		} else {
			$variable{error} .= 'You are not authorized to approve PO ' . $PO->id() . '<br/>';
		} # end if
		$variable{'ExternalRedirect'} = '/employee/purchase_order/history.html' if ! $variable{error};
    } elsif ( $param{'btnFunction'} eq 'AuthorizeAndSend' ) {
		if ( $PO->can_authorize() ) {
			if ( $_ = $PO->authorize() ) {
				$variable{error} .= $_ . '<br/>';
			} else {
				$variable{information} .= 'PO ' . $$PO{id} . ' has been authorized.<br/>';
				$variable{error} .= $PO->send_to_vendor();
			} # end if
		} else {
			$variable{error} .= 'You are not authorized to approve PO ' . $PO->id() . '<br/>';
		} # end if
		$variable{'ExternalRedirect'} = '/employee/purchase_order/history.html' if ! $variable{error};
	} elsif ( $param{'btnFunction'} eq 'Send' ) {
	} elsif ( $param{'btnFunction'} eq 'Email Vendor' ) {
		$variable{'error'} = $PO->send_to_vendor();
		$variable{'ExternalRedirect'} = '/employee/purchase_order/history.html' if ! $variable{error};
	} elsif ( $param{'btnFunction'} eq 'Email Me' ) {
		$variable{'error'} = $PO->send_to_me();
		$variable{'ExternalRedirect'} = '/employee/purchase_order/view.html?po_id='.$PO->id();
	} elsif ( $param{'btnFunction'} eq 'Received' ) {
	} elsif ( $param{'btnFunction'} eq 'Copy' ) {
		my $New = $PO->copy();
		if ( ! ( $variable{'error'} = $New->save() ) ) {
			foreach my $C ( $PO->Contents() ) {
				$C = $C->copy();
				$C->po_id( $New->id() );
				$C->save();
			} # end foreach
			$New->save();
			$variable{'information'} .= 'PO ' . $PO->id() . ' copied to PO ' . $New->id() .'<br/>';
			my $L = new openprint::PurchaseOrder_Log();
			$L->save({
					'user_id'	=>	$session{'user_id'},
					'po_id'		=>	$New->id(),
					'reason'	=>	'Copied from PO '. $PO->id(),
					});
			$L = new openprint::PurchaseOrder_Log();
			$L->save({
					'user_id'	=>	$session{'user_id'},
					'po_id'		=>	$PO->id(),
					'reason'	=>	'Copied to PO '. $New->id(),
					});
			$PO = $New;
		} # end if
		if ( $PO->total() ) {
			if ( $PO->can_authorize() ) {
				$variable{error} .= $PO->save({
						'authorized'	=> 1,
						'authorized_on'	=> 'NOW()',
						'authorized_by'	=> $session{user_id},
						});
			} else {
				$variable{error} .= $PO->save({
						'authorized'	=> 0,
						'authorized_on'	=> undef,
						'authorized_by'	=> undef,
						});
			} # end if 
		} # end if
	} elsif ( $param{'btnFunction'} eq 'AuthRequest' ) {
		$variable{information} .= $PO->send_approval_required_notification();
		if ( ! $variable{information} ) {
			$variable{warning} .= 'This PO needs approval but no one could be found to do it.';
		} else {
			$variable{information} =~ s/Sent/send/g;
			$variable{information} = 'Approval request ' . $variable{information};
			my $L = new openprint::PurchaseOrder_Log();
			$L->save({
					'user_id'	=>	$session{user_id},
					'po_id'		=>	$PO->id(),
					'reason'	=>	$variable{information}
					});
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Attach' ) {
		my $Asset = new openprint::Asset();
		$variable{'error'} .= $Asset->save({ 'name'	=>	$param{asset_name}, 'filename' => $param{filename} } );
		if ( ! $variable{'error'} ) {
			$variable{'information'} .= 'Information successfully stored.<br/>';
		} # end if
		if ( $param{'filename'} ) {
			my $upload = $r->upload('filename');
			if ( ! $upload ) {
				$Asset->save({'filename'=>''});
				$variable{'error'} .= "There was no upload for $param{'filename'}<br/>";
			} elsif ( ! $upload->link( $Asset->on_disk_path() ) ) {
				$variable{'error'} .= "There was an error saving file $param{'filename'} to " . $Asset->on_disk_path() . ": $!<br/>";
				$Asset->save({'filename'=>''});
			} else {
				$variable{'information'} .= "File $param{'filename'} was uploaded successfully.<br/>";
			} # end if
		} # end if
		if ( $Asset->id() ) {
			my $PO_Asset = new openprint::Object_Asset();
			$variable{'error'} .= $PO_Asset->save({'object_id'=>$param{'po_id'},'object_type'=>'openprint::PurchaseOrder','asset_id'=>$Asset->id()});
			if ( ! $variable{error} ) {
				$variable{ExternalRedirect} = '/employee/purchase_order/view.html?po_id='.$PO->id();
			} # end if
		} # end if
		%param = ();
	} # end if btnFunction

	$variable{'PurchaseOrder'} = $PO;
} # end sub view

sub edit {

	my $Me = new openprint::User( $session{'user_id'} );
	my $PO = new openprint::PurchaseOrder( $param{'po_id'} );

	if ( $param{'btnFunction'} eq 'New' ) {
		my $Label = new openprint::Label( $param{'label_id'} );
		my $C = $Me->Company();
		
		my $Project = $Label->Project();
		if ( ! ( $Project and $Project->company_id() ) ) {
			$variable{error} .= 'No project for label.';
			return;
		} # end if

		$variable{'error'} .= $PO->save( {
				created_by			=>	$session{'user_id'}, 
				company_id			=>	$Me->company_id(),
				supplier_id			=>	$Project->company_id(),
				currency_id			=>	openprint::Currency::get_current()->id(),
				created_by			=>	$Me->id(),
				shipto_contact		=>	$Me->name(),
				shipto_name			=>	$C->name(),
				shipto_address1		=>	$C->address1(),
				shipto_address2		=>	$C->address2(),
				shipto_city			=>	$C->city(),
				shipto_state		=>	$C->state(),
				shipto_country		=>	$C->country(),
				shipto_postalcode	=>	$C->postalcode(),
				shipto_phone		=>	$C->phone(),
				shipto_mobile		=>	$Me->mobile(),
				shipto_fax			=>	$C->fax(),
				shipto_email		=>	$Me->email(),
				shipto_sms			=>	$Me->sms(),
				} );
$log->debug("Creating PO $$PO{id} from label $variable{error}");
		
		my $C = new openprint::PurchaseOrder_Content();
		$C->save( {
			'po_id'		 => 	$PO->id(),
			'qty'			=>	1,
			'item'			=>	'Shipping',
			'description'	=>	'From: ' . $Label->get_data('from') . ' To: ' . $Label->get_data('to'),
			'docket'		=>	$Label->Project()->docket(),
			'type'			=> 'Other',
			});
	
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		if ( ! $param{po_id} ) {
			$variable{error} .= $PO->save( { created_by	=> $session{user_id}, company_id => $Me->company_id() } );
		} # end if

		$param{supplier_id} = save_supplier( \%param ) if ( ! $param{supplier_id} ) and $param{vendor_name};
		if ( $param{supplier_id} and $param{vendor_name} ) {
			my $Supplier = openprint::Company->find_one( id=>$param{supplier_id} );
			if ( ! $Supplier ) {
				$log->error("SUpplier not found!");
			} else {
				if ( ! $Supplier->name() ) {
					$Supplier->name($param{vendor_name});
					foreach ( 'country', 'state', 'address1', 'address2', 'city', 'postalcode', 'phone', 'fax' ) {	
						$$Supplier{$_} = $param{"vendor_$_"} if ( ! $$Supplier{$_}) and $param{"vendor_$_"};
					} # end foreach
					$Supplier->save();
				} # end if
			} # end if
		} # end if
		
		$param{contact_id} = save_contact( \%param ) if $param{supplier_id} and ( ! $param{contact_id} ) and $param{contact_name};
		my %types = save_contents( $PO, \%param );

		if ( $param{'delivered_on_switch'} eq 'DATE' ) {
			$param{'delivered_on'} = sprintf('%.4d-%.2d-%.2d', @param{'delivered_on_year','delivered_on_month','delivered_on_day'}) if ! $param{'delivered_on'};
		} else {
			$param{'delivered_on'} = undef;
		} # end if

		# We start locking here, because we load the taxes here. Taxes are where the locking becomes important.
		my $ac = sql::start_transaction( $dbh );
		$dbh->do( "LOCK TABLE $openprint::PurchaseOrder_Tax::table IN EXCLUSIVE MODE" ) or $log->error( DBI->errstr );

		# Theoretically, the taxes in params are up to date, because any change in country would update them.
		# This must happen before saving because charging or not for a tax alters the total.
		foreach my $Tax ( $PO->Taxes() ) {
			# Order is important here. Also the 1* turns an undef value into a specific boolean 0, because we used a checkbox
			$Tax->charge(1*$param{'tax_charge-'.$Tax->tax_id()}) if $Tax->charge() != 1*$param{'tax_charge-'.$Tax->tax_id()};
		} # end foreach
		# Save will recalc taxes as well.
		$variable{error} .= $PO->save( \%param );

		if ( $PO->total() ) {
			$param{authorized} = $PO->can_authorize();
			if ( $param{authorized} ) {
				if ( ! $PO->authorized() ) {
					$param{authorized_on} = 'NOW()';
					$param{authorized_by} = $session{user_id},
				} # end if
			} else {
			} # end if wasn't already authorized
		} # end if

		# Save will recalc taxes as well.
		$variable{error} .= $PO->save( \%param );
		sql::end_transaction( $dbh, $ac );

		if ( ( ! $variable{'error'} ) and $param{'reason'} ) {
			my $L = new openprint::PurchaseOrder_Log();
			$L->save({
				'user_id'	=>	$session{user_id},
				'po_id'		=>	$PO->id(),
				'reason'	=>	$param{reason},
				});
		} # end if
		my @companies = ( $PO->company_id(), $PO->supplier_id() );
		my @notifications = $PO->notifications(); # returns user_ids
		my @new_notifications = @notifications;
		if ( $PO->is_FSC() or $PO->is_PEFC() ) {
			@new_notifications = sets::union( @new_notifications, map { $PO->can_view( $_->User() ) ? $_->user_id() : () } openprint::User_Notification->find( type=>'FSC/PEFC Notifications', value=>'Yes', company_id=>\@companies ) );
		} # end if
		foreach my $type ( keys %types ) {
			@new_notifications = sets::union( @new_notifications, map { $PO->can_view( $_->User() ) ? $_->user_id() : () } openprint::User_Notification->find( type=>'PO ' . $type . ' Notifications', value=>'Yes', company_id=>\@companies ) );
		} # end foreach
		if ( scalar @notifications != scalar @new_notifications ) {
			$PO->notifications(\@new_notifications);
		} # end if
		if ( ! $variable{error} ) {
			if ( ! $param{po_id} ) {
				$variable{ExternalRedirect} = '/employee/purchase_order/edit.html?po_id='.$PO->id();
			} else {
				$variable{ExternalRedirect} = '/employee/purchase_order/view.html?po_id='.$PO->id();
			} # end if
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Attach' ) {
		$param{supplier_id} = save_supplier( \%param ) if ( ! $param{supplier_id} ) and $param{vendor_name};
		$param{contact_id} = save_contact( \%param ) if ! $param{contact_id};
		my %types = save_contents( $PO, \%param );
		foreach my $Tax ( $PO->Taxes() ) {
			# Order is important here. Also the 1* turns an undef value into a specific boolean 0, because we used a checkbox
			$Tax->charge(1*$param{'tax_charge-'.$Tax->id()}) if $Tax->charge() != 1*$param{'tax_charge-'.$Tax->id()};
			$Tax->amount(undef);
			$Tax->save();
		} # end foreach
		$variable{'error'} .= $PO->save( \%param );

		my $Asset = new openprint::Asset();
		$variable{'error'} .= $Asset->save({ 'name'	=>	$param{asset_name}, 'filename' => $param{filename} } );
		if ( ! $variable{'error'} ) {
			$variable{'information'} .= 'Information successfully stored.<br/>';
		} # end if
		if ( $param{'filename'} ) {
			my $upload = $r->upload('filename');
			if ( ! $upload ) {
				$Asset->save({'filename'=>''});
				$variable{'error'} .= "There was no upload for $param{'filename'}<br/>";
			} elsif ( ! $upload->link( $Asset->on_disk_path() ) ) {
				$variable{'error'} .= "There was an error saving file $param{'filename'} to " . $Asset->on_disk_path() . ": $!<br/>";
				$Asset->save({'filename'=>''});
			} else {
				$variable{'information'} .= "File $param{'filename'} was uploaded successfully.<br/>";
			} # end if
		} # end if
		if ( $Asset->id() ) {
			my $PO_Asset = new openprint::Object_Asset();
			$variable{'error'} .= $PO_Asset->save({'object_id'=>$param{'po_id'},'object_type'=>'openprint::PurchaseOrder','asset_id'=>$Asset->id()});
			if ( ! $variable{error} ) {
				$variable{ExternalRedirect} = '/employee/purchase_order/edit.html?po_id='.$PO->id();
			} # end if
		} # end if
		%param = ();

	} # end if btnFunction

	if ( ! $PO->id() ) {
		my $C = $Me->Company();
		$PO->set( {
			'currency_id'		=>	openprint::Currency::get_current()->id(),
			'company_id'		=>	$C->id(),
			'created_by'		=>	$Me->id(),
			'shipto_contact'	=>	$Me->name(),
			'shipto_name'		=>	$C->name(),
			'shipto_address1'	=>	$C->address1(),
			'shipto_address2'	=>	$C->address2(),
			'shipto_city'		=>	$C->city(),
			'shipto_state'		=>	$C->state(),
			'shipto_country'	=>	$C->country(),
			'shipto_postalcode'	=>	$C->postalcode(),
			'shipto_phone'		=>	$C->phone(),
			'shipto_mobile'		=>	$Me->mobile(),
			'shipto_fax'		=>	$C->fax(),
			'shipto_email'		=>	$Me->email(),
			'shipto_sms'		=>	$Me->sms(),
		} );
	} # end if
	$variable{'PurchaseOrder'} = $PO;
} # end sub edit

sub history {
	if ( $param{'btnFunction'} eq 'Delete' ) {
		foreach my $po_id ( ref $param{'po_id'} eq 'ARRAY' ? @{$param{'po_id'}} : $param{'po_id'} ) {
			my $PO = new openprint::PurchaseOrder( $po_id );
			if ( $_ = $PO->delete() ) {
				$variable{'error'} .= $_ . '<br/>';
			} else {
				my $L = new openprint::PurchaseOrder_Log();
				$L->save({
						'user_id'	=>	$session{'user_id'},
						'po_id'		=>	$PO->id(),
						'reason'	=>	'deleted.',
						});
				$variable{'information'} .= 'PO ' . $po_id . ' has been deleted.<br/>';
			} # end if
		} # end foreach po_id
		delete $param{'po_id'};
	} elsif ( $param{'btnFunction'} eq 'Undelete' ) {
		foreach my $po_id ( ref $param{'po_id'} eq 'ARRAY' ? @{$param{'po_id'}} : $param{'po_id'} ) {
			my $PO = new openprint::PurchaseOrder( $po_id );
			if ( $_ = $PO->undelete() ) {
				$variable{'error'} .= $_ . '<br/>';
			} else {
				my $L = new openprint::PurchaseOrder_Log();
				$L->save({
						'user_id'	=>	$session{'user_id'},
						'po_id'		=>	$PO->id(),
						'reason'	=>	'undeleted.',
						});
			} # end if
		} # end foreach
		delete $param{'po_id'};
	} elsif ( $param{'btnFunction'} eq 'Authorize' ) {
		foreach my $po_id ( ref $param{po_id} eq 'ARRAY' ? @{$param{po_id}} : $param{po_id} ) {
			my $PO = new openprint::PurchaseOrder( $po_id );
			next if ! $PO->id();
			if ( $PO->can_authorize() ) {
				if ( $_ = $PO->authorize() ) {
					$variable{error} .= $_ . '<br/>';
				} else {
					$variable{information} .= 'PO ' . $po_id . ' has been authorized.<br/>';
				} # end if
			} else {
				$variable{error} .= 'You are authorized to approve PO ' . $PO->id() . '<br/>';
			} # end if
		} # end foreach po_id
		delete $param{'po_id'};
    } elsif ( $param{'btnFunction'} eq 'AuthorizeAndSend' ) {
        foreach my $po_id ( ref $param{po_id} eq 'ARRAY' ? @{$param{po_id}} : $param{po_id} ) {
            my $PO = new openprint::PurchaseOrder( $po_id );
            next if ! $PO->id();
            if ( $PO->can_authorize() ) {
                if ( $_ = $PO->authorize() ) {
                    $variable{error} .= $_ . '<br/>';
                } else {
                    $variable{information} .= 'PO ' . $po_id . ' has been authorized.<br/>';
					$variable{error} .= $PO->send_to_vendor();
                } # end if
            } else {
                $variable{error} .= 'You are authorized to approve PO ' . $PO->id() . '<br/>';
            } # end if
        } # end foreach po_id
        delete $param{'po_id'};

	} elsif ( $param{'btnFunction'} eq 'Decline' ) {
		foreach my $po_id ( ref $param{'po_id'} eq 'ARRAY' ? @{$param{'po_id'}} : split(',',$param{'po_id'}) ) {
			my $PO = new openprint::PurchaseOrder( $po_id );
			if ( $_ = $PO->decline( $param{'reason'} ) ) {
				$variable{'error'} .= $_ . '<br/>';
			} else {
				$variable{'information'} .= 'PO ' . $po_id . ' has been declined.<br/>';
			} # end if
		} # end foreach po_id
		delete $param{'po_id'};
	} # end if
	_history();
	ssi::setup_date_select( '/employee/purchase_order/history.html', 'starting_start', -7 );
	ssi::setup_date_select( '/employee/purchase_order/history.html', 'starting_end', '' );
	$session{'/employee/purchase_order/history.html?cancelled'} = '0' if ! exists $session{'/employee/purchase_order/history.html?cancelled'};

} # end sub history

sub _history {
	ssi::save_params( '/employee/purchase_order/history.html', ( 
				( map { 'starting_start_'.$_ } ( 'year', 'month','day' ) ),
				( map { 'starting_end_'.$_ } ( 'year', 'month','day' ) ),
				'authorized', 'supplier_id','created_by','deleted','types', 'item_id', 'cancelled', 'vendor_category_id', 'department_id', 'docket' ) );
} # end sub _purchase_orders

sub _po_autocomplete {
} # end sub _po_autocomplete

sub _po_select_contact {
} # end sub _po_select_contact

sub _purchase_order_supplier_address {
	my $PO = new openprint::PurchaseOrder( $param{'po_id'} );
	$PO->supplier_id( $param{'supplier_id'} );
	$PO->save() if $PO->id();
	$variable{'PurchaseOrder'} = $PO;
} # end sub _purchase_order_supplier_address

sub _po_content_line {
	my $PO = new openprint::PurchaseOrder( $param{'po_id'} );
	$variable{'PurchaseOrder'} = $PO;
	if ( $param{'action'} eq 'add' ) {
		my $C = new openprint::PurchaseOrder_Content( $param{'po_content_id'} );
		$C->save( {
			po_id		=>	$param{po_id},
			qty			=>	$param{qty},
			item		=>	$param{item},
			product		=>	$param{product},
			description	=>	$param{description},
			docket		=>	$param{docket},
			price		=>	$param{price},
			total		=>	$param{total},
			type_id		=>	$param{type_id},
			});
		$variable{'C'} = $C;
		$variable{'error'} .= $PO->save();
	} elsif ( $param{'action'} eq 'delete' ) {
		my $PO_Content = new openprint::PurchaseOrder_Content( $param{'id'} );
		if ( $PO_Content->id() ) {
			# Might have already been deleted
			$PO = $PO_Content->PurchaseOrder();
			$PO_Content->delete();
			$variable{'error'} .= $PO->save();
		} # end if
	} # end if
} # end sub _purchase_order_content_line

sub _notifications {
	my $PO = new openprint::PurchaseOrder( $param{'po_id'} );
	if ( ( $param{'action'} eq 'add' ) and $param{'new_notification_id'} ) {
		$PO->notifications( [ split(',', $param{'notifications'}), $param{'new_notification_id'} ] );
	} elsif ( $param{'action'} eq 'delete' ) {
		$PO->notifications( [ sets::exclude( [$param{'notification_id'}], [$PO->notifications()] ) ] );
	} # end if
	$variable{'PurchaseOrder'} = $PO;
} # end sub _notifications

sub _po_select_vendor {
}

sub _update_taxes {
	# Set incoming data because we may have changed suppliers, do not save though!
	my $PO = $variable{PO} = new openprint::PurchaseOrder( $param{po_id} );
	$variable{error} .= $PO->set( \%param );
	# Reload $PO->Taxes() with current set
	$PO->Taxes(1);
} # end sub _update_taxes

sub _similar_pos {
} # end sub _similar_pos

sub _item_select {
} # end sub _item_select

sub items {
	if ( $param{'btnFunction'} eq 'Delete' ) {
		foreach my $item_id ( ref $param{'item_id'} eq 'ARRAY' ? @{$param{'item_id'}} : $param{'item_id'} ) {
			my $Item = new openprint::PurchaseOrder_Item( $item_id );
			if ( $_ = $Item->delete() ) {
				$variable{'error'} .= $_ . '<br/>';
			} # end if
		} # end foreach item_id
		delete $param{'item_id'};
	} elsif ( $param{'btnFunction'} eq 'Merge' ) {
		my @ids = sort( ref $param{'item_id'} eq 'ARRAY' ? @{$param{'item_id'}} : $param{'item_id'} );
		if ( ! @ids ) {
			$variable{'error'} .= 'No items selected. Nothing done.';
			return;
		} # end if
		my $final_id = shift @ids;
		my $Final_Item = new openprint::PurchaseOrder_Item( $final_id );
		if ( ! $Final_Item->id() ) {
			$variable{'error'} .= 'Unable to get final item. Nothing done.';
			return;
		} # end if
		foreach my $id ( @ids ) {
			foreach my $Content ( openprint::PurchaseOrder_Content->find('item_id'=>$id) ) {
				if ( $Content->item_id() != $id ) {
					$log->error("DANGER: Content has different item_id than asked for.");
					$variable{'error'} .= 'Crazy things have happened. Some merging has been done, some hasnt';
					return;
				} # end if
				$Content->save({'item_id'=>$final_id});
			} # end foreach Content
			my $Item = new openprint::PurchaseOrder_Item( $id );
			$variable{'error'} .= $Item->delete();
		} # end foreach id
	} else {
		ssi::save_params( '/employee/purchase_order/items.html', ( 'supplier_id','types', 'item_contains' ) );
	} # end if
} # end sub items

sub _items {
	ssi::save_params( '/employee/purchase_order/items.html', ( 'supplier_id','types', 'item_contains' ) );
} # end sub _items

sub _item_filter {
	ssi::save_params( '/employee/purchase_order/history.html', ( 'supplier_id' ) );
} # end sub

sub item {
	my $Item = $variable{'Item'} = new openprint::PurchaseOrder_Item( $param{'item_id'} );
	if ( $param{'func'} eq 'Save' ) {
		$variable{'error'} = $Item->save({
			'name'		=>	$param{'name'},
			'product'	=>	$param{'product'},
			'price'		=>	$param{'price'},
			'type_id'	=>	$param{'type_id'},
		});
	} elsif ( $param{'func'} eq 'Delete' ) {
		$variable{'error'} .= $Item->delete();
		%param = ();
		$variable{'ExternalRedirect'} = '/employee/purchase_order/items.html';
	} # end if
} # end sub item

sub _po_created_by_options {
} # end sub _po_created_by_options

sub _vendor_dropdown {
	ssi::save_params( '/employee/purchase_order/history.html', ( 'vendor_category_id', 'supplier_id' ) );
} # end sub _vendor_dropdown

sub _assets {
	$variable{'PurchaseOrder'} = new openprint::PurchaseOrder( $param{'po_id'} );
	if ( $param{'action'} eq 'delete' ) {
		my $PA = openprint::Object_Asset->find_one( 'object_type'=>'openprint::PurchaseOrder','object_id'=>$param{'po_id'}, 'asset_id'=>$param{'asset_id'} );
		if ( ! $PA ) {
			$variable{'error'} .= 'Asset not found. Nothing deleted.<br/>';
		} else {
			$PA->delete();
		} # end if
	} # end if
} # end sub _assets

sub _items_dropdown {
} # end sub _items_dropdown

sub authorizations {
	if ( $param{action} eq 'Save' ) {
		my @POC_Types = openprint::PurchaseOrder_ContentType->find('order'=>'lower(name)');
		foreach my $User ( openprint::User->find( company_id=>$param{company_id},
					( $param{user_id} ? ( id=>$param{user_id} ) : () ) ) ) {
			my $save = 0;
			if ( $User->purchasing_limit() != $param{'limit_per_po-'.$$User{id}} ) {
				$User->purchasing_limit( $param{'limit_per_po-'.$$User{id}} );
				$save = 1;
			} # end if
			if ( $User->purchasing_total_limit() != $param{'limit_total-'.$$User{id}} ) {
				$User->purchasing_total_limit( $param{'limit_total-'.$$User{id}} );
				$save = 1;
			} # end if
			$User->save() if $save;
			foreach my $POC_Type ( @POC_Types ) {
				if ( $User->po_limit( $$POC_Type{id} ) != $param{'limit-'.$$User{id}.'-'.$$POC_Type{id}} ) {
					$User->po_limit( $$POC_Type{id}, $param{'limit-'.$$User{id}.'-'.$$POC_Type{id}} );
				} # end if
			} # end foreach POC_TYPE	
		} # end foreach User
	} # end if
	_authorizations();
	$session{'/employee/purchase_order/authorizations.html?company_id'} = new openprint::User($session{user_id})->company_id() if ! $session{'/employee/purchase_order/authorizations.html?company_id'};
} # end sub authorizations

sub _authorizations {
	ssi::save_params( '/employee/purchase_order/authorizations.html', ( 'company_id','user_id' ) );
} # end sub _items

sub _payments_edit {
	my $PO = $variable{PurchaseOrder} = new openprint::PurchaseOrder( $param{po_id} );
	if ( ! $PO->id() ) {
		$variable{error} = "Invalid Purchase Order specified: $param{po_id}<br/>";
		return;
	} # end if
	if ( $param{action} eq 'Add' ) {
		my $ac = sql::start_transaction( $openprint::dbh );
		my $Payment = new openprint::Payment();
		$variable{error} .= $Payment->save({ 
				amount			=>	$param{amount},
				currency_id		=>	$$PO{currency_id},
				received_on		=>	$param{received_on},
				memo			=>	$param{description},
				recipient_id	=>	$PO->supplier_id(),
				payor_id		=>	$PO->company_id(),
				});
		return if $variable{error};
		my $PO_Payment = new openprint::Object_Payment();
		$variable{error} .= $PO_Payment->save({payment_id=>$Payment->id(), object_id=>$PO->id(), object_type=>'openprint::PurchaseOrder', amount=>$param{amount} });
		$PO->Payments( undef );
		$PO->payments_total(undef);
		$PO->total(undef);
		$variable{error} .= $PO->save();
		$openprint::dbh->rollback() if $variable{error};
		sql::end_transaction( $openprint::dbh, $ac );
	} elsif ( $param{action} eq 'Delete' ) {
$openprint::log->debug("delet");
		if ( ! sets::isin( $param{payment_id}, [ map { $_->payment_id() } $PO->Payments() ] ) ) {
			$variable{error} .= "Payment $param{payment_id} is not attached to PO $$PO{id}<br/>";
			return;
		} # end if
		#my $PO_Payment = openprint::Object_Payment->find_one( object_id=>$$PO{id}, payment_id=>int($param{payment_id}) );
		my $PO_Payment = openprint::Object_Payment->find_one( object_id=>$$PO{id}, object_type=>'openprint::PurchaseOrder', payment_id=>int($param{payment_id}) );
		if ( ! $PO_Payment ) {
			$variable{error} .= 'Payment for this PO not found.';
			return;
		} # end if
		my $ac = sql::start_transaction( $openprint::dbh );
$openprint::log->debug("deleting");
		if ( ( $variable{error} = $PO_Payment->delete() ) or ( $variable{error} = $PO->save() ) ) {
			$openprint::dbh->rollback();
		} # end if
		sql::end_transaction( $openprint::dbh, $ac );
	} # end if action
} # end sub payments_edit

1;
__END__
