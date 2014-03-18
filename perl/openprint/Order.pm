use strict;
package openprint::Order;
our @ISA=qw(openprint::Object);

use openprint ();
use vars qw( $debug %session %config %variable $log $dbh $table $serial %fields %find_fields %transforms %defaults );
*session = \%openprint::session;
*config = \%openprint::config;
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require sql;
require openprint::usergroup;
require openprint::logs;
require openprint::OrderedProduct;
require openprint::OrderedProject;
require openprint::Order_Tax;
require openprint::Order_Invoice;
require openprint::Order_Status;
require openprint::Payment;
require openprint::Tax;
require openprint::Order_Notification;

$debug = 0;

$table = 'orders';
$serial = 'orders_id_seq';
%fields = (
	id						=> 'id',
	session_id				=> 'strsessionid',
	company_id				=> 'company_id',
	user_id					=> 'user_id',
	docket					=> 'docket',
	status					=> undef,
	status_id				=>	'status_id',
	total					=> 'total',
	downpayment				=> 'downpayment',
	cod_percent				=>	'cod_percent',
	downpayment_percent		=>	'downpayment_percent',
	created_on				=> 'created_on',
	company_name			=> 'company_name',
	salutation				=> 'salutation',
	firstname				=> 'firstname',
	lastname				=> 'lastname',
	address1				=> 'address1',
	address2				=> 'address2',
	city					=> 'city',
	state					=> 'state',
	country					=> 'country',
	postalcode				=> 'postalcode',
	phone					=> 'phone',
	extension				=> 'extension',
	fax						=> 'fax',
	email					=> 'email',
	alsonotify				=> 'alsonotify',	
	paid					=> 'paid',
	owing					=>	'owing',
	currency_id				=> 'currency_id',
	po						=> 'po',
	administrator_name		=> 'administrator_name',
	administrator_comments	=> 'administrator_comments',
	salesrep_id				=>	'salesrep_id',
	invoice_id				=>	'invoice_id',
	# deprecated, look up invioce and use it's created_on time instead
	#'invoiced_on'				=>	'invoiced_on',
	terms_accepted			=>	'terms_accepted',
	supplier_id				=>	'supplier_id',
	);

%transforms = (
	id			=>	[ 's/\D//g', '<2147483647' ],
	docket		=>	[ 's/\D//g', '<2147483647' ],
);

%find_fields = (
	project_id	=>	'(SELECT lngprojectindex FROM Order_Contents WHERE OrderIndex=Orders.id)',
	status		=>	'(SELECT name FROM Order_Statuses WHERE order_statuses.id=status_id)',
);

