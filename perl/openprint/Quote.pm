package openprint::Quote;
@ISA=qw(openprint::Object);

use MIME::QuotedPrint;
use MIME::Base64;
use openprint::Currency;
use strict;
use openprint ();
use vars qw(%variable $log $dbh);
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require sql;
require openprint::logs;

my $debug = 1;

my %fields = (
	'id'			=>	'index',
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
	);

my %defaults = (
	'created_on'	=>	'NOW()',
	'updated_on'	=>	'NOW()',
);

sub find {
	my %params = @_;
	if ( $params{'id'} ) {
		return new openprint::Quote( $params{'id'} );
	} else {
		my @values;
		my $sql = 'SELECT * FROM tbl_Quotes WHERE 1>0';
		if ( $params{'company_id'} ) {
			if ( ref $params{'company_id'} eq 'ARRAY' ) {
				if ( @{$params{'company_id'}} ) {
					$sql .= q{ AND CompanyIndex IN (} . join(',', map {'?'} @{$params{'company_id'}}). ')';
					push @values, @{$params{'company_id'}};
				} else {
					$log->warn("EMpty company array passed to openprint::Quote::find");
				} # end if
			} else {
				$sql .= q{ AND CompanyIndex=?};
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
			$sql .= q{ AND (dtmquotedate BETWEEN ? AND ?)};
			push @values, @params{'created_on_start','created_on_end'};
		} elsif ( $params{'created_on_start'} ) {
			$sql .= q{ AND (dtmquotedate >= ?::timestamp with time zone)};
			push @values, $params{'created_on_start'};
		} elsif ( $params{'created_on_end'} ) {
			$sql .= q{ AND (dtmquotedate <= ?::timestamp with time zone)};
			push @values, $params{'created_on_end'};
		} # end if
		if ( $params{'value_start'} and $params{'value_end'} ) {
			$sql .= q{ AND (curtotalsale BETWEEN ? AND ? )};
			push @values, $params{'value_start','value_end'};
		} elsif ( $params{'value_start'} ) {
			$sql .= q{ AND (curtotalsale >= ?)};
			push @values, $params{'value_start'};
		} elsif ( $params{'value_end'} ) {
			$sql .= q{ AND (curtotalsale <= ?)};
			push @values, $params{'value_end'};
		} # end if
		if ( $params{'status'} ) {
			if ( ref $params{'status'} eq 'ARRAY' ) {
				$sql .= q{ AND strStatus IN (} . join(',', map {'?'} @{$params{'status'}}). ')';
				push @values, @{$params{'status'}};
			} else {
				$sql .= q{ AND (strStatus=?)};
				push @values, $params{'status'};
			} # end if
		} # end if
		if ( $params{'for_name'} ) {
			$sql .= q{ AND (SELECT strFirstName || ' ' || strLastName FROM tbl_Quote_Users_for WHERE quoteindex=index)=?};
			push @values, $params{'for_name'};
		} # end if
		if ( $params{'id_like'} ) {
			$sql .= " AND index LIKE '$params{'id_like'}%'";
		} # end if

		if ( exists $params{'order'} ) {
			if ( $params{'order'} eq 'created_on' ) {
				$sql .= ' ORDER BY dtmquotedate';
			} elsif ( $params{'order'} ) {
				$sql .= " ORDER BY $params{'order'}" if $params{'order'};
			} # end if
		} # end if
		$sql .= " LIMIT $params{'limit'}" if $params{'limit'};
		my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
		if ( ! $data ) {
			$log->error("Error loading Quotes: ($sql) (@values)");
			return;
		} elsif ( $debug ) {
			$log->debug("Loading Quotes: ($sql) (@values)");
		} # end if
		return map { new openprint::Quote( $_->{index}, $_ ) } @$data;
	} # end if
} # end sub find

sub copy {
	my $self = shift;
	my $new = new openprint::Quote( );
	return $new;
} # end sub copy

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $dbh->selectrow_hashref( q{SELECT * FROM tbl_Quotes WHERE index=?}, {}, $$self{'id'} );
	} # end if
	@$self{keys %fields} = @$data{@fields{keys %fields}};

	$data = $dbh->selectrow_hashref( q{SELECT * FROM tbl_Quote_Users_for WHERE quoteindex=?}, {}, $$self{'id'} );
	@$self{qw/for_companyname for_firstname for_lastname for_title for_salutation for_address1 for_address2 for_city for_state for_country for_postalcode for_phone for_extension for_fax for_email/} = @$data{qw/strcompanyname strfirstname strlastname strtitle strsalutation straddress straddress2 strcity strstate strcountry strpostalcode strphone strextension strfax stremail/};

	$data = $dbh->selectrow_hashref( q{SELECT * FROM tbl_Quote_Users_by WHERE quoteindex=?}, {}, $$self{'id'} );
	@$self{qw/by_companyname by_firstname by_lastname by_title by_salutation by_address1 by_address2 by_city by_state by_country by_postalcode by_phone by_extension by_fax by_email/} = @$data{qw/strcompanyname strfirstname strlastname strtitle strsalutation straddress straddress2 strcity strstate strcountry strpostalcode strphone strextension strfax stremail/};
} # end sub load

sub save {
	my $self = shift;
	my %sql;
	foreach my $key ( keys %fields ) {
		$sql{$fields{$key}} = ( defined $$self{$key} ? $$self{$key} : $defaults{$key} );
	} # end foreach
		
	if ( ! $$self{'id'} ) {
		my $ac = sql::start_transaction( $dbh );
		if ( $openprint::config{'QuoteIDFormat'} eq 'Year' ) {
			$dbh->do( "LOCK TABLE tbl_Quotes IN SHARE ROW EXCLUSIVE MODE" ) or $log->error( DBI->errstr );

			my ( $quote ) = sql::execute( undef, undef, q{SELECT MAX(Index) FROM tbl_Quotes} );
			$quote =~ /(\d\d\d\d)/;
			if ( $1 > ( 1900 + (localtime(time))[5]) or $quote eq '' ) {
				return (1900 + (localtime(time))[5]) . '00001';
			} # end if
			$$self{'id'} = $quote + 1;
		} else {
			@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('Quotes_id_seq')} );
		} # end if
		$sql{'index'} = $$self{'id'};
		if ( ( my $error = sql::insert( undef, undef, 'tbl_Quotes', \%sql ) ) ) {
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if
		sql::end_transaction( $dbh, $ac );
	} else {
		sql::update( undef, undef, 'tbl_Quotes', ['Index=?', $$self{'id'}], \%sql );
	} # end if
	$self->load();
	return;
} # end sub save

