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
sub colour_import_export {

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
				my $status = $csv->parse($_);		 # parse a CSV string into fields

				my ( $pms_id, $service, $material, $desc, $washups, $equipment, $service_cost, $service_markup, $material_cost, $material_markup ) = misc::trim($csv->fields());
				if ( ! $pms_id ) {
					$variable{'error'} .= "Bad record: $pms_id, $service, $material, $desc, $washups, $equipment, $service_cost, $service_markup, $material_cost, $material_markup";
					last;
				} # end if
				if ( ! $services{$service} ) {
					my $Service = new openprint::Service();
					$variable{'error'} .= $Service->save({
						'name'	=>	$service,
						'description'	=>	$desc,
					});
					$services{$service} = $Service->id();
				} # end if
				if ( ! $materials{$material} ) {
					my $Material = new openprint::Material();
					$variable{'error'} .= $Material->save({
						'name'	=>	$material,
						'description'	=>	$desc,
					});
					$materials{$material} = $Material->id();
				} # end if
				if ( $variable{'error'} ) {
					$dbh->rollback();
					last;
				} # end if

				my $Ink = openprint::Ink->find_one( 'pmsid' => $pms_id );
				$Ink = new openprint::Ink() if ! $Ink;
				$variable{'error'} .= $Ink->save({
					'pmsid',			$pms_id,
					'service_id',		$services{$service},
					'material_id',		$materials{$material},
					'name',				$desc,
					'washups',			$washups,
				});
				if ( $variable{'error'} ) {
					$dbh->rollback();
					last;
				} # end if

				if ( $service_cost or $service_markup ) {
					my $Service = new openprint::Service( $services{$service} );
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
									$Price->cost( $service_cost ) if $service_cost;
									$Price->markup( $service_markup ) if $service_markup;
									$variable{'error'} .= $Price->save();
								} # end foreach Price
							} # end foreach Pricelist
						} # end if has equipment
					} # end foreach Equipment
				} # end if service_cost or service_markup
				if ( $material_cost or $material_markup ) {
					my $Material = new openprint::Service( $materials{$material} );
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
									$Price->cost( $material_cost ) if $material_cost;
									$Price->markup( $service_markup ) if $material_markup;
									$variable{'error'} .= $Price->save();
								} # end foreach Price
							} # end foreach Pricelist
						} # end if has equipment
					} # end foreach Equipment
				} # end if service_cost or service_markup

			} # end while
      		# Add record to audit log - action "Import Colour Definitions".
         	openprint::logs::insertLogRecord('56', '');
			sql::end_transaction( $dbh, $ac );
		} else {
			$log->warn( "No file given to upload." );
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Export Colours' ) {
		my @header = ( 'PMSId', 'Serivce ID', 'Material ID', 'Colour Name' );
		$_ = "SELECT PMSID, (SELECT name FROM Services WHERE id=service_id), (SELECT name FROM Materials WHERE id=Material_ID), washups, strColourName FROM Inks";
		my @data = sql::execute( $log, $dbh, $_ );
		misc::export_csv( $r, $log, \%variable, 'colours.csv', \@header, \@data );
		# Add record to audit log - action "Export Colour Definitions".
		logs::insertLogRecord('57',);
	} # end if
} # end sub inks

sub ink {
	$variable{'Ink'} = new openprint::Ink( $param{'ink_id'} );
} # end sub ink

sub _material_id_ddm {
	$variable{'Ink'} = new openprint::Ink( $param{'ink_id'} );
} # end sub _material_id_ddm
sub _service_id_ddm {
	$variable{'Ink'} = new openprint::Ink( $param{'ink_id'} );
} # end sub _service_id_ddm