sub save {
	my ( $self, $params ) = @_;

	$self->set( $params );
	$self->paid(undef);
	$$self{'owing'} = $$self{'total'} - $$self{'paid'};
	$$self{'company_id'} = $session{'company_id'} if ! $$self{'company_id'};
	$$self{'user_id'} = $session{'user_id'} if ! $$self{'user_id'};
	my %sql;
	foreach my $key ( keys %fields ) {
		next if ! $fields{$key};
		$$self{$key} = undef if $$self{$key} eq '';
		$sql{$fields{$key}} = $$self{$key};
	} # end foreach

	my $ac = sql::start_transaction( $dbh );
	if ( ! $$self{'id'} ) {
		if ( $openprint::config{'OrderIDStyle'} eq 'Year' ) {
			$sql{'id'} = $$self{'id'} = openprint::order::get_order_id( $openprint::log, $openprint::dbh );
		} else {
			@$self{'id'} = sql::execute( $log, $dbh, q{SELECT nextval('order_id_seq')} );
			$sql{'id'} = $$self{'id'};
		} # end if
		$sql{$fields{'created_on'}} = 'NOW()';
		if ( ( my $error = sql::insert( $log, $dbh, 'Orders', \%sql ) ) ) {
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if	
	} elsif ( $$params{'force_insert'} ) {
		if ( ( my $error = sql::insert( $log, $dbh, 'Orders', \%sql ) ) ) {
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if	
	} else {
		if ( ( my $error = sql::update( $log, $dbh, 'Orders', ['id=?', $$self{'id'}], \%sql ) ) ) {
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if	
	} # end if

	$self->load();
if ( 0 ) {
	if ( sets::isin($$self{'status'}, ['Re-Opened','Incomplete'] ) ) {
		# Reload taxes
		foreach my $Tax ( $self->Taxes() ) {
			my $error = $Tax->save();
			if ( $error ) {
				$dbh->rollback();
				return $error;
			} # end if
		} # end foreach $Tax
	} # end if
}
	sql::end_transaction( $dbh, $ac );
	return;
} # end sub save

sub delete {
	my $self = shift;

	if ( ! $$self{'id'} ) {
		$log->error("Order::delete called with no id");
		return;
	}

	my $ac = sql::start_transaction( $dbh );
	sql::execute( $log, $dbh, q{DELETE FROM Schedule WHERE ProjectIndex IN ( SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?)}, $$self{'id'} );
	sql::execute( $log, $dbh, q{DELETE FROM Order_Log WHERE order_id=?}, $$self{'id'} );
	sql::execute( $log, $dbh, q{DELETE FROM Order_Taxes WHERE order_id=?}, $$self{'id'} );
	sql::execute( $log, $dbh, q{DELETE FROM Order_Contents WHERE OrderIndex=?}, $$self{'id'} );
	sql::execute( $log, $dbh, q{DELETE FROM Ordered_Products WHERE order_id=?}, $$self{'id'} );
	sql::update( undef, undef, 'Projects', [ 'order_id=?', $$self{'id'}], [ 'order_id', undef ] );
	sql::update( undef, undef, 'payments', [ 'order_id=?', $$self{'id'}], [ 'order_id', undef ] );
	sql::execute( $log, $dbh, q{DELETE FROM Orders WHERE id=?}, $$self{'id'} );
	sql::end_transaction( $dbh, $ac );
	
	openprint::logs::insertLogRecord('4', "Order ID: " . $$self{'id'},);
	
} # end sub delete

sub destroy {
	$_->delete();
} # end sub destroy 

sub to_string {
	my $self = shift;
	return '';
} # end sub

# Approve is acknowledging the prices, etc and giving the go ahead. So this function updates all the prices, taxes, statuses, etc.
sub approve {
	my $self = shift;

	my $error;
	my $ac = sql::start_transaction( $openprint::dbh );


	foreach my $OP ( $self->Ordered_Projects() ) {
		my $Project = $OP->Project();
		sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND strStatus=?', $Project->id(), 'Waiting For Customer Approval'], 'strstatus', 'Ordered' );
		$Project->add_to_log( @openprint::session{'company_id', 'user_id'}, 'Additional Charges Approved' );
		$Project->price( $Project->ordered_quantity_index(), undef );
		$error .= $Project->save();
		$error .= $OP->save({price=>undef});
		last if $error;
	} # end while
	if ( $error ) {
		$dbh->rollback();
		sql::end_transaction( $openprint::dbh, $ac );
		return $error;
	} # end if
	foreach my $Tax ( $self->Taxes() ) {
		$Tax->amount(undef);
		$error .= $Tax->save();
	} # end foreach
	if ( $error ) {
		$dbh->rollback();
		sql::end_transaction( $openprint::dbh, $ac );
		return $error;
	} # end if

	$self->subtotal( undef );
	$self->total( undef );
	$error .= $self->save({ status => 'In Production'});
	if ( $error ) {
		$dbh->rollback();
		sql::end_transaction( $openprint::dbh, $ac );
		return $error;
	} # end if
	$self->add_log( 'Customer Approved' );
	sql::end_transaction( $openprint::dbh, $ac );
	return;
} # end sub approve

sub Status {
	return new openprint::Order_Status( $_[0]{status_id} );
} # end sub Status

sub status {
	if ( @_ > 1 ) {
$openprint::log->debug("Setting status to $_[1]");
		my $Status = openprint::Order_Status->find_one(name => $_[1]);
		if ( ! $Status ) {
			$log->error("New Order Status! $_[1]");
			$Status = new openprint::Order_Status();
			$Status->save({name=>$_[1]});
		} # end if
		if ( $Status->id() != $_[0]{status_id} ) {
			$_[0]->save({ status_id => $Status->id() }) if $_[0]{id};
			$_[0]{status} = $_[1];
			$_[0]->add_log( "Changed Status to $_[1]" ) if $_[0]{id};
		} # end if
	} # end if
	if ( ! $_[0]{status} ) {
		$_[0]{status} = $_[0]->Status()->name();
		if ( !$_[0]{status} ) {
			$_[0]{status} = 'Incomplete';
		} # end if
	} # end if
	return $_[0]{status};
} # end sub status

# Adding Waiting For Pickup, Shipped, Picked Up
sub update_status {
	my $self = shift;

	$_ = q{SELECT DISTINCT(strStatus) FROM Projects WHERE id IN (SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?)};
	my @statuses = sql::execute( $log, $dbh, $_, $$self{id} );

	if ( sets::isin( 'Pending Deposit', \@statuses ) and $self->status() ne 'Pending Deposit' ) {
		$self->status( 'Pending Deposit' );
	} elsif (	sets::isin( 'Waiting For Customer Approval', \@statuses ) ) {
		return $self->status( 'Waiting For Customer Approval' );
	} elsif (	sets::isin( 'Waiting For QA Approval', \@statuses ) ) {
		return $self->status( 'Waiting For QA Approval' );
	} elsif ( sets::intersection( @statuses, 'In Prepress','Proofs Out','Approved','Printed') ) {
		$self->status( 'In Production' );
	} else { # Projcets are complete
		# All projects have same shipping type, so if one is waiting, all must be waiting
		if ( sets::isin( 'Waiting For Pickup', \@statuses ) ) {
			$self->status( 'Waiting For Pickup' );
		} elsif ( sets::isin( 'Picked Up', \@statuses ) ) {
			$self->status( 'Picked Up' );
		} elsif ( sets::isin( 'Shipped', \@statuses ) ) {
			$self->status( 'Shipped' );
		} # end if
		$self->status('Complete');
	} # end if
	if ( 'Complete' eq $self->status() ) {
		$self->send_completion_notice( );

		if ( $config{'SendInvoiceOnProjectCompletion'} ne 'N' ) {
			#send_invoice( $r, $log, $dbh, $order_id );
		} # end if
	} # end if
	return $$self{'status'};
} # end sub update_status

sub add_log {
	my ( $self, $comment ) = @_;
	sql::insert( undef, undef, 'Order_Log',[
			'order_id',		$$self{'id'},
			'company_id',	$openprint::session{'company_id'} ? $openprint::session{'company_id'} : undef,
			'user_id',		$openprint::session{'user_id'},
			'description',	$comment,
			] );
} # end sub add_log

sub company {
	my $self = shift;
	return new openprint::Company( $$self{'company_id'} );
} # end sub company
sub Company {
	return new openprint::Company( $_[0]{company_id} );
} # end sub Company

sub Contents {
	if ( ! $_[0]{Contents} ) {
		$_[0]{Contents} = [ 
			openprint::OrderedProject->find('order_id'=>$_[0]{'id'},'order'=>$openprint::OrderedProject::fields{'project_id'}), 
			openprint::OrderedProduct->find('order_id'=>$_[0]{'id'},'order'=>$openprint::OrderedProduct::fields{'project_id'}),
			];
	} # end if
	return @{$_[0]{Contents}};
} # end sub Contents

sub Ordered_Projects {
	return openprint::OrderedProject->find('order_id'=>$_[0]{'id'},'order'=>$openprint::OrderedProject::fields{'project_id'});
} # end sub Ordered_Projects

sub Projects {
	my $self = shift;
	return @{$$self{'Projects'}} if $$self{'Projects'};
	return () if ! $$self{'id'};
	$$self{'Projects'} = [ map { $_->Project() } openprint::OrderedProject->find( 'order_id'=>$$self{id} ) ];
	return @{$$self{'Projects'}};
} # end sub Projects

sub Products {
	my $self = shift;
	if ( ! $$self{'id'} ) {
		Carp::cluck("openrpint::Order->Products called with no id");
		$openprint::log->error("openrpint::Order->Products called with no id");
		return ();
	} # end if
	@{$$self{'Products'}} = openprint::OrderedProduct->find( 'order_id'=>$$self{id} );
	return @{$$self{'Products'}};
} # end sub Products

sub User {
	return new openprint::User( $_[0]{'user_id'} );
}

sub name {
	my $self = shift;
	if ( ! ( $$self{'firstname'} or $$self{'lastname'} ) ) {
		return $self->User()->name();
	} # end if
	return $$self{'firstname'} . ' ' . $$self{'lastname'};
} # end sub name

sub balance {
	my $self = shift;
	return 1*($self->total() - $$self{'paid'});
} # end sub balance

sub Currency {
	my $self = shift;
	return new openprint::Currency( $$self{'currency_id'} );
} # end sub

sub pay {
	my $self = shift;
	if ( $self->owing() <= 0 ) {
		$self->update_status();
		return "Order $$self{id} is already paid!<br/>";
	} # end if

	my $error = (new openprint::Payment())->save({
			order_id		=>	$$self{id},
			payor_id		=>	$$self{company_id},
			recipient_id	=>	$self->supplier_id(),
			amount		=>	$self->owing(),
			method		=>	'Manual',
			currency_id	=>	$$self{currency_id},
			memo			=>	'Order marked paid',
			received_on	=>	'NOW()',
			});
	if ( ! $error ) {
		$self->add_log("Paid.");
		$self->update_status();
		$error .= $self->save();
	} # end if
	return $error;
} # end sub pay

sub send_cancellation_notice {

	my @Recipients;
	# Send to inventory and scheduling people.
	foreach my $Recipient ( 
		openprint::User->find('usergroup any'=>'Inventory',type=>['E','A']),
		openprint::User->find('usergroup any'=>'Scheduling','type'=>['E','A'])
		) {
		next if $Recipient->id() == $session{'user_id'};
		next if $Recipient->notification('Docket Cancellations') ne 'Yes';
		push @Recipients, $Recipient;
	} # end foreach Recipient

	return if ! @Recipients;

	my %order;
	$order{'Order'} = $_[0];
	$order{'ReplacementText'} = ssi::include('/email_content/order_cancellation_notice.html', \%order );
	new openprint::Email()->send(
			FROM	=> new openprint::User( $session{user_id} ),
			TO	=> \@Recipients,
			SUBJECT => "Docket $_[0]{docket} has been cancelled.",
			ATTACHMENTS => [ '', MIME::QuotedPrint::encode_qp( ssi::include( '/email_template.html', \%order ) ), 'text/html', 'quoted-printable'],
			);
	
} # end sub send_cancellation_notice

sub subtotal {
	my $self = shift;
	if ( @_ ) {
		$$self{'subtotal'} = shift;
	} # end if

	if ( sets::isin($$self{'status'}, ['Re-Opened','Incomplete'] ) or ! $$self{'subtotal'} ) {
		$$self{'subtotal'} = 0;
		foreach my $Project ( $self->Projects() ) {
			my $price = $Project->ordered_price();
#$log->debug("subtotal: ordered price: $price");
			if ( $Project->currency_id() != $$self{'currency_id'} ) {
				my $rate = $Project->Currency()->conversions( $$self{'currency_id'} );
				$price *= $rate;
#$log->debug("subtotal: ordered price converted to: $price");
			} # end if
			$$self{'subtotal'} += $price;
		} # end foreach Project
		foreach my $Product ( $self->Products() ) {
			my $price = $Product->price();
#$log->debug("subtotal: ordered price: $price");
			if ( $Product->currency_id() != $$self{'currency_id'} ) {
				my $rate = $Product->Currency()->conversions( $$self{'currency_id'} );
				$price *= $rate;
#$log->debug("subtotal: ordered price converted to: $price rate($rate) $$self{'currency_id'} != ".$Product->currency_id());
			} # end if
			$$self{'subtotal'} += $price;
		} # end foreach Project
	} # end if
	return $$self{'subtotal'};
} # end sub subtotal

sub total {
	my $self = shift;
	if ( @_ ) {
		$$self{'total'} = shift;
	} # emd of
	if ( sets::isin( $$self{'status'}, ['Re-Opened','Incomplete'] ) or ! $$self{'total'} ) {
		$$self{'total'} = $self->subtotal();
		foreach my $Tax ( $self->Taxes() ) {
			$$self{'total'} += $Tax->amount();
		} # end foreach Tax
	} # end if
	return $$self{'total'};
} # end sub total

sub send_completion_notice {
	my ( $self ) = @_;

	my %order = (
		OrderID => $self->id(),
		Order	=> $self,
		Currency	=>$self->Currency(),
	);

	my @attachments = ();

	$order{'ReplacementText'} = ssi::include( '/email_content/order_completion_notice.html', \%order );
	my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
	$_ = MIME::QuotedPrint::encode_qp( Encode::encode( 'utf-8', ssi::variable_substitution( \$email_template, \%order ) ) );
	my @body = ('', $_, 'text/html', 'quoted-printable');

	$_ = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/sales_order.html' );
	if ( $_ ) {
		$_ = MIME::QuotedPrint::encode_qp( Encode::encode( 'utf-8', ssi::variable_substitution( \$_, \%order ) ) );
		push @attachments, "Order$$self{id}.html", $_, 'text/html', 'quoted-printable';
	} # end if
	#my %mail = (
		#SMTP	=> $config{'Mail Server'},
		#FROM	=> $config{'AccountingEmail'},
		##TO		=> $order{'txtEmail'},
		#TO	 => 'keith@point-one.com, iconnor@point-one.com',
		#SUBJECT => "Order $order_id Is Complete",
#);
	#misc::send_email_with_attachment( $log, \%mail, @body, @attachments );
} # end sub send_completion_notice

# This is a self-contained function that sends the email messages for a specified order to the apropriate people.
# >Something to note:	the order email is sent in the currency that the order is stored in, not neccessarily the current currency
sub send_sales_order {
	my ( $self ) = @_;
	my %order = (
		OrderID => $$self{id},
		Order => $self,
	);

	# When an order is made,the Order currency will be the current session Currency.	
	# All resends should stay in the currency that the order was created in.
	my $Currency = $self->Currency();
	@order{'Currency','CurrencyName','CurrencySymbol'} = ( $Currency, $Currency->name(), $Currency->symbol() );

	my $email_template = ssi::slurp_content( '/email_template.html' );

	$order{'ReplacementText'} = ssi::include('/email_content/sales_order_body.html', \%order );
	my @body = ('', MIME::QuotedPrint::encode_qp( Encode::encode( 'utf-8', ssi::variable_substitution( \$email_template, \%order ) ) ), 'text/html', 'quoted-printable');

	my @sales_order;
	$order{'ReplacementText'} = ssi::include( '/email_content/sales_order.html', \%order );
	$_ = MIME::QuotedPrint::encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$email_template, \%order ) ) );
	@sales_order = ( "Order$$self{id}.html", $_, 'text/html', 'quoted-printable' );

	# Add a project summary for each project in the order
	my @project_summaries = ();
	my $content = ssi::slurp_content( '/email_content/project_summary.html' );
	foreach my $Project ($self->Projects()) {
		my %data;
		openprint::print_project::summary( $openprint::r, $log, $dbh, \%data, $Project->id() );
		$data{'ReplacementText'} = ssi::variable_substitution( \$content, \%data );
		push @project_summaries, "ProjectSummary$$Project{id}.html", MIME::QuotedPrint::encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$email_template, \%data ))), 'text/html', 'quoted-printable';
	} # for each Project

	my $sales_person_email;
	if ( $self->salesrep_id() ) {
		my $CSR = new openprint::User( $self->salesrep_id() );
		$sales_person_email = sprintf('"%s %s" <%s>', $CSR->get('firstname','lastname','email')),
	}
	if ( ! $sales_person_email ) {
		$sales_person_email = $config{'OrderingEmail'};
	} # end if
	
	new openprint::Email()->send(
		FROM	=> $sales_person_email,
		TO		=> sprintf('"%s %s" <%s>', $self->get('firstname','lastname','email')),
		#BCC	 =>	'iconnor@point-one.com',
		SUBJECT => "Order $$self{id}",
		ATTACHMENTS	=>	[ @body, @sales_order ],
		);

	$order{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/order_admin_body.html' );
	$order{'ReplacementText'} = ssi::variable_substitution( \$order{'ReplacementText'}, \%order );
	$_ = MIME::QuotedPrint::encode_qp( Encode::encode( 'utf-8', ssi::variable_substitution( \$email_template, \%order ) ) );
	@body = ('', $_, 'text/html', 'quoted-printable');
	$order{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/sales_order_for_admin.html' );
	$order{'ReplacementText'} = ssi::variable_substitution( \$order{'ReplacementText'}, \%order );
	$_ = MIME::QuotedPrint::encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$email_template, \%order ) ) );
	@sales_order = ( "Order$$self{id}.html", $_, 'text/html', 'quoted-printable' );
	my @project_dockets = ();

	$log->debug("***************** ADDING PROJECT DOCKET *************************");
	my $docket_content = ssi::slurp_content( '/email_content/order_docket_sheet.html' );
	if ( $docket_content ) {
		foreach my $Project ($self->Projects()) {
			my %data = (
					OrderID => $$self{id},
					Order => $self,
					Project =>	$Project,
					);
			
			openprint::print_project::summary( $openprint::r, $log, $dbh, \%data, $Project->id() );
			$_ = MIME::QuotedPrint::encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$docket_content, \%data ) ) );
			push @project_dockets, "ProjectDocket$$Project{id}.html", $_, 'text/html', 'quoted-printable';
		} # for each
	} # end if

	my @admin_emails = split( ',', $config{'OrderingEmail'} );
	@admin_emails = map { misc::trim(lc $_) } @admin_emails;

	my @accounting_emails = split( ',', $config{'AccountingEmail'} );
	@accounting_emails = map { misc::trim(lc $_) } @accounting_emails;

	@admin_emails = sets::union( @admin_emails, @accounting_emails, $sales_person_email );

	if ( @admin_emails ) {
		new openprint::Email()->send(
				FROM	=> $config{'OrderingEmail'},
				'Reply-to'	=> $$self{'email'},
				TO		=> join(',',@admin_emails),
				#TO	 =>	'iconnor@point-one.com',
				SUBJECT => "Order $$self{id}",
				ATTACHMENTS	=>	[ @body, @sales_order, @project_summaries, @project_dockets ],
				);
	} # end if

} # end sub send_sales_order

