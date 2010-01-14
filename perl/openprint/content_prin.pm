package openprint::content_prin;

use strict;
require openprint::project;

sub _breakdown {
	my ( $r, $log, $dbh, $variable ) = @_;
	openprint::project::view( $log, $dbh, $variable, $openprint::param{'project_id'} ) if $openprint::param{'project_id'};
}

sub prin_broc {
	my $ProjectType = openprint::ProjectType::find_one('strid'=>$openprint::param{'ProjectType'});
	if ( $ProjectType ) {
		$_ = q{SELECT strFieldName, strDefaultValue FROM tbl_ProjectType_Defaults WHERE lngProjectTypeIndex=?};
		my %defaults = sql::execute( $openprint::log, $openprint::dbh, $_, $ProjectType->id() );
		foreach my $k ( keys %defaults ) {
			$openprint::variable{$k} = $defaults{$k};
		} # end foreach
	} # end if
} # end sub prin_broc
sub prin_multi {
} # end sub prin_broc
sub envelopes {
} # end sub prin_broc
