package openprint::administrator_product_categories;
use strict;
use openprint ();

sub list {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $ProductCategory = new openprint::ProductCategory( $openprint::param{'category_id'} );
	if ( $openprint::param{'btnFunction'} eq 'Save' ) {
		$ProductCategory->save( \%openprint::param );
	} elsif ( $openprint::param{'btnFunction'} eq 'Delete' ) {
		$ProductCategory->delete();
	} elsif ( $openprint::param{'btnFunction'} eq 'Export' ) {
	    my @header = ( 'Name', 'Description');
	    my @data = sql::execute( $log, $dbh, 'SELECT name, description FROM Product_Categories' );
    	misc::export_csv( $r, $log, $variable, 'Product_Categories.csv', \@header, \@data );
	} # end if
} # end sub list

sub edit {
	my $ProductCategory = new openprint::ProductCategory( $openprint::param{'category_id'} );
	if ( $openprint::param{'btnFunction'} eq 'Copy' ) {
		$ProductCategory = $ProductCategory->copy();
		$ProductCategory->save();
	} # end if
	$openprint::variable{Category} = $ProductCategory;
} # end sub edit

1;
__END__


