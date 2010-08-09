package openprint::main_quote;

use Date::Calc qw(Add_Delta_Days);

use MIME::QuotedPrint;
use MIME::Base64;
use Mail::Sendmail;
use strict;

use openprint ();
use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

require sql;
require ssi;
require misc;
require configuration;
require openprint::Currency;
require openprint::Project;
require openprint::Quote;

sub try_to_delete {
	my $quote_id = shift;
	my $Quote = new openprint::Quote( $quote_id );
	if ( $session{'company_id'} == $Quote->company_id() ) {
		$Quote->delete();
	} else {
		return "Quote $quote_id does not belong to you.  Not deleted.<br>";
	} # end if
	return '';
} # end sub try_to_delete

sub make_quote_from_quote {
    my ( $r, $log, $dbh, $customer, $user, $quote_id ) = @_;

    my $Quote = new openprint::Quote( $quote_id );
# check that the specified quote actually exists.
	if ( $Quote->id() and ( $Quote->company_id() == $customer ) ) {
# pull info for the quote we are duplicating
		my $NewQuote = new openprint::Quote();
		$NewQuote->save();
		my $new_quote_id = $NewQuote->id();
		
		my @data = sql::execute( $log, $dbh, 'SELECT project_id, dblMarkup1, dblMarkup2, dblMarkup3 FROM tbl_Quote_Details WHERE quote_id=?', $quote_id );
		while ( @data ) {
			my ( $project_index, $markup1, $markup2, $markup3 ) = splice @data, 0, 4;
			add_project_to_quote( $new_quote_id, $project_index );
			sql::update( $log, $dbh, 'tbl_Quote_Details', ['quote_id=? AND project_id=?', $new_quote_id, $project_index],[
					'dblMarkup1', 1*$markup1,
					'dblMarkup2', 1*$markup2,
					'dblMarkup3', 1*$markup3,
					] );
		} # end while

		my %for;
		my %by;
		openprint::quote::get_user_by_info( $log, $dbh, \%by, $quote_id );
		openprint::quote::get_user_for_info( $log, $dbh, \%for, $quote_id );
		$NewQuote->store_user_by_info( \%by );
		$NewQuote->store_user_for_info( \%for );
		$NewQuote->add_log( 'Copied from quote ' . $quote_id );
		$Quote->add_log( 'Copied to quote ' . $new_quote_id );
		return $new_quote_id;
	} # end if
	return 0;
} # End sub make_quote_from_quote

