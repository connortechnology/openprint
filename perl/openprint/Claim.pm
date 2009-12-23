package openprint::Claim;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use openprint ();
use vars qw(%variable $log $dbh %config %session %fields %transforms %defaults $table $serial );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*session = \%openprint::session;

require sql;
require ssi;
require misc;

require openprint::Claim_Content;
require openprint::PurchaseOrder;
require openprint::Company;
require openprint::Currency;


my $debug = 1;

$table = 'claims';
$serial = 'claims_id_seq';

%fields = (
	'id'			=>	'id',
	'company_id'	=>	'company_id',
	'created_on'	=>	'created_on',
	'created_by'	=>	'created_by',
	'updated_on'	=>	'updated_on',
	'filed_on'		=>	'filed_on',
	'sent_to_accounts_on'		=>	'sent_to_accounts_on',
	'invoiced_on'	=>	'invoiced_on',
	'invoice_id'	=>	'invoice_id',
	'po_id'			=>	'po_id',
	'docket'		=>	'docket',
	'supplier_id'	=>	'supplier_id',
	'contact_id'	=>	'contact_id',
	'currency_id'	=>	'currency_id',
	'total'				=>	'total',
	'subtotal'			=>	'subtotal',
	'federaltax'		=>	'federaltax',
	'federaltax_rate'	=>	'federaltax_rate',
	'federaltax_charge'	=>	'federaltax_charge',
	'statetax'			=>	'statetax',
	'statetax_rate'		=>	'statetax_rate',
	'statetax_charge'	=>	'statetax_charge',
	'deleted'			=>	'deleted',
	'reason'			=>	'reason',
	'vendor_contact'	=>	'vendor_contact',
	'vendor_name'		=>	'vendor_name',
	'vendor_address1'	=>	'vendor_address1',
	'vendor_address2'	=>	'vendor_address2',
	'vendor_city'		=>	'vendor_city',
	'vendor_country'	=>	'vendor_country',
	'vendor_state'		=>	'vendor_state',
	'vendor_postalcode'	=>	'vendor_postalcode',
	'vendor_phone'		=>	'vendor_phone',
	'vendor_fax'		=>	'vendor_fax',
	'vendor_sms'		=>	'vendor_sms',
	'vendor_email'		=>	'vendor_email',
);

%transforms = (
	'updated_on'	=> [ 's/.*//g' ],
	'po_id'			=>	[ 's/\D//g' ],
	'docket'		=>	[ 's/\D//g' ],
	'supplier_id'	=>	[ 's/\D//g' ],
	'contact_id'	=>	[ 's/\D//g' ],
	'currency_id'	=>	[ 's/\D//g' ],
);

