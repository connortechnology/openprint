package openprint::administrator_stock;
use Text::CSV_XS;
use strict;
require sql;
require misc;
require openprint::paper;
require openprint::Paper;

require openprint::pricelist;
require openprint::paper_price;
require openprint::paper_priceset;

use openprint;
use vars qw( %variable %session %param %config $log $dbh $r );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*r = \$openprint::r;

sub _stocks {
} # end sub _stocks

sub list {
	my @Papers;
	if ( $param{'chkStock'} ) {
		@Papers = openprint::Paper::find( 'id'=>$param{'chkStock'} );
	} elsif ( $param{'stock_ids'} ) {
		@Papers = openprint::Paper::find( 'id'=> (ref $param{'stock_ids'} eq 'ARRAY' ? $param{'stock_ids'} : [split(',', $param{'stock_ids'} )] ) );
	} # end if
		
	if ( $param{'btnFunction'} eq 'Delete' ) {
		foreach my $Paper ( @Papers ) {
			$Paper->delete();
		} # end foreach
	} elsif ( $param{'btnFunction'} eq 'Copy' ) {
		foreach my $Paper ( @Papers ) {
			$Paper = $Paper->copy();
			$Paper->save();
		} # end foreach
	} elsif ( $param{'btnFunction'} eq 'ApplyChanges' ) {
		foreach my $Paper ( @Papers ) {
			my $ac = sql::start_transaction( $dbh );
			if ( $param{'mode'} eq 'modify' ) {
				foreach my $Price ( $Paper->prices() ) {
					if ( $param{'amount'} ne '' ) {
						if ( $param{'amount'} =~ /^\+(.*)/ ) {
							$Price->Cost( $Price->Cost() + $1 );
						} elsif ( $param{'amount'} =~ /^\-(.*)/ ) {
							$Price->Cost( $Price->Cost() - $1 );
						} else {
$openprint::log->debug("Setting: $param{'amount'} " );
							$Price->Cost( $param{'amount'} );
						} # end if
					} elsif ( $param{'markup'} ne '' ) {
						if ( $param{'markup'} =~ /^\+(.*)/ ) {
							$Price->Markup( $Price->Markup() + $1 );
						} elsif ( $param{'markup'} =~ /^\-(.*)/ ) {
							$Price->Markup( $Price->Markup() - $1 );
						} else {
							$Price->Markup( $param{'markup'} );
						} # end if
					} # end if
					$Price->Price( $Price->Cost() * ( 1+($Price->Markup()/100) ) );
					$variable{'error'} .= $Price->save();
				} # end foreach Price
			} elsif ( $param{'mode'} eq 'new' ) {
				foreach my $Price ( $Paper->prices() ) {
					$Price->delete();
				} # end foreach Price
				foreach my $key ( keys %param ) {
					if ( my ( $pricelist_id, $id ) = $key =~ /min-(\d*)-(\d*)/ ) {
						next if ! $param{"pricecwt-$pricelist_id-$id"};

						my $Price = new openprint::PaperPrice( );
						$variable{'error'} .= $Price->save( {
								'pricelist_id'	=>	$pricelist_id,
								'paper_id'	=> $Paper->id(),
								'Min'	=>	$param{"min-$pricelist_id-$id"},
								'Max'	=>	$param{"max-$pricelist_id-$id"},
								'Units'	=>	$param{"units-$pricelist_id-$id"},
								'Cost'	=>	$param{"costcwt-$pricelist_id-$id"},
								'Markup'	=>	$param{"markup-$pricelist_id-$id"},
								'Price'	=>	$param{"pricecwt-$pricelist_id-$id"},
								'Discountable'	=>	$param{"discount-$pricelist_id-$id"},
								} );
						
						# Force reload
						delete $$Paper{'Prices'};
					} # end if
				} # end foreach param key
			} # end if
			sql::end_transaction( $dbh, $ac );
		} # end foreach Paper
	} # end if
} # end sub list

