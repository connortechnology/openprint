package openprint::Quote;
@ISA=qw(openprint::Object);

use MIME::QuotedPrint;
use MIME::Base64;
use openprint::Currency;
use strict;
use openprint ();
use vars qw( $debug $r %variable $log $dbh %config %session $table $serial %fields %transforms %defaults %find_fields );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*session = \%openprint::session;
*r = \$openprint::r;

require sql;
require openprint::logs;
require openprint::QuotedProject;
require openprint::QuotedProduct;

$debug = 1;

$table = 'quotes';
$serial = 'quotes_id_seq';

%fields = (
	'id'			=>	'id',
	'created_on'	=>	'dtmquotedate',
	'updated_on'	=>	'dtmlastmodified',
	'company_id'	=>	'companyindex',
	'user_id'		=>	'userindex',
	'currency_id'	=>	'currency_id',
	'status'		=>	'strstatus',
	'administrator_name'	=>	'stradministratorname',
	'administrator_comments'	=>	'stradministratorcomments',
	'customer_comments'		=>	'strcustomercomments',
	'modification1'	=>	'dblmodification1',
	'modification2'	=>	'dblmodification2',
	'modification3'	=>	'dblmodification3',
	'total1'		=>	'curtotalsale1',
	'total2'		=>	'curtotalsale2',
	'total3'		=>	'curtotalsale3',
	'Currency'		=>	undef,
	'reference'		=>	'reference',
	'comments'		=>	'comments',
	'deleted'		=>	'deleted',
	);

%find_fields = (
	'salesrep_id' => '(SELECT lngsalespersion FROM companies WHERE id=company_id)',
	'for_name' => q{(SELECT strFirstName || ' ' || strLastName FROM tbl_Quote_Users_for WHERE quote_id=index)},
);
%defaults = (
	'created_on'	=>	'NOW()',
	'updated_on'	=>	'NOW()',
	'currency_id'	=>	'openprint::Currency::get_current()',
);

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $dbh->selectrow_hashref( qq{SELECT * FROM $table WHERE id=?}, {}, $$self{'id'} );
	} # end if
	@$self{keys %fields} = @$data{@fields{keys %fields}};

	$data = $dbh->selectrow_hashref( q{SELECT * FROM tbl_Quote_Users_for WHERE quote_id=?}, {}, $$self{'id'} );
	@$self{qw/for_companyname for_firstname for_lastname for_title for_salutation for_address1 for_address2 for_city for_state for_country for_postalcode for_phone for_extension for_fax for_email/} = @$data{qw/strcompanyname strfirstname strlastname strtitle strsalutation straddress straddress2 strcity strstate strcountry strpostalcode strphone strextension strfax stremail/};

	$data = $dbh->selectrow_hashref( q{SELECT * FROM tbl_Quote_Users_by WHERE quote_id=?}, {}, $$self{'id'} );
	@$self{qw/by_companyname by_firstname by_lastname by_title by_salutation by_address1 by_address2 by_city by_state by_country by_postalcode by_phone by_extension by_fax by_email/} = @$data{qw/strcompanyname strfirstname strlastname strtitle strsalutation straddress straddress2 strcity strstate strcountry strpostalcode strphone strextension strfax stremail/};
} # end sub load

sub save {
	my ( $self, $params ) = @_;
	$self->set( $params );
	my %sql;
	foreach my $key ( keys %fields ) {
		next if ! $fields{$key};
		$sql{$fields{$key}} = ( defined $$self{$key} ? $$self{$key} : $defaults{$key} );
	} # end foreach
		
	if ( ! $$self{'id'} ) {
		my $ac = sql::start_transaction( $dbh );
		if ( $openprint::config{'QuoteIDFormat'} eq 'Year' ) {
			$dbh->do( "LOCK TABLE $table IN SHARE ROW EXCLUSIVE MODE" ) or $log->error( DBI->errstr );

			my ( $quote ) = sql::execute( undef, undef, q{SELECT MAX(id) FROM Quotes} );
			$quote =~ /(\d\d\d\d)/;
			if ( $1 > ( 1900 + (localtime(time))[5]) or $quote eq '' ) {
				return (1900 + (localtime(time))[5]) . '00001';
			} # end if
			$$self{'id'} = $quote + 1;
		} else {
			@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('quotes_id_seq')} );
		} # end if
		$sql{'id'} = $$self{'id'};
		if ( ( my $error = sql::insert( undef, undef, $table, \%sql ) ) ) {
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if
		sql::end_transaction( $dbh, $ac );
	} else {
		sql::update( undef, undef, $table, ['id=?', $$self{'id'}], \%sql );
	} # end if
	$self->load();
	return;
} # end sub save