sub owing {
	if ( $_[0]{status} eq 'Cancelled' ) {
		return 0;
	} else {
		return $_[0]{total} - $_[0]->paid();
	} # end if
} # end sub owing

sub Taxes {
	my ( $self ) = @_;

	if ( ! $$self{'id'} ) {
		return ();
	} # end if

	if ( ! $$self{'Taxes'} ) {
		@{$$self{'Taxes'}} = openprint::Order_Tax->find('order_id'=>$$self{'id'});
	} # end if
	if ( $self->Company()->country() and $self->Company()->state() and ! @{$$self{'Taxes'}} ) {
		foreach my $Tax ( openprint::Tax->find(
					'period_start null_or_<='	=>	$$self{'created_on'},
					'period_end null_or_>='		=>	$$self{'created_on'},
					'country'	=>	$self->Company()->country(),
					'state'		=>	$self->Company()->state()),
				) {
			my $T = new openprint::Order_Tax();
			$T->save({
				'order_id'	=>	$$self{'id'},
				'tax_id'	=>	$$Tax{'id'},
				'rate'		=>	$$Tax{'rate'},
			});
			push @{$$self{'Taxes'}}, $T;
		} # end foreach Tax
	} # end if
	return @{$$self{'Taxes'}};
} # end sub Taxes

