package openprint::administrator_quote;

use strict;

require openprint::quote;
require sql;

sub modify_project {
	my ( $r, $log, $dbh, $variable ) = @_;
	my $project_index = $r->param('ProjectIndex');
	my $quote_index = $r->param('QuoteId');

	if ($r->param('btnFunction') eq 'Modify Project') {
		sql::insert( $log, $dbh, 'tbl_Project_Contents',
				'lngProjectIndex',  $project_index,
				'strStatus',    'calculated' );

		$_ = "SELECT MAX(lngServiceIndex) FROM tbl_Project_Contents WHERE lngProjectIndex='$project_index'";
		( my $service_index ) = sql::execute( $log, $dbh, $_ );

		sql::insert( $log, $dbh, 'tbl_Service_Specifications', (
					'lngProjectIndex',  $project_index,
					'lngServiceIndex',  $service_index,
					'strName',          'ServiceType',
					'strValue',         '0' ));
		sql::insert( $log, $dbh, 'tbl_Service_Specifications', (
					'lngProjectIndex',  $project_index,
					'lngServiceIndex',  $service_index,
					'strName',          'txtPrice1',
					'strValue',         $r->param('txtPrice1') ));
		sql::insert( $log, $dbh, 'tbl_Service_Specifications', (
					'lngProjectIndex',  $project_index,
					'lngServiceIndex',  $service_index,
					'strName',          'txtPrice2',
					'strValue',         $r->param('txtPrice2') ));
		sql::insert( $log, $dbh, 'tbl_Service_Specifications', (
					'lngProjectIndex',  $project_index,
					'lngServiceIndex',  $service_index,
					'strName',          'txtPrice3',
					'strValue',         $r->param('txtPrice3') ));
		sql::insert( $log, $dbh, 'tbl_Service_Specifications', (
					'lngProjectIndex',  $project_index,
					'lngServiceIndex',  $service_index,
					'strName',          'ServiceName',
					'strValue',         $r->param('txtServiceName') ));
	} elsif ( $r->param('remove') ne '' ) {
		openprint::print_project::delete_service( $log, $dbh, $project_index, $r->param('remove') );
	} # end if

	openprint::project::view( $log, $dbh, $variable, $project_index );

	$_ = "SELECT curSalesPrice1, curSalesPrice2, curSalesPrice3, dblMarkup FROM tbl_Quote_Details WHERE ".
		" lngQuoteId='$quote_index' AND lngProjectIndex='$project_index'";
	my ($price1, $price2, $price3, $markup) = sql::execute( $log, $dbh, $_ );
	$log->debug("***** PRICES    $$variable{'TOTAL1'},$$variable{'TOTAL2'},$$variable{'TOTAL3'} ******");

	if ($price1 ne $$variable{'TOTAL1'} || $price2 ne $$variable{'TOTAL2'} || $price3 ne $$variable{'TOTAL3'} ) {

		sql::update( $log, $dbh, 'tbl_Quote_Details', "lngQuoteId='$quote_index' AND lngProjectIndex='$project_index'",
				'curSalesPrice1',		$$variable{'TOTAL1'},
				'curSalesPrice2',		$$variable{'TOTAL2'},
				'curSalesPrice3',		$$variable{'TOTAL3'},
				'curNewSalesPrice1',	$$variable{'TOTAL1'} * (1+($markup/100)),
				'curNewSalesPrice2',	$$variable{'TOTAL2'} * (1+($markup/100)),
				'curNewSalesPrice3',	$$variable{'TOTAL3'} * (1+($markup/100)) );

	} # end if

	$$variable{'ProjectIndex'} = $project_index;
	$$variable{'QuoteId'} = $quote_index;
} # end sub modify project

sub view {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $quote_id = $openprint::param{'quote_id'};

	if ( $r->param('btnFunction') eq 'Delete' ) {
		delete_quote( $log, $dbh, $quote_id );
	} elsif ( $r->param('btnFunction') eq 'Resend' ) {
		foreach my $key ( $r->param() ) {
			if ( $key =~ /txtMarkup(\w*)/ ) {
				sql::update( $log, $dbh, 'tbl_Quote_Details', "QuoteIndex=$quote_id AND ProjectIndex=$1",
						'dblMarkup',    $r->param($key).'',
						'curNewSalesPrice1', ( $r->param("txtNewPrice1$1") ne '' ? $r->param("txtNewPrice1$1") : undef ),
						'curNewSalesPrice2', ( $r->param("txtNewPrice2$1") ne '' ? $r->param("txtNewPrice2$1") : undef ),
						'curNewSalesPrice3', ( $r->param("txtNewPrice3$1") ne '' ? $r->param("txtNewPrice3$1") : undef )
						);
			} # end if
		} # end foreach
		my $Quote = new openprint::Quote( $quote_id );
		$Quote->save({
				'administrator_comments'	=>	$openprint::param{'txtComments'},
				'total1'					=>	$openprint::param{'total1'},
				'total2'					=>	$openprint::param{'total2'},
				'total3'					=>	$openprint::param{'total3'},
				'modification1'				=>	$openprint::param{'txtModification1'},
				'modification2'				=>	$openprint::param{'txtModification2'},
				'modification3'				=>	$openprint::param{'txtModification3'},
				});
		openprint::quote::send_quote( $r, $log, $dbh, $quote_id, $variable );
	} # end if

    openprint::quote::get_user_by_info( $log, $dbh, $variable, $quote_id );
    openprint::quote::get_user_for_info( $log, $dbh, $variable, $quote_id );
    $$variable{'CCITYPROV'} = misc::build_city_prov_country(@$variable{'ByCity','ByStateProvince','ByCountry'} );
    $$variable{'FCITYPROV'} = misc::build_city_prov_country(@$variable{'ForCity','ForStateProvince','ForCountry'} );

    openprint::quote::get_misc_info( $log, $dbh, $variable, $quote_id );

	openprint::quote::get_finished_quote_contents( $log, $dbh, $variable, $quote_id );
	$$variable{'QUOTE_ID'} = $quote_id;
	$$variable{'Quote'} = new openprint::Quote( $quote_id );

} # end sub view

1;
__END__
