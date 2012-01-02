use strict;
package openprint::administrator_projecttype_categories;
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
		foreach my $pt_id ( ref $param{'projecttype_id'} eq 'ARRAY' ? @{$param{'projecttype_id'}} : $param{'projecttype_id'} ) {
			my $ProjectType = new openprint::ProjectType( $pt_id );
			$variable{'error'} .= $ProjectType->save({'category_id'=>$ProjectTypeCategory->id()});
		} # end foreach pt_id
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		$variable{'error'} .= $ProjectTypeCategory->delete();
	} # end if
	$variable{'ProjectTypeCategory'} = $ProjectTypeCategory;
} # end sub list

sub edit {
	my $ProjectTypeCategory = $variable{'ProjectTypeCategory'} = new openprint::ProjectTypeCategory( $param{'category_id'} );
} # end sub edit

1;
__END__


