use strict;
package openprint::main_quote;

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
require openprint::quote;

sub try_to_delete {
	my $quote_id = shift;
	my $Quote = new openprint::Quote( $quote_id );
	if ( $Quote->can_delete() ) {
		$Quote->delete();
		$Quote->add_log('Deleted');
	} else {
		return "Quote $quote_id does not belong to you.  Not deleted.<br>";
	} # end if
	return '';
} # end sub try_to_delete

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
    ssi::setup_date_select( '/main/quote/history.html', 'created_on_start', -30 );
    ssi::setup_date_select( '/main/quote/history.html', 'created_on_end', 0 );
	$session{'/main/quote/history.html?company_id'} = $session{company_id} if ! exists $session{'/main/quote/history.html?company_id'};
	$session{'/main/quote/history.html?deleted'} = '0' if ! exists $session{'/main/quote/history.html?deleted'};
	_history();
} # end sub history

sub _history {
    ssi::save_params( '/main/quote/history.html',
            'created_on_start_year', 'created_on_start_month','created_on_start_day',
            'created_on_end_year', 'created_on_end_month','created_on_end_day',
			'QuotedFor', 'company_id','deleted',
            );
} # end sub _history

sub history_details {
	$param{quote_id} = openprint::Quote->transform('id', $param{quote_id} );
	my $Quote = $variable{Quote} = new openprint::Quote( $param{quote_id} );

	if ( $param{'btnFunction'} eq 'Move To' ) {
		if ( ! $Quote->id() ) {
			$variable{error} .= 'Empty or invalid quote id.<br/>';
		} elsif ( ! $param{company_id} ) {
			$variable{error} = 'You must select a company first.<br/>';
		} elsif ( $Quote->company_id() == $param{company_id} ) {
			$variable{error} = $Quote->Company()->name() .' already owns that quote.  No change made.<br/>';
		} else {
			my $OldCompany = $Quote->Company();
			my $NewCompany = new openprint::Company( $param{company_id} );

			if ( $Quote->can_delete() and ( $session{user_id} eq $$NewCompany{salesrep_id} ) ) {
				$variable{error} .= $Quote->save({company_id=>$param{company_id}});
			} else {
				$variable{error} .= 'You do not have permission to move this quote.<br/>';
			} # end if
		} # end if
		if ( ! $variable{error} ) {
			%param = ();
			$variable{ExternalRedirect} = '/main/quote/history.html';
			return;
		} # end if
	} elsif ( $param{btnFunction} eq 'Delete' ) {
		if ( ! $Quote->can_delete() ) {
			$variable{error} .= 'You do not have permission to delete this quote.<br/>';
		} else {
			$variable{error} .= $Quote->delete();
		} # end if
		if ( ! $variable{error} ) {
			$Quote->add_log('Deleted');
			$variable{ExternalRedirect} = '/main/quote/history.html';
		} # end if
	} elsif ( $param{btnFunction} eq 'Undelete' ) {
		if ( ! $Quote->can_delete() ) {
			$variable{error} .= 'You do not have permission to undelete this quote.<br/>';
		} else {
			$variable{error} .= $Quote->save({deleted=>0});
			$Quote->add_log('Undeleted');
		} # end if
		if ( ! $variable{error} ) {
			$variable{ExternalRedirect} = '/main/quote/history_details.html?quote_id='.$Quote->id();
		} # end if
	} elsif ( $param{btnFunction} eq 'Resend' ) {
		if ( ! $Quote->can_send( ) ) {
			my $results = $Quote->send();
			$Quote->add_log('Resent. Results: ' . $results);
			$variable{information} .= 'Quote resent. Results: '. $results;
			$variable{ExternalRedirect} = '/main/quote/history_details.html?quote_id='.$Quote->id();
		} # end if
	} # end if
	openprint::quote::get_finished_quote_contents( $log, $dbh, \%variable, $$Quote{id} ) if $param{quote_id};
} # end sub history_details