sub Tax {
	my $result = openprint::Order_Tax->find_one('order_id'=>$_[0]{'id'}, 'tax_id'=>$_[1]->id() );
	if ( ! $result ) {
		return new openprint::Order_Tax();
	} # end if
	return $result;
} # end sub Tax

sub paid {
	$_[0]{'paid'} = $_[1] if ( @_ == 2 );
	if ( $_[0]{id} and ! defined $_[0]{paid} ) {
		$_[0]{'paid'} = misc::sum( map { $_->amount() } openprint::Payment->find(order_id=>$_[0]{id}) );
	} # end if
	return $_[0]{'paid'};
} # end sub paid

sub payment_days {
	return 0 if ! $_[0]->invoiced_on();
	my $invoiced_on_seconds = Date::Parse::str2time( $_[0]->invoiced_on() );
	my $paid_on_seconds = $_[0]->paid_on_seconds();
	return int( ( $paid_on_seconds - $invoiced_on_seconds ) / ( 60*60*24 ) );
} # end sub payment_days

sub paid_on_seconds {
	if ( $_[0]->paid() < $_[0]->total() ) {
		return time;
	} # end if
	my $Last_Payment = openprint::Payment->find_one('order_id'=>$_[0]{'id'},'order'=>$openprint::Payment::fields{'received_on'}.' DESC');
	if ( ! $Last_Payment ) {
		return time;
	} # end if
	return Date::Parse::str2time( $Last_Payment->received_on() );
} # end sub paid_on
sub paid_on {
	if ( $_[0]->paid() < $_[0]->total() ) {
		return Date::Format::time2str( '%Y-%m-%d %H:%M:%S', time );
	} # end if
	my $Last_Payment = openprint::Payment->find_one('order_id'=>$_[0]{'id'},'order'=>$openprint::Payment::fields{'received_on'}.' DESC');
	if ( ! $Last_Payment ) {
		return Date::Format::time2str( '%Y-%m-%d %H:%M:%S', time );
	} # end if
	return $Last_Payment->received_on();
} # end sub paid_on