sub stock {

	my $Paper = new openprint::Paper( $param{'stock_id'} );
	if ( $param{'btnFunction'} eq 'Delete' ) {
		my $new = $Paper->next();
		$new = $Paper->previous() if $new == $Paper;
		$Paper->delete();
		$variable{'information'} .= 'Stock ' . $Paper->id() . ' has been deleted.';
		$Paper = $new;
		$param{'stock_id'} = $Paper->id();
		
	} elsif ( $param{'btnFunction'} eq 'Copy' ) {
		$variable{'information'} .= 'Stock ' . $Paper->id() . ' has been copied.';
		$Paper = $Paper->copy();
		$Paper->save();
		$param{'stock_id'} = $Paper->id();
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		$Paper->owner_id( $param{'ddmOwner'} );
		$Paper->manufacturer( $param{'txtManufacturer'} ) if $param{'txtManufacturer'};
		$Paper->manufacturer_id( $param{'ddmManufacturer'} ) if $param{'ddmManufacturer'};
		$Paper->group( $param{'txtGroup'} ) if $param{'txtGroup'};
		$Paper->group_id( $param{'Group'} ) if $param{'Group'};
		$Paper->name( $param{'txtName'} ) if $param{'txtName'};
		$Paper->name_id( $param{'ddmName'} ) if $param{'ddmName'};
		$Paper->finish( $param{'txtFinish'} ) if $param{'txtFinish'};
		$Paper->finish_id( $param{'ddmFinish'} ) if $param{'ddmFinish'};
		$Paper->colour( $param{'txtColour'} ) if $param{'txtColour'};
		$Paper->colour_id( $param{'ddmColour'} ) if $param{'ddmColour'};
		$Paper->weight( $param{'txtWeight'} ) if $param{'txtWeight'};
		$Paper->weight_id( $param{'ddmWeight'} ) if $param{'ddmWeight'};
		$Paper->quality( $param{'txtQuality'} ) if $param{'txtQuality'};
		$Paper->quality_id( $param{'ddmQuality'} ) if $param{'ddmQuality'};
		$Paper->material( $param{'material'} );
		$Paper->material_id( $param{'material_id'} ) if $param{'material_id'};
		if ( $param{'ddmPaperSize'} ) {
			my ( $width, $height ) = split 'x', $param{'ddmPaperSize'};
			$Paper->width( $width );
			$Paper->height( $height );
		} else {
			$Paper->width( $param{'width'} );
			$Paper->height( $param{'height'} );
		} # end if
		$Paper->mweight( $param{'mweight'} );

		$Paper->basis_mweight( $param{'basis_mweight'} );
		$Paper->basis_width( $param{'basis_width'} );
		$Paper->basis_height( $param{'basis_height'} );

		$Paper->gsm( $param{'gsm'} );
		$Paper->calliper( $param{'calliper'} );
		$Paper->sheets_per_package( $param{'sheets_per_package'} );
		$Paper->full_packages( $param{'full_packages'} );
		$Paper->minimum_order( $param{'minimum_order'} );
		$Paper->cuttable( $param{'cuttable'} );
		$Paper->doublesided( $param{'doublesided'} );
		$Paper->multipart( $param{'multipart'} );
		$Paper->perfecting( $param{'perfecting'} );
		$Paper->score_required( $param{'scoring'} );
		$Paper->req_die_scoring( $param{'diescoring'} );
		$Paper->digital( $param{'digital'} );
		$Paper->bladecleaning( $param{'bladecleaning'} );
		$Paper->grade( $param{'grade'} );
		$Paper->type( $param{'type'} );
		$Paper->supplied( $param{'supplied'} );
		$Paper->grain_direction( $param{'grain_direction'} );
		$Paper->taxexempt1( $param{'taxexempt1'} );
		$Paper->taxexempt2( $param{'taxexempt2'} );
		$Paper->fsc_code( $param{'fsc_code'} );
		$Paper->inventory_number( $param{'inventory_number'} );
		$Paper->minimum_order( $param{'minimum_order'} );
		$Paper->full_packages( $param{'full_packages'} );
		$Paper->message( $param{'message'} );

		@{$$Paper{'recommendations'}} = ();
		foreach my $Type ( openprint::ProjectType::find() ) {
			push @{$$Paper{'recommendations'}}, $Type->id() if $param{'chkPRF'.$Type->id()};
		} # end foreach

# Save prices
		foreach my $key ( keys %param ) {
			if ( $key =~ /min-(\d*)/ ) {
				my $Price = new openprint::PaperPrice( $1 );
				$variable{'error'} .= $Price->save({
						'Min'			=> $param{"min-$1"},
						'Max'			=> $param{"max-$1"},
						'Units'			=> $param{"units-$1"},
						'Cost'			=> $param{"cost-$1"},
						'Markup'		=> $param{"markup-$1"},
						'Price'			=> $param{"price-$1"},
						'Discountable'	=> $param{"discount-$1"},
						});
			} # end if
		} # end foreach

		$variable{'error'} .= $Paper->save();
		$variable{'information'} .= 'Stock ' . $Paper->id() . ' has been saved.' if ! $variable{'error'};
	} elsif ( $param{'btnFunction'} eq 'Prev' ) {
		$Paper = $Paper->previous();
		$param{'stock_id'} = $Paper->id();
	} elsif ( $param{'btnFunction'} eq 'Next' ) {
		$Paper = $Paper->next();
		$param{'stock_id'} = $Paper->id();
	} # end if

	$variable{'Stock'} = $Paper;
	$variable{'stock_id'} = $Paper->id();

} # end sub stock

