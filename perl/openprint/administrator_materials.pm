package openprint::administrator_materials;

use Text::CSV_XS;

use strict;
require sql;
require openprint::pricing;
require openprint::Equipment;

require openprint::pricelist;
require openprint::material_price;
require openprint::priceset;
require openprint::material_priceset;
require openprint::Material;
require openprint::MaterialCategory;
require openprint::logs;

sub edit {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $Material = new openprint::Material( $openprint::param{'ddmMaterial'} );

	if ( $openprint::param{'btnFunction'} eq '<<' ) {
		$Material = $Material->Previous( 'category_id'=>$openprint::param{'ddmSearchCategory'} );
	} elsif ( $openprint::param{'btnFunction'} eq '>>' ) {
		$Material = $Material->Next( 'category_id'=>$openprint::param{'ddmSearchCategory'} );
	} elsif ( $openprint::param{'btnFunction'} eq 'Delete' ) {
		$Material->delete();
		$Material = $Material->Next( 'category_id'=>$openprint::param{'ddmSearchCategory'} );
	} elsif ( $openprint::param{'btnFunction'} eq 'Save' ) {
		if ( $openprint::param{'new_category'} ) {
			if ( my @Categories = openprint::MaterialCategory::find('name'=>$openprint::param{'new_category'} ) ) {
				$openprint::param{'category_id'} = $Categories[0]->id();
			} else {
				my $Category = new openprint::MaterialCategory();
				$Category->name( $openprint::param{'new_category'} );
				if ( $_ = $Category->save() ) {
					$$variable{'error'} .= $_;
					return;
				} else {
					$openprint::param{'category_id'} = $Category->id();
				} # end if
			} # end if
		} # end if
		$Material->save( \%openprint::param );
		my $ac = sql::start_transaction( $dbh );
		foreach my $List ( openprint::Pricelist::find( 'id'=>$openprint::param{'ddmPriceList'} ) ) {
			my $list = $List->id();
			my $price_set = new openprint::material_priceset( $log, $dbh, $list, $Material->id() );
			foreach my $key ( %openprint::param ) {
				if ( $key =~ /ddmEquipment-$list-(.*)/ ) {
					my $equipment_index = $1;
$openprint::log->debug("Doing equipment ($equipment_index)");
					foreach my $key ( %openprint::param ) {
						if ( $key =~ /chk-$list-$equipment_index-(.*)/ ) {
							
$openprint::log->debug("Doing price ( $list $equipment_index $1)");
							my $price = new openprint::material_price( $log, $dbh, $price_set );
							$price->set( 
									$openprint::param{"ddmEquipment-$list-$equipment_index"} ? $openprint::param{"ddmEquipment-$list-$equipment_index"} : undef,
									$openprint::param{"min-$list-$equipment_index-$1"},
									$openprint::param{"max-$list-$equipment_index-$1"},
									$openprint::param{"units-$list-$equipment_index-$1"},
									$openprint::param{"cost-$list-$equipment_index-$1"},
									$openprint::param{"markup-$list-$equipment_index-$1"},
									$openprint::param{"price-$list-$equipment_index-$1"},
									$openprint::param{"discount-$list-$equipment_index-$1"}
									);
							$price_set->addPrice( $price );
						} # end if
					} # end foreach
				} # end if
			} # end foreach
			$price_set->save();
		} # end foreach

		sql::execute( $log, $dbh, q{DELETE FROM Material_Specifications WHERE material_id=?}, $Material->id() );
		foreach my $key ( keys %openprint::param ) {
			if ( $key =~ /txtSpecificationName(.*)/ and $openprint::param{$key} ne '' ) {
				my $i = $1;
				$openprint::param{'txtSpecificationMin'.$i} =~ s/[^\d\.]//g;
				$openprint::param{'txtSpecificationMax'.$i} =~ s/[^\d\.]//g;
				my @params = (
					'material_id',	$Material->id(),
					'min',			( $openprint::param{'txtSpecificationMin'.$1} ? $openprint::param{'txtSpecificationMin'.$1} : undef ),
					'max',			( $openprint::param{'txtSpecificationMax'.$1} ? $openprint::param{'txtSpecificationMax'.$1} : undef ),
					'units',		$openprint::param{'txtSpecificationUnits'.$1},
					'name',			$openprint::param{'txtSpecificationName'.$1},
					'value',		$openprint::param{'txtSpecificationValue'.$1},
					'interpolate',	$openprint::param{'interpolate'.$1},
				);
				sql::insert( $log, $dbh, 'Material_Specifications', \@params );
			} # end if
		} # end foreach
		sql::end_transaction( $dbh, $ac );

	} elsif ( $openprint::param{'btnFunction'} eq 'Copy' ) {
		my @prices = $Material->prices();

		my $NewMaterial = $Material->copy();
        
        if ( $_ = $NewMaterial->save() ) {
			$$variable{'error'} = $_;
		} else {
			openprint::logs::insertLogRecord('43', "Material Index: " . $$Material{'id'} . " - " . $$Material{'name'},); # Add record to audit log - action "Copy Material".
			foreach my $price ( @prices ) {
				$$price{'material_id'} = $$NewMaterial{'id'};
				delete $$price{'id'};
				$price->save();
			} # end foreach
			foreach my $Spec ( $Material->Specifications() ) {
				$Spec = $Spec->copy();
				$$Spec{'material_id'} = $NewMaterial->id();
				$Spec->save();
			} # end foreach
			$Material = $NewMaterial;
		} # end if
	} # end if
	$$variable{'Material'} = $Material;

} # end sub edit

1;

__END__

