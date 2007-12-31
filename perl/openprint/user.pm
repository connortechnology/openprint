package openprint::user;
use MIME::QuotedPrint;

use strict;

require sql;
require misc;
require openprint::usergroup;
require openprint::logs;

# This function saves Information into the Users table.  It will create records if neccessary.
# Most parameters are self-explanatory, except for $variable which is defined to be a pointer to a hash array of values
# for the various fields.  

sub load {
    my ( $log, $dbh, $user_id, $variable ) = @_;

	$_ = "SELECT strEmail, strPassword, strTitle, strFirstName, strLastName, strSalutation, strPhone, strExt, strFax, ysnChangePassword, chrType, ysnMailingList, CompanyIndex, dblCommission, strCustomGreeting, ysnAccountActivation, ysnAdministrator, dtmdateentered, dtmlastmodified, ftp_active\n".
			"FROM Users WHERE Index=?";
	@$variable{'txtEmail',
		'txtPassword',
		'txtTitle',
		'txtFirstName',
		'txtLastName', 
		'rdbSalutation',
		'txtPhone',
		'txtExtension',
		'txtFax',
		'rdbChangePassword',
		'UserType',
		'rdbMailingList',
		'CustomerIndex',
		'txtCommission',
		'txtCustomGreeting',
		'AccountActivation',
		'rdbAdministrator',
		'CreatedOn', 'UpdatedOn','ftp_active'
	} = sql::execute( $log, $dbh, $_, $user_id );
} # end sub load_user

sub save {
    my ( $r, $log, $dbh, $variable, $user_id ) = @_;

	my $User = new openprint::User( $user_id );
	# send a notification about change of type
	if ( defined $r->param('ddmUserType') ) {
		my $user_type = $User->Type();

		if ( $user_type ne $r->param('ddmUserType') ) {
			my %info;
			if ( $r->param('ddmUserType') eq 'R' ) {
				$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/usertype_reseller_notification.html' );
			} elsif ( $r->param('ddmUserType') eq 'S' ) {
				$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/usertype_supplier_notification.html' );
			} elsif ( $r->param('ddmUserType') eq 'A' ) {
				$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/usertype_administrator_notification.html' );
			} elsif ( $r->param('ddmUserType') eq 'C' ) {
				$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/usertype_customer_notification.html' );
			} elsif ( $r->param('ddmUserType') eq 'E' ) {
				$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/usertype_employee_notification.html' );
			} else {
				$log->warn( "Unknown User Type Requested!" );
			} # end if
			$info{'User'} = $User;
			$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );

			my $email_template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );
			$email_template = ssi::variable_substitution( \$email_template, \%info );

			my %mail = (
					SMTP    => $openprint::config{'Mail Server'},
					FROM    => $openprint::config{'AdministratorEmail'},
					TO      => $r->param('txtEmail'),
					SUBJECT => "User type has changed!"
					);
			misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp($email_template), 'text/html', 'quoted-printable' ) );

			if ( $r->param('ddmUserType') ne 'C' ) {
				# Notify someone
				my %info;
				@info{'UserFirstName','UserLastName','UserType'} = ( $r->param('txtFirstName'), $r->param('txtLastName'), $r->param('ddmUserType') );
				$_ = "SELECT strFirstName, strLastName, strEmail, strExt FROM Users WHERE Index = '$openprint::session{'user_id'}'";
				@info{'EmployeeFirstName','EmployeeLastName','EmployeeEmail','EmployeeExtension'} = sql::execute( $log, $dbh, $_ );

				$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/usertype_system_notification.html' );
				$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );

				my $email_template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );
				$email_template = ssi::variable_substitution( \$email_template, \%info );

				my %mail = (
						SMTP    => $openprint::config{'Mail Server'},
						FROM    => $openprint::config{'LoginEmail'},
						TO      => $openprint::config{'LoginEmail'},
						SUBJECT => "Someone's UserType has changed!"
						);
				misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp($email_template), 'text/html', 'quoted-printable' ) );

			} # end if
		} # end if
	} # end if

	if ( defined $r->param('rdbAccountActivation') ) {
		if ( $User->AccountActivation() ne $r->param('rdbAccountActivation') ) {
			my %info;
			$info{'User'} = $User;
			$info{'SecureSiteURL'} = $r->dir_config('SecureSiteURL');
			$info{'siteURL'} = $r->dir_config('siteURL');
			$info{'CustomerServiceEmail'} = $openprint::config{'CustomerServiceEmail'};
			$_ = $r->param('rdbAccountActivation') eq 'Y' ? 'user_account_activated.html' : 'user_account_deactivated.html';
			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . "/email_content/$_" );
			$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
            my $email_template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );
			$email_template = ssi::variable_substitution( \$email_template, \%info );

			my %mail = (
					SMTP    => $openprint::config{'Mail Server'},
					FROM    => $openprint::config{'AdministratorEmail'},
					TO      => $r->param('txtEmail'),
					SUBJECT => "User account status has changed!"
					);
			misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp($email_template), 'text/html', 'quoted-printable' ) );
		} # end if
	} # end if

	sql::update( $log, $dbh, 'Users', "Index = '$user_id'", 
			( defined $r->param('ddmCompany') ? ( 'CompanyIndex', $r->param('ddmCompany') ) : () ),
			( defined $r->param('txtTitle') ? ( 'strTitle', $r->param('txtTitle') ) : () ),
			( defined $r->param('txtFirstName') ? ( 'strFirstName', $r->param('txtFirstName') ) : () ),
			( defined $r->param('txtLastName') ? ( 'strLastName', $r->param('txtLastName') ) : () ),
			( defined $r->param('rdbSalutation') ? ( 'strSalutation', $r->param('rdbSalutation') ) : () ),
			( defined $r->param('txtEmail') ? ( 'strEmail', lc $r->param('txtEmail') ) : () ),
			( defined $r->param('txtPhone') ? ( 'strPhone', $r->param('txtPhone') ) : () ),
			( defined $r->param('txtExtension') ? ( 'strExt', $r->param('txtExtension') ) : () ),
			( defined $r->param('txtFax') ? ( 'strFax', $r->param('txtFax') ) : () ),
			( defined $r->param('txtCommission') ? ( 'dblCommission', ( $r->param('txtCommission') ne '' ? $r->param('txtCommission') : '0' ) ) : () ),
			( defined $r->param('txtCustomGreeting') ? ( 'strCustomGreeting', $r->param('txtCustomGreeting') ) : () ),
			( defined $r->param('ddmUserType') ? ( 'chrType', $r->param('ddmUserType') ) : () ),
			( $r->param('txtPassword') ne '' ? ( 'strPassword', $r->param('txtPassword') ) : () ),
			( defined $r->param('rdbChangePassword') ? ( 'ysnChangePassword', $r->param('rdbChangePassword') ) : () ),
			( defined $r->param('rdbMailingList') ? ( 'ysnMailingList', $r->param('rdbMailingList') ) : () ),
			( defined $r->param('rdbAccountActivation') ? ( 'ysnAccountActivation', $r->param('rdbAccountActivation') ) : () ),
			( defined $r->param('rdbAdministrator')		? ( 'ysnAdministrator',	$r->param('rdbAdministrator') ) : () ),
			( defined $r->param('ftp_active') ? ( 'ftp_active', $r->param('ftp_active') ) : () ),
			'dtmlastmodified',      'NOW()',
			() );
			
   # Add record to audit log - action "Update User Profile".
	openprint::logs::insertLogRecord('71', "ID: $user_id - " . lc $r->param('txtEmail') ,);
	return;
} # end sub save

