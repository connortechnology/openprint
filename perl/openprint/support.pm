use strict;
package openprint::support;

require MIME::QuotedPrint;
use Email::Valid ();
use openprint ();
use vars qw( $r $log $dbh %variable %param %session %config);
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*param = \%openprint::param;
*session = \%openprint::session;
*config = \%openprint::config;

require sql;
require openprint::RMA;
require openprint::RMA_Type;
require openprint::RMA_Status;

sub returns {
	if ( $param{action} eq 'Submit' ) {

		$param{project_id} = openprint::Project->transform( 'id', $param{project_id} );
		my $Order;

		if ( $param{docket} ) {
			$param{docket} = openprint::Order->transform('docket', $param{docket} );
			$Order = openprint::Order->find_one(docket=>$param{docket}) if $param{docket};
		} elsif ( $param{order_id} ) {
			$param{order_id} = openprint::Order->transform('id', $param{order_id} );
			$Order = openprint::Order->find_one(id=>$param{order_id}) if $param{order_id};
		} # end if

		if ( ! $Order ) {
			if ( $config{RMAValidOrder} ne 'Y' ) {
				$Order = new openprint::Order();
				$variable{error} .= $Order->save({
					id		=>	$param{order_id},
					docket	=>	$param{docket},
					company_id => ( $param{company_id} ? $param{company_id} : $session{company_id} ),
				}, 1 );
			} else {
				$variable{error} .= 'Invalid Order ID';
				return;
			} # end if
		} elsif ( ( ! sets::isin( $session{user_type}, ['E','A'] ) ) and ( $Order->company_id() != $session{company_id} ) ) {
			$variable{error} .= 'You are not the owner of that order.';
			return;
		} # end if

		my $Project = new openprint::Project( $param{project_id} );
		if ( $param{project_id} and ! openprint::OrderedProject->find(order_id=>$$Order{id},project_id=>$param{project_id}) ) {
			$variable{error} .= qq`Order <a href="/main/order/history_details.html?order_id=$$Order{id}">$$Order{id}</a> does not contain project <a href="/main/project/view.html?project_id=$param{project_id}">$param{project_id}</a>.`;
			return;
		} # end if

		my $RMA = new openprint::RMA();
		$variable{error} .= $RMA->save({
				project_id		=>	$param{project_id},
				company_id		=>	( sets::isin( $session{user_type}, ['E','A'] ) ? $param{company_id} : $session{'company_id'} ),
				user_id			=>	$session{user_id},
				order_id		=>	$$Order{id},
				type_id			=>	$param{type_id},
				description		=>	$param{description},
				});
		return if $variable{error};
		
		$session{information} .= 'RMA has been saved.';

		my %info = (
			RMA		=>	$RMA,
			Project	=>	$Project,
			Order	=>	$Order,
		);

		my $template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/rma_notification.html' );
		$template = ssi::variable_substitution( \$template, \%info );

		my $Email = new openprint::Email();
		$Email->html_body( $template );
		$Email->send(
				FROM	=> $config{'RMAEmail'},
				TO		=> $config{'RMAEmail'},
				SUBJECT => 'Online RMA Submission.',
				);

		$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/rma_confirmation.html' );
		$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );

		$template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
		$template = ssi::variable_substitution( \$template, \%info );

		$Email->html_body( $template );
		$Email->send(
				TO		=> $info{'Email'},
				);
		$variable{ExternalRedirect} = '/support/returns.html';
		%param = ();
	} # end if action

} # end sub rma

sub help_desk {
} # end sub help_desk

