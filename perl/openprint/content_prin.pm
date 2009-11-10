package openprint::content_prin;

use strict;
require openprint::project;
require openprint::ProjectType;
use openprint ();
use vars qw( $log $dbh %variable %param );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*param = \%openprint::param;
*variable = \%openprint::variable;

sub _breakdown {
	openprint::project::view( $log, $dbh, \%variable, $param{'project_id'} ) if $param{'project_id'};
}

sub prin_broc {
	$variable{'Project'} = new openprint::Project( $param{'project_id'} );
	if ( $variable{'Project'}->id() ) {
		$variable{'ProjectType'} = $variable{'Project'}->Type();
	} else {
		$variable{'ProjectType'} = new openprint::ProjectType( $param{'projecttype_id'} );
	} # end if
} # end sub prin_broc

sub prin_multi {
	$variable{'Project'} = new openprint::Project( $param{'project_id'} );
	if ( $variable{'Project'}->id() ) {
		$variable{'ProjectType'} = $variable{'Project'}->Type();
	} else {
		$variable{'ProjectType'} = new openprint::ProjectType( $param{'projecttype_id'} );
	} # end if
} # end sub prin_multi