sub delete {
	my $self = shift;

	if ( ! $$self{'id'} ) {
		$log->error("Quote::delete called with no id");
		return;
	}

	my $ac = sql::start_transaction( $dbh );
	sql::execute( undef, undef, 'DELETE FROM tbl_Quote_Details WHERE QuoteIndex=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM tbl_Quote_Users_By WHERE QuoteIndex=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM tbl_Quote_Users_For WHERE QuoteIndex=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM tbl_Quotes WHERE Index=?', $$self{'id'} );
	sql::end_transaction( $dbh, $ac );
	openprint::logs::insertLogRecord('11', "Quote Index: " . $$self{'id'},);
} # end sub delete

sub to_string {
	my $self = shift;
	return '';
} # end sub

sub created_on {
	my $self = shift;
	if ( @_ ) {
		$$self{'created_on'} = shift;
	} # end if
	return $$self{'created_on'};
} # end sub created_on
sub created_by_id {
	my $self = shift;
	return $$self{'created_by_id'};
} # end sub created_by_id

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
			'company_id',	$openprint::session{'company_id'},
			'user_id',		$openprint::session{'user_id'},
			'Description',	$comment,
			);
} # end sub add_log

sub Company {
	my $self = shift;
	return new openprint::Company( $$self{'company_id'} );
} # end sub company
sub Projects {
	my $self = shift;
	if ( ! exists $$self{'Projects'} ) {
	@{$$self{'Projects'}} = map {new openprint::Project( $_ );} sql::execute( undef, undef, q{SELECT ProjectIndex FROM tbl_Quote_Details WHERE QuoteIndex=?}, $$self{'id'} );
	} # end if
	return @{$$self{'Projects'}};
} # end sub projects

sub Currency {
	my $self = shift;
	if ( @_ ) {
		$$self{'currency_id'} = (shift @_)->id();
	} # end if
	return new openprint::Currency( $$self{'currency_id'} );
} # end sub Currency

sub for_name {
	my $self = shift;
	return $$self{'for_firstname'} . ' ' . $$self{'for_lastname'};
} # end sub