sub _prices {
	if ( $param{'action'} eq 'Delete' ) {
		sql::execute( $log, $dbh, 'DELETE FROM Paper_Prices WHERE id=?', $param{'price_id'} );
	} elsif ( $param{'action'} eq 'Add' ) {
		my $PaperPrice = new openprint::PaperPrice( );
		$PaperPrice->paper_id( $param{'stock_id'} );
		$PaperPrice->pricelist_id( $param{'pricelist_id'} );
		$PaperPrice->save();
	} elsif ( $param{'action'} eq 'Copy' ) {
		my $PaperPrice = new openprint::PaperPrice( $param{'price_id'} );
		my $NewPrice = $PaperPrice->copy();
		$NewPrice->save();
	} else { #save
		foreach my $key ( keys %param ) {
			if ( $key =~ /min-(\d*)/ ) {
				my $Price = new openprint::PaperPrice( $1 );
				$variable{'error'} .= $Price->save( {
					'Min'	=>	$param{"min-$1"},
					'Max'	=>	$param{"max-$1"},
					'Units'	=>	$param{"units-$1"},
					'Cost'	=>	$param{"costcwt-$1"},
					'Markup'	=>	$param{"markup-$1"},
					'Price'	=>	$param{"pricecwt-$1"},
					'Discountable'	=>	$param{"discount-$1"},
	} );
			} # end if
		} # end foreach
	} # end if
} # end sub _prices