sub downpayment_owing {
	if ( ! exists $_[0]{'downpayment_owing'} ) {
		$_[0]{'downpayment_owing'} = $_[0]->downpayment() - $_[0]->paid();
		$_[0]{'downpayment_owing'} = 0 if $_[0]{'downpayment_owing'} < 0;
	} # end if
	return $_[0]{'downpayment_owing'};
} # end sub downpayment_owing
sub downpayment_percent {
	if ( ! defined $_[0]{'downpayment_percent'} ) {
		my $Credit = $_[0]->Company()->Credit();
		$_[0]{'downpayment_percent'} = $Credit->downpayment();
	} # end if
	return $_[0]{'downpayment_percent'};
} # end sub downpayment_percent
sub cod_percent {
	my $Credit = $_[0]->Company()->Credit();
	return $Credit->cod();
} # end sub cod_percent

sub cod { 
	return Math::Round::nearest( .01,$_[0]{'total'} * ($_[0]->cod_percent/100));
} # end sub cod
# Returns the remmaining amount to pay on delivery
sub cod_owing {
	if ( ! exists $_[0]{'cod_owing'} ) {
		if ( $_[0]{status} eq 'Cancelled' ) {
			$_[0]{'cod_owing'} = 0;
		} else {
			$_[0]{'cod_owing'} = $_[0]->cod() - $_[0]->paid();
			$_[0]{'cod_owing'} = 0 if $_[0]{'cod_owing'} < 0;
		} # end if
	} # end if
	return $_[0]{'cod_owing'};
} # end sub cod_owing
sub cod_owing_percent {
	my $cod_total = $_[0]->cod();
	return 0 if ! $cod_total;
	return 0 if (1*$_[0]->paid()) == (1*$cod_total);
	return 0 if (1*$_[0]->paid()) eq (1*$cod_total);

	my $owing = int($_[0]->paid()*100/$cod_total) if $cod_total;
#$openprint::log->debug( "cod_toal $cod_total owing: $owing paid: " . $_[0]->paid() );

	return 0 if $owing == 100;
	return 100-$owing;
	return 0;
} # end sub cod_owing_percent
sub supplier_id {
	if ( @_ > 1 ) {
		$_[0]{supplier_id} = $_[1];
	} 
	if ( ! $_[0]{supplier_id} ) {
		$_[0]{supplier_id} = $openprint::config{owner_id};
	} # end if
	return $_[0]{supplier_id};
} # end sub supplier_id
sub Supplier {
	return new openprint::Company( $_[0]->supplier_id() );
} # end sub Supplier

