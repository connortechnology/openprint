package openprint::administrator_services;

use strict;

require sql;
require openprint::Pricelist;
require openprint::Service;
require openprint::Timetrack;
require openprint::ServiceCategory;
require openprint::ServicePrice;
require openprint::logs;

use openprint ();
use vars qw( $log $dbh %param %variable );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*param = \%openprint::param;
*variable = \%openprint::variable;

sub edit {
	my $Service = new openprint::Service( $param{ddmService} );

	if ( $param{btnFunction} eq '<<' ) {
		$Service = $Service->Previous( {'category_id'=>$param{ddmSearchCategory}} );
	} elsif ( $param{btnFunction} eq '>>' ) {
		$Service = $Service->Next( {'category_id'=>$param{ddmSearchCategory}} );
	} elsif ( $param{btnFunction} eq 'Delete' ) {
		foreach my $T ( openprint::Timetrack->find('service_id'=>$Service->id() ) ) {
			$variable{error} .= sprintf('Service is used in <a href="/timetrack/edit.html?timetrack_id=%1$d">Timetrack %1$d</a><br/>', $T->id() );
		} # end foreach T
		$variable{error} .= $Service->delete() if ! $variable{error};
		$Service = $Service->Next( {'category_id'=>$param{ddmSearchCategory}} ) if ! $variable{error};
	} elsif ( $param{btnFunction} eq 'Save' ) {
		if ( $param{new_category} ) {
			if ( my @Categories = openprint::ServiceCategory->find('name'=>$param{new_category} ) ) {
				$param{category_id} = $Categories[0]->id();
			} else {
				my $Category = new openprint::ServiceCategory();
				$Category->name( $param{new_category} );
				if ( $_ = $Category->save() ) {
					$variable{error} .= $_;
					return;
				} else {
					$param{category_id} = $Category->id();
				} # end if
			} # end if
		} # end if

		my $ac = sql::start_transaction( $dbh );
		$variable{error} .= $Service->save( \%param );
		(new openprint::Log())->save({object_id=>$$Service{id},object_type=>ref$Service, action=>'Edit Service'});
		if ( ! $variable{error} ) {

			# Please note that we don't do any deleting here.  We mayonlyhave the prices for 1 piee of equipment on screen, so just update the ones that are on screen.

			foreach my $Price ( openprint::ServicePrice->find( service_id=>$$Service{id},
($param{equipment_id} ? ( equipment_id=>$param{equipment_id} ) : () ),
						) ) {
				next if ! exists $param{"price-$$Price{id}"};

				$variable{error} .= $Price->save( {
						#equipment_id	=>	$param{"equipment_id-$$Price{id}"},
						period_start	=>	( Date::Calc::check_date( map { $param{"period_start-$$Price{id}_$_"} } ( 'year','month','day' ) ) ? sprintf('%.4d-%.2d-%.2d 00:00:00', map { $param{"period_start-$$Price{id}_$_"} } ( 'year','month','day' ) ) : undef ),
						period_end		=>	( Date::Calc::check_date( map { $param{"period_end-$$Price{id}_$_"} } ( 'year','month','day' ) ) ? sprintf('%.4d-%.2d-%.2d 23:59:59', map { $param{"period_end-$$Price{id}_$_"} } ( 'year','month','day' ) ) : undef ),
						min				=>	$param{"min-$$Price{id}"},
						max				=>	$param{"max-$$Price{id}"},
						units			=>	$param{"units-$$Price{id}"},
						cost			=>	$param{"cost-$$Price{id}"},
						markup			=>	$param{"markup-$$Price{id}"},
						price			=>	$param{"price-$$Price{id}"},
						discountable	=>	$param{"discount-$$Price{id}"},
						supplier_id		=>	$param{"supplier_id-$$Price{id}"},
						} );
			} # end foreach 
		} # end if not error
		sql::end_transaction( $dbh, $ac );
		if ( ! $variable{error} ) {
			$variable{ExternalRedirect} = '/administrator/services/edit.html?ddmService='.$Service->id();
			if ( $param{ddmServiceCategory} ) {
				$variable{ExternalRedirect} .= '&ddmServiceCategory='.$param{ddmServiceCategory};
			}
			if ( $param{equipment_id} ) {
				$variable{ExternalRedirect} .= '&equipment_id='.$param{equipment_id};
			} # end if
		} # end if
    } elsif ( $param{btnFunction} eq 'Copy' ) {
        my @prices = $Service->prices();
        
        openprint::logs::insertLogRecord('27', "Service Index: " . $Service->id() . " - " . $Service->name(),);
		$Service = $Service->copy();
		$$Service{name} = 'Copy of '.$$Service{name};
        
        $variable{error} = $Service->save();
        if ( ! $variable{error} ) {
			foreach my $price ( @prices ) {
				$$price{service_id} = $$Service{id};
				delete $$price{id};
				$variable{error} .= $price->save();
			} # end foreach
		} # end if
	} # end if

	$variable{Service} = $Service;
} # end sub edit

sub _prices_table_body {
	my $Price = new openprint::ServicePrice( $param{price_id} );
	$variable{Equipment} = $Price->Equipment();
	$variable{Pricelist} = $Price->Pricelist();
	$variable{Service} = $Price->Service();
	$variable{company_ids} = [ map { $_->id(), $_->name() } openprint::Company->find( supplier=>'Y', order=>'lower(name)' ) ];
	if ( $param{action} eq 'add' ) {
		my $Service = $variable{Service} = new openprint::Service( $param{ddmService} );
		my $Price = $variable{Price} = new openprint::ServicePrice();
		$variable{error} .= $Price->save({ equipment_id=>$param{equipment_id}, pricelist_id=>$param{pricelist_id}, service_id=>$$Service{id} });
	} elsif ( $param{action} eq 'copy' ) {
		$Price = $Price->copy();
		$variable{error} .= $Price->save();
	} elsif ( $param{action} eq 'delete' ) {
		$variable{error} .= $Price->delete();
	} # end if
} # end sub _prices_table_body

sub _price {
	$variable{Equipment} = new openprint::Equipment( $param{equipment_id} );
	$variable{Pricelist} = new openprint::Pricelist( $param{pricelist_id} );
	$variable{Service} = new openprint::Service( $param{service_id} );
	$variable{company_ids} = [ map { $_->id(), $_->name() } openprint::Company->find( supplier=>'Y', order=>'lower(name)' ) ];
	if ( $param{action} eq 'add' ) {
		my $Price = $variable{Price} = new openprint::ServicePrice();
		$variable{error} .= $Price->save({ equipment_id=>$param{equipment_id}, pricelist_id=>$param{pricelist_id}, service_id=>$param{service_id} });
	} # end if
} # end sub _price

sub _prices_per_equipment {
	$variable{Equipment} = new openprint::Equipment( $param{equipment_id} );
	$variable{Pricelist} = new openprint::Pricelist( $param{pricelist_id} );
	$variable{Service} = new openprint::Service( $param{service_id} );
	$variable{company_ids} = [ map { $_->id(), $_->name() } openprint::Company->find( supplier=>'Y', order=>'lower(name)' ) ];
	if ( $param{action} eq 'add' ) {
		my $Price = new openprint::ServicePrice();
		$variable{error} .= $Price->save({ equipment_id=>$param{equipment_id}, pricelist_id=>$param{pricelist_id}, service_id=>$param{service_id} });
	} # end if
} # end sub _prices_per_equipment

1;
__END__
