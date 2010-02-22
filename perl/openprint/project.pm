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
	my $Project = $$variable{'Project'} = new openprint::Project( $project_index );
	my $save = 0;
	foreach my $qty_index ( $$variable{'Project'}->quantity_indexes() ) {
		if ( $$Project{'price'.$qty_index} != $Project->price($qty_index,undef) ) {
			$save = 1;
			last;
		} # endif
	} # end foreach
	$Project->save() if $save;
} # end sub view

1;

__END__
~		
