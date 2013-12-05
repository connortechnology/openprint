use strict;
package openprint::administrator_materials;

require Text::CSV_XS;

require sql;
require openprint::pricing;
require openprint::Equipment;

require openprint::pricelist;
require openprint::material_price;
require openprint::Material;
require openprint::MaterialCategory;
require openprint::Log;
use openprint ();
use vars qw( $log $dbh %param %variable );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*param = \%openprint::param;
*variable = \%openprint::variable;

sub edit {

	my $Material = new openprint::Material( $param{'ddmMaterial'} );

	if ( $param{'btnFunction'} eq '<<' ) {
		$Material = $Material->Previous( 'category_id'=>$param{'ddmSearchCategory'} );
	} elsif ( $param{'btnFunction'} eq '>>' ) {
		$Material = $Material->Next( 'category_id'=>$param{'ddmSearchCategory'} );
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		$Material->delete();
		$Material = $Material->Next( 'category_id'=>$param{'ddmSearchCategory'} );
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		if ( $param{'new_category'} ) {
			if ( my @Categories = openprint::MaterialCategory->find('name'=>$param{'new_category'} ) ) {
				$param{'category_id'} = $Categories[0]->id();
			} else {
				my $Category = new openprint::MaterialCategory();
				$Category->name( $param{'new_category'} );
				if ( $_ = $Category->save() ) {
					$variable{'error'} .= $_;
					return;
				} else {
					$param{'category_id'} = $Category->id();
				} # end if
			} # end if
		} # end if
		$Material->save( \%param );
		my $ac = sql::start_transaction( $dbh );
		my @Pricelists = openprint::Pricelist->find( );
		my @Prices = 	openprint::MaterialPrice->find( material_id=>$Material->id() );
		my @Equipment = map { $_ ? new openprint::Equipment($_) : () } sets::union( map { $_->equipment_id() } @Prices );

		my @NewPrices;
		foreach my $Pricelist ( @Pricelists ) {
			foreach my $Equipment ( @Equipment, {} ) {
				push @NewPrices, { id=>'New', pricelist_id=>$$Pricelist{id}, equipment_id=>$$Equipment{id} };
			} # end foreach Equipment
		} # end foreach Pricelist;

		foreach my $Price ( @Prices, @NewPrices ) {
			if ( ! $param{"chk-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"} ) {
				$Price->delete() if $$Price{id} ne 'New';
			} else {
				$Price->set( 
						$param{"ddmEquipment-$$Price{pricelist_id}-$$Price{equipment_id}"} ? $param{"ddmEquipment-$$Price{pricelist_id}-$$Price{equipment_id}"} : undef,
						$param{"min-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"},
						$param{"max-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"},
						$param{"units-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"},
						$param{"cost-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"},
						$param{"markup-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"},
						$param{"price-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"},
						$param{"discount-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"}
						);
				$_ = $Price->save();
				if ( $_ ) {
					$variable{error} .= $_;
					$dbh->rollback();
					last;
				} # end if
			} # end if
		} # end foreach Price

		my %Specs = map { $_->id() => $_ } $Material->Specifications();

		foreach my $key ( keys %param ) {
			if ( $key =~ /^txtSpecificationName(.*)/ ) {
				my $Spec = $Specs{$1};
				$Spec = new openprint::MaterialSpecification() if ! $Spec;

				if ( ! $param{$key} ) {
					$Spec->delete() if $Spec->id();
				} else {
					$variable{'error'} .= $Spec->save({
							'material_id'	=>	$Material->id(),
							'equipment_id'	=>	( $param{'spec_equipment_id-'.$1} ? $openprint::param{'spec_equipment_id-'.$1} : undef ),
							'min'			=>	( $param{'txtSpecificationMin'.$1} ? $param{'txtSpecificationMin'.$1} : undef ),
							'max'			=>	( $param{'txtSpecificationMax'.$1} ? $param{'txtSpecificationMax'.$1} : undef ),
							'units'			=>	$param{'txtSpecificationUnits'.$1},
							'name'			=>	$param{'txtSpecificationName'.$1},
							'value'			=>	$param{'txtSpecificationValue'.$1},
							'interpolate'	=>	$param{'interpolate'.$1},
							});
				} # end if name is empty
			} # end if key
		} # end foreach
		sql::end_transaction( $dbh, $ac );

	} elsif ( $param{'btnFunction'} eq 'Copy' ) {
		my @prices = $Material->prices();

		my $NewMaterial = $Material->copy();
		$$NewMaterial{'name'} = 'Copy of ' . $$NewMaterial{'name'};
        
        if ( $_ = $NewMaterial->save() ) {
			$variable{'error'} .= $_;
		} else {
			(new openprint::Log())->save({'action'=>'Copy Material', 'Object'=>$NewMaterial } );
			foreach my $price ( @prices ) {
				$$price{'material_id'} = $$NewMaterial{'id'};
				delete $$price{'id'};
				$variable{'error'} .= $price->save();
			} # end foreach
			foreach my $Spec ( $Material->Specifications() ) {
				$Spec = $Spec->copy();
				$$Spec{'material_id'} = $NewMaterial->id();
				$variable{'error'} .= $Spec->save();
			} # end foreach
			$Material = $NewMaterial;
		} # end if
	} # end if
	$variable{'Material'} = $Material;

} # end sub edit

1;
__END__