sub add {
	my ( $r, $log, $dbh, $variable, $cust_id ) = @_;

	my $email = lc $r->param('txtEmail');  # email is a required field
	my $password = $r->param('txtPassword');

	sql::insert( $log, $dbh, 'Users',
			'CompanyIndex', $cust_id,
			'chrType', ( defined $r->param('ddmUserType') ? $r->param('ddmUserType') : 'C' ),
			'strEmail', $email,
			( defined $r->param('txtPassword') ? ( 'strPassword', $password ) : () ),
			( defined $r->param('txtTitle')             ? ( 'strTitle',             $r->param('txtTitle') ) : () ),
			( defined $r->param('txtFirstName')         ? ( 'strFirstName',         $r->param('txtFirstName') ) : () ),
			( defined $r->param('txtLastName')          ? ( 'strLastName',          $r->param('txtLastName') ) : () ),
			( defined $r->param('rdbSalutation')        ? ( 'strSalutation',        $r->param('rdbSalutation') ) : () ),
			( defined $r->param('txtPhone')             ? ( 'strPhone',             $r->param('txtPhone') ) : () ),
			( defined $r->param('txtExtension')         ? ( 'strExt',               $r->param('txtExtension') ) : () ),
			( defined $r->param('txtFax')               ? ( 'strFax',               $r->param('txtFax') ) : () ),
			( defined $r->param('rdbMailingList')       ? ( 'ysnMailingList',       $r->param('rdbMailingList') ) : () ),
			( defined $r->param('txtCustomGreeting')    ? ( 'strCustomGreeting',    $r->param('txtCustomGreeting') ) : () ),
			( defined $r->param('rdbChangePassword')    ? ( 'ysnChangePassword',    $r->param('rdbChangePassword') ) : () ),
			( defined $r->param('rdbAccountActivation')	? ( 'ysnAccountActivation',	$r->param('rdbAccountActivation') ) : () ),
			( defined $r->param('rdbAdministrator')		? ( 'ysnAdministrator',	$r->param('rdbAdministrator') ) : () ),
			( defined $r->param('ftp_active') ? ( 'ftp_active', $r->param('ftp_active') ) : () ),
			'dtmDateEntered',  'NOW()',
			'dtmLastModified', 'NOW()'
			);

	( $_ ) = sql::execute( $log, $dbh, 'SELECT Index FROM Users WHERE strEmail=?', $email );

   # Add record to audit log - action "New User Profile".
   openprint::logs::insertLogRecord('70', "ID: $_ - $email",);
	
	return $_;

} # end sub add

sub groups {
    my ( $log, $dbh, $id ) = @_;

    if ( ! $id ) {
        $log->warn("user::groups called with no userid!");
        return;
    } # end if

    return sql::execute( $log, $dbh, q{SELECT usergroup_id FROM users_in_usergroups WHERE user_id=?}, $id );
} # end sub groups


1;

__END__

