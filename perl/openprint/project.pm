package openprint::project;

use strict;

require sql;
require openprint::Project;

sub view {
	my ( $log, $dbh, $variable, $project_index ) = @_;

	if ( exists $openprint::param{'ShowAllSignatures'} ) {
		$openprint::session{'ShowAllSignatures'} = $openprint::param{'ShowAllSignatures'};
	} # end if
	$$variable{'ProjectIndex'} = $project_index;
	$$variable{'Project'} = new openprint::Project( $project_index );
} # end sub view

1;

__END__
~		