%defaults = (
	'created_on'	=>	'NOW()',
	'updated_on'	=>	'NOW()',
	'filed_on'	=>	undef,
	'sent_to_accounts_on'	=>	undef,
	'invoiced_on'	=>	undef,
	'po_id'			=>	undef,
	'docket'		=>	undef,
	'supplier_id'	=>	undef,
	'contact_id'	=>	undef,
	'invoice_id'	=>	undef,
	'currency_id'	=>	undef,
	'total'			=>	0,
	'subtotal'		=>	0,
	'federaltax'	=>	undef,
	'federaltax_rate'	=>	undef,
	'statetax'		=>	undef,
	'statetax_rate'	=>	undef,
	'deleted'		=>	0,
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my @values;
	my $sql = 'SELECT * FROM Claims WHERE 1>0';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( $params{'id_like'} ) {
		$sql .= " AND id LIKE '%$params{id_like}%'";
	} # end if
	if ( exists $params{'po_id'} ) {
		if ( ref $params{'po_id'} eq 'ARRAY' ) {
			if ( @{$params{'po_id'}} ) {
				$sql .= ' AND po_id IN ('. join(',', map {'?'} @{$params{'po_id'}} ) . ')';
				push @values, @{$params{'po_id'}};
			} else {
				return ();
			} # end if
		} else {
			$sql .= ' AND po_id=?';
			push @values, $params{'po_id'};
		} # end if
	} # end if
	if ( exists $params{'supplier_id'} ) {
		if ( ref $params{'supplier_id'} eq 'ARRAY' ) {
			if ( @{$params{'supplier_id'}} ) {
				$sql .= ' AND supplier_id IN ('. join(',', map {'?'} @{$params{'supplier_id'}} ) . ')';
				push @values, @{$params{'supplier_id'}};
			} else {
				return ();
			} # end if
		} else {
			$sql .= ' AND supplier_id=?';
			push @values, $params{'supplier_id'};
		} # end if
	} # end if
	if ( exists $params{'docket'} ) {
		if ( ref $params{'docket'} eq 'ARRAY' ) {
			if ( @{$params{'docket'}} ) {
				$sql .= ' AND docket IN ('. join(',', map {'?'} @{$params{'docket'}} ) . ')';
				push @values, @{$params{'docket'}};
			} else {
				return ();
			} # end if
		} else {
			$sql .= ' AND docket=?';
			push @values, $params{'docket'};
		} # end if
	} # end if

	if ( $params{'received_on_start'} and $params{'received_on_end'} ) {
		$sql .= ' AND ( received_on BETWEEN ? AND ? )';
		push @values, @params{'received_on_start','received_on_end'};
	} elsif ( $params{'received_on_start'} ) {
		$sql .= ' AND received_on >= ?';
		push @values, $params{'received_on_start'};
	} elsif ( $params{'received_on_end'} ) {
		$sql .= ' AND received_on <= ?';
		push @values, $params{'received_on_end'};
	} # end if

	if ( $params{'created_on_start'} and $params{'created_on_end'} ) {
		$sql .= ' AND ( created_on BETWEEN ? AND ? )';
		push @values, @params{'created_on_start','created_on_end'};
	} elsif ( $params{'created_on_start'} ) {
		$sql .= ' AND created_on >= ?';
		push @values, $params{'created_on_start'};
	} elsif ( $params{'created_on_end'} ) {
		$sql .= ' AND created_on <= ?';
		push @values, $params{'created_on_end'};
	} # end if
	if ( $params{'updated_on_start'} and $params{'updated_on_end'} ) {
		$sql .= ' AND ( updated_on BETWEEN ? AND ? )';
		push @values, @params{'updated_on_start','updated_on_end'};
	} elsif ( $params{'updated_on_start'} ) {
		$sql .= ' AND updated_on >= ?';
		push @values, $params{'updated_on_start'};
	} elsif ( $params{'updated_on_end'} ) {
		$sql .= ' AND updated_on <= ?';
		push @values, $params{'updated_on_end'};
	} # end if
	if ( exists $params{'deleted'} ) {
		if ( ref $params{'deleted'} eq 'ARRAY' ) {
			if ( @{$params{'deleted'}} ) {
				$sql .= ' AND deleted IN ('. join(',', map {'?'} @{$params{'deleted'}} ) . ')';
				push @values, @{$params{'deleted'}};
			} else {
				return ();
			} # end if
		} else {
			$sql .= ' AND deleted=?';
			push @values, $params{'deleted'};
		} # end if
	} else {
		$sql .= ' AND (deleted=? OR deleted IS NULL)';
		push @values, 0;
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug("Error loading Claim SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No Claim loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded Claim ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::Claim( $_->{id}, $_ ) } @$data;
} # end sub find

sub save {
	my ( $self, $hash ) = @_;
	delete $$self{'subtotal'};
	delete $$self{'federaltax'};
	delete $$self{'statetax'};
	$$hash{'subtotal'} = $self->subtotal();
	$$hash{'federaltax'} = $self->federaltax();
	$$hash{'statetax'} = $self->statetax();
	$$hash{'total'} = $self->total();
	if ( ! $$hash{'currency_id'} ) {
		my $Currency = openprint::Currency::get_current();
		$$hash{'currency_id'} = $Currency->id();
	} # end if
	$$self{'created_by'} = $session{'user_id'} if ! $$self{'created_by'};
	$$self{'company_id'} = $session{'company_id'} if ! $$self{'company_id'};
	return $self->SUPER::save( $hash );
} # end sub save

sub destroy {
    my $self = shift;
    my $ac = sql::start_transaction( );
    sql::execute( undef, undef, q{DELETE FROM Claim_Contents WHERE claim_id=?}, $$self{'id'} );
	return $dbh->errstr() if $dbh->errstr();
    sql::execute( undef, undef, q{DELETE FROM Claims WHERE id=?}, $$self{'id'} );
    sql::end_transaction( undef, $ac );
	return $dbh->errstr() if $dbh->errstr();
	delete $openprint::Object::cache{'openprint::Claim'}{$$self{'id'}};
	return '';
} # end sub delete

sub Contents {
	my ( $self, %params ) = @_;
	if ( %params ) {
		if ( $$self{'id'} ) {
			return openprint::Claim_Content::find('claim_id'=>$$self{id}, %params );
		} # end if
	} # end if
	if ( ! $$self{'Contents'} ) {
		if ( $$self{'id'} ) {
			@{$$self{'Contents'}} = openprint::Claim_Content::find('claim_id'=>$$self{id} );
		} # end if
	} # end if
	return @{$$self{'Contents'}} if $$self{'Contents'};
	return;
} # end sub Contents

sub Vendor {
	return new openprint::Company( $_[0]{'supplier_id'} );
} # end sub Vendor

sub Currency {
	return new openprint::Currency( $_[0]{'currency_id'} );
} # end sub Currency

sub Creator {
	return new openprint::User( $_[0]{created_by} );
} # end sub Creator

sub federaltax {
	my ( $self, $new ) = @_;

	if ( defined $new ) {
		$$self{'federaltax'} = $new;
	} # end if
	if ( ( ! $$self{'federaltax'} ) and $self->federaltax_charge() ) {
		$$self{'federaltax'} = $self->subtotal() * ( $self->federaltax_rate()/100 );
	} # end if
	return $$self{'federaltax'};
} # end sub federaltax

sub federaltax_rate {
	my ( $self, $new ) = @_;
	if ( defined $new ) {
		$$self{'federaltax_rate'} = $new;
	} # end if
	if ( ! $$self{'federaltax_rate'} ) {
		if ( my ( $Tax ) = openprint::Tax::find( 'state'=>$self->Company()->state(), 'country'=>$self->Company()->country() ) ) {
			$$self{'federaltax_rate'} = $Tax->federaltax_rate();
		} # end if
	} # end if
	return $$self{'federaltax_rate'};
} # end sub federaltax_rate

sub federaltax_charge {
	my $self = shift;
	if ( @_ ) {
		$$self{'federaltax_charge'} = $_[0];
	} # end if
	if ( $$self{'company_id'} and ! defined $$self{'federaltax_charge'} ) {
		if ( $self->Company()->taxexempt1() eq 'Y' ) {
			$$self{'federaltax_charge'} = 0;
		} # end if
# This is true, but can't expect people to type it in
#if ( ! $self->Vendor()->gst_number() ) {
#   return 0;
#} # end if
		$$self{'federaltax_charge'} = 1;
	} # end if
	return $$self{'federaltax_charge'};
} # end sub federaltax_charge
sub statetax {
	my ( $self, $new ) = @_;

	if ( defined $new ) {
		$$self{'statetax'} = $new;
	} # end if
	if ( ( ! $$self{'statetax'} ) and $self->statetax_charge() ) {
		$$self{'statetax'} = $self->subtotal() * ( $self->statetax_rate()/100 );
	} # end if
	return $$self{'statetax'};
} # end sub statetax

sub statetax_rate {
	my ( $self, $new ) = @_;
	if ( defined $new ) {
		$$self{'statetax_rate'} = $new;
	} # end if
	if ( ! $$self{'statetax_rate'} ) {
		if ( my ( $Tax ) = openprint::Tax::find( 'state'=>$self->Company()->state(), 'country'=>$self->Company()->country() ) ) {
			$$self{'statetax_rate'} = $Tax->statetax_rate();
		} # end if
	} # end if
	return $$self{'statetax_rate'};
} # end sub statetax_rate

sub statetax_charge {
	my $self = shift;
	if ( @_ ) {
		$$self{'statetax_charge'} = $_[0];
	} # end if
	if ( $$self{'company_id'} and ! defined $$self{'statetax_charge'} ) {
		if ( $self->Company()->taxexempt2() eq 'Y' ) {
			$$self{'statetax_charge'} = 0;
		} else {
			$$self{'statetax_charge'} = 1;
		} # end if
	} # end if
	return $$self{'statetax_charge'};
} # end sub statetax_charge

sub subtotal {
	my ( $self, $new ) = @_;
	
	$$self{'subtotal'} = $_[1] if ( @_ > 1 );
	if ( ! $$self{'subtotal'} ) {
		$$self{'subtotal'} = 0;
		foreach my $C ( $self->Contents() ) {
			$$self{'subtotal'} += $C->total();
		} # end foreach
	} # endif
	return $$self{'subtotal'};
} # end sub subtotal

sub total {
	my ( $self ) = @_;
	return $self->subtotal() + $self->federaltax() + $self->statetax();
} # end sub total

sub Company {
	return new openprint::Company( $_[0]{'company_id'} );
} # end sub Company
sub Contact {
	return new openprint::User( $_[0]{'contact_id'} );
} # end sub Contact

sub send {
	my ( $self ) = @_;

	my $From = new openprint::User( $session{'user_id'} );
	
	my %info = (
			'Claim'	=>	$self,
			'From'	=>	$From,
			);
	my @attachments = ();

	my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );
	$info{'ReplacementText'} = "<!--#include virtual=\"/email_content/claim_body.html\"-->";
	$_ = MIME::QuotedPrint::encode_qp( Encode::encode('utf-8', ssi::variable_substitution( undef, $log, $dbh, \$email_template, \%info ) ) );
	push @attachments, ('', $_, 'text/html', 'quoted-printable');

	my $content = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/claim.html' );
	push @attachments, $From->Company()->name().'-CLAIM'.$$self{'id'}.'.html', MIME::QuotedPrint::encode_qp( Encode::encode('utf-8',ssi::variable_substitution( undef, $log, $dbh, \$content, \%info ) ) ), 'text/html', 'quoted-printable';

	my $results = 'CLAIM ' . $$self{'id'} . ' emailed to the following recipients:<br/>';
	my $Email = new openprint::Email();
	$results .= $Email->send( 
			TO	=>	[ split(',', $self->Contact()->email() ) ],
			FROM	=>	sprintf( '"%s" <%s>', $From->name(), $From->email() ),
			SUBJECT	=>	'CLAIM ' . $self->id() . ' for ' . $self->Vendor()->name(),
			ATTACHMENTS =>	\@attachments,
			);
	return $results;
} # end sub send

1;
__END__