sub AdditionalChargeNotifications {
	if ( @_ > 1 ) {
		delete $_[0]{Notifications};
	} # end if
	if ( ! $_[0]{Notifications} ) {
		$_[0]{Notifications} = [ openprint::Order_Notification->find(order_id=>$_[0]{id}, order=>'user_id') ];
	} # end if
	if ( ! @{$_[0]{Notifications}} ) {
		
		my %users;
		if ( $_[0]->email() ) {
			foreach my $e ( split(',', lc $_[0]->email() ) ) {
				next if ! $e;
				next if $users{$e};
				my $U = openprint::User->find_one(email=>$e);
				if ( ! $U ) {
					$U = new openprint::User();
					$U->save({ email=>$e, company_id=>$_[0]{company_id} });
				} # end if
				my $ON = new openprint::Order_Notification();
				$ON->save({order_id=>$_[0]{id}, user_id=>$$U{id}});
				push @{$_[0]{Notifications}}, $ON;
				$users{$$U{email}} = $U;
			} # end foreach
		} # end if 
		my $CSR = $_[0]->CSR();
		if ( $CSR->id() and ! $users{$CSR->email()} ) {
			my $ON = new openprint::Order_Notification();
			$ON->save({order_id=>$_[0]{id}, user_id=>$$CSR{id}});
			push @{$_[0]{Notifications}}, $ON;
			$users{$CSR->email()} = $CSR;
		} # end if
		$CSR = $_[0]->Company()->CSR();
		if ( $CSR->id() and ! $users{$CSR->email()} ) {
			my $ON = new openprint::Order_Notification();
			$ON->save({order_id=>$_[0]{id}, user_id=>$$CSR{id}});
			push @{$_[0]{Notifications}}, $ON;
			$users{$CSR->email()} = $CSR;
		} # end if
	} # end if
	return @{$_[0]{Notifications}};
} # end sub AdditionalChargeNotifiactions

