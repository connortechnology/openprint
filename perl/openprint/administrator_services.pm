package openprint::administrator_services;

use Text::CSV_XS;

use strict;

require sql;
require misc;

require openprint::Pricelist;
require openprint::Service;
require openprint::ServiceCategory;
require openprint::service_price;
require openprint::service_priceset;
require openprint::logs;

use openprint ();
use vars qw( $log $dbh %param %variable );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*param = \%openprint::param;
*variable = \%openprint::variable;

sub edit {
	my $Service = new openprint::Service( $param{'ddmService'} );

	if ( $param{'btnFunction'} eq '<<' ) {
		$Service = $Service->Previous( {'category_id'=>$param{'ddmSearchCategory'}} );
	} elsif ( $param{'btnFunction'} eq '>>' ) {
		$Service = $Service->Next( {'category_id'=>$param{'ddmSearchCategory'}} );
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		foreach my $T ( openprint::Timetrack->find('service_id'=>$Service->id() ) ) {
			$variable{'error'} .= sprintf('Service is used in <a href="/timetrack/edit.html?timetrack_id=%1$d">Timetrack %1$d</a><br/>', $T->id() );
		} # end foreach T
		$variable{'error'} .= $Service->delete() if ! $variable{'error'};
		$Service = $Service->Next( {'category_id'=>$param{'ddmSearchCategory'}} ) if ! $variable{'error'};
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		if ( $param{'new_category'} ) {
			if ( my @Categories = openprint::ServiceCategory->find('name'=>$param{'new_category'} ) ) {
				$param{'category_id'} = $Categories[0]->id();
			} else {
				my $Category = new openprint::ServiceCategory();
				$Category->name( $param{'new_category'} );
				if ( $_ = $Category->save() ) {
					$variable{'error'} .= $_;
					return;
				} else {
					$param{'category_id'} = $Category->id();
				} # end if
			} # end if
		} # end if

		$variable{'error'} .= $Service->save( \%openprint::param );
		if ( ! $variable{'error'} ) {

		my $ac = sql::start_transaction( $dbh );
		foreach my $List ( openprint::Pricelist->find() ) {
			my $list = $List->id();
			my $price_set = new openprint::service_priceset( $log, $dbh, $list, $Service->id() );
			foreach my $key ( %param ) {
				if ( $key =~ /chk-$list-(.*)-(.*)/ ) {
					my $equipment = $1;
					my $index = $2;
					if ( ! $param{"ddmEquipment-$list-$equipment"} ) {
							my $price = new openprint::service_price( $log, $dbh, $price_set );
							$price->set(
									undef,
									$param{"min-$list-$equipment-$index"},
									$param{"max-$list-$equipment-$index"},
									$param{"units-$list-$equipment-$index"},
									$param{"cost-$list-$equipment-$index"},
									$param{"markup-$list-$equipment-$index"},
									$param{"price-$list-$equipment-$index"},
									$param{"discount-$list-$equipment-$index"},
									$param{"supplier_id-$list-$equipment-$index"},
									);
							$price_set->addPrice( $price );
					} else {
			
						foreach my $equipment_index ( ref $param{"ddmEquipment-$list-$equipment"} eq 'ARRAY' ? @{$param{"ddmEquipment-$list-$equipment"}} : $param{"ddmEquipment-$list-$equipment"} ) {
							my $price = new openprint::service_price( $log, $dbh, $price_set );
							$price->set(
									$equipment_index,
									$param{"min-$list-$equipment-$index"},
									$param{"max-$list-$equipment-$index"},
									$param{"units-$list-$equipment-$index"},
									$param{"cost-$list-$equipment-$index"},
									$param{"markup-$list-$equipment-$index"},
									$param{"price-$list-$equipment-$index"},
									$param{"discount-$list-$equipment-$index"},
									$param{"supplier_id-$list-$equipment-$index"},
									);
							$price_set->addPrice( $price );
						} # end foreach
					} # end if equipment
				} # end if chk 
			} # end foreach
			$price_set->save();
		} # end foreach 
		sql::end_transaction( $dbh, $ac );
		} # end if not error
    } elsif ( $param{'btnFunction'} eq 'Copy' ) {
        my @prices = $Service->prices();
        
        openprint::logs::insertLogRecord('27', "Service Index: " . $Service->id() . " - " . $Service->name(),);
		$Service = $Service->copy();
		$$Service{'name'} = 'Copy of '.$$Service{'name'};
        
        $variable{'error'} = $Service->save();
        if ( ! $variable{'error'} ) {
			foreach my $price ( @prices ) {
				$$price{'service_id'} = $$Service{'id'};
				delete $$price{'id'};
				$variable{'error'} .= $price->save();
			} # end foreach
		} # end if
	} # end if

	$variable{'Service'} = $Service;
} # end sub edit

sub _prices_table_body {
	my $Price = new openprint::ServicePrice( $param{'price_id'} );
	$variable{'Equipment'} = $Price->Equipment();
	$variable{'Pricelist'} = $Price->Pricelist();
	$variable{'Service'} = $Price->Service();
	$variable{'company_ids'} = [ map { $_->id(), $_->name() } openprint::Company->find( 'supplier'=>'Y', 'order'=>'lower(name)' ) ];
	if ( $param{'action'} eq 'copy' ) {
		$Price = $Price->copy();
		$variable{'error'} .= $Price->save();
	} elsif ( $param{'action'} eq 'delete' ) {
		$variable{'error'} .= $Price->delete();
	} # end if
} # end sub _prices_table_body

1;

__END__