sub import_export {

	if ( $param{'btnFunction'} eq 'Export Stock' ) {
		my @header = ( 'ID', 'Owner','Manufacturer','Group','Name', 'Finish', 'Colour', 'Weight', 'MWeight', 'gsm','Calliper', 'Type','Width', 'Height', 'Basis Width','Basis Height', 'Grain Direction','Supplier','DoubleSided?','Cuttable?','Multiple Parts?','Perfecting','Scoring Required?','Blade Cleaning Required?','Grade','Sheets Per Package','Supplied', 'Digital','Full Packages','Minimum Order','Inventory #','Material Type','Message', 'Recommendations');
		my @data;

		foreach my $Paper ( openprint::Paper::find( 'order'=>'name,finish,colour,weight,width,height' ) ) {
			push @data, $Paper->id(), $Paper->owner(), $Paper->manufacturer(), $Paper->group(), $Paper->name(), $Paper->finish(), $Paper->colour(), $Paper->weight(), $Paper->mweight(), $Paper->gsm(), $Paper->calliper(), $Paper->type(), $Paper->width(), $Paper->height(), $Paper->basis_width(), $Paper->basis_height(), $Paper->grain_direction(), '', $Paper->doublesided(), $Paper->cuttable(), $Paper->multipart(), $Paper->perfecting(), $Paper->score_required(), $Paper->bladecleaning(), $Paper->grade(), $Paper->sheets_per_package(), $Paper->supplied(), $Paper->digital(), $Paper->full_packages(), $Paper->minimum_order(), $Paper->inventory_number(), $Paper->material(), $Paper->message();
			push @data, join(',', $Paper->recommendations());
		} # end foreach
		misc::export_csv( $r, $log, \%variable, 'stock.csv', \@header, \@data );

	} elsif ( $param{'btnFunction'} eq 'Import Stock' ) {

		my $error = '';
		if ( $param{'fileStock'} ne '' ) {
# get the upload.
			my $upload = $r->upload( 'fileStock' );
			my $io = $upload->io();
			$_ = <$io>;

			my $ac = sql::start_transaction( $dbh );
			my %project_types = map { $_->name(), $_->id() } openprint::ProjectType::find();
			my %owners = map { $_->name(), $_->id() } openprint::Company::find();
			my %papers = map { $_->id(), $_ } openprint::Paper::find();

			my $csv = Text::CSV_XS->new();
			while ( <$io> ) {
				my $status = $csv->parse($_);
				my ( $paper_id, $owner, $manufacturer, $group, $name, $finish, $colour, $weight, $mweight, $gsm, $calliper, $type, $width, $height, $basis_width, $basis_height, $grain_direction, $supplier, $double_sided, $cuttable, $multipart, $perfecting, $scoring, $bladecleaning, $grade, $spp, $supplied, $digital, $full_packages, $minimum_order, $inventory_number, $material, $message, $recommendations ) = misc::trim($csv->fields());

				next if ! $paper_id;

				$mweight =~ s/[^\d\.]//g;
				$calliper =~ s/[^\d\.]//g;
				$width =~ s/[^\d\.]//g;
				$height =~ s/[^\d\.]//g;
				$gsm =~ s/[^\d\.]//g;
				$spp =~ s/[^\d]//g;

				my $Paper = $papers{$paper_id} ? $papers{$paper_id} : new openprint::Paper();
				$Paper->owner_id( $owners{$owner} ? $owners{$owner} : $session{'company_id'} );
				$Paper->manufacturer( $manufacturer );
				$Paper->name( $group );
				$Paper->name( $name );
				$Paper->finish( $finish );
				$Paper->colour( $colour );
				$Paper->weight( $weight );
				$Paper->mweight( $mweight );
				$Paper->gsm( $gsm );
				$Paper->calliper( $calliper );
				$Paper->type( $type );
				$Paper->width( $width );
				$Paper->height( $height );
				$Paper->basis_width( $basis_width );
				$Paper->basis_height( $basis_height );
				$Paper->grain_direction( $grain_direction );
				$Paper->perfecting( $perfecting );
				$Paper->score_required( $scoring );
				$Paper->cuttable( $cuttable );
				$Paper->doublesided( $double_sided );
				$Paper->multipart( $multipart );
				$Paper->bladecleaning( $scoring );
				$Paper->grade( $scoring );
				$Paper->supplied( $supplied );
				$Paper->digital( $digital );
				$Paper->full_packages( $full_packages );
				$Paper->minimum_order( $minimum_order );
				$Paper->inventory_number( $inventory_number );
				$Paper->material( $material );
				$Paper->message( $message );
				$Paper->recommendations( misc::trim(split(',', $recommendations)));
				my $rc = $Paper->save();	
				if ( $rc ) {
					$error .= "Error adding Stock: $rc<br>";
					next;
				} # end if
			} # end foreach
			sql::end_transaction( $dbh, $ac );
		} else {
			$error .= "No file given.<br>";
		} # end if
		if ( $error ) {
			return misc::error( $log, $dbh, \%variable, 'The following errors occured during import:<br>', $error );
		} # end if
	} # end if

} # end sub import_export

sub inventory {

	ssi::get_start_end_dates( $log, $dbh, \%variable,
			$param{'ddmStartYear'},
			$param{'ddmStartMonth'},
			$param{'ddmStartDay'},
			$param{'ddmEndYear'},
			$param{'ddmEndMonth'},
			$param{'ddmEndDay'} );

} # end sub inventory