sub CSR {
	return new openprint::User( $_[0]{salesrep_id} );
} # end sub CSR

sub can_invoice {
	return 0 if ! $_[0]{id};
	return 1 if $openprint::session{user_type} eq 'A';
$openprint::log->debug("No admin");
	return 1 if $openprint::session{user_type} eq 'E' and openprint::usergroup::is_user_in( ['Accounting'], $openprint::session{user_id} );
$openprint::log->debug("Not employee" );
	return 0;
} # end sub can_invoice

sub Invoice {
$openprint::log->error("Deprecated call to Order::Invoice");
	return new openprint::Invoice( $_[0]{invoice_id} );
} # end sub Invoice

sub Invoices {
	return openprint::Order_Invoice->find( order_id=>$_[0]{id}, order=>'invoice_id' );
} # end sub Invoices

sub invoiced_on {
	my @Invoices = $_[0]->Invoices() ;
	if ( @Invoices ) {
		return $Invoices[0]->created_on();
	} 
	return;	
}  # end sub invoiced_on

sub can_see_pricing {
	return 1 if $openprint::session{user_type} eq 'A';
	return 1 if $_[0]{user_id} == $openprint::session{user_id};
	return 1 if $_[0]{salesrep_id} == $openprint::session{user_id};
	return 1 if openprint::usergroup::is_user_in( ['Accounting'], $openprint::session{user_id} );
	return 0;
} # end sub can_see_pricing

1;
__END__