sub destroy {
	my $self = shift;

	if ( ! $$self{'id'} ) {
		$log->error("Quote::delete called with no id");
		return;
	}

	my $ac = sql::start_transaction( $dbh );
	sql::execute( undef, undef, 'DELETE FROM tbl_Quote_Details WHERE quote_id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM tbl_Quote_Users_By WHERE quote_id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM tbl_Quote_Users_For WHERE quote_id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM Quote_Log WHERE quote_id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM Quotes WHERE id=?', $$self{'id'} );
	sql::end_transaction( $dbh, $ac );
	openprint::logs::insertLogRecord('11', "Quote Index: " . $$self{'id'},);
} # end sub delete

sub to_string {
	my $self = shift;
	return '';
} # end sub

sub status {
	my ( $self, $new_status ) = @_;
	if ( defined $new_status and $$self{'status'} ne $new_status ) {
		#sql::update( $log, $dbh, 'Quotes', "Index=$$self{'id'}", 'strStatus', $new_status );
		$$self{'status'} = $new_status;
		#$self->add_log( "Changed Status to $new_status" );
	} # end if
	return $$self{'status'};
} # end sub set_status

sub add_log {
	my ( $self, $comment ) = @_;
	sql::insert( $log, $dbh, 'Quote_Log',
			'quote_id',		$$self{'id'},
			'company_id',	$session{'company_id'},
			'user_id',		$session{'user_id'},
			'Description',	$comment,
			);
} # end sub add_log

sub Quoted_Projects {
	my $self = shift;
	return map {new openprint::QuotedProject( $_ );} sql::execute( undef, undef, q{SELECT id FROM tbl_Quote_Details WHERE quote_id=?}, $$self{'id'} );
} # end sub Quoted_Projects

sub Projects {
	my $self = shift;
	if ( ! exists $$self{'Projects'} ) {
	@{$$self{'Projects'}} = map {new openprint::Project( $_ );} sql::execute( undef, undef, q{SELECT project_id FROM tbl_Quote_Details WHERE quote_id=?}, $$self{'id'} );
	} # end if
	return @{$$self{'Projects'}};
} # end sub projects

sub Products {
	my $self = shift;
	if ( ! exists $$self{'Products'} ) {
		@{$$self{'Products'}} = openprint::QuotedProduct->find('quote_id'=>$$self{'id'});
	} # end if
	return @{$$self{'Products'}};
} # end sub projects

sub for_name {
	my $self = shift;
	return $$self{'for_firstname'} . ' ' . $$self{'for_lastname'};
} # end sub
sub by_name {
	my $self = shift;
	return $$self{'by_firstname'} . ' ' . $$self{'by_lastname'};
} # end sub

sub contents {
	my $self = shift;
	$$self{'contents'} = $dbh->selectall_arrayref( q{SELECT * FROM tbl_Quote_Details WHERE quote_id=?}, {Slice=>{}}, $$self{'id'} );
	return $$self{'contents'};
}

sub markup1 {
	my $self = shift;
	my $project = shift;
	my $contents = $self->contents();
	my %hash = map { $_->{projectindex}, $_ } @$contents;
	if ( ref $project eq 'openprint::Project' ) {
		return $hash{$project->id()}{'markup1'};
	} else {
		return $hash{$project}{'markup1'};
	} # end if
}

