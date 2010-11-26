use strict;
package openprint::Claim;
our @ISA = qw(openprint::Object);
require openprint::Object;

use MIME::Base64;
use MIME::QuotedPrint;
use MIME::Types;
use MIME::Type;

use openprint ();
use vars qw(%variable $log $dbh %config %session $debug %fields %transforms %defaults $table $serial );
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
require openprint::Claim_Tax;
require openprint::Claim_Asset;


$debug = 1;

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
	'editor_id'			=>	'editor_id',
	'also_notify'		=>	'also_notify',
);

%transforms = (
	'updated_on'	=> [ 's/.*//g' ],
	'po_id'			=>	[ 's/\D//g' ],
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
	'deleted'		=>	0,
	'editor_id'		=>	[],
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
				$sql .= ' AND docket = {?}';
				push @values, $params{'docket'};
		} else {
			$sql .= ' AND ? = ANY docket';
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
	$self->subtotal(undef);
	foreach my $Tax ( $self->Taxes() ) {
		$Tax->amount(undef);
	} # end foreach Tax
	$self->total(undef);
	if ( ! $$hash{'currency_id'} ) {
		my $Currency = openprint::Currency::get_current();
		$$hash{'currency_id'} = $Currency->id();
	} # end if
	$$self{'created_by'} = $session{'user_id'} if ! $$self{'created_by'};
	$$self{'company_id'} = $session{'company_id'} if ! $$self{'company_id'};
	my $error = $self->SUPER::save( $hash );
	if ( ! $error ) {
		# Taxes
		foreach my $T ( $self->Taxes() ) {
			$error .= $T->save();
		} # end foreach
	} # end if
	return $error;
} # end sub save

sub destroy {
    my $self = shift;
    my $ac = sql::start_transaction( );
    sql::execute( undef, undef, q{DELETE FROM Claim_Taxes WHERE claim_id=?}, $$self{'id'} );
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

sub subtotal {
	my ( $self, $new ) = @_;
	
	$$self{'subtotal'} = $_[1] if ( @_ > 1 );
	if ( ! $$self{'subtotal'} ) {
		$$self{'subtotal'} = 0;
		foreach my $C ( $self->Contents() ) {
			$$self{'subtotal'} += $C->total();
		} # end foreach
        $$self{'subtotal'} = sprintf('%.2f', $$self{'subtotal'} );
	} # endif
	return $$self{'subtotal'};
} # end sub subtotal

sub total {
	my ( $self ) = @_;
	$$self{'total'} = $_[1] if ( @_ > 1 );
	if ( ! $$self{'total'} ) {
		$$self{'total'} = $self->subtotal();
        foreach my $Tax ( $self->Taxes() ) {
            $$self{'total'} += $Tax->amount();
        } # end foreach Tax
        $$self{'total'} = sprintf('%.2f', $$self{'total'} );
	} # end if
	return $$self{'total'};
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
my MIME::Types $types = MIME::Types->new;

	foreach my $Claim_Asset ( $self->Assets() ) {
		my $Asset = $Claim_Asset->Asset();

		push @attachments, $Asset->filename(), 
			 MIME::Base64::encode_base64( misc::load_file( $log, $Asset->on_disk_path() ) ), 
			 $types->mimeTypeOf($Asset->filename()), 'base64';
	} # end foreach Asset

	my $results = 'CLAIM ' . $$self{'id'} . ' emailed to the following recipients:<br/>';
	my $Email = new openprint::Email();
	$results .= $Email->send( 
			#TO	=>	[ split(',', $self->Contact()->email() ) ],
			TO	=>	'iconnor@point-one.com',
			FROM	=>	sprintf( '"%s" <%s>', $From->name(), $From->email() ),
			SUBJECT	=>	'CLAIM ' . $self->id() . ' for ' . $self->Vendor()->name(),
			ATTACHMENTS =>	\@attachments,
			);
	return $results;
} # end sub send

sub Taxes {
    my ( $self ) = @_;

	return if ! ( $$self{'id'} and $$self{'supplier_id'} );

    if ( ! $$self{'Taxes'} ) {
        @{$$self{'Taxes'}} = openprint::Claim_Tax->find('claim_id'=>$$self{'id'});
    } # end if
    if ( ! @{$$self{'Taxes'}} ) {
        foreach my $Tax ( openprint::Tax->find(
                    'period_start_null_or_<='   =>  $$self{'created_on'},
                    'period_end_null_or_>='     =>  $$self{'created_on'},
                    'country'   =>  $self->Company()->country(),
                    'state'     =>  $self->Company()->state()),
                ) {
            my $T = new openprint::Claim_Tax();
            $T->save({
                'claim_id'=>  $$self{'id'},
                'tax_id'    =>  $$Tax{'id'},
                'rate'      =>  $$Tax{'rate'},
            });
            push @{$$self{'Taxes'}}, $T;
        } # end foreach Tax
    } # end if
    return @{$$self{'Taxes'}};
} # end sub Taxes

sub Tax {
    my $result = openprint::Claim_Tax->find_one('claim_id'=>$_[0]{'id'}, 'tax_id'=>$_[1]->id() );
    if ( ! $result ) {
        return new openprint::Claim_Tax();
    } # end if
    return $result;
} # end sub Tax

sub Assets {
	return () if ! $_[0]{'id'};
	my ( $self, %param ) = @_;
	$param{'claim_id'} = $_[0]{'id'};
	$param{'order'}	=	'asset_id' if ! $param{'order'};
	my @Assets = openprint::Claim_Asset->find(%param);	
$openprint::log->debug("# of Assets: " . scalar @Assets );
	return @Assets;
} # end sub Assets

1;
__END__
