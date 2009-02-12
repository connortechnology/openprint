package openprint::administrator_products;

use strict;

use openprint ();
use vars qw($r $log $dbh %variable %param);
*r = \$openprint::r;
*variable = \%openprint::variable;
*param = \%openprint::param;
*log = \$openprint::log;
*dbh = \$openprint::dbh;


require openprint::Product;
require openprint::ProductCategory;
require openprint::logs;
require sql;

sub edit {
	my $Product = new openprint::Product( $param{'product_id'} );

	if ( $param{'btnFunction'} eq 'Save' ) {
		$param{'btnFunction'} = '';
		if ( (! $param{'product_id'}) and openprint::Product::find( 'name' => $param{'name'} ) ) {
			$variable{'error'} = "A product with name $param{'name'} already exists.  Please choose another name.";
			return;
		} # end if
			
		$variable{'error'} = $Product->save( \%param );
	} elsif ( $param{'btnFunction'} eq 'Copy' ) {
		my $NewProduct = $Product->copy();
		$NewProduct->save();

# Add record to audit log - action "Copy Product".
		openprint::logs::insertLogRecord('60', "Original Product ID: " . $param{'product_id'} . " Name: " . $NewProduct->name(),);

		foreach my $Price ( openprint::ProductPrice::find( 'product_id' => $param{'product_id'} ) ) {
			$$Price{'product_id'} = $NewProduct->id();
			$$Price{'id'} = undef;
			$Price->save();
		} # end foreach
		$Product = $NewProduct;

	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		$Product->delete();
	} elsif ( $param{'btnFunction'} eq '>>' ) {
		$Product = $Product->next();
	} elsif ( $param{'btnFunction'} eq '<<' ) {
		$Product = $Product->previous();
	} elsif ( $param{'btnFunction'} eq 'Export Definitions' ) {
	    my @header = ( 'Name', 'Description','Category', 'Tax Exempt 1','Tax Exempt2', 'Sort Order');
	    my @data = sql::execute( $log, $dbh, 'SELECT name, description, (SELECT name from product_categories where id=category_id), taxexempt1, taxexempt2, sort FROM Products ORDER BY sort' );
    	misc::export_csv( $r, $log, \%variable, 'Products.csv', \@header, \@data );
	} elsif ( $param{'btnFunction'} eq 'Import Definitions' ) {
		my $error = '';
		if ( $param{'fileImport'} ) {
			my $upload = $r->upload( 'fileImport' );
			my $io = $upload->io();
			$_ = <$io>;

			my $csv = Text::CSV_XS->new();
			my $ac = sql::start_transaction( $dbh );
			my %categories = map { $_->name(), $_ } openprint::ProductCategory::find();
			my %products = map { $_->name(), $_ } openprint::Product::find();
			
			while ( <$io> ) {
				my $status = $csv->parse($_);
				my ( $name, $description, $category, $taxexempt1, $taxexempt2, $sort ) = misc::trim( $csv->fields() );
				next if ! $name;
				if ( $category and ! $categories{$category} ) {
					$categories{$category} = new openprint::ProductCategory();
					$categories{$category}->name( $category );
					$categories{$category}->save();
				} # end if
				my %sql = (
					'name'			=>	$name,
					'description'	=>	$description,
					'category_id'	=>	$category ? $categories{$category}->id() : undef,
					'taxexempt1'	=>	$taxexempt1,
					'taxexempt2'	=>	$taxexempt2,
					'sort'			=>	$sort,
				);
				my $Product = $products{$name} ? $products{$name} : new openprint::Product();
$openprint::log->debug( "Product? $name :" . $products{$name} );
				$error .= $Product->save( \%sql );
			} # end while
			sql::end_transaction( $dbh, $ac );
		} else {
			$log->warn( "No file given to upload." );
		} # end if
		if ( $error ne '' ) {
			return misc::error( $log, $dbh, \%variable, 'Import errors.', $error );
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Export Specifications' ) {
	    my @header = ( 'Product', 'Name','Value');
	    my @data;
		foreach my $Product ( openprint::Product::find() ) {
			my %specs = %{$Product->specifications()};
			foreach my $k ( keys %specs ) {
				push @data, $Product->name(), $k, $specs{$k};
			} # end foreach
		} # end foreach
    	misc::export_csv( $r, $log, \%variable, 'ProductSpecifications.csv', \@header, \@data );
	} elsif ( $param{'btnFunction'} eq 'Import Specifications' ) {
		my $error = '';
		if ( $param{'fileImport'} ) {
			my $upload = $r->upload( 'fileImport' );
			my $io = $upload->io();
			$_ = <$io>;

			my $csv = Text::CSV_XS->new();
			my $ac = sql::start_transaction( $dbh );
			my %products = map { $_->name(), $_ } openprint::Product::find();
			# Clear Specifications
			foreach my $P ( keys %products ) {
				$products{$P}{Specifications} = ();
			} # end foreach
			
			while ( <$io> ) {
				my $status = $csv->parse($_);
				my ( $product, $name, $value ) = misc::trim( $csv->fields() );
				next if ! $product;
				$products{$product}{Specifications}{$name} = $value;
			} # end while

			foreach my $P ( keys %products ) {
				$error .= $products{$P}->save();
			} # end foreach
			sql::end_transaction( $dbh, $ac );
		} # end if
	} # end if
	$variable{'Product'} = $Product;
} # end sub edit

sub categories {
	$variable{'ProductCategory'} = new openprint::ProductCategory( $param{'id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
	} # end if
} # end sub categories

sub _prices {
	my $Product = new openprint::Product( $param{'product_id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
		foreach my $Pricelist ( openprint::Pricelist::find() ) {
			my $ac = sql::start_transaction( $dbh );
			$dbh->do( 'LOCK TABLE Product_Prices IN EXCLUSIVE MODE' ) or $log->error( DBI->errstr );
			foreach my $Price ( openprint::ProductPrice::find( 'Product' => $Product, 'Pricelist' => $Pricelist ) ) {
				if ( $param{'chk-'.$Price->id()} ) {
					$variable{'error'} .= $Price->save({
							'min'			=>	$param{'min-'.$Price->id()},
							'max'			=>	$param{'max-'.$Price->id()},
							'units'			=>	$param{'units-'.$Price->id()},
							'cost'			=>	$param{'cost-'.$Price->id()},
							'markup'		=>	$param{'markup-'.$Price->id()},
							'price'			=>	$param{'price-'.$Price->id()},
							'discountable'	=>	$param{'discount-'.$Price->id()},
							});
				} else {
					$Price->delete();
				} # end if
			} # end foreach Price
			if ( $param{'chk-'.$Pricelist->id().'-New'} ) {
				my $Price = new openprint::ProductPrice();
				$variable{'error'} .= $Price->save({
						'product_id'	=>	$Product->id(),
						'pricelist_id'	=>	$Pricelist->id(),
						'min'			=>	$param{'min-'.$Pricelist->id().'-New'},
						'max'			=>	$param{'max-'.$Pricelist->id().'-New'},
						'units'			=>	$param{'units-'.$Pricelist->id().'-New'},
						'cost'			=>	$param{'cost-'.$Pricelist->id().'-New'},
						'markup'		=>	$param{'markup-'.$Pricelist->id().'-New'},
						'price'			=>	$param{'price-'.$Pricelist->id().'-New'},
						'discountable'	=>	$param{'discount-'.$Pricelist->id().'-New'},
						});
			} # end if
			sql::end_transaction( $dbh, $ac );
		} # end foreach Pricelist
	} # end if
} # end sub _prices

1;

__END__
