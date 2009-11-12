package openprint::content_prin;

use strict;
require openprint::project;
require openprint::ProjectType;
use openprint ();
use vars qw( $log $dbh %variable %param %session );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*param = \%openprint::param;
*variable = \%openprint::variable;
*session = \%openprint::session;

sub _breakdown {
	openprint::project::view( $log, $dbh, \%variable, $param{'project_id'} ) if $param{'project_id'};
}

sub load_simple {
	$variable{'Project'} = new openprint::Project( $param{'project_id'} );
	if ( $variable{'Project'}->id() ) {
		$variable{'ProjectType'} = $variable{'Project'}->Type();
		my $services = $variable{'Project'}->services();
		if ( $$services{'UPS'} ) {
			foreach my $service_id ( @{$$services{'UPS'}} ) {
				my $service_specs = openprint::service::get_specs_ref( $variable{'Project'}, $service_id );
				@variable{'ToPostalCode','ToCountry'} = @$service_specs{'ToPostalCode','ToCountry'};
				last;
			} # end foreach
		} # end if
	} else {
		$variable{'ProjectType'} = new openprint::ProjectType( $param{'projecttype_id'} );
	} # end if
	if ( ! $variable{'ToCountry'} ) {
		if ( $session{'company_id'} ) {
			$variable{'ToCountry'} = new openprint::Company( $session{'company_id'} )->country();
		} 
		if ( ! $variable{'ToCountry'} ) {	
			$variable{'ToCountry'} = $session{'Country'};
		} # end if
$log->debug("Country: Session: $session{'Country'}");
	} # end if
	if ( ! $variable{'ToPostalCode'} ) {
		if ( $session{'company_id'} ) {
			$variable{'ToPostalCode'} = new openprint::Company( $session{'company_id'} )->postalcode();
		} # end if
	} # end if
} # end sub load_simple

sub prin_broc {
	load_simple();
} # end sub prin_broc

sub prin_multi {
	load_simple();
} # end sub prin_multi
sub envelopes {
	load_simple();
} # end sub envelopes