sub store_user_by_info {
	my ( $self, $data ) = @_;

	my $ac = sql::start_transaction( $dbh );
	sql::execute( undef, undef, 'DELETE FROM tbl_Quote_Users_By WHERE quote_id=?', $$self{'id'} );
	sql::insert( undef, undef, 'tbl_Quote_Users_By',
			'quote_id',		$$self{'id'},
			'strFirstName',		$$data{'ByFirstName'},
			'strLastName',		$$data{'ByLastName'},
			'strCompanyName',	$$data{'ByCompanyName'},
			'strTitle',			$$data{'ByTitle'},
			'strSalutation',	$$data{'BySalutation'},
			'strAddress',		$$data{'ByAddress1'},
			'strAddress2',		$$data{'ByAddress2'},
			'strCity',			$$data{'ByCity'},
			'strState',			$$data{'ByStateProvince'},
			'strCountry',		$$data{'ByCountry'},
			'strPostalCode',	$$data{'ByPostalCode'},
			'strPhone',			$$data{'ByPhone'},
			'strExt',			$$data{'ByExtension'},
			'strFax',			$$data{'ByFax'},
			'strEmail',			$$data{'ByEmail'}
			);
	sql::end_transaction( $dbh, $ac );
	@$self{qw/by_companyname by_firstname by_lastname by_title by_salutation by_address1 by_address2 by_city by_state by_country by_postalcode by_phone by_extension by_fax by_email/} = 
		@$data{qw/ByCompanyName ByFirstName ByLastName ByTitle BySalutation ByAddress1 ByAddress2 ByCity ByState ByCountry ByPostalCode ByPhone ByExtension ByFax ByEmail/};

} # end sub store_user_by_info

sub store_user_for_info {
	my ( $self, $data ) = @_;

	my $ac = sql::start_transaction( $dbh );
	sql::execute( undef, undef, 'DELETE FROM tbl_Quote_Users_For WHERE quote_id=?', $$self{'id'} );
	sql::insert( undef, undef, 'tbl_Quote_Users_For',
			'quote_id',		$$self{'id'},
			'strFirstName',		$$data{'ForFirstName'},
			'strLastName',		$$data{'ForLastName'},
			'strCompanyName',	$$data{'ForCompanyName'},
			'strTitle',			$$data{'ForTitle'},
			'strSalutation',	$$data{'ForSalutation'},
			'strAddress',		$$data{'ForAddress1'},
			'strAddress2',		$$data{'ForAddress2'},
			'strCity',			$$data{'ForCity'},
			'strState',			$$data{'ForStateProvince'},
			'strCountry',		$$data{'ForCountry'},
			'strPostalCode',	$$data{'ForPostalCode'},
			'strPhone',			$$data{'ForPhone'},
			'strExt',			$$data{'ForExtension'},
			'strFax',			$$data{'ForFax'},
			'strEmail',			$$data{'ForEmail'}
		);
	sql::end_transaction( $dbh, $ac );
	@$self{qw/for_companyname for_firstname for_lastname for_title for_salutation for_address1 for_address2 for_city for_state for_country for_postalcode for_phone for_extension for_fax for_email/} = 
		@$data{qw/ForCompanyName ForFirstName ForLastName ForTitle ForSalutation ForAddress1 ForAddress2 ForCity ForState ForCountry ForPostalCode ForPhone ForExtension ForFax ForEmail/};
} # end sub store_for_info

sub description {
	return join('<br/>', map { $_->reference() } $_[0]->Projects() );
}