sub history {
	if ( $param{'btnFunction'} eq 'Delete' ) {
		if ( ref $param{'chkDelete'} eq 'ARRAY' ) {
			foreach my $quote_id ( @{$param{'chkDelete'}} ) {
				$variable{'error'} .= try_to_delete( $quote_id );	
			} # end foreach
		} else {
			$variable{'error'} .= try_to_delete($param{'chkDelete'});	
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Delete Quote' ) {
		$variable{'error'} .= try_to_delete($param{'quote_id'});	
	} # end if
    ssi::setup_date_select( '/main/quote/history.html', 'created_on', -30, 0 );
    ssi::save_params( '/main/quote/history.html',
            'created_on_start_year', 'created_on_start_month','created_on_start_day',
            'created_on_end_year', 'created_on_end_month','created_on_end_day',
			'QuotedFor',
            );
} # end sub history
sub _history {
    ssi::save_params( '/main/quote/history.html',
            'created_on_start_year', 'created_on_start_month','created_on_start_day',
            'created_on_end_year', 'created_on_end_month','created_on_end_day',
			'QuotedFor',
            );
} # end sub _history

sub history_details {
	my $quote_id = $param{'quote_id'};
	$quote_id =~ s/\D//g;
	$quote_id = $session{'quote_id'} if ! $quote_id;
	$variable{'Quote'} = new openprint::Quote( $quote_id );
	if ( sets::isin( $session{'user_type'}, ['A','E'] ) or ( $variable{'Quote'}->company_id() == $session{'company_id'} ) ) {
		openprint::quote::get_finished_quote_contents( $log, $dbh, \%variable, $quote_id );
		if ( $param{'btnFunction'} eq 'Resend' ) {
			$variable{'Quote'}->send();
			$variable{'Quote'}->add_log('Resent');
			$variable{'information'} .= 'Quote resent.';
		} # end if
	} # end if
} # end sub history_details

sub add_project_to_quote {
	my ( $quote_id, $project_id ) = @_;

	$quote_id = $session{'quote_id'} if ! $quote_id;
	$quote_id = new openprint::Quote( $quote_id )->id() if $quote_id;
	my $Quote = new openprint::Quote( $quote_id );
	$Quote->save() if ! $Quote->id();
	$session{'quote_id'} = $quote_id = $Quote->id();
	return if ! $quote_id;

	$project_id = $param{'ProjectIndex'} if ! $project_id;
	$project_id = $session{'project_id'} if ! $project_id;
	# check to make sure project isn't already in the quote.
	my @QuotedProjects = openprint::QuotedProject->find('quote_id'=>$Quote->id(), 'project_id'=>$project_id );
	if ( @QuotedProjects > 1 ) {
$openprint::log->error( "More than 1 occurrence of a project in a quote." );
		foreach my $QP ( @QuotedProjects ) {
			$QP->delete();
		} # end foreach QP
		@QuotedProjects = ();
	} # end if
	if ( ! @QuotedProjects ) {
		my $QP = new openprint::QuotedProject();
		my $Project = new openprint::Project( $project_id );
		if ( ( my $error = $QP->save( {
						'quote_id'			=>	$Quote->id(),
						'project_id'		=>	$project_id,
						'include_detailed'	=>	new openprint::Company( $session{'company_id'} )->quote_project_breakdown(),
						'template_id'		=>	new openprint::User( $session{'user_id'} )->quote_level(),
						'quantity1'			=>	$Project->quantity1(),
						'quantity2'			=>	$Project->quantity2(),
						'quantity3'			=>	$Project->quantity3(),
						} ) ) ) {
$openprint::log->error( $error );
		} else {
			$Quote->add_log( 'Added project ' . $project_id );
		} # end if
	} # end if
	return $quote_id;
} # end sub add_project_to_quote

# this page displays the user info page.
# It also processes and stores the information from the details page, in terms of markup, etc.
sub information {

	my $quote_id;
	if ( $param{'btnFunction'} eq 'New' ) {
		my $Quote = new openprint::Quote();
		$variable{'error'} .= $Quote->save({
			'user_id'	=>	$session{'user_id'},
			'company_id'=>	$session{'company_id'},
			'status'	=>	'Incomplete',
			'Currency'	=>	openprint::Currency::get_current(),
		});
		$quote_id = $Quote->id();
	} elsif ( $param{'btnFunction'} eq 'Process Quote' ) {
		$quote_id = add_project_to_quote( );
	} elsif ( ($param{'btnFunction'} eq 'Process New Quote') and $param{'quote_id'} ) {
		$quote_id = make_quote_from_quote( $r, $log, $dbh, @session{'company_id','user_id'}, $param{'quote_id'} );
	} elsif ( $param{'btnFunction'} eq 'Continue' ) {
		$quote_id = $param{'quote_id'};
	} else {
		$quote_id = $session{'quote_id'};
	} # end if
# this should only happen if there was an error creating the quote
	$quote_id = $session{'quote_id'} if ! $quote_id;

	my $Quote = $variable{'Quote'} = new openprint::Quote( $quote_id );	
	$session{'quote_id'} = $quote_id;

	if ( $param{'remove'} ) {
		sql::execute($log, $dbh, 'DELETE FROM tbl_Quote_Details WHERE quote_id=? AND project_id=?', @param{'quote_id','remove'} );
		$Quote->add_log( 'Remove project ' . $param{'remove'} );
	} # end if

# store fields from recalculate, we only store the markup, the NewPrices will calculate on the fly
	foreach my $key ( keys %param ) {
		if ( $key =~ /^txtMarkup(\d+)_(\d+)$/ ) {
			sql::update( $log, $dbh, 'tbl_Quote_Details', ['quote_id=? AND project_id=?', $quote_id, $2],
					'dblMarkup'.$1,         1*$param{$key},
					);
		} # end if
	} # end foreach

	# This isn't neccessarily the logged in company
	my $cust_id;

	if ( $session{'user_id'} ) {
		$cust_id = new openprint::User( $session{'user_id'} )->company_id();
	} # end if

	my $populated = 0;
	if ( ! openprint::quote::get_user_for_info( $log, $dbh, \%variable, $quote_id ) ) {
$openprint::log->debug("No for info");
		foreach my $k ( 'CompanyName','Address1','Address2','City','StateProvince','PostalCode','Country','Phone','Extension','Fax','FirstName','LastName','Title','Email','Salutation' ) {
			if ( $session{'/main/quote/information.html?For'.$k} ) {
$log->debug("Session: For$k". $session{'/main/quote/information.html?For'.$k} );
				$variable{'For'.$k} = $session{'/main/quote/information.html?For'.$k};
				$populated = 1;
			} # end if
		} # end foreach

		if ( $session{'user_id'} and ! $populated ) {
			# If we are representing some other company
			if ( $cust_id != $session{'company_id'} ) {
				my $Company = new openprint::Company( $session{'company_id'} );
# pull information to pre-fill input fields
                @variable{'ForCompanyName', 'ForAddress1', 'ForAddress2', 'ForCity', 'ForStateProvince', 'ForPostalCode', 'ForCountry', 'ForPhone','ForExtension', 'ForFax' } = (
				$Company->business_name(), $Company->address1(), $Company->address2(), $Company->city(), $Company->state(), $Company->postalcode(), $Company->country(), $Company->phone(), $Company->extension(), $Company->fax() );
            } # end if
        } # end if
    } # end if

    if ( ! openprint::quote::get_user_by_info( $log, $dbh, \%variable, $quote_id ) ) {
        if ( $session{'user_id'} ) {
# pull information to pre-fill input fields
			my $Company = new openprint::Company( $cust_id );
			@variable{'ByCompanyName', 'ByAddress1', 'ByAddress2', 'ByCity', 'ByStateProvince', 'ByPostalCode', 'ByCountry', 'ByPhone', 'ByExtension', 'ByFax'} = $Company->get('business_name','address1','address2','city','state','postalcode','country','phone','extension','fax' );
		} # end if
	} # end if

	if ( ! $variable{'ByEmail'} ) {
		if ( $session{'user_id'} ) {
			my $User = new openprint::User( $session{'user_id'} );
			@variable{'ByEmail','ByTitle','ByFirstName','ByLastName','BySalutation'} = $User->get('email','title','firstname','lastname','salutation');
		} # end if
	} # end if

	if ( $quote_id ) {
		openprint::quote::get_unfinished_quote_contents( $log, $dbh, \%variable, $quote_id );
	} # end if
} # end sub information

sub submit {
	if ( %param ) {
		foreach my $k ( 'CompanyName','Address1','Address2','City','StateProvince','PostalCode','Country','Phone','Extension','Fax','FirstName','LastName','Title','Email','Salutation' ) {
			$session{'/main/quote/information.html?For'.$k} = $param{'For'.$k};
		} # end foreach
	} # end if

    my $quote_id = $param{'quote_id'};
	$quote_id = $session{'quote_id'} if ! $quote_id;
    my $Quote = $variable{'Quote'} = new openprint::Quote( $quote_id );
	$Quote->save() if ! $Quote->id();
	$session{'quote_id'} = $Quote->id();

    if ( $param{'btnFunction'} eq 'Continue' ) {
		my %by;
		my %for;
		foreach my $key ( %param ) {
			if ( $key =~ /^By/ ) {
				$by{$key} = $param{$key};
			} elsif ( $key =~ /^For/ ) {
				$for{$key} = $param{$key};
			} # end if
		} # end foreach

		my @required_fields = split(',', $config{'QuoteRequiredFields'} );

		my $error = '';
		$error .= 'No prepared by first name entered.<br>' if $param{'ByFirstName'} eq '' and sets::isin('ByFirstName', \@required_fields );
		$error .= 'No prepared by last name entered.<br>' if $param{'ByLastName'} eq '' and sets::isin('ByLastName', \@required_fields );
		$error .= 'No prepared by email address entered.<br>' if $param{'ByEmail'} eq '' and sets::isin('ByEmail', \@required_fields );
		if ( $error ne '' ) {
			return misc::error( $log, $dbh, \%variable, 'Error', $error );
		} # end if

		if ( $param{'ForFirstName'} or $param{'ForLastName'} or $param{'ForEmail'} ) {
			my $error = "";
#		$error .= 'No prepared for address entered.<br>' if $r->param('ForAddress1') eq '';
#		$error .= 'No prepared for city entered.<br>' if $r->param('ForCity') eq '';
#		$error .= 'No prepared for state entered.<br>' if $r->param('ForStateProvince') eq '';
#		$error .= 'No prepared for postal code entered.<br>' if $r->param('ForPostalCode') eq '';
#		$error .= 'No prepared for country entered.<br>' if $r->param('ForCountry') eq ''; 
#		$error .= 'No prepared for phone number entered.<br>' if $r->param('ForPhone') eq '';
			$error .= 'No prepared for email address entered.<br>' if $param{'ForEmail'} eq '' and sets::isin('ForEmail', \@required_fields );
			if ( $error ne '' ) {
				return misc::error( $log, $dbh, \%variable, 'Error', $error );
			} # end if

		} else {
			foreach my $key ( keys %by ) {
				$key =~ /By(.*)/;
				$for{'For'.$1} = $by{$key};
			} # end foreach
		} # end if

		$Quote->save({'reference'=>$param{'reference'},'comments'=>$param{'comments'}});
		$Quote->store_user_by_info( \%by );
		$Quote->store_user_for_info( \%for );
# store fields from recalculate, we only store the markup, the NewPrices will calculate on the fly
		foreach my $QP ( $Quote->Quoted_Projects() ) {
			foreach my $qty_index ( 1 .. 3 ) {
				$QP->markup( $qty_index, $param{'markup'.$qty_index.'_'.$QP->project_id()} );
			} # end foreach
			$QP->save();
		} # end foreach
		foreach my $QP ( $Quote->Products() ) {
				$QP->save({
						'markup'	=> $param{'markup_'.$QP->id()},
						'quantity'	=> $param{'quantity_'.$QP->id()},
				});
		} # end foreach
    } # end if btnFunction eq Continue

    if ( sets::isin( $session{'user_type'}, [ 'A', 'E' ] ) ) {
        $variable{'AdministratorName'} = new openprint::User( $session{'user_id'} )->name();
    } # end if

    openprint::quote::get_unfinished_quote_contents( $log, $dbh, \%variable, $quote_id );

} # end submit

sub confirmation {

    my $quote_id = $param{'quote_id'};
	$quote_id = $session{'quote_id'} if ! $quote_id;
	my $Quote = new openprint::Quote( $quote_id );
	$variable{'Quote'} = $Quote;
	return if ! $quote_id;

	if ( $Quote->status() ne 'Complete' ) {

		my @subtotals;

		foreach my $QP ( $Quote->Quoted_Projects() ) {
			foreach my $qty_index ( 1 .. 3 ) {
				$QP->quantity( $QP->Project()->quantity() );
				$QP->price( $qty_index, undef );	
				$subtotals[$qty_index] += $QP->price( $qty_index );
			} # end foreach
			$QP->description( $QP->Project()->reference() );
			$QP->save();
		} # end foreach QP
		foreach my $Product ( $Quote->Products() ) {
			$Product->save({'cost'=>$Product->cost()});
		} # end foreach Product
		foreach my $qty_index ( 1 .. 3 ) {
			$Quote->total( $qty_index, $subtotals[$qty_index] );
		} # end foreach
		$Quote->status( 'Complete' );
		$Quote->administrator_name( $param{'AdministratorName'} ) if exists $param{'AdministratorName'};
		$Quote->administrator_comments( $param{'AdministratorComments'} ) if exists $param{'AdministratorComments'};
		$Quote->save();
		$Quote->send();
		$Quote->add_log( 'Submitted' );
	} # end if ! Complete
	delete $session{'quote_id'};
} # end sub finalise_quote

sub _project_template {
	$variable{'Quote'} = new openprint::Quote( $param{'quote_id'} );
	$variable{'QuotedProject'} = new openprint::QuotedProject( $param{'project_id'} );
	$variable{'QuotedProject'}->include_detailed( $param{'include_detailed'} );
	$variable{'QuotedProject'}->save();
} # end sub _project_template

sub _project_template_view {
	$variable{'Quote'} = new openprint::Quote( $param{'quote_id'} );
	$variable{'QuotedProject'} = new openprint::QuotedProject( $param{'project_id'} );
	$variable{'QuotedProject'}->template_id( $param{'template_id'} );
	$variable{'QuotedProject'}->save();
	$variable{'Project'} = $variable{'QuotedProject'}->Project();
	$variable{'ProjectIndex'} = $variable{'Project'}->id();
} # end sub _project_template

sub _quote_list {
} # end sub _quote_list

sub _view_log {
} # end sub _view_log

sub _products {
	$variable{'Quote'} = new openprint::Quote( $param{'quote_id'} );
	if ( ! $variable{'Quote'} ) {
		$variable{'error'} .= "Empty or invalid quote specified.";
		return;
	} # end if

	if ( $param{'action'} ) {
		foreach my $Product ( $variable{'Quote'}->Products() ) {
			$variable{'error'} .= $Product->save({
					'quantity'		=>	$param{'quantity-'.$Product->id()},
					'markup'		=>	$param{'markup-'.$Product->id()},
					});
		} # end foreach
		if ( $param{'action'} eq 'add' ) {
			my $Product = new openprint::QuotedProduct();
			$variable{'error'} .= $Product->save({
					'quote_id'		=>	$param{'quote_id'},
					'product_id'	=>	$param{'product_id-'},
					'quantity'		=>	$param{'quantity-'},
					'cost'			=>	$param{'cost-'},
					'markup'		=>	$param{'markup-'},
					});
		} elsif ( $param{'action'} eq 'del' ) {
			my $Product = new openprint::QuotedProduct( $param{'product_id'} );
			$variable{'error'} .= $Product->delete();
			delete $variable{'Quote'}{'Products'};
		} # end if
	} # end if
} # end sub _products

1;

__END__
