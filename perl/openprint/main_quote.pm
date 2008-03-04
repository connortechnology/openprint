package openprint::main_quote;

use Date::Calc qw(Add_Delta_Days);

use MIME::QuotedPrint;
use MIME::Base64;
use Mail::Sendmail;
use strict;

use openprint ();

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
	if ( $openprint::session{'company_id'} == $Quote->company_id() ) {
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
		my $new_quote_id = create_quote( $log, $dbh, \%openprint::variable );
		
		my @data = sql::execute( $log, $dbh, 'SELECT ProjectIndex, dblMarkup1, dblMarkup2, dblMarkup3 FROM tbl_Quote_Details WHERE QuoteIndex=?', $quote_id );
		while ( @data ) {
			my ( $project_index, $markup1, $markup2, $markup3 ) = splice @data, 0, 4;
			add_project_to_quote( $r, $log, $dbh, \%openprint::variable, $new_quote_id, $project_index );
			sql::update( $log, $dbh, 'tbl_Quote_Details', ['QuoteIndex=? AND ProjectIndex=?', $new_quote_id, $project_index],[
					'dblMarkup1', 1*$markup1,
					'dblMarkup2', 1*$markup2,
					'dblMarkup3', 1*$markup3,
					] );
		} # end while

		my %for;
		my %by;
		openprint::quote::get_user_by_info( $log, $dbh, \%by, $quote_id );
		openprint::quote::get_user_for_info( $log, $dbh, \%for, $quote_id );
		my $NewQuote = new openprint::Quote( $new_quote_id );
		$NewQuote->store_user_by_info( \%by );
		$NewQuote->store_user_for_info( \%for );
		$NewQuote->add_log( 'Copied from quote ' . $quote_id );
		$Quote->add_log( 'Copied to quote ' . $new_quote_id );
		return $new_quote_id;
	} # end if
	return 0;
} # End sub make_quote_from_quote

sub history {
	my ( $r, $log, $dbh, $variable ) = @_;

	if ( $openprint::param{'btnFunction'} eq 'Delete' ) {
		if ( ref $openprint::param{'chkDelete'} eq 'ARRAY' ) {
			foreach my $quote_id ( @{$openprint::param{'chkDelete'}} ) {
				$$variable{'error'} .= try_to_delete( $quote_id );	
			} # end foreach
		} else {
			$$variable{'error'} .= try_to_delete($openprint::param{'chkDelete'});	
		} # end if
	} elsif ( $openprint::param{'btnFunction'} eq 'Delete Quote' ) {
		$$variable{'error'} .= try_to_delete($openprint::param{'quote_id'});	
	} # end if
} # end sub quote_history

sub history_details {
	my ( $r, $log, $dbh, $variable ) = @_;


	my $quote_id = $openprint::param{'quote_id'};
	$quote_id =~ s/\D//g;
	$$variable{'Quote'} = new openprint::Quote( $quote_id );
	if ( sets::isin( $openprint::session{'user_type'}, ['A','E'] ) or ( $$variable{'Quote'}->company_id() == $openprint::session{'company_id'} ) ) {
		openprint::quote::get_finished_quote_contents( $log, $dbh, $variable, $quote_id );
		if ( $openprint::param{'btnFunction'} eq 'Resend' ) {
			$$variable{'Quote'}->send();
			$$variable{'Quote'}->add_log('Resent');
		} # end if
	} # end if
} # end sub history_details

sub get_project_info {
	my $project_index = shift;

	my $Project = new openprint::Project( $project_index );
	my $reference = $Project->reference();
	if ( ! $reference ) {
		$reference = $Project->summary();
	} # end if

	return ( $reference, $Project->quantities(), $Project->price1(), $Project->price2(), $Project->price3() );
} # end sub get_project_info


sub add_project_to_quote {
	my ( $r, $log, $dbh, $variable, $quote_id, $project_index ) = @_;

	$log->debug(" *** Adding Project to Quote ****" );

	$project_index = $openprint::param{'ProjectIndex'} if ! $project_index;
	$project_index = $openprint::session{'project_id'} if ! $project_index;

	$quote_id = $openprint::session{'quote_id'} if ! $quote_id;
	$quote_id = new openprint::Quote( $quote_id )->id() if $quote_id;
	$quote_id = create_quote( $log, $dbh, $variable ) if ! $quote_id;
	$openprint::session{'quote_id'} = $quote_id;

	my $Quote = new openprint::Quote( $quote_id );

	# check to make sure project isn't already in the quote.
	$_ = q{SELECT ProjectIndex FROM tbl_Quote_Details WHERE QuoteIndex=? AND ProjectIndex=?};
	if ( ! sql::execute( $log, $dbh, $_, $quote_id, $project_index ) ) {
		if ( ! sql::insert( $log, $dbh, 'tbl_Quote_Details', [
					'QuoteIndex',		$quote_id,
					'ProjectIndex',		$project_index,
					] ) ) {
			$Quote->add_log( 'Added project ' . $project_index );
		} # end if
	} # end if
	return $quote_id;
} # end sub add_project_to_quote

