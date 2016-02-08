use strict;
package openprint::administrator_service_types;

use openprint ();

require sql;
require openprint::logs;
require openprint::ServiceType;

use vars qw( $log $dbh %variable %param );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*param = \%openprint::param;

sub edit {

	my $ServiceType = new openprint::ServiceType( $param{ServiceType_id} );

	if ( $param{btnFunction} eq '<<' ) {
		$ServiceType = $ServiceType->Prev();
	} elsif ( $param{btnFunction} eq '>>' ) {
		$ServiceType = $ServiceType->Next();
	} elsif ( $param{btnFunction} eq 'Delete' ) {
		$variable{error} .= $ServiceType->delete();
		if ( ! $variable{error} ) {
			$ServiceType = $ServiceType->Next() if ! $variable{error};
			openprint::logs::insertLogRecord('23',sprintf('Service Type: %d - %s', $ServiceType->id(), $ServiceType->name() ) );
		} # end if
		if ( ! $variable{error} ) {
			$variable{ExternalRedirect} = '/administrator/service_types/index.html';
		}
	} elsif ( $param{btnFunction} eq 'Destroy' ) {
		$variable{error} .= $ServiceType->destroy();
		if ( ! $variable{error} ) {
			$ServiceType = $ServiceType->Next();
			openprint::logs::insertLogRecord('23',sprintf('Service Type: %d - %s', $ServiceType->id(), $ServiceType->name() ) );
		} # end if
		if ( ! $variable{error} ) {
			$variable{ExternalRedirect} = '/administrator/service_types/index.html';
		}
	} elsif ( $param{btnFunction} eq 'Save' ) {

		if ( $param{new_category} ) {
			if ( my $Category = openprint::ServiceType_Category->find_one( name=>$param{new_category} ) ) {
				$param{category_id} = $Category->id();
			} else {
				my $Category = new openprint::ServiceType_Category();
				$Category->name( $param{new_category} );
				if ( $_ = $Category->save() ) {
					$variable{error} .= $_;
					return;
				} else {
					$param{category_id} = $Category->id();
                } # end if
            } # end if
        } # end if

		$variable{error} = $ServiceType->save( \%param );
		my $ac = sql::start_transaction( $dbh );
		foreach my $SD ( $ServiceType->Defaults() ) {
			if ( ! $param{'name-'.$$SD{id}} ) {
				$variable{error} .= $SD->delete();
			} else {
				$variable{error} .= $SD->save({
					projecttype_id	=>	$param{'projecttype_id-'.$$SD{id}},
					name			=>	$param{'name-'.$$SD{id}},
					value			=>	$param{'value-'.$$SD{id}},
					}) if (
						( $SD->projecttype_id() != $param{'projecttype_id-'.$$SD{id}} ) or
						( $SD->name() ne $param{'name-'.$$SD{id}} ) or
						( $SD->value() ne $param{'value-'.$$SD{id}} )
						);
			} # end if
		} # end foreach
		if ( $param{'name-'} ne '' ) {
			my $SD = new openprint::ServiceType_Default( );
			$variable{error} .= $SD->save({
					servicetype_id	=>	$$ServiceType{id},
					projecttype_id	=>	$param{'projecttype_id-'},
					name				=>	$param{'name-'},
					value				=>	$param{'value-'},
					});
		} # end if
		sql::end_transaction( $dbh, $ac );
		if ( ! $variable{error} ) {
			$variable{ExternalRedirect} = '/administrator/service_types/index.html';
		}
	} elsif ( $param{btnFunction} eq 'Copy' ) {
		my $New = $ServiceType->copy();
		
		if ( $_ = $New->save({'name'=>'Copy of' . $New->name()}) ) {
			$variable{error} = $_;
		} else {
			foreach my $Default ( $ServiceType->Defaults() ) {
				$Default = $Default->copy();
				$variable{error} .= $Default->save({'servicetype_id'=>$New->id()});
				last if $variable{error};
			} # end foreach Default
			$ServiceType = $New;
		} # end if
	} # end if

	$variable{ServiceType} = $ServiceType;
} # end sub edit

sub _row {
	my $Default = new openprint::ServiceType_Default( $param{default_id} );
	if ( $param{action} eq 'delete' ) {
		$variable{error} .= $Default->delete();
	} elsif ( $param{action} eq 'copy' ) {
		$Default = $Default->copy();
		$variable{error} .= $Default->save();
	} # end if
	$variable{Default} = $Default;
} # end sub _row

sub index {
    _index();
    #if ( ( ! $session{'/administrator/service_types/index.html?lastupdated'} ) or ( time - $session{'/administrator/service_types/index.html?lastupdated'} ) > ( 12*60*60 ) ) {
        #ssi::setup_date_select( '/administrator/service_types/index.html', 'starting_on_start', 0 );
        #ssi::setup_date_select( '/administrator/service_types/index.html', 'starting_on_end', '' );
    #} # end if
} # end sub search
sub _index {
    if ( ! $param{'btnFunction'} ) {
        ssi::save_params( '/administrator/service_types/index.html', (
                #'starting_on_start_year','starting_on_start_month','starting_on_start_day',
                #'starting_on_end_year','starting_on_end_month','starting_on_end_day',
					'category_id',
					) );
    } # end if
}

1;
__END__
