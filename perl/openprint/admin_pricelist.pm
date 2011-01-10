package openprint::admin_pricelist;

use strict;
use Text::CSV_XS;

use strict;
require sql;
require openprint::pricing;
require openprint::Equipment;
require openprint::Material;
require openprint::Pricelist;
require openprint::Product;
require openprint::Paper;
require openprint::logs;

sub edit {
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
		$Pricelist->save( \%openprint::param );
	} elsif ( $r->param('btnFunction') eq 'Copy' ) {
		my $new = new openprint::Pricelist( );
		$openprint::param{'name'} = 'Copy of '.$openprint::param{'name'};
		$$variable{'error'} .= $new->save( \%openprint::param );
		if ( $$variable{'error'} ) {
			return;
		} # end if
		openprint::logs::insertLogRecord('32', "Price List: " . $openprint::param{'name'},);
		my $ac = sql::start_transaction( $dbh );
		my @prices = $Pricelist->getPrices();
		foreach my $price (@prices ) {
			$$price{'id'} = undef;
			$$price{'pricelist_id'} = $new->id();
			$$variable{'error'} .= $price->save();
		} # end foreach
		sql::end_transaction( $dbh, $ac );

		$Pricelist = $new;
	} elsif ( $r->param('btnFunction') eq 'Markup' ) {
		my $markup = $r->param('Markup');
		$markup =~ s/[^\+\-\.\d]//g;
		if ( $markup ne '' ) {
			my $ac = sql::start_transaction( $dbh );
			my @prices = $Pricelist->getPrices();
			foreach my $price (@prices ) {
				if ( $markup =~ /^[\+\-]/ ) {
					$price->markup( $price->markup() + $markup );
				} else {
					$price->markup( $markup );
				} # end if
				$price->price(undef);
				$$variable{'error'} .= $price->save();
			} # end foreach
			sql::end_transaction( $dbh, $ac );
		} # end if
	} elsif ( $r->param('btnFunction') eq 'Export Material Prices' ) {
		if ( $id eq '' ) {
			return misc::error( $log, $dbh, $variable, 'No pricelist selected.', 'You must select a pricelist before exporting.');
		} # end if
		my @header = ( 'Material ID', 'Equipment ID','Min', 'Max', 'Units', 'Cost', 'Markup', 'Price', 'Discountable' );
        $_ = "SELECT (SELECT name FROM Materials WHERE id = lngMaterialIndex) AS strID,\n".
				"(SELECT strID FROM tbl_Equipment WHERE Id = lngEquipmentIndex) AS EquipmentID,\n".
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
	
		my @header = ( 'Paper Brand', 'Finish','Colour','Weight','Width','Height','Service', 'Equipment', 'Min', 'Max', 'Units', 'Cost', 'Markup', 'Price', 'Discountable' );
		my @data;
		foreach my $Paper (openprint::Paper::find( 'order'=>'name,finish,colour,weight,width,height' ) ) {
			foreach my $Price ( $Paper->Prices('Pricelist'=>$Pricelist, 'order'=>'lngMin') ) {
				push @data, $Paper->name(), $Paper->finish(),$Paper->colour(), $Paper->weight(), $Paper->width(), $Paper->height();
				push @data, $Price->service(), $Price->Equipment()->strid(), $Price->min(), $Price->max(), $Price->units(), $Price->cost(), $Price->markup(), $Price->price(), $Price->discountable();
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
        $_ = "SELECT (SELECT name FROM Services WHERE id = service_id) AS strID,\n".
				"(SELECT strID FROM tbl_Equipment WHERE Id = equipment_id) AS EquipmentID,\n".
				"lngMin, lngMax, Units, Cost, Markup, Price, ysnDiscountable\n".
                "FROM Service_Prices\n".
                "WHERE pricelist_id = '$id'\n".
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
		sql::execute( $log, $dbh, "DELETE FROM Service_Prices WHERE pricelist_id=$id" );

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

} # end sub edit

1;

__END__

