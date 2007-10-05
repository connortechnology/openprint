package openprint::administrator_products;

use strict;

use openprint ();
use vars qw(%variable %param);
*variable = \%openprint::variable;
*param = \%openprint::param;


require openprint::Product;
require openprint::ProductCategory;
require openprint::logs;
require sql;


sub edit {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $Product = new openprint::Product( $param{'product_id'} );

	if ( $param{'btnFunction'} eq 'Save' ) {
		if ( (! $param{'product_id'}) and openprint::Product::find( 'name' => $param{'txtName'} ) ) {
			$$variable{'error'} = "A product with name $param{'txtName'} already exists.  Please choose another name.";
			return;
		} # end if
			
		$Product->name( $param{'txtName'} );
		$Product->description( $param{'txtDescription'} );
		$Product->category_id( $param{'ddmCategory'} );
		$Product->taxexempt1( $param{'rdbTaxExempt1'} );
		$Product->taxexempt2( $param{'rdbTaxExempt2'} );
		$Product->sort( $param{'sort'} );
		$$variable{'error'} = $Product->save();
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
	} # end if
	$$variable{'Product'} = $Product;
} # end sub defaults_edit

sub categories {
	$variable{'ProductCategory'} = new openprint::ProductCategory( $param{'id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
	} # end if
} # end sub categories

sub prices {
	my $Product = new openprint::Product( $openprint::param{'product_id'} );
	if ( $openprint::param{'btnFunction'} eq 'Save' ) {
		foreach my $Pricelist ( openprint::Pricelist::find() ) {
			foreach my $Price ( openprint::ProductPrice::find( 'product' => $Product, 'pricelist' => $Pricelist ) ) {
				if ( $openprint::param{'chk-'.$Price->id()} ) {
					$Price->min($openprint::param{'min-'.$Price->id()});
					$Price->max($openprint::param{'max-'.$Price->id()});
					$Price->units($openprint::param{'units-'.$Price->id()});
					$Price->cost($openprint::param{'cost-'.$Price->id()});
					$Price->markup($openprint::param{'markup-'.$Price->id()});
					$Price->price($openprint::param{'price-'.$Price->id()});
					$Price->discountable($openprint::param{'discount-'.$Price->id()});
					$Price->save();
				} else {
					$Price->delete();
				} # end if
			} # end foreach Price
			if ( $openprint::param{'chk-'.$Pricelist->id().'-New'} ) {
				my $Price = new openprint::ProductPrice();
				$Price->product( $Product );
				$Price->pricelist( $Pricelist );
				$Price->min($openprint::param{'min-'.$Pricelist->id().'-New'});
				$Price->max($openprint::param{'max-'.$Pricelist->id().'-New'});
				$Price->units($openprint::param{'units-'.$Pricelist->id().'-New'});
				$Price->cost($openprint::param{'cost-'.$Pricelist->id().'-New'});
				$Price->markup($openprint::param{'markup-'.$Pricelist->id().'-New'});
				$Price->price($openprint::param{'price-'.$Pricelist->id().'-New'});
				$Price->discountable($openprint::param{'discount-'.$Pricelist->id().'-New'});
				$Price->save();

			} # end if
		} # end foreach Pricelist
	} # end if
} # end sub prices

1;

__END__
