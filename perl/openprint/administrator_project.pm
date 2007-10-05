package openprint::administrator_project;

use strict;

require openprint::project;
require openprint::print_project;

# requires project id and order id
sub view {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $project_index = $openprint::param{'ProjectIndex'};

	openprint::project::view( $log, $dbh, $variable, $project_index );
} # end sub view_project

sub summary {
	openprint::print_project::summary( @_ );
}

sub docket {
	openprint::print_project::summary( @_ );
}

1;

__END__
