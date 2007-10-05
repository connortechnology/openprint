package openprint::reseller_application;
use MIME::QuotedPrint;
use strict;

require sql;
require ssi;
require misc;

require openprint::customer;
require openprint::obj_customer;

	my %fields = (
			'rdbLegalForm'			=>	'LegalForm',
			'txtLegalBusinessName'	=>	'LegalBusinessName',
			'txtBusinessType'		=>	'BusinessType',
			'BusinessStartDate'		=>	'BusinessStartDate',
			'txtPresidentOwner'		=>	'PresidentOwner',
			'ddmEmployees'			=>	'Employees',
			'ddmAnnualSales'		=>	'AnnualSales',
			'txtGSTNumber'			=>	'TaxNumber1',
			'txtPSTNumber'			=>	'TaxNumber2',
	);

sub reseller_application_display {
	my ( $r, $log, $dbh, $variable ) = @_;

	if ( $openprint::session{'company_id'} ) {

		my $customer = new openprint::obj_customer( $log, $dbh, $openprint::session{'company_id'} );
		@$variable{ keys %fields } = ssi::htmlize( $customer->get( @fields{ keys %fields } ) );

		$$variable{'BusinessStartDate'} =~ /^(\d\d\d\d)-(\d\d)-(\d\d) .*/;
		$$variable{'txtStartYear'} = $1;
		$$variable{'rdbLegalForm'.$$variable{'rdbLegalForm'}} = 'checked';

		$$variable{'ddmEmployees'} = ssi::getemployee_numbers( $r, $log, $dbh, $$variable{'ddmEmployees'} );
		$$variable{'ddmAnnualSales'} = ssi::getannual_sales( $r, $log, $dbh, $$variable{'ddmAnnualSales'} );

		openprint::customer::load_shipping( $log, $dbh, $openprint::session{'company_id'}, $variable );
		openprint::customer::load_tradereferences( $r, $log, $dbh, $openprint::session{'company_id'}, $variable );

		$$variable{'ddmShippingStateProvince'} = ssi::return_states_and_provinces($$variable{'ddmShippingStateProvince'});
		$$variable{'ddmShippingCountry'} = ssi::return_countries($$variable{'ddmShippingCountry'});
	} # end if
} # end sub reseller_application_display

sub reseller_application_process {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $cust_id = $openprint::session{'company_id'};
	my $user_id = $openprint::session{'user_id'};
	my ( $email ) = sql::execute( $log, $dbh, 'SELECT strEmail FROM Users WHERE Index=?', $user_id );

	my $error = '';
	# first, check all fields that are required

	$error .= "Missing legal form<br>" if $r->param('rdbLegalForm') eq '';
	$error .= "Missing legal business name<br>" if $r->param('txtLegalBusinessName') eq '';
	$error .= "Missing legal business type<br>" if $r->param('txtBusinessType') eq '';
	$error .= "Missing President/Owner<br>" if $r->param('txtPresidentOwner') eq '';
#$error .= "Bad Federal Tax number<br>" if $r->param('txtGSTNumber') eq '';
#$error .= "Bad State Tax number<br>" if $r->param('txtPSTNumber') eq '';

	foreach my $tr ( 1 .. 3 ) {
		$error .= "Missing company name for trade reference $tr<br>" if $r->param('txtTradeReferenceCompanyName'.$tr) eq '';
		$error .= "Missing contact for trade reference $tr<br>" if $r->param('txtTradeReferenceContact'.$tr) eq '';
		$error .= "Missing phone number for trade reference $tr<br>" if $r->param('txtTradeReferencePhone'.$tr) eq '';
#$error .= "Missing email address for trade reference $tr<br>" if $r->param('txtTradeReferenceEmail'.$tr) eq '';
	} # end foreach



# process error conditions
	if ( $error ne '' ) {
		return misc::error( $log, $dbh, $variable, 'Bad Field', $error );
	} # end if

    my $customer = new openprint::obj_customer( $log, $dbh, $openprint::session{'company_id'} );
    my %params;
    foreach my $field ( keys %fields ) { 
        $params{$fields{$field}} = $r->param($field) if defined $r->param($field);
    } # end foreach 

	my $startyear = $r->param('txtStartYear');
	$startyear =~ s/\D//g;
    if ( $startyear ) {
        $params{'BusinessStartDate'} = sprintf( '%.4d-%.2d-%.2d', $startyear, ( $r->param('ddmStartMonth') ? $r->param('ddmStartMonth') : '01' ) , 1 );
    } # end if 
    $customer->set( \%params );
	openprint::customer::save_shipping( $r, $log, $dbh, $cust_id );
	openprint::customer::save_tradereferences( $r, $log, $dbh, $cust_id );

	my %info;
	$info{'date'} = localtime;
    $info{'SecureSiteURL'} = $r->dir_config('SecureSiteURL');
    $info{'siteURL'} = $r->dir_config('siteURL');

	my $email_template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/email_template.html' );

	my @fields = keys %fields;
	@info{ @fields } = $customer->get( @fields{@fields} );
	openprint::user::load( $log, $dbh, $user_id, \%info );
	$info{'txtEmployees'} = ssi::get_range_text( sql::execute( $log, $dbh, "SELECT Min, Max FROM EmployeeNumbers WHERE ID=$info{'ddmEmployees'}" ) );
	$info{'txtAnnualSales'} = ssi::get_range_text( sql::execute( $log, $dbh, "SELECT Min, Max FROM AnnualSales WHERE Id=$info{'ddmAnnualSales'}" ) );

#$template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/reseller_application_confirmation.html' );
#$template = ssi::variable_substitution( $r, $log, $dbh, $template, \%info );
#
#my %mail = (
#SMTP	=>	$openprint::config{'Mail Server'},
#TO		=>	$email,
#FROM	=>	'creditapp@'.$openprint::config{'domain'},
#SUBJECT =>	"Reseller application received."
#);
#misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp($template), 'text/html', 'quoted-printable' ) );

	$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/reseller_application_notification.html' );
	$info{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, $info{'ReplacementText'}, \%info );
	my $template = ssi::variable_substitution( $r, $log, $dbh, $email_template, \%info );

	my %mail = (
			SMTP	=> $openprint::config{'Mail Server'},
			FROM	=> $openprint::config{'ResellerApplicationEmail'},
			TO		=> $openprint::config{'ResellerApplicationEmail'},
			SUBJECT	=> "New Reseller Application"
			);

	misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp($template), 'text/html', 'quoted-printable' ) );

} # sub reseller_application_process

1;

__END__