sub pricelist {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $id = $openprint::param{'ddmPriceList'};
	my $Pricelist = new openprint::Pricelist( $id );

	if ( $r->param('btnFunction') eq '>>' ) {
		$Pricelist = $Pricelist->Next();
	} elsif ( $r->param('btnFunction') eq '<<' ) {
		$Pricelist = $Pricelist->Previous();
	} elsif ( $r->param('btnFunction') eq 'Delete' ) {
		$Pricelist->delete();
		$Pricelist = $Pricelist->Next();
	} elsif ( $r->param('btnFunction') eq 'Save' ) {
		my $param = $r->param;
		$Pricelist->save( $param );
	} elsif ( $r->param('btnFunction') eq 'Copy' ) {
		my $new = new openprint::Pricelist( );
		$openprint::param{'Name'} = 'Copy of '.$openprint::param{'Name'};
		$new->save( \%openprint::param );
		openprint::logs::insertLogRecord('32', "Price List: " . $openprint::param{'Name'},);
		my $ac = sql::start_transaction( $dbh );
		my @prices = $Pricelist->getPrices();
		foreach my $price (@prices ) {
			$$price{'id'} = undef;
			$$price{'PricelistIndex'} = $new->id();
			$price->save();
		} # end foreach
		sql::end_transaction( $dbh, $ac );

		$Pricelist = $new;
	} elsif ( $r->param('btnFunction') eq 'Markup' ) {
		my $markup = $r->param('Markup');
		$markup =~ s/[^\+\-\.\d]//g;
		my $ac = sql::start_transaction( $dbh );
		my @prices = $Pricelist->getPrices();
		foreach my $price (@prices ) {
			if ( $markup =~ /^[\+\-]/ ) {
				$$price{'Markup'} += $markup;
			} else {
				$$price{'Markup'} = $markup;
			} # end if
			$$price{'Price'} = $$price{'Cost'} * (1+$$price{'Markup'}/100);
			$price->save();
		} # end foreach
		sql::end_transaction( $dbh, $ac );
	} elsif ( $r->param('btnFunction') eq 'Export Material Prices' ) {
		if ( $id eq '' ) {
			return misc::error( $log, $dbh, $variable, 'No pricelist selected.', 'You must select a pricelist before exporting.');
		} # end if
		my @header = ( 'Material ID', 'Equipment ID','Min', 'Max', 'Units', 'Cost', 'Markup', 'Price', 'Discountable' );
        $_ = "SELECT (SELECT name FROM Materials WHERE id = lngMaterialIndex) AS strID,\n".
				"(SELECT strID FROM tbl_Equipment WHERE lngIndex = lngEquipmentIndex) AS EquipmentID,\n".
				"lngMin, lngMax, strUnits, dblCost, dblMarkup, dblPrice, ysnDiscountable\n".
                "FROM tbl_Material_Prices\n".
                "WHERE lngListIndex = '$id'\n".
				"ORDER BY strID, EquipmentID, lngMin";
        my @data = sql::execute( $log, $dbh, $_ );
		misc::export_csv( $r, $log, $variable, $Pricelist->name() . 'MaterialPrices.csv', \@header, \@data );
	} elsif ( $openprint::param{'btnFunction'} eq 'Export Paper Prices' ) {
		if ( $id eq '' ) {
			return misc::error( $log, $dbh, $variable, 'No pricelist selected.', 'You must select a pricelist before exporting.');
		} # end if
	
		my @header = ( 'Paper Brand', 'Finish','Colour','Weight','Width','Height','Min', 'Max', 'Units', 'Cost', 'Markup', 'Price', 'Discountable' );
		my @data;
		foreach my $Paper (openprint::Paper::find( 'order'=>'name,finish,colour,weight,width,height' ) ) {
			foreach my $Price ( $Paper->Prices('Pricelist'=>$Pricelist, 'order'=>'lngMin') ) {
				push @data, $Paper->name(), $Paper->finish(),$Paper->colour(), $Paper->weight(), $Paper->width(), $Paper->height();
				push @data, $Price->Min(), $Price->Max(), $Price->Units(), $Price->Cost(), $Price->Markup(), $Price->Price(), $Price->Discountable();
			} # end foreach
		} # end foreach Paper
		misc::export_csv( $r, $log, $variable, $Pricelist->name() . 'PaperPrices.csv', \@header, \@data );
	} elsif ( $openprint::param{'btnFunction'} eq 'Export Product Prices' ) {
		return misc::error( $log, $dbh, $variable, 'No pricelist selected.', 'You must select a pricelist before exporting.') if ! $id;
	
		my @header = ( 'Name','Min', 'Max', 'Units', 'Cost', 'Markup', 'Price', 'Discountable' );
		my @data;
		foreach my $Product (openprint::Product::find( 'order'=>'name' ) ) {
			foreach my $Price ( $Product->Prices('Pricelist'=>$Pricelist, 'order'=>'lngMin') ) {
				push @data, $Product->name();
				push @data, $Price->min(), $Price->max(), $Price->units(), $Price->cost(), $Price->markup(), $Price->price(), $Price->discountable();
			} # end foreach
		} # end foreach Product
		misc::export_csv( $r, $log, $variable, $Pricelist->name() . 'ProductPrices.csv', \@header, \@data );
	} elsif ( $r->param('btnFunction') eq 'Export Service Prices' ) {
		if ( $id eq '' ) {
			return misc::error( $log, $dbh, $variable, 'No pricelist selected.', 'You must select a pricelist before exporting.');
		} # end if
		my @header = ( 'Service ID', 'Equipment ID','Min', 'Max', 'Units', 'Cost', 'Markup', 'Price', 'Discountable' );
        $_ = "SELECT (SELECT name FROM Services WHERE id = lngServiceIndex) AS strID,\n".
				"(SELECT strID FROM tbl_Equipment WHERE lngIndex = lngEquipmentIndex) AS EquipmentID,\n".
				"lngMin, lngMax, strUnits, dblCost, dblMarkup, dblPrice, ysnDiscountable\n".
                "FROM tbl_Service_Prices\n".
                "WHERE lngListIndex = '$id'\n".
				"ORDER BY strID, EquipmentID, lngMin";
        my @data = sql::execute( $log, $dbh, $_ );
		misc::export_csv( $r, $log, $variable, $Pricelist->name() . 'ServicePrices.csv', \@header, \@data );


	} elsif ( $r->param('btnFunction') eq 'Import Service Prices' ) {
		my $error = '';

		if ( $id eq '' ) {
			return misc::error( $log, $dbh, $variable, 'No pricelist selected.', 'You must select a pricelist before importing.');
		} # end if

		if ( $r->param('filePrices') eq '' ) {
			return misc::error( $log, $dbh, $variable, 'No file given.', 'You must select a file to import.');
		} # end if

		my $pricelist = new openprint::pricelist( $log, $dbh, $id );

		# An import replaces the current pricelist, so delete verything in the current one.
		sql::execute( $log, $dbh, "DELETE FROM tbl_Service_Prices WHERE lngListIndex=$id" );

		# get the upload.
		my $upload = $r->upload( 'filePrices' );
		my $io = $upload->io();
		$_ = <$io>;
		my $csv = Text::CSV_XS->new();
		my %equipment = map { $_->strid(), $_->id() } openprint::Equipment::find();

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
			return misc::error( $log, $dbh, $variable, 'Import errors.', $error );
		} # end if
	} elsif ( $r->param('btnFunction') eq 'Import Material Prices' ) {
		my $error = '';

		if ( $id eq '' ) {
			return misc::error( $log, $dbh, $variable, 'No pricelist selected.', 'You must select a pricelist before importing.');
		} # end if

		if ( $r->param('filePrices') eq '' ) {
			return misc::error( $log, $dbh, $variable, 'No file given.', 'You must select a file to import.');
		} # end if

		my $pricelist = new openprint::pricelist( $log, $dbh, $id );

		# An import replaces the current pricelist, so delete verything in the current one.
		sql::execute( $log, $dbh, "DELETE FROM tbl_Material_Prices WHERE lngListIndex = '$id'" );

		# get the upload.
		my $upload = $r->upload('filePrices');
		my $io = $upload->io();
		$_ = <$io>;
		my $csv = Text::CSV_XS->new();

		my %equipment = map { $_->strid(), $_->id() } openprint::Equipment::find();
		my %materials = map { $_->name(), $_->id() } openprint::Material::find();

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
			return misc::error( $log, $dbh, $variable, 'Import errors.', $error );
		} # end if
	} elsif ( $openprint::param{'btnFunction'} eq 'Import Paper Prices' ) {
		my $error = '';

		if ( $id eq '' ) {
			return misc::error( $log, $dbh, $variable, 'No pricelist selected.', 'You must select a pricelist before importing.');
		} # end if

		if ( $r->param('filePrices') eq '' ) {
			return misc::error( $log, $dbh, $variable, 'No file given.', 'You must select a file to import.');
		} # end if

		my $pricelist = new openprint::pricelist( $log, $dbh, $id );

		# An import replaces the current pricelist, so delete verything in the current one.
		sql::execute( $log, $dbh, 'DELETE FROM Paper_Prices WHERE lngListIndex=?', $id );

# get the upload.
		my $upload = $r->upload('filePrices');
		my $io = $upload->io();
		$_ = <$io>;

		my $csv = Text::CSV_XS->new();

		while ( <$io> ) {
			my $status = $csv->parse($_);         # parse a CSV string into fields
			my ( $name, $finish, $colour, $weight, $width, $height, @data ) = misc::trim( $csv->fields());
			my @Papers = openprint::Paper::find('name'=>$name, 'finish'=>$finish, 'colour'=>$colour, 'weight'=>$weight, 'width'=>$width, 'height'=>$height );
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
			return misc::error( $log, $dbh, $variable, 'Import errors.', $error );
		} # end if
	} elsif ( $openprint::param{'btnFunction'} eq 'Import Product Prices' ) {
		my $error = '';
		return misc::error( $log, $dbh, $variable, 'No pricelist selected.', 'You must select a pricelist before importing.') if ! $id;
		return misc::error( $log, $dbh, $variable, 'No file given.', 'You must select a file to import.') if ! $r->param('filePrices');

		my $pricelist = new openprint::pricelist( $log, $dbh, $id );

# get the upload.
		my $upload = $r->upload('filePrices');
		my $io = $upload->io();
		$_ = <$io>;
		my $csv = Text::CSV_XS->new();

		my %products = sql::execute( undef, undef, q{SELECT name,id FROM Products} );
		my %equipment = map { $_->strid(), $_->id() } openprint::Equipment::find();

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
			return misc::error( $log, $dbh, $variable, 'Import errors.', $error );
		} # end if

	} # end if

	@$variable{'ID', 'Name','Description', 'Currency'} = @$Pricelist{'id','Name','Description','Currency'};

} # end sub edit

1;
__END__
