package openprint::employee_purchase_order;
use MIME::QuotedPrint;
use Text::CSV_XS;
use strict;
require sql;
require misc;
require openprint::paper;

require openprint::PurchaseOrder;
require openprint::PurchaseOrder_Item;

use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

sub view {

	my $Me = new openprint::User( $session{'user_id'} );
	my $PO = new openprint::PurchaseOrder( $param{'po_id'} );
	if ( ! $PO->id() ) {
		$variable{'error'} .= 'Invalid PO # given: ' . $param{'po_id'}.'<br/>';
		$variable{'PurchaseOrder'} = $PO;
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
			$variable{'Redirect'} = '/employee/purchase_order/history.html';
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
			$variable{'Redirect'} = '/employee/purchase_order/history.html';
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
			$variable{'Redirect'} = '/employee/purchase_order/history.html';
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
			$variable{'Redirect'} = '/employee/purchase_order/history.html';
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Send' ) {
	} elsif ( $param{'btnFunction'} eq 'Email Vendor' ) {
		$variable{'error'} = $PO->send_to_vendor();
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
		if ( ! $PO->authorized() ) {
			if ( sets::isin( $session{'user_type'}, ['A'] ) or ( $PO->total() < $Me->purchasing_limit() ) ) {
				$variable{'error'} .= $PO->save({
						'authorized'	=> 1,
						'authorized_on'	=> 'NOW()',
						'authorized_by'	=> $session{'user_id'},
						});
			} else {
				$PO->send_approval_required_notification();
			} # end if
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		if ( ! $param{'po_id'} ) {
			$variable{'error'} .= $PO->save( { 'created_by'	=>	$session{'user_id'}, 'company_id'=>$Me->company_id() } );
		} # end if

		# Used to get a list of the types in this PO, so we can add automatic notifications
		my %types;
		foreach my $k ( keys %param ) {
			my ( $content_id ) = $k =~ /qty-(.*)/;
			if ( defined $content_id ) {
				next if ( $content_id eq 'new' and ! $param{'qty-'.$content_id} );

				my $Item = new openprint::PurchaseOrder_Item( $param{'item_id-'.$content_id} );
				if ( ! $Item->id() ) {
					$Item->save({'company_id'=>$PO->company_id(), 'vendor_id'=>$PO->supplier_id(), 'type_id'=>$param{'type_id-'.$content_id}, 'name'=>$param{'item-'.$content_id}, 'description'=>$param{'description-'.$content_id}, 'price'=>$param{'price-'.$content_id} });
				} elsif ( $Item->price() != $param{'price-'.$content_id} ) {
				# Update the latest price
					$Item->save({'price'=>$param{'price-'.$content_id}});
				} # end if

				my $C = new openprint::PurchaseOrder_Content( $content_id );
				
				$variable{'error'} .= $C->save( {
						'po_id'         =>  $PO->id(),
						'qty'           =>  $param{'qty-'.$content_id},
						'item_id'       =>  $$Item{'id'},
						'description'   =>  $param{'description-'.$content_id},
						'docket'        =>  $param{'docket-'.$content_id},
						'price'         =>  $param{'price-'.$content_id},
						'total'         =>  $param{'total-'.$content_id},
						'type_id'		=>	$param{'type_id-'.$content_id},
						});

				$types{$C->Type()->name()} = 1;
				if ( $C->docket() and ! ( $C->docket() =~ /\D/ ) ) {
					foreach my $P ( openprint::Project::find('docket'=>$C->docket()) ) {
						$P->add_to_log( @session{'company_id','user_id'}, 
								sprintf('<a href="/employee/purchase_order/view.html?po_id=%1$d">%2$s%3$s %4$s ordered on PO%1$d</a>',
									$PO->id(), $C->qty(), $C->units(), $C->description() ) );
					} # end foreach Project
				} # end if docket
			} # end if
		} # end foreach
		if ( ! $param{'supplier_id'} ) {
			my @Companies = openprint::Company::find( 'name'=>$param{'vendor_name'} );
			if ( ! @Companies ) {
				my $C = new openprint::Company();
				$C->save({
						'supplier'		=> 'Y',
						'name'			=> $param{'vendor_name'},
						'business_name'	=> $param{'vendor_name'},
						'address1'		=> $param{'vendor_address1'},
						'address2'		=> $param{'vendor_address2'},
						'city'			=> $param{'vendor_city'},
						'state'			=> $param{'vendor_state'},
						'country'		=> $param{'vendor_country'},
						'postalcode'	=> $param{'vendor_postalcode'},
						'phone'			=> $param{'vendor_phone'},
						'fax'			=> $param{'vendor_fax'},
						} );
				$param{'supplier_id'} = $C->id();
			} else {
				my $Company;
				foreach my $C ( @Companies ) {
					if ( $C->supplier() eq 'Y' ) {
						$Company = $C;
						last;
					} # end if
				} # end foreach
				if ( ! $Company ) {
					$Company = $Companies[0];
					$Company->save( {'supplier'=>'Y'} );
				} # end if
				$param{'supplier_id'} = $Company->id();
			} # end if
		} # end if
		if ( ! $param{'contact_id'} ) {
			my @Users = openprint::User::find( 'company_id'=>$param{'supplier_id'}, 'email'=> lc $param{'vendor_email'} );
			if ( ! @Users ) {
				my $User = new openprint::User();
				my ( $first, $last ) = $param{'vendor_contact'} =~ /(\S+)\s*(\S*)/;
				$User->save( {
						'company_id'=>	$param{'supplier_id'},
						'email'		=>	$param{'vendor_email'},
						'firstname'	=>	$first,
						'lastname'	=>	$last,
						'phone'		=>	$param{'vendor_phone'},
						'fax'		=>	$param{'vendor_fax'},
						'sms'		=>	$param{'vendor_sms'},
						'change_password'	=>	'N',
						'administrator'	=>	'N',
						'ftp_active'	=>	0,
						'web_active'	=>	0,
					} );
			} # end if
		} # end if
		if ( $param{'delivered_on_switch'} eq 'DATE' ) {
			$param{'delivered_on'} = sprintf('%.4d-%.2d-%.2d', @param{'delivered_on_year','delivered_on_month','delivered_on_day'}) if ! $param{'delivered_on'};
		} else {
			$param{'delivered_on'} = undef;
		} # end if
		if ( ( $param{'vendor_country'} ne $PO->vendor_country() ) or ( $param{'vendor_state'} ne $PO->vendor_state() ) ) {
			$PO->Taxes(1);
		} # end if need to change taxes
		foreach my $Tax ( $PO->Taxes() ) {
			# Order is important here. Also the 1* turns an undef value into a specific boolean 0, because we used a checkbox
			$Tax->charge(1*$param{'tax_charge-'.$Tax->id()}) if $Tax->charge() != 1*$param{'tax_charge-'.$Tax->id()};
			$Tax->amount(undef);
			$Tax->save();
		} # end foreach
		$variable{'error'} .= $PO->save( \%param );
		if ( ! $PO->authorized() ) {
			if ( $PO->total() < $Me->purchasing_limit() ) {
				$variable{'error'} .= $PO->save({
						'authorized'	=> 1,
						'authorized_on'	=> 'NOW()',
						'authorized_by'	=> $session{'user_id'},
						});
			} else {
				$PO->send_approval_required_notification();
			} # end if
		} # end if
		if ( ( ! $variable{'error'} ) and $param{'reason'} ) {
			my $L = new openprint::PurchaseOrder_Log();
			$L->save({
				'user_id'	=>	$session{'user_id'},
				'po_id'		=>	$PO->id(),
				'reason'	=>	$param{'reason'},
				});
		} # end if
		my @notifications = $PO->notifications(); # returns user_ids
		my @new_notifications = @notifications;
		if ( $PO->is_FSC() or $PO->is_PEFC() ) {
			@new_notifications = sets::union( @new_notifications, map { $_->user_id() } openprint::User_Notification->find('type'=>'PSC/PEFC Notifications','value'=>'Yes' ) );
		} # end if
		foreach my $type ( keys %types ) {
			@new_notifications = sets::union( @new_notifications, map { $_->user_id() } openprint::User_Notification->find('type'=>'PO ' . $type . ' Notifications','value'=>'Yes' ) );
		} # end foreach
		if ( scalar @notifications != scalar @new_notifications ) {
			$PO->notifications(\@new_notifications);
		} # end if
	} # end if btnFunction

	$variable{'PurchaseOrder'} = $PO;
} # end sub view

sub edit {

	my $Me = new openprint::User( $session{'user_id'} );
	my $PO = new openprint::PurchaseOrder( $param{'po_id'} );

	if ( $param{'btnFunction'} eq 'New' ) {
$log->debug("Creating PO from label");
		my $Label = new openprint::Label( $param{'label_id'} );
		$log->debug("Creating PO from label $$Label{id}");
		my $C = $Me->Company();
		$variable{'error'} .= $PO->save( {
				'created_by'	=>	$session{'user_id'}, 
				'company_id'=>$Me->company_id(),
				'currency_id'		=>	openprint::Currency::get_current()->id(),
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
$log->debug("Creating PO $$PO{id} from label $variable{error}");
		
		my $C = new openprint::PurchaseOrder_Content();
        $C->save( {
            'po_id'         => 	$PO->id(),
            'qty'           =>  1,
            'item'          =>  'Shipping',
            'description'   =>  'From: ' . $Label->get_data('from') . ' To: ' . $Label->get_data('to'),
            'docket'        =>  $Label->Project()->docket(),
            'type'       	=> 'Other',
            });
	
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		if ( ! $param{'po_id'} ) {
			$variable{'error'} .= $PO->save( { 'created_by'	=>	$session{'user_id'}, 'company_id'=>$Me->company_id() } );
		} # end if
		if ( ! $param{'supplier_id'} ) {
			my @Companies = openprint::Company::find( 'name'=>$param{'vendor_name'} );
			if ( ! @Companies ) {
				my $C = new openprint::Company();
				$C->save({
						'supplier'		=> 'Y',
						'name'			=> $param{'vendor_name'},
						'business_name'	=> $param{'vendor_name'},
						'address1'		=> $param{'vendor_address1'},
						'address2'		=> $param{'vendor_address2'},
						'city'			=> $param{'vendor_city'},
						'state'			=> $param{'vendor_state'},
						'country'		=> $param{'vendor_country'},
						'postalcode'	=> $param{'vendor_postalcode'},
						'phone'			=> $param{'vendor_phone'},
						'fax'			=> $param{'vendor_fax'},
						} );
				$param{'supplier_id'} = $C->id();
			} else {
				my $Company;
				foreach my $C ( @Companies ) {
					if ( $C->supplier() eq 'Y' ) {
						$Company = $C;
						last;
					} # end if
				} # end foreach
				if ( ! $Company ) {
					$Company = $Companies[0];
					$Company->save( {'supplier'=>'Y'} );
				} # end if
				$param{'supplier_id'} = $Company->id();
			} # end if
		} # end if
		if ( ! $param{'contact_id'} ) {
			my @Users = openprint::User::find( 'company_id'=>$param{'supplier_id'}, 'email'=> lc $param{'vendor_email'} );
			if ( ! @Users ) {
				my $User = new openprint::User();
				my ( $first, $last ) = $param{'vendor_contact'} =~ /(\S+)\s*(\S*)/;
				$User->save( {
						'company_id'=>	$param{'supplier_id'},
						'email'		=>	$param{'vendor_email'},
						'firstname'	=>	$first,
						'lastname'	=>	$last,
						'phone'		=>	$param{'vendor_phone'},
						'fax'		=>	$param{'vendor_fax'},
						'sms'		=>	$param{'vendor_sms'},
						'change_password'	=>	'N',
						'administrator'	=>	'N',
						'ftp_active'	=>	0,
						'web_active'	=>	0,
					} );
			} # end if
		} # end if
		if ( $param{'delivered_on_switch'} eq 'DATE' ) {
			$param{'delivered_on'} = sprintf('%.4d-%.2d-%.2d', @param{'delivered_on_year','delivered_on_month','delivered_on_day'}) if ! $param{'delivered_on'};
		} else {
			$param{'delivered_on'} = undef;
		} # end if
		$variable{'error'} .= $PO->save( \%param );
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
	ssi::save_params( '/employee/purchase_order/history.html', ( 'starting_start_year','starting_start_month','starting_start_day','starting_end_year','starting_end_month','starting_end_day','authorized', 'supplier_id','created_by','deleted','types' ) );
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
		foreach my $po_id ( ref $param{'po_id'} eq 'ARRAY' ? @{$param{'po_id'}} : $param{'po_id'} ) {
			my $PO = new openprint::PurchaseOrder( $po_id );
			next if ! $PO->id();
			if ( $_ = $PO->authorize() ) {
				$variable{'error'} .= $_ . '<br/>';
			} else {
				$variable{'information'} .= 'PO ' . $po_id . ' has been authorized.<br/>';
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
	} elsif ( $param{'btnFunction'} eq 'Email Vendor' ) {
		my $PO = new openprint::PurchaseOrder( $param{'po_id'} );
		$variable{'error'} .= $PO->send_to_vendor();
		delete $param{'po_id'};
	} # end if
	ssi::setup_date_select( '/employee/purchase_order/history.html', 'starting_start', -7 );
	ssi::setup_date_select( '/employee/purchase_order/history.html', 'starting_end', '' );

} # end sub history

sub _history {
	ssi::save_params( '/employee/purchase_order/history.html', ( 'starting_start_year','starting_start_month','starting_start_day','starting_end_year','starting_end_month','starting_end_day','authorized', 'supplier_id','created_by','deleted','types' ) );
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
            'po_id'         =>  $param{'po_id'},
            'qty'           =>  $param{'qty'},
            'item'          =>  $param{'item'},
            'description'   =>  $param{'description'},
            'docket'        =>  $param{'docket'},
            'price'         =>  $param{'price'},
            'total'         =>  $param{'total'},
            'type_id'       =>  $param{'type_id'},
            });
		$variable{'C'} = $C;
		$variable{'error'} .= $PO->save();
	} elsif ( $param{'action'} eq 'delete' ) {
		my $PO_Content = new openprint::PurchaseOrder_Content( $param{'id'} );
		$PO = $PO_Content->PurchaseOrder();
		$PO_Content->delete();
		$variable{'error'} .= $PO->save();
	} # end if
} # end sub _purchase_order_content_line

sub _po_notifications {
	my $PO = new openprint::PurchaseOrder( $param{'po_id'} );
	if ( ( $param{'action'} eq 'add' ) and $param{'new_notification_id'} ) {
		$PO->notifications( [ split(',', $param{'notifications'}), $param{'new_notification_id'} ] );
	} elsif ( $param{'action'} eq 'delete' ) {
		$PO->notifications( [ sets::exclude( [$param{'notification_id'}], [$PO->notifications()] ) ] );
	} # end if
	$variable{'PurchaseOrder'} = $PO;
} # end if

sub _po_select_vendor {
}

sub _update_taxes {
} # end sub _update_taxes

sub _similar_pos {
} # end sub _similar_pos

sub _item_select {
} # end sub _item_select

1;
__END__
