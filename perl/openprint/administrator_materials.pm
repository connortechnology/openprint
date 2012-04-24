use strict;
package openprint::administrator_materials;

use Text::CSV_XS;

require sql;
require openprint::pricing;
require openprint::Equipment;

require openprint::pricelist;
require openprint::material_price;
require openprint::priceset;
require openprint::material_priceset;
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
		foreach my $List ( openprint::Pricelist->find( ) ) {
			my $list = $List->id();
			my $price_set = new openprint::material_priceset( $log, $dbh, $list, $Material->id() );
			foreach my $key ( %param ) {
				if ( $key =~ /ddmEquipment-$list-(.*)/ ) {
					my $equipment_index = $1;
$openprint::log->debug("Doing equipment ($equipment_index)");
					foreach my $key ( %param ) {
						if ( $key =~ /chk-$list-$equipment_index-(.*)/ ) {
							
$openprint::log->debug("Doing price ( $list $equipment_index $1)");
							my $price = new openprint::material_price( $log, $dbh, $price_set );
							$price->set( 
									$param{"ddmEquipment-$list-$equipment_index"} ? $param{"ddmEquipment-$list-$equipment_index"} : undef,
									$param{"min-$list-$equipment_index-$1"},
									$param{"max-$list-$equipment_index-$1"},
									$param{"units-$list-$equipment_index-$1"},
									$param{"cost-$list-$equipment_index-$1"},
									$param{"markup-$list-$equipment_index-$1"},
									$param{"price-$list-$equipment_index-$1"},
									$param{"discount-$list-$equipment_index-$1"}
									);
							$price_set->addPrice( $price );
						} # end if
					} # end foreach
				} # end if
			} # end foreach
			$price_set->save();
		} # end foreach

		sql::execute( $log, $dbh, q{DELETE FROM Material_Specifications WHERE material_id=?}, $Material->id() );
		foreach my $key ( keys %param ) {
			if ( $key =~ /txtSpecificationName(.*)/ and $param{$key} ne '' ) {
				my $i = $1;
				$param{'txtSpecificationMin'.$i} =~ s/[^\d\.]//g;
				$param{'txtSpecificationMax'.$i} =~ s/[^\d\.]//g;
				my @params = (
					'material_id',	$Material->id(),
					'min',			( $param{'txtSpecificationMin'.$1} ? $param{'txtSpecificationMin'.$1} : undef ),
					'max',			( $param{'txtSpecificationMax'.$1} ? $param{'txtSpecificationMax'.$1} : undef ),
					'units',		$param{'txtSpecificationUnits'.$1},
					'name',			$param{'txtSpecificationName'.$1},
					'value',		$param{'txtSpecificationValue'.$1},
					'interpolate',	$param{'interpolate'.$1},
				);
				sql::insert( $log, $dbh, 'Material_Specifications', \@params );
			} # end if
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