sub add_project_to_quote {
	my ( $quote_id, $project_id ) = @_;

	$quote_id = $session{'quote_id'} if ! $quote_id;
	$quote_id = new openprint::Quote( $quote_id )->id() if $quote_id;
	my $Quote = new openprint::Quote( $quote_id );
	$Quote->save() if ! $Quote->id();
	$session{'quote_id'} = $quote_id = $Quote->id();
	return if ! $quote_id;

	$project_id = $param{ProjectIndex} if ! $project_id;
	$project_id = $session{project_id} if ! $project_id;
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
			$Quote->add_log( 'Added project ' . $project_id . ' prices: ' . join(', ', $Project->prices() ) );
			$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Add to quote $quote_id prices: " . join(', ', $Project->prices() ) );
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
		$variable{ExternalRedirect} = '/main/quote/information.html?quote_id='.$quote_id;
		return;
	} elsif ( $param{'btnFunction'} eq 'Process Quote' ) {
		$quote_id = add_project_to_quote( );
		$variable{ExternalRedirect} = '/main/quote/information.html?quote_id='.$quote_id;
		return;
	} elsif ( ($param{'btnFunction'} eq 'Process New Quote') and $param{'quote_id'} ) {
		my $Quote = new openprint::Quote( $param{'quote_id'} );
		if ( ! $Quote->id() ) {
			$variable{'error'} .= 'Invalid quote id: ' . $param{'quote_id'}.'<br/>';
		} # end if
		my $NewQuote = new openprint::Quote();
		$NewQuote->user_id( $session{'user_id'} );
		if ( $param{'company_id'} and 
				( $param{'company_id'} != $session{'company_id'} ) and 
				sets::isin( $session{'user_type'}, ['A','E'] ) 
		   ) {
				openprint::switch_company( new openprint::Company( $param{'company_id'} ) ) if sets::isin( $session{'user_type'}, ['A','E'] );
		} # end if
		$NewQuote->company_id( $session{'company_id'} );
		$NewQuote->status( 'Incomplete' );
		$NewQuote->Currency( openprint::Currency::get_current() );
		$NewQuote->save();
		if ( ! $NewQuote->id() ) {
			$variable{'error'} .= 'Unable to create new quote.<br/>';
			$log->error('Unable to create new quote.');
			return;
		} # end if

		foreach my $QP ( $Quote->Quoted_Projects() ) {
			my $NewQP = $QP->copy();
			my $Project = $QP->Project();
			my $NewProject = $Project;
			if ( $Quote->company_id() != $NewQuote->company_id() ) {
				$NewProject = $Project->copy();
				$NewProject->docket( '' );
				$NewProject->due_date( '' );
				$NewProject->user_id( $session{'user_id'} );
				$NewProject->order_id( '' );
# This allows uncalc->uncalc, everything else to UnOrdered
				if ( sets::isin( $Project->status(), [ 'Pending Deposit', 'In Prepress', 'Proofs Out', 'Approved', 'Printed', 'Complete','Shipped','Picked Up' ] ) ) {
					$NewProject->status('Unordered');
				} # end if
				$NewProject->company_id( $session{'company_id'} );
				$NewProject->save();
				$NewProject->add_to_log( @session{'company_id','user_id'}, 'Reused from project '.$Project->id() );
				$Project->add_to_log( @session{'company_id','user_id'}, 'Reused to project '.$NewProject->id() );
			} # end if
			$variable{'error'} .= $NewQP->save({
					'quote_id'		=> $NewQuote->id(),
					'project_id'	=> $NewProject->id(),
					});
		} # end foreach QP
		foreach my $QP ( $Quote->Products() ) {
			my $NewQP = $QP->copy();
			$variable{'error'} .= $NewQP->save({'quote_id'=>$NewQuote->id()});
		} # end foreach QP

		my %by;
		openprint::quote::get_user_by_info( $log, $dbh, \%by, $Quote->id() );
		$NewQuote->store_user_by_info( \%by );
		if ( $Quote->company_id() == $NewQuote->company_id() ) {
			my %for;
			openprint::quote::get_user_for_info( $log, $dbh, \%for, $Quote->id() );
			$NewQuote->store_user_for_info( \%for );
		} # end if
		$NewQuote->add_log( 'Copied from quote ' . $Quote->id() );
		$Quote->add_log( 'Copied to quote ' . $NewQuote->id() );
		$quote_id = $NewQuote->id();
		$variable{ExternalRedirect} = '/main/quote/information.html?quote_id='.$quote_id;
		return;
	} elsif ( $param{'btnFunction'} eq 'Continue' ) {
		$quote_id = $param{'quote_id'};
	} # end if
