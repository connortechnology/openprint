package openprint::quote;

use Date::Calc qw(Add_Delta_Days);

use MIME::QuotedPrint;
use MIME::Base64;
use Mail::Sendmail;
use Email::Valid;
use strict;

require sql;
require ssi;
require misc;
require configuration;
require openprint::Currency;
require openprint::Project;
require openprint::Quote;

sub get_unfinished_quote_id {
	my ( $log, $dbh, $cookie, $variable ) = @_;

	$_ = q{SELECT Index, CompanyIndex, UserIndex FROM tbl_Quotes WHERE strSessionID=? AND strStatus='Incomplete'};
	my ( $quote_id, $cust_id, $user_id ) = sql::execute( $log, $dbh, $_, $cookie );

	# This is to update the quote if we login or switch company before finishing the quote
	if ( $quote_id ) {
		if ( $cust_id != $openprint::session{'company_id'} ) {
			
			# This should also remove any projects in the quote that belong to other companies FIXME
			sql::update( $log, $dbh, 'tbl_Quotes', "Index=$quote_id", 'CompanyIndex', $openprint::session{'company_id'},
					'currency_id',		openprint::Currency::get_current()->id(),
					);
		} # end if
		if ( $user_id != $openprint::session{'user_id'} ) {
			sql::update( $log, $dbh, 'tbl_Quotes', "Index=$quote_id", 'UserIndex', $openprint::session{'user_id'} );
		} # end if
	} # end if
	
	return $quote_id;
} # end sub get_unfinished_quote_id

sub get_unfinished_quote_contents {
	my ( $log, $dbh, $variable, $quote_id ) = @_;
	@{$$variable{'PROJECTS'}} = ();

	my $subtotal1 = 0;
	my $subtotal2 = 0;
	my $subtotal3 = 0;

	$_ = 'SELECT ProjectIndex, dblMarkup1, dblMarkup2, dblMarkup3 FROM tbl_Quote_Details WHERE QuoteIndex=?';
	my @projects = sql::execute( $log, $dbh, $_, $quote_id );
	while ( my ( $project_index, $markup1, $markup2, $markup3 ) = splice @projects, 0, 4 ) {
		my ( $reference, $qty1, $qty2, $qty3, $price1, $price2, $price3 ) = get_project_info( $log, $dbh, $project_index );
		my $newprice1 = sprintf( '%.2f',($price1*(1+($markup1/100))));
		my $newprice2 = sprintf( '%.2f',($price2*(1+($markup2/100))));
		my $newprice3 = sprintf( '%.2f',($price3*(1+($markup3/100))));
		$subtotal1 += $newprice1;
		$subtotal2 += $newprice2;
		$subtotal3 += $newprice3;

		push @{$$variable{'PROJECTS'}}, $project_index, $reference;
		push @{$$variable{"PROJECT_PRICES_$project_index"}}, 
			'1', $markup1, $qty1, sprintf( '%.2f',$price1), $newprice1,
			'2', $markup2, $qty2, sprintf( '%.2f',$price2), $newprice2,
			'3', $markup3, $qty3, sprintf( '%.2f',$price3), $newprice3;
	} # end while
	@{$$variable{'TOTALS'}} = ( '1', sprintf( '%.2f',$subtotal1), '2', sprintf( '%.2f',$subtotal2),'3', sprintf( '%.2f',$subtotal3));
} # end sub get_unfinished_quote_contents

sub store_quote_info {
	my ( $r, $log, $dbh, $quote_id, $variable ) = @_;
	my %by;
	my %for;
	foreach my $key ( $r->param() ) {
		if ( $key =~ /^By/ ) {
			$by{$key} = $r->param($key);
		} elsif ( $key =~ /^For/ ) {
			$for{$key} = $r->param($key);
		} # end if
	} # end foreach

	my $error = '';
	$error .= 'No prepared by first name entered.<br/>' if $by{'ByFirstName'} eq '';
	$error .= 'No prepared by last name entered.<br/>' if $by{'ByLastName'} eq '';
	$error .= 'No prepared by email address entered.<br/>' if $by{'ByEmail'} eq '';
	$error .= 'Invalid prepared by email address entered.<br/>' if ( ! Email::Valid->address( $by{'ByEmail'} ) );
	if ( $error ne '' ) {
		return $error;
	} # end if

	if ( $r->param('ForFirstName') or $r->param('ForLastName') or $r->param('ForEmail') ) {
		my $error = "";
#		$error .= 'No prepared for address entered.<br>' if $r->param('ForAddress1') eq '';
#		$error .= 'No prepared for city entered.<br>' if $r->param('ForCity') eq '';
#		$error .= 'No prepared for state entered.<br>' if $r->param('ForStateProvince') eq '';
#		$error .= 'No prepared for postal code entered.<br>' if $r->param('ForPostalCode') eq '';
#		$error .= 'No prepared for country entered.<br>' if $r->param('ForCountry') eq ''; 
#		$error .= 'No prepared for phone number entered.<br>' if $r->param('ForPhone') eq '';
		$error .= 'No prepared for email address entered.<br/>' if $r->param('ForEmail') eq '';
		$error .= 'Invalid prepared for email address entered.<br/>' if ( ! Email::Valid->address( $for{'ForEmail'} ) );
		if ( $error ne '' ) {
			return $error;
		} # end if

	} else {
		foreach my $key ( keys %by ) {
			$key =~ /By(.*)/;
			$for{'For'.$1} = $by{$key};
		} # end foreach
	} # end if

	my $Quote = new openprint::Quote( $quote_id );
	$Quote->store_user_by_info( \%by );
	$Quote->store_user_for_info( \%for );
	return;

} # end sub store_quote_info