sub create_quote {
	my ( $log, $dbh, $variable ) = @_;

	my $Quote = new openprint::Quote();
	$Quote->user_id( $openprint::session{'user_id'} );
	$Quote->company_id( $openprint::session{'company_id'} );
	$Quote->created_on( undef );
	$Quote->updated_on( undef );
	$Quote->status( 'Incomplete' );
	$Quote->Currency( openprint::Currency::get_current() );
	$Quote->save();

	return $Quote->id();
} # end sub create_quote

# this page displays the user info page.
# It also processes and stores the information from the details page, in terms of markup, etc.
sub information {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $quote_id;
	if ( $openprint::param{'btnFunction'} eq 'Process Quote' ) {
		$quote_id = add_project_to_quote( $r, $log, $dbh, $variable );
	} elsif ( ($openprint::param{'btnFunction'} eq 'Process New Quote') and $openprint::param{'quote_id'} ) {
		$quote_id = make_quote_from_quote( $r, $log, $dbh, @openprint::session{'company_id','user_id'}, $openprint::param{'quote_id'} );
	} elsif ( $openprint::param{'btnFunction'} eq 'Continue' ) {
		$quote_id = $openprint::param{'quote_id'};
	} else {
		$quote_id = $openprint::session{'quote_id'};
	} # end if
# this should only happen if there was an error creating the quote
	$quote_id = $openprint::session{'quote_id'} if ! $quote_id;

	my $Quote = new openprint::Quote( $quote_id );	
	$$variable{'Quote'} = $Quote;
	$openprint::session{'quote_id'} = $quote_id;

	if ( $openprint::param{'remove'} ) {
		sql::execute($log, $dbh, 'DELETE FROM tbl_Quote_Details WHERE QuoteIndex=? AND ProjectIndex=?', @openprint::param{'quote_id','remove'} );
		$Quote->add_log( 'Remove project ' . $openprint::param{'remove'} );
	} # end if

# store fields from recalculate, we only store the markup, the NewPrices will calculate on the fly
	foreach my $key ( $r->param() ) {
		if ( $key =~ /txtMarkup(\d+)_(\d+)/ ) {
			sql::update( $log, $dbh, 'tbl_Quote_Details', ['QuoteIndex=? AND ProjectIndex=?', $quote_id, $2],
					'dblMarkup'.$1,         1*$r->param($key),
					);
		} # end if
	} # end foreach

	# This isn't neccessarily the logged in company
	my $cust_id;

	if ( $openprint::session{'user_id'} ) {
		$cust_id = new openprint::User( $openprint::session{'user_id'} )->company_id();
	} # end if

	my $populated = 0;
	if ( ! openprint::quote::get_user_for_info( $log, $dbh, $variable, $quote_id ) ) {
$openprint::log->debug("No for info");
		foreach my $k ( 'CompanyName','Address1','Address2','City','StateProvince','PostalCode','Country','Phone','Extension','Fax','FirstName','LastName','Title','Email','Salutation' ) {
			if ( $openprint::session{'/main/quote/information.html?For'.$k} ) {
				$$variable{'For'.$k} = $openprint::session{'/main/quote/information.html?For'.$k};
				$populated = 1;
			} # end if
		} # end foreach

		if ( $openprint::session{'user_id'} and ! $populated ) {
			# If we are representing some other company
			if ( $cust_id != $openprint::session{'company_id'} ) {
				my $Company = new openprint::Company( $openprint::session{'company_id'} );
# pull information to pre-fill input fields
                @$variable{'ForCompanyName', 'ForAddress1', 'ForAddress2', 'ForCity', 'ForStateProvince', 'ForPostalCode', 'ForCountry', 'ForPhone','ForExtension', 'ForFax' } = (
				$Company->name(), $Company->address1(), $Company->address2(), $Company->city(), $Company->state(), $Company->postalcode(), $Company->country(), $Company->phone(), $Company->extension(), $Company->fax() );
            } # end if
        } # end if
    } # end if

    if ( ! openprint::quote::get_user_by_info( $log, $dbh, $variable, $quote_id ) ) {
        if ( $openprint::session{'user_id'} ) {
# pull information to pre-fill input fields
			my $Company = new openprint::Company( $cust_id );
			@$variable{'ByCompanyName', 'ByAddress1', 'ByAddress2', 'ByCity', 'ByStateProvince', 'ByPostalCode', 'ByCountry', 'ByPhone', 'ByExtension', 'ByFax'} = $Company->get('name','address1','address2','city','state','postalcode','country','phone','extension','fax' );
		} # end if
	} # end if

	if ( ! $$variable{'ByEmail'} ) {
		if ( $openprint::session{'user_id'} ) {
			my $User = new openprint::User( $openprint::session{'user_id'} );
			@$variable{'ByEmail','ByTitle','ByFirstName','ByLastName','BySalutation'} = $User->get('email','title','firstname','lastname','salutation');
		} # end if
	} # end if

	if ( $openprint::session{'user_id'} ) {
		$$variable{'ddmUsersOptions'} = ssi::make_drop_down( [ map { $_->id(), $_->name() } openprint::User::find('company_id'=>$openprint::session{'company_id'},'order'=>'lower(strlastname)' ) ] );
	} # end if

	if ( $quote_id ) {
		openprint::quote::get_unfinished_quote_contents( $log, $dbh, $variable, $quote_id );
	} # end if
} # end sub information

