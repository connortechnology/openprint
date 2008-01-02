package openprint::administrator_service_types;

use Text::CSV_XS;

use strict;
require sql;
require misc;

require openprint::pricing;
require openprint::Equipment;

require openprint::pricelist;
require openprint::service_price;
require openprint::service_priceset;
require openprint::logs;

sub edit {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $ServiceType = new openprint::ServiceType( $openprint::param{ServiceType_id} );

	if ( $openprint::param{'btnFunction'} eq '<<' ) {
		$ServiceType = $ServiceType->Prev();
	} elsif ( $openprint::param{'btnFunction'} eq '>>' ) {
		$ServiceType = $ServiceType->Next();
	} elsif ( $openprint::param{'btnFunction'} eq 'Delete' ) {
		$ServiceType->delete();
		$ServiceType = $ServiceType->Next();
		openprint::logs::insertLogRecord('23',sprintf('Service Type: %d - %s', $ServiceType->id(), $ServiceType->name() ) );
	} elsif ( $openprint::param{'btnFunction'} eq 'Save' ) {
		$$variable{'error'} = $ServiceType->save( \%openprint::param );
		my $ac = sql::start_transaction( $openprint::dbh );
        sql::execute( $log, $dbh, q{DELETE FROM tbl_Service_Defaults WHERE lngServiceTypeIndex=?}, $ServiceType->id() );
        foreach my $key ( keys %openprint::param ) {
            if ( $key =~ /txtName-(.*)/ and $openprint::param{"txtName-$1"} ne '' ) {
                $$variable{'error'} .= sql::insert( $log, $dbh, 'tbl_Service_Defaults',
                        'lngServiceTypeIndex', $ServiceType->id(),
                        'strFieldName',		$openprint::param{"txtName-$1"},
                        'strDefaultValue',	$openprint::param{"txtValue-$1"},
                        );
            } # end if
        } # end foreach
		sql::end_transaction( $openprint::dbh, $ac );
	} elsif ( $openprint::param{'btnFunction'} eq 'Copy' ) {
		my $New = $ServiceType->copy();
        
        if ( $_ = $New->save() ) {
			$$variable{'error'} = $_;
		} else {
			$ServiceType = $New;
		} # end if
	} # end if

	$$variable{'ServiceType'} = $ServiceType;

} # end sub types_edit

1;

__END__
