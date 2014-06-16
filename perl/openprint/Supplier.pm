use strict;
package openprint::Supplier;

require openprint;
require sql;
require openprint::Company;

sub get_or_create {
	my ( $name ) = @_;

   my $ac = sql::start_transaction( $openprint::dbh );
    $openprint::dbh->do( 'LOCK TABLE companies IN SHARE ROW EXCLUSIVE MODE' ) or $openprint::log->error( DBI->errstr );
	my $error;

    if ( $name ) {
        my @Companies = openprint::Company->find( name=>$name );
		@Companies = openprint::Company->find( name=>$name, deleted=>1 ) if ! @Companies;
        if ( ! @Companies ) {
            my $C = new openprint::Company();
            $error .= $C->save({
                    supplier        => 'Y',
                    name            => $name,
                    business_name   => $name,
                    } );
			return $C->id();
        } elsif ( @Companies == 1 ) {
            if ( $Companies[0]->supplier() ne 'Y' ) {
                $error .= $Companies[0]->save( { supplier=>'Y' } );
            } # end if
			if ( $Companies[0]->deleted() ) {
                $error .= $Companies[0]->save( { deleted=>0 } );
			} # end if
            return $Companies[0]->id();
        } # end if
    } # end if supplier and ! supplier_id
    sql::end_transaction( $openprint::dbh, $ac );
} # end get_or_create

1;
__END__
