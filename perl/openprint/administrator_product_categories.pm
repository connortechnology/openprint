package openprint::administrator_product_categories;
use strict;
use openprint;
use vars qw( %variable %session %param %config $log $dbh $r );
*variable = \%openprint::variable;
*param = \%openprint::param;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

sub list {
	my ( $r, $log, $dbh, $variable ) = @_;
	my $ProductCategory = new openprint::ProductCategory( $param{'category_id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
		$ProductCategory->save( \%param );
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		$ProductCategory->delete();
	} elsif ( $param{'btnFunction'} eq 'Export' ) {
	    my @header = ( 'Name', 'Description' );
	    my @data = sql::execute( $log, $dbh, 'SELECT name, description FROM Product_Categories' );
    	misc::export_csv( $r, $log, \%variable, 'Product_Categories.csv', \@header, \@data );
	} # end if
} # end sub list

sub edit {
	my ( $r, $log, $dbh, $variable ) = @_;
	my $ProductCategory = new openprint::ProductCategory( $param{'category_id'} );
	if ( $param{'btnFunction'} eq 'Copy' ) {
		$ProductCategory = $ProductCategory->copy();
		$ProductCategory->save();
	} elsif ( $param{'btnFunction'} eq 'Export' ) {
	    my @header = ( 'Name', 'Description' );
	    my @data = sql::execute( $log, $dbh, 'SELECT name, description FROM Product_Categories' );
    	misc::export_csv( $r, $log, \%variable, 'Product_Categories.csv', \@header, \@data );
	} elsif ( $param{'btnFunction'} eq 'Import' ) {
		my $error = '';
		if ( $param{'fileImport'} ) {
			my $upload = $r->upload( 'fileImport' );
			my $io = $upload->io();
			$_ = <$io>;

			my $csv = Text::CSV_XS->new();
			my %categories = map { $_->name(), $_ } openprint::ProductCategory->find();

			my $ac = sql::start_transaction( $dbh );
			while ( <$io> ) {
				my $status = $csv->parse($_);
				my ( $name, $description ) = misc::trim( $csv->fields() );
				next if ! $name;
				if ( ! $categories{$name} ) {
					$categories{$name} = new openprint::ProductCategory();
				} # end if
				$categories{$name}->name( $name );
				$categories{$name}->description( $description );
				$error .= $categories{$name}->save();
			} # end while
			sql::end_transaction( $dbh, $ac );
		} else {
			$log->warn( "No file given to upload." );
		} # end if
		if ( $error ne '' ) {
			return misc::error( $log, $dbh, \%variable, 'Import errors.', $error );
		} # end if
	} # end if
	$variable{Category} = $ProductCategory;
} # end sub edit

1;
__END__