sub usage {

	ssi::get_start_end_dates( $log, $dbh, \%variable,
			$param{'ddmStartYear'},
			$param{'ddmStartMonth'},
			$param{'ddmStartDay'},
			$param{'ddmEndYear'},
			$param{'ddmEndMonth'},
			$param{'ddmEndDay'} );


	if ( $param{'ddmStockGroup'} ) {
		@{$variable{'Groups'}} = ( $param{'ddmStockGroup'} );
	} else {
		@{$variable{'Groups'}} = sql::execute( $log, $dbh, "SELECT DISTINCT Name FROM Paper ORDER BY name" );
	} # end if
	if ( $param{'ddmStockBrand'} ) {
		@{$variable{'Brands'}} = ( $param{'ddmStockBrand'} );
	} else {
		@{$variable{'Brands'}} = sql::execute( $log, $dbh, "SELECT DISTINCT Name FROM Paper ORDER BY name" );
	} # end if
	if ( $param{'ddmStockFinish'} ) {
		@{$variable{'Finishes'}} = ( $param{'ddmStockFinish'} );
	} else {
		@{$variable{'Finishes'}} = sql::execute( $log, $dbh, "SELECT DISTINCT Finish FROM Paper ORDER BY Finish" );
	} # end if
	if ( $param{'ddmStockColour'} ) {
		@{$variable{'Colours'}} = ( $param{'ddmStockColour'} );
	} else {
		@{$variable{'Colours'}} = sql::execute( $log, $dbh, "SELECT DISTINCT Colour FROM Paper ORDER BY Colour" );
	} # end if
	if ( $param{'ddmStockWeight'} ) {
		@{$variable{'Weights'}} = ( $param{'ddmStockWeight'} );
	} else {
		@{$variable{'Weights'}} = sql::execute( $log, $dbh, "SELECT DISTINCT calliper FROM Paper ORDER BY Calliper" );
	} # end if

	if ( $param{'ddmCustomer'} ) {
		$variable{'ddmCustomer'} = "<option value=\"".$param{'ddmCustomer'}."\" selected></option>";
	} # end if


	my $query = "SELECT Projects.lngProjectIndex,lngDocketNumber, intQuantityIndex, (SELECT strName FROM Company WHERE Index=CompanyIndex) FROM Projects, Order_Contents WHERE Projects.Index=lngProjectIndex AND strStatus IN ( 'Ordered','Complete','Printed','Proofs Out','Approved','In Prepress' )\n";
	$query .= "AND due_date BETWEEN '$variable{'StartDate'}' AND '$variable{'EndDate'}' ";
	if ( $param{'ddmCustomer'} ) {
		$query .= "AND Projects.CompanyIndex = $param{'ddmCustomer'}\n";
	} # end if
	$query .= "ORDER BY due_date, Projects.Index";
	my @projects = sql::execute( $log, $dbh, $query );

	if ( 1 ) {
		while ( my ( $project_index, $docket_number, $qty_index, $company ) = splice @projects, 0, 4 ) {
			my $Project = new openprint::Project( $project_index );
			foreach my $signature_service_index ( $Project->signatures() ) {
				my $specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );
				if ( ! sets::isin( $$specs{'ddmStockBrand'}, @{$variable{'Brands'}} ) ) {
					next;
				} # end if
				if ( ! sets::isin( $$specs{'ddmStockFinish'}, @{$variable{'Finishes'}} ) ) {
					next;
				} # end if
				if ( ! sets::isin( $$specs{'ddmStockColour'}, @{$variable{'Colours'}} ) ) {
					next;
				} # end if
				if ( ! sets::isin( $$specs{'ddmStockWeight'}, @{$variable{'Weights'}} ) ) {
					next;
				} # end if
				my %paper;
				@paper{'index','mweight'} = sql::execute( $log, $dbh, "SELECT lngIndex,MWeight FROM Paper\n"
						. "WHERE name='$$specs{'ddmStockBrand'}'\n"
						. "AND finish='$$specs{'ddmStockFinish'}'\n"
						. "AND colour='$$specs{'ddmStockColour'}'\n"
						. "AND calliper=$$specs{'ddmStockWeight'}\n"
						. "AND width=$$specs{'hdnSheetSizeWidth'}\n"
						. "AND height=$$specs{'hdnSheetSizeHeight'}\n"
						);
				if ( $paper{'index'} ) {
					my $price = openprint::paper::get_price( $log, $dbh, \%variable, \%paper, @$specs{'ddmPress','hdnGrossSheetCount'.$qty_index} );
					push @{$variable{'Results'.$$specs{'ddmStockBrand'}}}, $company,$project_index,$docket_number, @$specs{'hdnGrossSheetCount'.$qty_index,'UsedSheetQuantity'},
						 sprintf( '$%.2f', $$specs{'hdnGrossSheetCount'.$qty_index}*$$price{'Price'} ),
						 sprintf( '$%.2f', $$specs{'UsedSheetQuantity'}*$$price{'Price'} );
				} # end if
			} # end foreach
		} # end while
	}

} # end sub usage

1;

__END__
~       