sub contents {
	my $self = shift;
	$$self{'contents'} = $dbh->selectall_arrayref( q{SELECT * FROM tbl_Quote_Details WHERE QuoteIndex=?}, {Slice=>{}}, $$self{'id'} );
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
	sql::execute( undef, undef, 'DELETE FROM tbl_Quote_Users_By WHERE QuoteIndex=?', $$self{'id'} );
	sql::insert( undef, undef, 'tbl_Quote_Users_By',
			'QuoteIndex',		$$self{'id'},
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
	sql::execute( undef, undef, 'DELETE FROM tbl_Quote_Users_For WHERE QuoteIndex=?', $$self{'id'} );
	sql::insert( undef, undef, 'tbl_Quote_Users_For',
			'QuoteIndex',		$$self{'id'},
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

sub send {
	my $self = shift;

    my %quote;
    $quote{'Quote'} = $self;
    openprint::quote::get_user_by_info( $log, $dbh, \%quote, $$self{id} );
    openprint::quote::get_user_for_info( $log, $dbh, \%quote, $$self{id} );

	openprint::quote::get_finished_quote_contents( $log, $dbh, \%quote, $$self{id} );
	my $email_template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/email_template.html' );

	my @project_summaries;
	if ( $self->Company()->quote_project_breakdown() eq 'Y' ) {
		# Add a project summary for each project in the quote
		foreach my $Project ($self->Projects()) {
			my %variable;
			openprint::project::view( $openprint::log, $openprint::dbh, \%variable, $Project->id() );
			$variable{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/project_view.html' );
			$variable{'ReplacementText'} = ssi::variable_substitution( $openprint::r, $openprint::log, $openprint::dbh, \$variable{'ReplacementText'}, \%variable );
			push @project_summaries, sprintf('Project%d.html',$Project->id()), encode_qp( ssi::variable_substitution( $openprint::r, $openprint::log, $openprint::dbh, \$email_template, \%variable )), 'text/html', 'quoted-printable';
		} # for each Project
	} # end if

	if ( $self->Company()->reseller() eq 'Y' or sets::isin( $openprint::session{'user_type'}, ['A', 'E']) ) {

		my @attachments = ();
		$quote{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/quote_reseller_by_body.html' );
		$quote{'ReplacementText'} = ssi::variable_substitution( \$quote{'ReplacementText'}, \%quote );
		$_ = encode_qp( ssi::variable_substitution( \$email_template, \%quote ) );
		push @attachments, '', $_, 'text/html', 'quoted-printable';

		$quote{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/quote_reseller_by_invoice.html' );
		$quote{'ReplacementText'} = ssi::variable_substitution( \$quote{'ReplacementText'}, \%quote );
		push @attachments, "Quote$$self{id}.html", encode_qp( ssi::variable_substitution( \$email_template, \%quote ) ), 'text/html', 'quoted-printable';

		my %mail = (

				SMTP    => $openprint::config{'Mail Server'},
				FROM    => sprintf("%s %s <%s>", @$self{'by_firstname','by_lastname','by_email'}),
				TO      => sprintf("%s %s <%s>", @$self{'by_firstname','by_lastname','by_email'}),
				SUBJECT => sprintf('Quote %d for %s', $$self{id}, $self->for_companyname() ),
				);
		misc::send_email_with_attachment( $log, \%mail, @attachments, @project_summaries );
#misc::send_email_with_attachment( $log, \%mail, @attachments, @project_summaries );

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
			$_ = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/quote_reseller_for_body.html' );
			if ( $_ ) {
				$_ = ssi::variable_substitution( \$_, \%quote );
				push @attachments, '', encode_qp($_), 'text/html', 'quoted-printable';
			} # end if
			$_ = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/quote_reseller_for_invoice.html' );
			if ( $_ ) {
				$_ = ssi::variable_substitution( \$_, \%quote );
				push @attachments, "Quote$$self{id}.html", encode_qp($_), 'text/html', 'quoted-printable';
			} # end if


			my %mail = (
					SMTP    => $openprint::config{'Mail Server'},
					FROM    => sprintf("%s %s <%s>", @$self{'by_firstname','by_lastname','by_email'}),
					TO      => sprintf("%s %s <%s>", @$self{'for_firstname','for_lastname','for_email'}),
					SUBJECT => "Quote $$self{id}",
					);
			misc::send_email_with_attachment( $log, \%mail, @attachments, @project_summaries );
		} # end if

	} else {
# Not a reseller
		my @attachments = ();

		$quote{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/quote_reseller_by_body.html' );
		$quote{'ReplacementText'} = ssi::variable_substitution( \$quote{'ReplacementText'}, \%quote );
		my $email_template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/email_template.html' );
		$_ = encode_qp( ssi::variable_substitution( \$email_template, \%quote ) );
		push @attachments, '', $_, 'text/html', 'quoted-printable';

		$_ = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/quote_end_user_body.html' );
#if ( $_ ) {
#$_ = ssi::variable_substitution( \$_, \%quote );
#push @attachments, '', encode_qp($_), 'text/html', 'quoted-printable';
#} # end if
#get_finished_quote_contents( $log, $dbh, \%quote, $$self{id} );

		$quote{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/quote_end_user_invoice.html' );
		$quote{'ReplacementText'} = ssi::variable_substitution( \$quote{'ReplacementText'}, \%quote );
		$_ = encode_qp( ssi::variable_substitution( \$email_template, \%quote ) );
		push @attachments, "Quote$$self{id}.html", $_, 'text/html', 'quoted-printable';

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
		my $email_template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );
		$_ = encode_qp( ssi::variable_substitution( \$email_template, \%quote ) );
		my @body = ('', $_, 'text/html', 'quoted-printable');

		openprint::quote::get_finished_quote_contents( $log, $dbh, \%quote, $$self{id} );
		$quote{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/quote_admin_invoice.html' );
		$quote{'ReplacementText'} = ssi::variable_substitution( \$quote{'ReplacementText'}, \%quote );
		if ( $email_template ) {
			$email_template = encode_qp( ssi::variable_substitution( \$email_template, \%quote ) );
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

} # end sub send_quote

1;
__END__
