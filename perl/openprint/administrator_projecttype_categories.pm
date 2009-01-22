package openprint::administrator_projecttype_categories;
use strict;
use openprint ();

require openprint::ProjectTypeCategory;

use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

sub list {
	my $ProjectTypeCategory = new openprint::ProjectTypeCategory( $param{'category_id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
		$variable{'error'} .= $ProjectTypeCategory->save(\%param);
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		$variable{'error'} .= $ProjectTypeCategory->delete();
	} # end if
	$variable{'ProjectTypeCategory'} = $ProjectTypeCategory;
} # end sub list

sub edit {
	my $ProjectTypeCategory = new openprint::ProjectTypeCategory( $param{'category_id'} );
	$variable{'ProjectTypeCategory'} = $ProjectTypeCategory;
} # end sub edit

1;
__END__