sub submit {
    my ( $r, $log, $dbh, $variable ) = @_;

	if ( %openprint::param ) {
		foreach my $k ( 'CompanyName','Address1','Address2','City','StateProvince','PostalCode','Country','Phone','Extension','Fax','FirstName','LastName','Title','Email','Salutation' ) {
			$openprint::session{'/main/quote/information.html?For'.$k} = $openprint::param{'For'.$k};
		} # end foreach
	} # end if

    my $quote_id = $openprint::param{'quote_id'};
	$quote_id = $openprint::session{'quote_id'} if ! $quote_id;
	if ( ! $quote_id ) {
		$quote_id = create_quote( $log, $dbh, $variable );
		$openprint::session{'quote_id'} = $quote_id;
	} # end if
    $$variable{'Quote'} = new openprint::Quote( $quote_id );

    if ( $openprint::param{'btnFunction'} eq 'Continue' ) {
        if ( $_ = openprint::quote::store_quote_info( $r, $log, $dbh, $quote_id, $variable ) ) {
            return misc::error( $log, $dbh, $variable, 'Error', $_ );
        } # end if
    } # end if

    if ( sets::isin( $openprint::session{'user_type'}, [ 'A', 'E' ] ) ) {
        $$variable{'AdministratorName'} = new openprint::User( $openprint::session{'user_id'} )->name();
    } # end if

    openprint::quote::get_unfinished_quote_contents( $log, $dbh, $variable, $quote_id );

} # end submit

sub confirmation {
    my ( $r, $log, $dbh, $variable ) = @_;

    my $quote_id = $openprint::param{'quote_id'};
	$quote_id = $openprint::session{'quote_id'} if ! $quote_id;
	return if ! $quote_id;

	my $Quote = new openprint::Quote( $quote_id );
	if ( $Quote->status() ne 'Complete' ) {

		my $subtotal1 = 0;
		my $subtotal2 = 0;
		my $subtotal3 = 0;

		$_ = 'SELECT ProjectIndex, dblMarkup1, dblMarkup2, dblMarkup3 FROM tbl_Quote_Details WHERE QuoteIndex=?';
		my @projects = sql::execute( $log, $dbh, $_, $quote_id );
		while ( my ( $project_index, $markup1, $markup2, $markup3 ) = splice @projects, 0, 4 ) {
			my $Project = new openprint::Project( $project_index );
			$subtotal1 += $Project->price1()*(1+($markup1/100));
			$subtotal2 += $Project->price2()*(1+($markup2/100));
			$subtotal3 += $Project->price3()*(1+($markup3/100));
			sql::update( $log, $dbh, 'tbl_Quote_Details', ['QuoteIndex=? AND ProjectIndex=?', $quote_id, $project_index], [
					'strDescription',   $Project->reference(),
					'intQuantity1', $Project->quantity1(), 'dblPrice1', $Project->price1(),
					'intQuantity2', $Project->quantity2(), 'dblPrice2', $Project->price2(),
					'intQuantity3', $Project->quantity3(), 'dblPrice3', $Project->price3(),
					] );

		} # end while
		$Quote->total1( $subtotal1 );
		$Quote->total2( $subtotal2 );
		$Quote->total3( $subtotal3 );
		$Quote->status( 'Complete' );
		$Quote->administrator_name( $openprint::param{'AdministratorName'} ) if exists $openprint::param{'AdministratorName'};
		$Quote->administrator_comments( $openprint::param{'AdministratorComments'} ) if exists $openprint::param{'AdministratorComments'};
		$Quote->save();
		$Quote->send();
		$Quote->add_log( 'Submitted' );
	} # end if
	delete $openprint::session{'quote_id'};
} # end sub finalise_quote


1;

__END__
