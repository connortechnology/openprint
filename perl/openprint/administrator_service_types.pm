use strict;
package openprint::administrator_service_types;

use openprint ();

require sql;
require openprint::logs;
require openprint::ServiceType;

use vars qw( $r $log $dbh %variable %param );
*r = \$openprint::r;
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
			(new openprint::Log())->save({'action'=>'Delete Service Type', 'note'=> "Service Type ID: $$ServiceType{id} Name: $$ServiceType{name}"});
		} # end if
		if ( ! $variable{error} ) {
			$variable{ExternalRedirect} = '/administrator/service_types/index.html';
		}
	} elsif ( $param{btnFunction} eq 'Destroy' ) {
		$variable{error} .= $ServiceType->destroy();
		if ( ! $variable{error} ) {
			(new openprint::Log())->save({'action'=>'Destroy Service Type', 'note'=> "Service Type ID: $$ServiceType{id} Name: $$ServiceType{name}"});
			$ServiceType = $ServiceType->Next();
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
	} elsif ( $param{btnFunction} eq 'Import' ) {
		if ( $param{fileImport} ) {
			my $upload = $r->upload( 'fileImport' );
			my $io = $upload->io();
			$_ = <$io>;

			my $csv = Text::CSV_XS->new();
			my %PT_cache = map { $_->name(), $_ } openprint::ProjectType->find();
			
			(new openprint::Log())->save({'action'=>'Import Service Type Defaults', 'note'=> "Service Type ID: $$ServiceType{id} Name: $$ServiceType{name}"});
      	
			my $ac = sql::start_transaction( $dbh );
			while ( <$io> ) {
				my $status = $csv->parse($_);
				my ( $project_type, $name, $value ) = misc::trim( $csv->fields() );
				
				my $PT = $PT_cache{$project_type};
				if ( ! $PT ) {
					$variable{error} .= "No Project Type found for $project_type<br/>";
					next;
				}

				my $STD = new openprint::ServiceType_Default();
				if ( $_ .= $PT->save({
							projecttype_id	=>	$PT->id(),
							servicetype_id	=>	$ServiceType->id(),
							name			=>	$name,
							value			=>	$value,
							}) ) {
					$variable{error} .= "Error saving Service Type Default $$ServiceType{id} : $_<br/>";
				} # end if
			} # end foreach
			sql::end_transaction( $dbh, $ac );
		} else {
			$log->warn( "No file given to upload." );
		} # end if
	} elsif ( $param{btnFunction} eq 'Export' ) {
	    my @header = ( 'Project Type', 'Name', 'Value' );
	    my @data = map { $_->ProjectType()->name(), $_->name(), $_->value() } openprint::ServiceType_Default->find(servicetype_id=>$$ServiceType{id}, order=>$openprint::ServiceType_Default::fields{'name'});
    	misc::export_csv( $r, $log, \%variable, $ServiceType->name().'_ServiceTypeDefaults.csv', \@header, \@data );
		# Add record to audit log - action "Export Project Types".
		(new openprint::Log())->save({'action'=>'Export Service Type Defaults', 'note'=> "Service Type ID: $$ServiceType{id} Name: $$ServiceType{name}"});
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
