package openprint::administrator_services;

use Text::CSV_XS;

use strict;
require sql;
require misc;

require openprint::pricing;
require openprint::Equipment;

require openprint::Pricelist;
require openprint::Service;
require openprint::ServiceCategory;
require openprint::service_price;
require openprint::service_priceset;
require openprint::logs;

sub edit {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $Service = new openprint::Service( $openprint::param{'ddmService'} );

	if ( $openprint::param{'btnFunction'} eq '<<' ) {
		$Service = $Service->Previous( {'category_id'=>$openprint::param{'ddmSearchCategory'}} );
	} elsif ( $openprint::param{'btnFunction'} eq '>>' ) {
		$Service = $Service->Next( {'category_id'=>$openprint::param{'ddmSearchCategory'}} );
	} elsif ( $openprint::param{'btnFunction'} eq 'Delete' ) {
		$Service->delete();
		$Service = $Service->Next( {'category_id'=>$openprint::param{'ddmSearchCategory'}} );
	} elsif ( $openprint::param{'btnFunction'} eq 'Save' ) {
        $Service->save( \%openprint::param );

		my $ac = sql::start_transaction( $dbh );
		foreach my $List ( openprint::Pricelist::find() ) {
			my $list = $List->id();
			my $price_set = new openprint::service_priceset( $log, $dbh, $list, $Service->id() );
			foreach my $key ( %openprint::param ) {
				if ( $key =~ /chk-$list-(.*)-(.*)/ ) {
					my $equipment = $1;
					my $index = $2;
					if ( ! $openprint::param{"ddmEquipment-$list-$equipment"} ) {
							my $price = new openprint::service_price( $log, $dbh, $price_set );
							$price->set(
									undef,
									$openprint::param{"min-$list-$equipment-$index"},
									$openprint::param{"max-$list-$equipment-$index"},
									$openprint::param{"units-$list-$equipment-$index"},
									$openprint::param{"cost-$list-$equipment-$index"},
									$openprint::param{"markup-$list-$equipment-$index"},
									$openprint::param{"price-$list-$equipment-$index"},
									$openprint::param{"discount-$list-$equipment-$index"}
									);
							$price_set->addPrice( $price );
					} else {
			
						foreach my $equipment_index ( ref $openprint::param{"ddmEquipment-$list-$equipment"} eq 'ARRAY' ? @{$openprint::param{"ddmEquipment-$list-$equipment"}} : $openprint::param{"ddmEquipment-$list-$equipment"} ) {
							my $price = new openprint::service_price( $log, $dbh, $price_set );
							$price->set(
									$equipment_index,
									$openprint::param{"min-$list-$equipment-$index"},
									$openprint::param{"max-$list-$equipment-$index"},
									$openprint::param{"units-$list-$equipment-$index"},
									$openprint::param{"cost-$list-$equipment-$index"},
									$openprint::param{"markup-$list-$equipment-$index"},
									$openprint::param{"price-$list-$equipment-$index"},
									$openprint::param{"discount-$list-$equipment-$index"}
									);
							$price_set->addPrice( $price );
						} # end foreach
					} # end if equipment
				} # end if chk 
			} # end foreach
			$price_set->save();
		} # end foreach 
		sql::end_transaction( $dbh, $ac );
    } elsif ( $openprint::param{'btnFunction'} eq 'Copy' ) {
        my @prices = $Service->prices();
        
        openprint::logs::insertLogRecord('27', "Service Index: " . $Service->id() . " - " . $Service->name(),);
        
        $Service->name( 'Copy of ' . $Service->name() );
        delete $$Service{'id'};
        if ( ! $Service->save() ) {
			foreach my $price ( @prices ) {
				$$price{'service_id'} = $$Service{'id'};
				delete $$price{'id'};
				$price->save();
			} # end foreach
		} # end if
	} # end if

	$$variable{'Service'} = $Service;
} # end sub edit

1;

__END__
