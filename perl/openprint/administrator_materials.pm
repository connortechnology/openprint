use strict;
use warnings;
package openprint::administrator_materials;

require Text::CSV_XS;

require sql;
require openprint::pricing;

require openprint::pricelist;
require openprint::material_price;
require openprint::Material;
require openprint::MaterialCategory;
require openprint::Log;
use openprint ();
use vars qw( $r $log $dbh %param %variable );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*param = \%openprint::param;
*variable = \%openprint::variable;

sub edit {
	require openprint::Equipment;

	my $Material = $variable{Material} = new openprint::Material( $param{ddmMaterial} );
	ssi::save_params($variable{uri}, ( 'ddmSearchCategory' ) );

	if ( $param{btnFunction} ) {
		if ( $param{btnFunction} eq '<<' ) {
			$Material = $Material->Previous( category_id=>$param{ddmSearchCategory} );
		} elsif ( $param{btnFunction} eq '>>' ) {
			$Material = $Material->Next( category_id=>$param{ddmSearchCategory} );
		} elsif ( $param{btnFunction} eq 'Delete' ) {
			$Material->delete();
			$Material = $Material->Next( category_id=>$param{ddmSearchCategory} );
		} elsif ( $param{btnFunction} eq 'Export' ) {
			my @header = ( 'Material Name', 'Description','Category', 'Activity Code', 'Manufacturer', 'Supplier','Fed Tax Exempt', 'State Tax Exempt' );

			my @data;
			foreach my $Material ( openprint::Material->find( order=>'name' ) ) {
				push @data, $Material->get( 'name', 'description', 'category', 'activity_code', 'manufacturer','supplier','taxexempt1','taxexempt2' );
			} # end foreach

			misc::export_csv( $openprint::r, $log, \%variable, 'materials.csv', \@header, \@data );
		} elsif ( $param{btnFunction} eq 'Import' ) {

			my $error = '';
			if ( $param{file} ) {
				my $ac = sql::start_transaction( $dbh );
				my %Materials = map { $$_{name}, $_ } openprint::Material->find();

				my $upload = $r->upload( 'file' );
				my $io = $upload->io();
				$_ = <$io>;

				my $csv = Text::CSV_XS->new();

				while (<$io>) {
					my $status = $csv->parse($_);
					my ( $name, $description, $category, $activity_code, $manufacturer, $supplier, $tax1, $tax2 ) = misc::trim( $csv->fields() );
	$log->debug("$name, $description, $category, $activity_code, $manufacturer, $supplier, $tax1, $tax2");
					next if $name eq '';
					if ( $Materials{$name} ) {
						$error .= "Not importing $name because it already exists at " . $Materials{$name}->link_to().'<br/>';
						next;
					}
					my $Material = new openprint::Material();
					$_ = $Material->save({
							name	=>	$name,
							description	=>	$description,
							category	=>	$category,
							activity_code	=>	$activity_code,
							manufacturer	=>	$manufacturer,
							supplier		=>	$supplier,
							taxexempt1		=>	$tax1,
							taxexempt2		=>	$tax2,
							});
					if ( $_ ) {
						$error .= $_;
						$dbh->rollback();
						last;
					} else {
						$Materials{$name} = $Material;
					}
				} # end while
				sql::end_transaction( $dbh, $ac );
			} else {
				$error .= 'No file given to upload.<br>';
			} # end if
			$variable{error} = $error; 

		} elsif ( $param{btnFunction} eq 'Save' ) {
			if ( $param{new_category} ) {
				if ( my @Categories = openprint::MaterialCategory->find(name=>$param{new_category} ) ) {
					$param{category_id} = $Categories[0]->id();
				} else {
					my $Category = new openprint::MaterialCategory();
					$Category->name( $param{new_category} );
					if ( $_ = $Category->save() ) {
						$variable{error} .= $_;
						return;
					} else {
						$param{category_id} = $Category->id();
					} # end if
				} # end if
			} # end if
		} # end if btnFunction
		my @changes = $Material->changes( \%param );

		if ( @changes or ! $$Material{id} ) {	
			$variable{error} .= $Material->save( \%param );
			return if $variable{error};
		} # end if
		my $ac = sql::start_transaction( $dbh );
		my @Pricelists = openprint::Pricelist->find( );
		my @Prices = openprint::MaterialPrice->find( material_id=>$Material->id() );
		my @Equipment = map { $_ ? new openprint::Equipment($_) : () } sets::union( map { $_->equipment_id() } @Prices );

		my @NewPrices;
		foreach my $Pricelist ( @Pricelists ) {
			foreach my $Equipment ( @Equipment, {} ) {
				my $NewPrice = new openprint::MaterialPrice();
				$NewPrice->set( { pricelist_id=>$$Pricelist{id}, equipment_id=>$$Equipment{id}, material_id=>$$Material{id} } );
				push @NewPrices,$NewPrice;
			} # end foreach Equipment
		} # end foreach Pricelist;

		my @pricing_changes;
		foreach my $Price ( @Prices, @NewPrices ) {
			if ( ! $param{"chk-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"} ) {
				if ( $$Price{id} ) {
					$Price->delete();
					push @pricing_changes, "Delete price: " . $Price->to_string();
				}
			} else {
				my @price_changes = $Price->changes( {
						equipment_id	=>	$param{"ddmEquipment-$$Price{pricelist_id}-$$Price{equipment_id}"},
						min				=>	$param{"min-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"},
						max				=>	$param{"max-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"},
						units			=>	$param{"units-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"},
						cost			=>	$param{"cost-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"},
						markup			=>	$param{"markup-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"},
						price			=>	$param{"price-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"},
						discountable		=>	$param{"discountable-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"},
						} );

				if ( @price_changes ) {
					if ( $Price->set( {
							equipment_id	=>	$param{"ddmEquipment-$$Price{pricelist_id}-$$Price{equipment_id}"},
							min				=>	$param{"min-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"},
							max				=>	$param{"max-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"},
							units			=>	$param{"units-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"},
							cost			=>	$param{"cost-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"},
							markup			=>	$param{"markup-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"},
							price			=>	$param{"price-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"},
							discountable	=>	$param{"discountable-$$Price{pricelist_id}-$$Price{equipment_id}-$$Price{id}"},
							} ) ) {
						$_ = $Price->save();
						if ( $_ ) {
							$variable{error} .= $_;
							$dbh->rollback();
							last;
						} # end if
					} # end if
					push @pricing_changes, @price_changes;
				} # end if
			} # end if
		} # end foreach Price
		push @changes, @pricing_changes;

		my @specs_changes;
		if ( ! $variable{error} ) {
			my $New = new openprint::MaterialSpecification();
			$New->set( { material_id=>$Material->id() } );
			foreach my $Spec ( $Material->Specifications(), $New ) {

				if ( $param{"txtSpecificationName$$Spec{id}"} ) {
					my @spec_changes = $Spec->changes({
							equipment_id	=>	$param{'spec_equipment_id-'.$$Spec{id}},
							min				=>	$param{'txtSpecificationMin'.$$Spec{id}},
							max				=>	$param{'txtSpecificationMax'.$$Spec{id}},
							units			=>	$param{'txtSpecificationUnits'.$$Spec{id}},
							name			=>	$param{'txtSpecificationName'.$$Spec{id}},
							value			=>	$param{'txtSpecificationValue'.$$Spec{id}},
							interpolate		=>	$param{'interpolate'.$$Spec{id}},
							});
					if ( @spec_changes ) {

						$variable{error} .= $Spec->save({
								equipment_id	=>	$param{'spec_equipment_id-'.$$Spec{id}},
								min				=>	$param{'txtSpecificationMin'.$$Spec{id}},
								max				=>	$param{'txtSpecificationMax'.$$Spec{id}},
								units			=>	$param{'txtSpecificationUnits'.$$Spec{id}},
								name			=>	$param{'txtSpecificationName'.$$Spec{id}},
								value			=>	$param{'txtSpecificationValue'.$$Spec{id}},
								interpolate		=>	$param{'interpolate'.$$Spec{id}},
								});
						push @specs_changes, @spec_changes;	
					} # end if
				} elsif ( $Spec->id() ) {
					$variable{error} .= $Spec->delete();
					push @specs_changes, "Delete specification: " . $Spec->to_string();
				} # end if key
				if ( $variable{error} ) {
					$dbh->rollback();
					last;
				} # end if
			} # end foreach
		} # end if
		push @changes, @specs_changes;
		(new openprint::Log())->save({action=>'Save Material', Object=>$Material, note=>join('<br/>', @changes ) } );
		sql::end_transaction( $dbh, $ac );
		if ( ! $variable{error} ) {
			$variable{ExternalRedirect} = '/administrator/materials/edit.html?ddmMaterial='.$Material->id();
			return;
		} # end if

	} elsif ( $param{btnFunction} eq 'Copy' ) {
		my @prices = $Material->prices();

		my $NewMaterial = $Material->copy();
		$$NewMaterial{name} = 'Copy of ' . $$NewMaterial{name};
        
        if ( $_ = $NewMaterial->save() ) {
			$variable{error} .= $_;
		} else {
			(new openprint::Log())->save({action=>'Copy Material', Object=>$NewMaterial } );
			foreach my $price ( @prices ) {
				$$price{material_id} = $$NewMaterial{id};
				delete $$price{id};
				$variable{error} .= $price->save();
			} # end foreach
			foreach my $Spec ( $Material->Specifications() ) {
				$Spec = $Spec->copy();
				$$Spec{material_id} = $NewMaterial->id();
				$variable{error} .= $Spec->save();
			} # end foreach
			$Material = $NewMaterial;
		} # end if
	} # end if
	$variable{Material} = $Material;

} # end sub edit

1;
__END__