sub send {
	my $self = shift;

    my %quote;
    $quote{'Quote'} = $self;
	$quote{'uri'} = 'quote';
    openprint::quote::get_user_by_info( $log, $dbh, \%quote, $$self{id} );
    openprint::quote::get_user_for_info( $log, $dbh, \%quote, $$self{id} );

	openprint::quote::get_finished_quote_contents( $log, $dbh, \%quote, $$self{id} );
	my $email_template = misc::load_file( $log, $config{'SkinPath'}.'/email_template.html' );

	my @project_summaries;
# Add a project summary for each project in the quote
	foreach my $Project ($self->Quoted_Projects()) {
		next if ! $Project->include_detailed();
		my %variable;
		if ( $Project->template_id() ) {
			$variable{'Quote'} = $self;
			$variable{'Project'} = $Project->Project();
			$variable{'QuotedProject'} = $Project;
			$variable{'ReplacementText'} = '<style type="text/css">'.misc::load_file( $log, $config{'SkinPath'} . '/css/project.css' ).'</style>'.
			misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/main/quote/_project_template_view.html' );
		} elsif ( -f $config{'SkinPath'} . '/email_content/project_view.html' ) {
			$variable{'ReplacementText'} = misc::load_file( $log, $config{'SkinPath'} . '/email_content/project_view.html' );
		} else {
			$variable{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/project_view.html' );
		} # end if
		$variable{'ReplacementText'} = ssi::variable_substitution( \$variable{'ReplacementText'}, \%variable );
		push @project_summaries, sprintf('Project%d.html',$Project->project_id()), encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$email_template, \%variable ))), 'text/html', 'quoted-printable';
	} # for each Project
	
	my $Me = new openprint::User( $session{'user_id'} );

	if ( $self->Company()->reseller() eq 'Y' or sets::isin( $session{'user_type'}, ['A', 'E']) ) {

		if ( $Me->email_quotes_to_myself() ) {
			my @attachments = ();
			$quote{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/quote_reseller_by_body.html' );
			$quote{'ReplacementText'} = ssi::variable_substitution( \$quote{'ReplacementText'}, \%quote );
			$_ = encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$email_template, \%quote ) ) );
			push @attachments, '', $_, 'text/html', 'quoted-printable';

			$quote{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/quote_reseller_by_invoice.html' );
			$quote{'ReplacementText'} = ssi::variable_substitution( \$quote{'ReplacementText'}, \%quote );
			push @attachments, "Quote$$self{id}.html", encode_qp( ssi::variable_substitution( \$email_template, \%quote ) ), 'text/html', 'quoted-printable';

			my %mail = (
					SMTP    => $openprint::config{'Mail Server'},
					FROM    => sprintf('%s %s <%s>', @$self{'by_firstname','by_lastname','by_email'}),
					TO      => sprintf('%s %s <%s>', @$self{'by_firstname','by_lastname','by_email'}),
					SUBJECT => sprintf('Quote %d for %s : ', $$self{id}, $self->for_companyname(), $self->reference() ),
					);
			misc::send_email_with_attachment( $log, \%mail, @attachments, @project_summaries );
		} # end if

		if ( $quote{'ForEmail'} ne '' and (
					( $quote{'ByFirstName'} ne $quote{'ForFirstName'} ) or
					( $quote{'ByLastName'} ne $quote{'ForLastName'} ) or
					( $quote{'ByCompanyName'} ne $quote{'ForCompanyName'} ) or
					( $quote{'ByTitle'} ne $quote{'ForTitle'} ) or
					( $quote{'BySalutation'} ne $quote{'ForSalutation'} ) or
					( $quote{'ByAddress1'} ne $quote{'ForAddress1'} ) or
					( $quote{'ByAddress2'} ne $quote{'ForAddress2'} ) or
					( $quote{'ByCity'} ne $quote{'ForCity'} ) or
					( $quote{'ByStateProvince'} ne $quote{'ForStateProvince'} ) or
					( $quote{'ByCountry'} ne $quote{'ForCountry'} ) or
					( $quote{'ByPostalCode'} ne $quote{'ForPostalCode'} ) or
					( $quote{'ByPhone'}  ne $quote{'ForPhone'} ) or
					( $quote{'ByExtension'} ne $quote{'ForExtension'} ) or
					( $quote{'ByFax'} ne $quote{'ForFax'} ) or
					( $quote{'ByEmail'} ne $quote{'ForEmail'} )
					) ) {
			openprint::quote::get_finished_quote_contents( $log, $dbh, \%quote, $$self{id} );

			my @attachments = ();
			$quote{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/quote_reseller_for_body.html' );
			$quote{'ReplacementText'} = ssi::variable_substitution( \$quote{'ReplacementText'}, \%quote );
			$_ = encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$email_template, \%quote ) ) );
			push @attachments, '', $_, 'text/html', 'quoted-printable';
			$quote{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/quote_reseller_for_invoice.html' );
			$quote{'ReplacementText'} = ssi::variable_substitution( \$quote{'ReplacementText'}, \%quote );
			$_ = encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$email_template, \%quote ) ) );
			push @attachments, "Quote$$self{id}.html", $_, 'text/html', 'quoted-printable';

			my %mail = (
					SMTP    => $openprint::config{'Mail Server'},
					FROM    => sprintf('%s %s <%s>', @$self{'by_firstname','by_lastname','by_email'}),
					TO      => sprintf('%s %s <%s>', @$self{'for_firstname','for_lastname','for_email'}),
					#TO      => '"Isaac Connor" <iconnor@connortechnology.com>',
					SUBJECT => "Quote $$self{id} : " . $self->reference(),
					);
			misc::send_email_with_attachment( $log, \%mail, @attachments, @project_summaries );
		} # end if for someone else

	} else {
# Not a reseller
		my @attachments = ();

		$quote{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/quote_reseller_by_body.html' );
		$quote{'ReplacementText'} = ssi::variable_substitution( \$quote{'ReplacementText'}, \%quote );
		my $email_template = misc::load_file( $log, $config{'SkinPath'}.'/email_template.html' );
		$_ = encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$email_template, \%quote ) ) );
		push @attachments, '', $_, 'text/html', 'quoted-printable';

		$_ = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/quote_end_user_body.html' );

		$quote{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/quote_end_user_invoice.html' );
		$quote{'ReplacementText'} = ssi::variable_substitution( \$quote{'ReplacementText'}, \%quote );
		push @attachments, "Quote$$self{id}.html", encode_qp( Encode::encode('utf-8',ssi::variable_substitution( \$email_template, \%quote ) ) ), 'text/html', 'quoted-printable';

		my %mail = (
				SMTP    => $openprint::config{'Mail Server'},
				FROM    => sprintf("%s %s <%s>", @$self{'by_firstname','by_lastname','by_email'}),
				TO      => sprintf("%s %s <%s>", @$self{'for_firstname','for_lastname','for_email'}),
				SUBJECT => "$openprint::config{'SiteTitle'}:Quote $$self{id}",
				);
		misc::send_email_with_attachment( $log, \%mail, @attachments );
	} # end if reseller or admin

	if ( $openprint::config{'SendQuoteToAdmin'} eq 'Y' ) {
# Send one to the admin
		$quote{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/quote_admin_body.html' );
		$quote{'ReplacementText'} = ssi::variable_substitution( \$quote{'ReplacementText'}, \%quote );
		my $email_template = misc::load_file( $log, $config{'SkinPath'}.'/email_template.html' );
		$_ = encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$email_template, \%quote ) ) );
		my @body = ('', $_, 'text/html', 'quoted-printable');

		openprint::quote::get_finished_quote_contents( $log, $dbh, \%quote, $$self{id} );
		$quote{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/quote_admin_invoice.html' );
		$quote{'ReplacementText'} = ssi::variable_substitution( \$quote{'ReplacementText'}, \%quote );
		if ( $email_template ) {
			$email_template = encode_qp( Encode::encode('utf-8',ssi::variable_substitution( \$email_template, \%quote ) ) );
			my %mail = (
					SMTP    => $openprint::config{'Mail Server'},
					FROM    => $openprint::config{'QuotingEmail'},
					TO      => $openprint::config{'QuotingEmail'},
#BCC        =>  '"Isaac Connor" <iconnor@penultima.org>',
					SUBJECT => "$$self{'for_companyname'} : Quote $$self{id}",
					);
			misc::send_email_with_attachment( $log, \%mail, @body, "Quote$$self{id}.html", $email_template, 'text/html', 'quoted-printable' );
		} # end if
	} # end if

} # end sub send

sub total {
	my ( $self, $qty_index, $new_value ) = @_;
	if ( defined $new_value ) {
		$$self{'total'.$qty_index} = $new_value;
	} # end if
	return $$self{'total'.$qty_index};
} # end sub total

1;
__END__