# this should only happen if there was an error creating the quote
	$quote_id = $param{quote_id} if ( ! $quote_id ) and $param{quote_id};
	$quote_id = $session{quote_id} if ! $quote_id;

	my $Quote = $variable{'Quote'} = new openprint::Quote( $quote_id );	
	$session{'quote_id'} = $quote_id;

	if ( $param{'remove'} ) {
		sql::execute($log, $dbh, 'DELETE FROM tbl_Quote_Details WHERE quote_id=? AND project_id=?', @param{'quote_id','remove'} );
		$Quote->add_log( 'Remove project ' . $param{'remove'} );
	} # end if

# store fields from recalculate, we only store the markup, the NewPrices will calculate on the fly
	foreach my $key ( keys %param ) {
		foreach my $QP ( $Quote->Quoted_Projects() ) {
			foreach my $qty_index ( $QP->quantity_indexes() ) {
				$QP->markup( $qty_index, $param{'markup-'.$qty_index.'_'.$QP->project_id()} );
				$QP->quantity( $QP->Project()->quantity() );
				$QP->price( $qty_index, undef );	
				$QP->description( $QP->Project()->reference() );
			} # end foreach
			$QP->save();
		} # end foreach
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

				my @Users = openprint::User->find('company_id'=>$openprint::session{'company_id'},'limit'=>2);
				if ( @Users == 1 ) {
					@variable{'ForFirstName','ForLastName','ForTitle','ForEmail','ForSalutation'} = $Users[0]->get('firstname','lastname','title','email','salutation');
				} # end if
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
		# On submit, if all is well, we set final costs, nothing should change after this, unless we go back to information
		foreach my $QP ( $Quote->Quoted_Projects() ) {
			foreach my $qty_index ( $QP->quantity_indexes() ) {
				$QP->markup( $qty_index, $param{'markup-'.$qty_index.'_'.$QP->project_id()} );
				$QP->quantity( $QP->Project()->quantity() );
				$QP->price( $qty_index, undef );	
				$QP->description( $QP->Project()->reference() );
			} # end foreach
			$QP->save();
		} # end foreach
		foreach my $QP ( $Quote->Products() ) {
				$variable{'error'} .= $QP->save({
						cost		=> $param{'cost-'.$QP->id()},
						markup		=> $param{'markup-'.$QP->id()},
						quantity	=> $param{'quantity-'.$QP->id()},
						comments	=> $param{'comments-'.$QP->id()},
				});
		} # end foreach
    } # end if btnFunction eq Continue

    if ( sets::isin( $session{'user_type'}, [ 'A', 'E' ] ) ) {
        $variable{'AdministratorName'} = new openprint::User( $session{'user_id'} )->name();
    } # end if

    openprint::quote::get_unfinished_quote_contents( $log, $dbh, \%variable, $quote_id );

} # end submit

sub confirmation {

    my $quote_id = $param{quote_id};
	$quote_id = $session{quote_id} if ! $quote_id;
	my $Quote = new openprint::Quote( $quote_id );
	$variable{'Quote'} = $Quote;
	return if ! $quote_id;

	if ( $Quote->status() ne 'Complete' ) {

		my @subtotals;

		foreach my $QP ( $Quote->Quoted_Projects() ) {
			foreach my $qty_index ( $QP->quantity_indexes() ) {
				$subtotals[$qty_index] += $QP->price( $qty_index );
			} # end foreach
			$QP->save();
		} # end foreach QP
		foreach my $Product ( $Quote->Products() ) {
			$Product->save({'cost'=>$Product->cost()});
			$subtotals[1] += $Product->price();
			$subtotals[2] += $Product->price();
			$subtotals[3] += $Product->price();
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
sub overview {
} # end sub overview

sub _quote_list {
} # end sub _quote_list

sub _products_dropdown {
} # end sub _products_dropdown

sub _view_log {
} # end sub _view_log

sub _user_information {
} # end sub _user_information

sub _company_information {
} # end sub _company_information

1;

__END__
