package openprint::administrator_projecttype_categories;
use strict;
use openprint ();

require openprint::ProjectTypeCategory;

sub list {
	my ( $r, $log, $dbh, $variable ) = @_;
	my $ProjectTypeCategory = new openprint::ProjectTypeCategory( $openprint::param{'category_id'} );
	if ( $openprint::param{'btnFunction'} eq 'Save' ) {
		$ProjectTypeCategory->name( $openprint::param{'name'} );
		$ProjectTypeCategory->description( $openprint::param{'description'} );
		$$variable{'error'} = $ProjectTypeCategory->save();
	} elsif ( $openprint::param{'btnFunction'} eq 'Delete' ) {
		$ProjectTypeCategory->delete();
	} # end if
	$$variable{'ProjectTypeCategory'} = $ProjectTypeCategory;
} # end sub list

sub edit {
} # end sub edit

1;
__END__


