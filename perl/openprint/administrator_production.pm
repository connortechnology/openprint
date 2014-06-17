package openprint::administrator_production;

use Text::CSV_XS;

use strict;
require sql;
require misc;
require openprint::logs;
require openprint::Ink;
require openprint::pricing;
require openprint::Equipment;
require openprint::Material;
require openprint::MaterialSpecification;
require openprint::Pricelist;
require openprint::Product;
require openprint::Paper;
require openprint::logs;

use openprint ();
use vars qw( $r $log $dbh %variable %param %session %config);
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*param = \%openprint::param;
*session = \%openprint::session;
*config = \%openprint::config;

# Colour Definitions Import/Export
sub inks {

	if ( $param{'btnFunction'} eq 'Save' ) {
		my $ac = sql::start_transaction( $dbh );
		foreach my $id ( sql::execute( undef, undef, q{SELECT id FROM Inks} ) ) {
			if ( $param{"pmsid-$id"} ) {
			sql::update( undef, undef, 'Inks', ['id=?', $id], [
				'pmsid', $param{"pmsid-$id"},
				'material_id', $param{"material_id-$id"} ? $param{"material_id-$id"} : undef,
				'service_id', $param{"service_id-$id"} ? $param{"service_id-$id"} : undef,
				'washups', $param{"washups-$id"} ? $param{"washups-$id"} : undef,
			] );
			} else {
				sql::execute(undef,undef,q{DELETE FROM Inks WHERE Id=?}, $id );
			} # end if
		} # end foreach id
		if ( $param{"pmsid-New"} ) {
			sql::insert( undef, undef, 'Inks', [
					'pmsid', $param{"pmsid-New"},
					'material_id', $param{"material_id-New"} ? $param{"material_id-New"} : undef,
					'service_id', $param{"service_id-New"} ? $param{"service_id-New"} : undef,
					'washups', $param{"washups-New"} ? $param{"washups-New"} : undef,
					] );
		} # end if
		sql::end_transaction( $dbh, $ac );
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
        my $ac = sql::start_transaction( $dbh );
        foreach my $id ( ref $param{colours} eq 'ARRAY' ? @{$param{colours}} : $param{colours} ) {
            my $Ink = new openprint::Ink( $id );
            if ( ! $Ink->id() ) {
                $variable{error} .= "Error deleting ink $id : not found.<br/>";
                next;
            } # end if
            $Ink->delete();
		} # end foreach
		sql::end_transaction( $dbh, $ac );

	} elsif ( $param{'btnFunction'} eq 'Import Colours' ) {
		if ( $param{'fileColour'} ) {

			my %services = map { $_->name(), $_->id() } openprint::Service->find();
			my %materials = map { $_->name(), $_->id() } openprint::Material->find();
			# get the upload.
			my $upload = $r->upload( 'fileColour' );
			my $io = $upload->io();
			#convert it
			my $csv = Text::CSV_XS->new();
			$_ = <$io>; # drop the title row

			my $ac = sql::start_transaction( $dbh );
			while ( <$io> ) {
				my $status = $csv->parse($_);		# parse a CSV string into fields
				my @data = misc::trim($csv->fields());

				my ( $pms_id, $service, $material, $desc, $washups, $equipment, $service_cost, $service_units,$service_markup, $material_cost, $material_units, $material_markup, $gloss_coverage, $matte_coverage, $uncoated_coverage ) = @data;
				if ( ! $pms_id ) {
					$variable{'error'} .= "Bad record: $pms_id, $service, $material, $desc, $washups, $equipment, $service_cost, $service_markup, $material_cost, $material_markup";
					last;
				} # end if
$log->debug("Ink $pms_id Service: $service Material: $material $desc");
				my $Service;
				if ( $service ) {
					if ( ! $services{$service} ) {
						$Service = new openprint::Service();
						$variable{'error'} .= $Service->save({
								'name'			=>	$service,
								'description'	=>	$desc,
								});
						$services{$service} = $Service->id();
					} else {
						$Service = new openprint::Service( $services{$service} );
					} # end if
				} # end if
				my $Material;
				if ( $material ) {
					if ( ! $materials{$material} ) {
						$Material = new openprint::Material();
						$variable{'error'} .= $Material->save({
								'name'	=>	$material,
								'description'	=>	$desc,
								});
						$materials{$material} = $Material->id();
					} else {
						$Material = new openprint::Material( $materials{$material} );
					} # end if
				} # end if
				if ( $variable{'error'} ) {
					$dbh->rollback();
					last;
				} # end if

				my $Ink = openprint::Ink->find_one( 'pmsid' => $pms_id );
				$Ink = new openprint::Ink() if ! $Ink;
				$variable{'error'} .= $Ink->save({
					'pmsid',			$pms_id,
					'service_id',		( $Service ? $Service->id() : undef ),
					'material_id',		( $Material ? $Material->id() : undef ),
					'name',				$desc,
					'washups',			$washups,
				});
				if ( $variable{'error'} ) {
$log->error( $variable{'error'} );
					$dbh->rollback();
					last;
				} # end if
				
				if ( $Service and ( $service_cost or $service_markup or $service_units ) ) {
					foreach my $e_id ( misc::trim( split(',', $equipment ) ) ) {
						if ( my $Equipment = openprint::Equipment->find_one('strid'=>$e_id) ) {
							foreach my $Pricelist ( openprint::Pricelist->find() ) {
								my @Prices = openprint::ServicePrice->find('service_id'=>$services{$service}, 'equipment_id'=>$Equipment->id(), 'pricelist_id'=>$Pricelist->id() );
								if ( ! @Prices ) {
									my $Price = new openprint::ServicePrice();
									$Price->set({'service_id'=>$services{$service}, 'equipment_id'=>$Equipment->id(), 'pricelist_id'=>$Pricelist->id() } );
									push @Prices, $Price;
								} # end if no Prices;
								foreach my $Price ( @Prices ) {
									if ( $$Price{'cost'} != $service_cost or $$Price{'markup'} != $service_markup or ( $$Price{'units'} ne $service_units ) ) {
										$Price->cost( $service_cost ) if $service_cost;
										$Price->markup( $service_markup ) if $service_markup;
										$Price->units( $service_units ) if $service_units;
										$variable{'error'} .= $Price->save();
									} # en dnif
								} # end foreach Price
							} # end foreach Pricelist
						} # end if has equipment
					} # end foreach Equipment
				} # end if service_cost or service_markup
				if ( $Material ) {
					if ( $material_cost or $material_markup ) {
						foreach my $e_id ( misc::trim( split(',', $equipment ) ) ) {
							if ( my $Equipment = openprint::Equipment->find_one('strid'=>$e_id) ) {
								foreach my $Pricelist ( openprint::Pricelist->find() ) {
									my @Prices = openprint::MaterialPrice->find('material_id'=>$materials{$material}, 'equipment_id'=>$Equipment->id(), 'pricelist_id'=>$Pricelist->id() );
									if ( ! @Prices ) {
										my $Price = new openprint::MaterialPrice();
										$Price->set({'material_id'=>$materials{$material}, 'equipment_id'=>$Equipment->id(), 'pricelist_id'=>$Pricelist->id() } );
										push @Prices, $Price;
									} # end if no Prices;
									foreach my $Price ( @Prices ) {
										if ( ( 1*$$Price{'cost'} != $material_cost ) or ( 1*$$Price{'markup'} != 1*$material_markup ) or ( $$Price{'units'} ne $material_units ) ) {
											$Price->cost( $material_cost ) if $material_cost;
											$Price->markup( $material_markup ) if $material_markup;
											$Price->units( $material_units ) if $material_units;
											$variable{'error'} .= $Price->save();
										} # end if
									} # end foreach Price
								} # end foreach Pricelist
							} # end if has equipment
						} # end foreach Equipment
					} # end if material_cost or material_markup
					if ( $gloss_coverage ) {
						my $Spec = $Material->Specification('Coverage', 1 );
						if ( ! $Spec ) {
							$Spec = new openprint::MaterialSpecification();
							$Spec->set({
									'material_id'=>$Material->id(),
									'name'		=>	'Coverage',
									'min'		=>	1,
									'max'		=>	1,
									});
						} # end if
						if ( $gloss_coverage != $Spec->value() ) {
							$variable{'error'} .= $Spec->save({'value'=>$gloss_coverage});
						} # end if
						$Spec = $Material->Specification('Coverage', 3 );
						if ( ! $Spec ) {
							$Spec = new openprint::MaterialSpecification();
							$Spec->set({
									'material_id'=>$Material->id(),
									'name'		=>	'Coverage',
									'min'		=>	3,
									'max'		=>	3,
									});
						} # end if
						if ( $gloss_coverage != $Spec->value() ) {
							$variable{'error'} .= $Spec->save({'value'=>$gloss_coverage});
						} # end if
					} # end if
					if ( $matte_coverage ) {
						my $Spec = $Material->Specification('Coverage', 2 );
						if ( ! $Spec ) {
							$Spec = new openprint::MaterialSpecification();
							$Spec->set({
									'material_id'	=>	$Material->id(),
									'name'		=>	'Coverage',
									'min'		=>	2,
									'max'		=>	2,
									});
						} # end if
						if ( $matte_coverage != $Spec->value() ) {
							$variable{'error'} .= $Spec->save({'value'=>$matte_coverage});
						} # end if
					} # end if
					if ( $uncoated_coverage ) {
						my $Spec = $Material->Specification('Coverage', 4 );
						if ( ! $Spec ) {
							$Spec = new openprint::MaterialSpecification();
							$Spec->set({
									'material_id'	=>	$Material->id(),
									'name'		=>	'Coverage',
									'min'		=>	4,
									'max'		=>	5,
									});
						} # end if
						if ( $uncoated_coverage != $Spec->value() ) {
							$variable{'error'} .= $Spec->save({'value'=>$uncoated_coverage});
						} # end if
					} # end if
				} # end if

			} # end while
			sql::end_transaction( $dbh, $ac );
				# Add record to audit log - action "Import Colour Definitions".
			openprint::logs::insertLogRecord('56', '');
		} else {
			$log->warn( "No file given to upload." );
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Export Colours' ) {
		my @header = ( 'PMSId', 'Service ID', 'Material ID', 'Colour Name' );
		$_ = "SELECT PMSID, (SELECT name FROM Services WHERE id=service_id), (SELECT name FROM Materials WHERE id=Material_ID), washups, strColourName FROM Inks";
		my @data = sql::execute( $log, $dbh, $_ );
		misc::export_csv( $r, $log, \%variable, 'inks.csv', \@header, \@data );
		# Add record to audit log - action "Export Colour Definitions".
		logs::insertLogRecord('57',);
	} # end if

	_inks();
} # end sub inks

sub _inks {
	ssi::save_params( '/administrator/production/inks.html', ( 'pmsid','name','grade' ) );
} # end sub _inks

sub ink {
	my $Ink = $variable{Ink} = new openprint::Ink($param{ink_id});
	if ( $param{btnFunction} eq 'Save' ) {
		my $grades;
		if ( $param{grades} ) {
			$grades = ref $param{grades} eq 'ARRAY' ? $param{grades} : [ $param{grades} ];
		} # end if
		$variable{error} .= $Ink->save({
			name	=>	$param{name},
			pmsid	=>	$param{pmsid},
			washups	=>	$param{washups},
			mix		=>	$param{mix},
			service_id	=>	$param{service_id},
			material_id	=>	$param{material_id},
			grades		=>	$grades,
		});
		if ( ! $variable{error} ) {
			$variable{ExternalRedirect} = '/administrator/production/inks.html';
		} # end if
	} elsif ( $param{btnFunction} eq 'Copy' ) {
		$Ink = $Ink->copy();
		$variable{error} .= $Ink->save({name=>'Copy of ' . $Ink->name});
		$variable{Ink} = $Ink;
		$variable{ExternalRedirect} = '/administrator/production/ink.html?ink_id='.$Ink->id();
	} # end if
} # end sub ink

sub _material_id_ddm {
	$variable{Ink} = new openprint::Ink( $param{'ink_id'} );
} # end sub _material_id_ddm
sub _service_id_ddm {
	$variable{Ink} = new openprint::Ink( $param{'ink_id'} );
} # end sub _service_id_ddm


sub pricelists {
	require openprint::ProductPrice;
	$param{'ddmPriceList'} =~ s/\D//g;
	my $Pricelist = new openprint::Pricelist( $param{'ddmPriceList'} );
	if ( ! ( $Pricelist and $Pricelist->id() ) ) {
		if ( ! ( $Pricelist = openprint::Pricelist->find_one('order'=>'lower(name)') ) ) {
			$Pricelist = new openprint::Pricelist( );
		} # end if
	} # end if

	if ( $param{'btnFunction'} eq '>>' ) {
		$Pricelist = $Pricelist->Next();
	} elsif ( $param{'btnFunction'} eq '<<' ) {
		$Pricelist = $Pricelist->Previous();
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		$Pricelist->delete();
		$Pricelist = $Pricelist->Next();
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		$Pricelist->save( \%param );
	} elsif ( $param{'btnFunction'} eq 'Copy' ) {
		my $New = $Pricelist->copy();
		$param{'name'} = 'Copy of '.$param{'name'};
		$variable{'error'} .= $New->save( \%param );
		openprint::logs::insertLogRecord('32', "Price List: " . $param{'name'},);
		my $ac = sql::start_transaction( $dbh );
		foreach ( $Pricelist->getPrices() ) {
			my $Price = $_->copy();
			$$Price{'pricelist_id'} = $$New{'id'};
			$variable{'error'} .= $Price->save();
		} # end foreach
		sql::end_transaction( $dbh, $ac );
		$Pricelist = $New;
	} elsif ( $param{'btnFunction'} eq 'Markup' ) {
		my $markup = $param{'Markup'};
		$markup =~ s/[^\+\-\.\d]//g;
		if ( $markup ne '' ) {
			my $ac = sql::start_transaction( $dbh );
			foreach my $Price ( $Pricelist->getPrices() ) {
				if ( $markup =~ /^[\+\-]/ ) {
					$$Price{'markup'} += $markup;
				} else {
					$$Price{'markup'} = $markup;
				} # end if
				$$Price{'price'} = $$Price{'cost'} * (1+$$Price{'markup'}/100);
				$variable{'error'} .= $Price->save();
			} # end foreach
			sql::end_transaction( $dbh, $ac );
		} # end if markup
	} elsif ( $param{'btnFunction'} eq 'Export Material Prices' ) {
		if ( ! $Pricelist->id() ) {
			return misc::error( $log, $dbh, \%variable, 'No pricelist selected.', 'You must select a pricelist before exporting.');
		} # end if
		my @header = ( 'Material ID', 'Equipment ID','Min', 'Max', 'Units', 'Cost', 'Markup', 'Price', 'Discountable' );
		my @data = map { $_->Material()->name(), $_->Equipment()->name(), $_->min(), $_->max(), $_->units(), $_->cost(), $_->markup(), $_->price(), $_->discountable() } openprint::MaterialPrice->find('pricelist_id'=>$Pricelist->id(), 'order'=>join(',',@openprint::MaterialPrice::fields{'min','max'}));
		misc::export_csv( $r, $log, \%variable, $Pricelist->name() . 'MaterialPrices.csv', \@header, \@data );

	} elsif ( $param{'btnFunction'} eq 'Export Paper Prices' ) {
		if ( ! $Pricelist->id() ) {
			return misc::error( $log, $dbh, \%variable, 'No pricelist selected.', 'You must select a pricelist before exporting.');
		} # end if
	
		my @header = ( 'Paper Brand', 'Finish','Colour','Weight','Width','Height','Service', 'Equipment', 'Min', 'Max', 'Units', 'Cost', 'Markup', 'Price', 'Discountable' );
		my @data;
		foreach my $Paper (openprint::Paper->find( 'order'=>'name,finish,colour,weight,width,height' ) ) {
            foreach my $Price ( openprint::PaperPrice->find( paper_id=>$$Paper{id}, pricelist_id=>$$Pricelist{id}, order=>'lnglistindex, lngmin NULLS FIRST, lngmax NULLS FIRST') ) {
				push @data, $Paper->brand(), $Paper->finish(),$Paper->colour(), $Paper->weight(), $Paper->width(), $Paper->height();
				push @data, $Price->service(), $Price->Equipment()->strid(), $Price->min(), $Price->max(), $Price->units(), $Price->cost(), $Price->markup(), $Price->price(), $Price->discountable();
			} # end foreach
		} # end foreach Paper
		misc::export_csv( $r, $log, \%variable, $Pricelist->name() . 'PaperPrices.csv', \@header, \@data );

	} elsif ( $param{'btnFunction'} eq 'Export Product Prices' ) {
		return misc::error( $log, $dbh, \%variable, 'No pricelist selected.', 'You must select a pricelist before exporting.') if ! $Pricelist->id();
		my @header = ( 'Name','Min', 'Max', 'Units', 'Cost', 'Markup', 'Price', 'Discountable' );
		my @data;
		foreach my $Product (openprint::Product->find( 'order'=>'name' ) ) {
			foreach my $Price ( $Product->Prices('Pricelist'=>$Pricelist, 'order'=>'lngMin') ) {
				push @data, $Product->name();
				push @data, $Price->min(), $Price->max(), $Price->units(), $Price->cost(), $Price->markup(), $Price->price(), $Price->discountable();
			} # end foreach
		} # end foreach Product
		misc::export_csv( $r, $log, \%variable, $Pricelist->name() . 'ProductPrices.csv', \@header, \@data );

	} elsif ( $param{'btnFunction'} eq 'Export Service Prices' ) {
		return misc::error( $log, $dbh, \%variable, 'No pricelist selected.', 'You must select a pricelist before exporting.') if ! $Pricelist->id();
		my @header = ( 'Service ID', 'Equipment ID','Min', 'Max', 'Units', 'Cost', 'Markup', 'Price', 'Discountable' );
		my @data = map { $_->Service()->name(), $_->Equipment()->name(), $_->min(), $_->max(), $_->units(), $_->cost(), $_->markup(), $_->price(), $_->discountable() } openprint::ServicePrice->find('pricelist_id'=>$Pricelist->id(), 'order'=>join(',',@openprint::ServicePrice::fields{'min','max'}));
		misc::export_csv( $r, $log, \%variable, $Pricelist->name() . 'ServicePrices.csv', \@header, \@data );
	} elsif ( $param{'btnFunction'} eq 'Import Service Prices' ) {
		return misc::error( $log, $dbh, \%variable, 'No pricelist selected.', 'You must select a pricelist before importing.') if ! $Pricelist->id();
		return misc::error( $log, $dbh, \%variable, 'No file given.', 'You must select a file to import.') if ! $param{'filePrices'};

		my $error = '';
		my $pricelist = new openprint::pricelist( $log, $dbh, $Pricelist->id() );

		# An import replaces the current pricelist, so delete verything in the current one.
		sql::execute( $log, $dbh, 'DELETE FROM Service_Prices WHERE pricelist_id=?', $Pricelist->id() );

		# get the upload.
		my $upload = $r->upload( 'filePrices' );
		my $io = $upload->io();
		$_ = <$io>;
		my $csv = Text::CSV_XS->new();
		my %equipment = map { $_->strid(), $_->id() } openprint::Equipment->find();

		while ( <$io> ) {
			my $status = $csv->parse($_);
			my ( $prod_id, $equip_ids, @data ) = misc::trim( $csv->fields());
			next if ! $prod_id;
			
			my $prod_index = openprint::service::get_index_by_id( $prod_id );
			if ( $prod_index eq '' ) {
				$error .= "No Service found for $prod_id<br>";
				next;
			} # end if

			if ( $equip_ids eq '' ) {
					my $price_set = $pricelist->getServicesPriceSet( $prod_index );
					my $price = new openprint::service_price( $log, $dbh, $price_set );
					$price->set( undef, @data );
					$price_set->addPrice( $price );
			} else {
				foreach my $equip_id ( split(',',$equip_ids) ) {
					$equip_id =~ s/^\s*(.*?)\s*$/$1/;
					if ( ! $equipment{$equip_id} ) {
						$error .= "No Equipment found for $equip_id<br>";
						next;
					} # end if

					my $price_set = $pricelist->getServicesPriceSet( $prod_index );
					my $price = new openprint::service_price( $log, $dbh, $price_set );
					$price->set( $equipment{$equip_id}, @data );
					$price_set->addPrice( $price );
				} # end foreach
			} # end if
		} # end foreach
		$pricelist->save();

		if ( $error ne '' ) {
			return misc::error( $log, $dbh, \%variable, 'Import errors.', $error );
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Import Material Prices' ) {
		return misc::error( $log, $dbh, \%variable, 'No pricelist selected.', 'You must select a pricelist before importing.') if ! $Pricelist->id();

		return misc::error( $log, $dbh, \%variable, 'No file given.', 'You must select a file to import.') if ! $param{'filePrices'};

		my $error = '';
		my $pricelist = new openprint::pricelist( $log, $dbh, $Pricelist->id() );

		# An import replaces the current pricelist, so delete verything in the current one.
		sql::execute( $log, $dbh, 'DELETE FROM tbl_Material_Prices WHERE lngListIndex=?', $Pricelist->id() );

		# get the upload.
		my $upload = $r->upload('filePrices');
		my $io = $upload->io();
		$_ = <$io>;
		my $csv = Text::CSV_XS->new();

		my %equipment = map { $_->strid(), $_->id() } openprint::Equipment->find();
		my %materials = map { $_->name(), $_->id() } openprint::Material->find();

		while ( <$io> ) {
			my $status = $csv->parse($_);
			my ( $material_id, $equip_ids, @data ) = $csv->fields();

			next if $material_id eq '';
			
			if ( ! $materials{$material_id} ) {
				$error .= "No Material found for $material_id<br>";
				next;
			} # end if

			if ( $equip_ids eq '' ) {
					my $price_set = $pricelist->getMaterialsPriceSet( $materials{$material_id} );
					my $price = new openprint::material_price( $log, $dbh, $price_set );
					$price->set( undef, @data );
					$price_set->addPrice( $price );
			} else {
				foreach my $equip_id ( split(',',$equip_ids) ) {
					$equip_id =~ s/^\s*(.*?)\s*$/$1/;
					if ( ! $equipment{$equip_id} ) {
						$error .= "No Equipment found for $equip_id<br>";
						next;
					} # end if

					my $price_set = $pricelist->getMaterialsPriceSet( $materials{$material_id} );
					my $price = new openprint::material_price( $log, $dbh, $price_set );
					$price->set( $equipment{$equip_id}, @data );
					$price_set->addPrice( $price );
				} # end foreach
			} # end if
		} # end foreach
		$pricelist->save();

		if ( $error ne '' ) {
			return misc::error( $log, $dbh, \%variable, 'Import errors.', $error );
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Import Paper Prices' ) {

		return misc::error( $log, $dbh, \%variable, 'No pricelist selected.', 'You must select a pricelist before importing.') if ! $Pricelist->id();

		return misc::error( $log, $dbh, \%variable, 'No file given.', 'You must select a file to import.') if ! $param{'filePrices'};

		my $error = '';
		my $pricelist = new openprint::pricelist( $log, $dbh, $Pricelist->id() );

		# An import replaces the current pricelist, so delete verything in the current one.
		sql::execute( $log, $dbh, 'DELETE FROM Paper_Prices WHERE lngListIndex=?', $Pricelist->id() );

# get the upload.
		my $upload = $r->upload('filePrices');
		my $io = $upload->io();
		$_ = <$io>;

		my $csv = Text::CSV_XS->new();

		while ( <$io> ) {
			my $status = $csv->parse($_);
			my ( $name, $finish, $colour, $weight, $width, $height, @data ) = misc::trim( $csv->fields());
			my @Papers = openprint::Paper->find('name'=>$name, 'finish'=>$finish, 'colour'=>$colour, 'weight'=>$weight, 'width'=>$width, 'height'=>$height );
			if ( ! @Papers ) {
				$error .= "No Paper found for $name, $finish, $colour, $weight, $width, $height<br/>";
				next;
			} # end if

			foreach my $Paper ( @Papers ) {
				my $price_set = $pricelist->getPaperPriceSet( $Paper->id() );
				my $price = new openprint::paper_price( $log, $dbh, $price_set );
				$price->set( undef, @data );
				$price_set->addPrice( $price );
			} # end foreach Paper
		} # end foreach CSV line
		$pricelist->save();

		if ( $error ) {
			return misc::error( $log, $dbh, \%variable, 'Import errors.', $error );
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Import Product Prices' ) {
		return misc::error( $log, $dbh, \%variable, 'No pricelist selected.', 'You must select a pricelist before importing.') if ! $Pricelist->id();
		return misc::error( $log, $dbh, \%variable, 'No file given.', 'You must select a file to import.') if ! $param{'filePrices'};
		my $error = '';

		my $pricelist = new openprint::pricelist( $log, $dbh, $Pricelist->id() );

# get the upload.
		my $upload = $r->upload('filePrices');
		my $io = $upload->io();
		$_ = <$io>;
		my $csv = Text::CSV_XS->new();

		my %products = map { $_->name(), $_->id() } openprint::Product->find();
		my %equipment = map { $_->strid(), $_->id() } openprint::Equipment->find();

		while ( <$io> ) {
			my $status = $csv->parse($_);
			my ( $name, @data ) = misc::trim( $csv->fields());
			if ( ! $products{$name} ) {
				$error .= "No Product found for $name<br/>";
				next;
			} # end if
$openprint::log->debug("Doing $name");
			my $price_set = $pricelist->getProductPriceSet( $products{$name} );
			my $price = new openprint::product_price( $log, $dbh, $price_set );
			$price->set( undef, @data );
			$price_set->addPrice( $price );
		} # end foreach CSV line
		$pricelist->save();

		if ( $error ) {
			return misc::error( $log, $dbh, \%variable, 'Import errors.', $error );
		} # end if

	} # end if

	$variable{'Pricelist'} = $Pricelist;

} # end sub edit

1;
__END__
