package openprint::administrator_quote;

use strict;

use openprint ();
require openprint::quote;
require sql;

sub view {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $quote_id = $openprint::param{'quote_id'};

	if ( $param{'btnFunction'} eq 'Delete' ) {
		delete_quote( $log, $dbh, $quote_id );
	} elsif ( $param{'btnFunction'} eq 'Resend' ) {
		foreach my $key ( keys %openprint::param ) {
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