sub confirmation_help_desk {

	my $error = '';
	$error .= 'Missing First Name<br/>' if $param{'txtFirstName'} eq '';
	$error .= 'Missing Last Name<br/>' if $param{'txtLastName'} eq '';
	$error .= 'Missing Address<br/>' if $param{'txtAddress1'} eq '';
	$error .= 'Missing City<br/>' if $param{'txtCity'} eq '';
	$error .= 'Missing Postal Code<br/>' if $param{'txtPostalCode'} eq '';
	$error .= 'Missing Phone<br/>' if $param{'txtPhone'} eq '';
	$error .= 'Missing/Invalid E-mail<br/>' if ( ! $param{'txtEmail'} ) or ( ! Email::Valid->address( $param{'txtEmail'} ) );
	$error .= 'Missing Question or Comment<br/>' if $param{'txtQuestion-Quote'} eq '';
	if ( ! $session{'user_id'} ) {
		# Remove spaces, because some people want to put spaces between the characters, etc.
		$param{'Captcha'} =~ s/\s//g;
		require Authen::Captcha;
		my $Captcha = new Authen::Captcha('data_folder' => '/tmp', 'output_folder' => $config{'SkinPath'}.'/images/captcha');
		if ( 1 != $Captcha->check_code( $param{'Captcha'}, $param{'MD5SUM'} ) ) {
			$error .= 'Validation Code incorrect. Please try again.';
		} # end if
	} # end if

	if ( $error ) {
		return misc::error( $log, $dbh, \%variable, 'Bad Field', $error );
	} # end if

	my ( $index ) = sql::execute( $log, $dbh, q{SELECT nextval('HelpDesk_Id_seq')} );
	if ( ! $index ) {
		return misc::error( $log, $dbh, \%variable, 'System Error', 'Unable to create helpdesk entry.' );
	} # end if

	sql::insert( $log, $dbh, 'Helpdesk',
			'Id', $index,
			'company_id', $session{'company_id'},
			'user_id',	 $session{'user_id'},
			'strCompanyName',	$param{'txtCompanyName'},
			'strTitle',			$param{'txtTitle'},
			'strFirstName',		$param{'txtFirstName'},
			'strLastName',		$param{'txtLastName'},
			'strAddress',		$param{'txtAddress1'},
			'strAddress2',		$param{'txtAddress2'},
			'strCity',			$param{'txtCity'},
			'strStateProv',		$param{'ddmStateProvince'},
			'strPostalCode',	$param{'txtPostalCode'},
			'strCountry',		$param{'ddmCountry'},
			'strPhone',			$param{'txtPhone'},
			'strExtension',		$param{'txtExtension'},
			'strEmail',			$param{'txtEmail'},
			'blbdescription',	$param{'txtQuestion-Quote'},
			'chrMethod',		$param{'rdbMethod'},
			'dtmRequestDate',	'NOW()',
			);

	my %info = ( 
			'HelpDeskIndex' => $index,
			'txtSalutation'	=>	$param{'rdbSalutation'},
			'txtFirstName'	=>	$param{'txtFirstName'},
			'txtLastName'	=>	$param{'txtLastName'},
			);

	@info{ keys %param } = @param{ keys %param };
	
	my $template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/helpdesk_notification.html' );
	$template = ssi::variable_substitution( \$template, \%info );

	my $Email = new openprint::Email();
	$Email->send(
			FROM	=> sprintf('"%s %s" <%s>', @param{'txtFirstName','txtLastName','txtEmail'} ),
			TO		=> $config{'HelpdeskEmail'},
			SUBJECT => 'Online Helpdesk Submission.',
			ATTACHMENTS =>	[ '', MIME::QuotedPrint::encode_qp($template), 'text/html', 'quoted-printable' ],
			);

	if ( 0 ) {
		# Sends an email saying we will get back to you as soon as possible.  Completely useless.
	$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/helpdesk_confirmation.html' );
	$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
	my $email_template = misc::load_file( $log, $config{'SkinPath'}. '/email_template.html' );
	$email_template = ssi::variable_substitution( \$email_template, \%info );

	$Email = new openprint::Email();
	$Email->send(
			FROM	=> sprintf('"%s %s" <%s>', @param{'txtFirstName','txtLastName','txtEmail'} ),
			TO		=> sprintf('"%s %s" <%s>', @param{'txtFirstName','txtLastName','txtEmail'} ),
			FROM	=> $config{'HelpdeskEmail'},
			SUBJECT => 'Online Helpdesk Submission.',
			ATTACHMENTS =>	[ '', MIME::QuotedPrint::encode_qp($email_template), 'text/html', 'quoted-printable' ],
		);
	} # end if

} # end sub helpdesk

1;

__END__