sub get_user_by_info {
	my ( $log, $dbh, $variable, $quote_id ) = @_;

	$_ = 'SELECT strCompanyName, strSalutation, strFirstName, strLastName, strAddress, strAddress2, strCity, strState, strCountry, strPostalCode, strPhone, strExt, strFax, strEmail FROM tbl_Quote_Users_By WHERE QuoteIndex=?';
	return @$variable{'ByCompanyName','BySalutation', 'ByFirstName','ByLastName','ByAddress1','ByAddress2','ByCity','ByStateProvince','ByCountry','ByPostalCode','ByPhone', 'ByExtension', 'ByFax', 'ByEmail'} = sql::execute( $log, $dbh, $_, $quote_id );
} # end sub get_user_by_info

sub get_user_for_info {
	my ( $log, $dbh, $variable, $quote_id ) = @_;

	$_ = 'SELECT strCompanyName, strSalutation, strFirstName, strLastName, strAddress, strAddress2, strCity, strState, strCountry, strPostalCode, strPhone, strExt, strFax, strEmail FROM tbl_Quote_Users_For WHERE QuoteIndex=?';
	return @$variable{'ForCompanyName', 'ForSalutation','ForFirstName','ForLastName','ForAddress1','ForAddress2','ForCity','ForStateProvince','ForCountry','ForPostalCode','ForPhone', 'ForExtension', 'ForFax', 'ForEmail'} = sql::execute( $log, $dbh, $_, $quote_id );
} # end sub get_user_for_info

sub get_misc_info {
    my ( $log, $dbh, $variable, $quote_id ) = @_;
    $_ = q{SELECT CompanyIndex, to_char(dtmQuoteDate, 'MM/DD/YYYY'), curTotalSale1, curTotalSale2, curTotalSale3, strCustomerComments, strAdministratorComments, strAdministratorName, currency_id FROM tbl_Quotes WHERE Index=?};
    @$variable{'Company_ID','DATE', 'TOTAL1','TOTAL2','TOTAL3','Comments','AdministratorComments', 'AdministratorName','currency_id'} = sql::execute( $log, $dbh, $_, $quote_id );
	my $Currency = new openprint::Currency( $$variable{'currency_id'} );
    @$variable{'CurrencyName', 'CurrencySymbol'} = ( $Currency->name(), $Currency->symbol() );
	$$variable{'QUOTE_ID'} = $quote_id;
} # end sub get_misc_info


sub get_finished_quote_contents {
	my ( $log, $dbh, $variable, $quote_id ) = @_;

	@{$$variable{'PROJECTS'}} = ();

	my $Quote = new openprint::Quote( $quote_id );
	foreach my $QP ( $Quote->Quoted_Projects() ) {
		my $Project = $QP->Project();

		push @{$$variable{'PROJECTS'}}, $QP->project_id(); 
		push @{$$variable{'PROJECTS'}}, ( $Project->reference() ? $Project->reference() : $Project->summary() );

		@{$$variable{'PROJECT_PRICES_'.$QP->project_id()}} = ();
		my $colour = 'black';
		if ( 
				( $QP->quantity1() != $Project->quantity1() ) or 
				( $QP->quantity2() != $Project->quantity2() ) or 
				( $QP->quantity3() != $Project->quantity3() ) or
				( $Project->price1() != $QP->price1() ) or 
				( $Project->price2() != $QP->price2() ) or
				( $Project->price3() != $QP->price3() ) 
				) {
			$colour = 'red';
		} # end if
		foreach my $qty_index ( 1 .. 3 ) {
			push @{$$variable{'PROJECT_PRICES_'.$QP->project_id()}}, $qty_index, $QP->get('markup'.$qty_index,'quantity'.$qty_index,'price'.$qty_index,'price'.$qty_index), $colour ;
		} # end foreach qty_index
	} # end foreach QP
	return @{$$variable{'PROJECTS'}};
} # end sub get_finished_quote_contents

sub get_project_info {
	my ( $log, $dbh, $project_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	my $reference = $Project->reference();

	return ( $reference, $Project->quantity1(), $Project->quantity2(), $Project->quantity3(), $Project->price(1), $Project->price(2), $Project->price(3) );
} # end sub get_project_info

1;

__END__
