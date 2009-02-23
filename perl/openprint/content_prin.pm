package openprint::content_prin;

use strict;
require openprint::project;

sub _breakdown {
	my ( $r, $log, $dbh, $variable ) = @_;
openprint::project::view( $log, $dbh, $variable, $openprint::param{'project_id'} );
}

sub prin_broc {
} # end sub prin_broc
