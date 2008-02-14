package openprint::administrator_paper;
use Text::CSV_XS;
use strict;
require sql;
require misc;
require openprint::paper;
require openprint::Paper;

require openprint::pricelist;
require openprint::paper_price;
require openprint::paper_priceset;

sub jsrs_actions {
	my ( $r, $log, $dbh, $variable, $action, $paper_id ) = splice @_, 0, 6;
	if ( $action eq 'Delete' ) {
		openprint::paper::delete( $log, $dbh, $paper_id );
	} elsif ( $action eq 'Copy' ) {
		my $Paper = new openprint::Paper( $paper_id );
		$Paper = $Paper->copy();
		$Paper->save( $r );
	} # end if
} # end sub jsrs_actions

sub list {
	my ( $r, $log, $dbh, $variable ) = @_;

	my @Papers;
	if ( $openprint::param{'chkPaper'} ) {
		@Papers = openprint::Paper::find( 'id'=>$openprint::param{'chkPaper'} );
	} # end if
		
	if ( $openprint::param{'btnFunction'} eq 'Delete' ) {
		foreach my $Paper ( @Papers ) {
			$Paper->delete();
		} # end foreach
	} elsif ( $openprint::param{'btnFunction'} eq 'Copy' ) {
		foreach my $Paper ( @Papers ) {
			$Paper = $Paper->copy();
			$Paper->save();
		} # end foreach
	} # end if
}

sub paper {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $Paper = new openprint::Paper( $openprint::param{'paper_id'} );
	if ( $openprint::param{'btnFunction'} eq 'Delete' ) {
		my $new = $Paper->next();
		$new = $Paper->previous() if $new == $Paper;
		$Paper->delete();
		$$variable{'information'} .= 'Paper ' . $Paper->id() . ' has been deleted.';
		$Paper = $new;
		$openprint::param{'paper_id'} = $Paper->id();
		
	} elsif ( $openprint::param{'btnFunction'} eq 'Copy' ) {
		$$variable{'information'} .= 'Paper ' . $Paper->id() . ' has been copied.';
		$Paper = $Paper->copy();
		$Paper->save();
		$openprint::param{'paper_id'} = $Paper->id();
	} elsif ( $openprint::param{'btnFunction'} eq 'Save' ) {
		$Paper->owner_id( $openprint::param{'ddmOwner'} );
		$Paper->manufacturer( $openprint::param{'txtManufacturer'} ) if $openprint::param{'txtManufacturer'};
		$Paper->manufacturer_id( $openprint::param{'ddmManufacturer'} ) if $openprint::param{'ddmManufacturer'};
		$Paper->name( $openprint::param{'txtName'} ) if $openprint::param{'txtName'};
		$Paper->name_id( $openprint::param{'ddmName'} ) if $openprint::param{'ddmName'};
		$Paper->finish( $openprint::param{'txtFinish'} ) if $openprint::param{'txtFinish'};
		$Paper->finish_id( $openprint::param{'ddmFinish'} ) if $openprint::param{'ddmFinish'};
		$Paper->colour( $openprint::param{'txtColour'} ) if $openprint::param{'txtColour'};
		$Paper->colour_id( $openprint::param{'ddmColour'} ) if $openprint::param{'ddmColour'};
		$Paper->weight( $openprint::param{'txtWeight'} ) if $openprint::param{'txtWeight'};
		$Paper->weight_id( $openprint::param{'ddmWeight'} ) if $openprint::param{'ddmWeight'};
		$Paper->quality( $openprint::param{'txtQuality'} ) if $openprint::param{'txtQuality'};
		$Paper->quality_id( $openprint::param{'ddmQuality'} ) if $openprint::param{'ddmQuality'};
		if ( $openprint::param{'ddmPaperSize'} ) {
			my ( $width, $height ) = split 'x', $openprint::param{'ddmPaperSize'};
			$Paper->width( $width );
			$Paper->height( $height );
		} else {
			$Paper->width( $openprint::param{'width'} );
			$Paper->height( $openprint::param{'height'} );
		} # end if
		$Paper->mweight( $openprint::param{'mweight'} );

		$Paper->basis_mweight( $openprint::param{'basis_mweight'} );
		$Paper->basis_width( $openprint::param{'basis_width'} );
		$Paper->basis_height( $openprint::param{'basis_height'} );

		$Paper->gsm( $openprint::param{'gsm'} );
		$Paper->calliper( $openprint::param{'calliper'} );
		$Paper->sheets_per_package( $openprint::param{'sheets_per_package'} );
		$Paper->cuttable( $openprint::param{'cuttable'} );
		$Paper->doublesided( $openprint::param{'doublesided'} );
		$Paper->multipart( $openprint::param{'multipart'} );
		$Paper->perfecting( $openprint::param{'perfecting'} );
		$Paper->score_required( $openprint::param{'scoring'} );
		$Paper->digital( $openprint::param{'digital'} );
		$Paper->bladecleaning( $openprint::param{'bladecleaning'} );
		$Paper->grade( $openprint::param{'grade'} );
		$Paper->type( $openprint::param{'type'} );
		$Paper->supplied( $openprint::param{'supplied'} );
		$Paper->grain_direction( $openprint::param{'grain_direction'} );
		$Paper->taxexempt1( $openprint::param{'taxexempt1'} );
		$Paper->taxexempt2( $openprint::param{'taxexempt2'} );
		$Paper->fsc_code( $openprint::param{'fsc_code'} );
		$Paper->inventory_number( $openprint::param{'inventory_number'} );
		$Paper->minimum_order( $openprint::param{'minimum_order'} );
		$Paper->full_packages( $openprint::param{'full_packages'} );

		my %types = sql::execute( undef, undef, q{SELECT strID, lngIndex FROM Project_Types} );
		@{$$Paper{'recommendations'}} = ();
		foreach my $type ( keys %types ) {
			push @{$$Paper{'recommendations'}}, $type if $openprint::param{'chkPRF'.$type};
		} # end foreach

# Save prices
		foreach my $key ( keys %openprint::param ) {
			if ( $key =~ /min-(\d*)/ ) {
				sql::update( $log, $dbh, 'Paper_Prices', "id=$1",
						'lngMin', $openprint::param{"min-$1"} ? int $openprint::param{"min-$1"} : undef,
						'lngMax', $openprint::param{"max-$1"} ? int $openprint::param{"max-$1"} : undef,
						'strunits', $openprint::param{"units-$1"},
						'dblcost', 1*$openprint::param{"cost-$1"},
						'dblmarkup', 1*$openprint::param{"markup-$1"},
						'dblprice', 1*$openprint::param{"price-$1"},
						'ysndiscountable', $openprint::param{"discount-$1"},
						);
			} # end if
		} # end foreach

		$$variable{'error'} .= $Paper->save();
		$$variable{'information'} .= 'Paper ' . $Paper->id() . ' has been saved.';
	} elsif ( $openprint::param{'btnFunction'} eq 'Prev' ) {
		$Paper = $Paper->previous();
		$openprint::param{'paper_id'} = $Paper->id();
	} elsif ( $openprint::param{'btnFunction'} eq 'Next' ) {
		$Paper = $Paper->next();
		$openprint::param{'paper_id'} = $Paper->id();
	} # end if

	$$variable{'Paper'} = $Paper;
	$$variable{'paper_id'} = $Paper->id();

} # end sub paper

sub jsrs_get_prices {
	my ( $r, $log, $dbh, $variable, $paper_index ) = @_;

	my $content = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/administrator/paper/_prices.html' );
	return ssi::variable_substitution( \$content, $variable ); 
} # end sub jsrs_get_prices

sub jsrs_del_price {
	my ( $r, $log, $dbh, $variable, $paper_index, $price_id ) = @_;
	sql::execute( $log, $dbh, "DELETE FROM Paper_Prices WHERE id=$price_id");
	$openprint::param{'paper_id'} = $paper_index;
	return jsrs_get_prices( $r, $log, $dbh, $variable, $paper_index );
}
sub jsrs_add_price {
	my ( $r, $log, $dbh, $variable, $paper_id, $pricelist_id ) = @_;

	my $PaperPrice = new openprint::PaperPrice( );
	$PaperPrice->paper_id( $paper_id );
	$PaperPrice->pricelist_id( $pricelist_id );
	$PaperPrice->save();

	$openprint::param{'paper_id'} = $paper_id;
	return jsrs_get_prices( $r, $log, $dbh, $variable, $paper_id );
} # end sub jsrs_add_price

sub jsrs_copy_price {
	my ( $r, $log, $dbh, $variable, $paper_id, $price_id ) = @_;

	my $PaperPrice = new openprint::PaperPrice( $price_id );
	my $NewPrice = $PaperPrice->copy();
	$NewPrice->save();

	$openprint::param{'paper_id'} = $paper_id;
	return jsrs_get_prices( $r, $log, $dbh, $variable, $paper_id );
} # end sub jsrs_get_price

sub jsrs_save_price {
	my ( $r, $log, $dbh, $variable, $id, $min, $max, $units, $cost, $markup, $price, $discount ) = @_;

	sql::update( $log, $dbh, 'Paper_Prices', "id=$id",
			'lngMin', $min ? int $min : undef,
			'lngMax', $max ? int $max : undef,
			'strunits', $units,
			'dblcost', 1*$cost,
			'dblmarkup', 1*$markup,
			'dblprice', 1*$price,
			'ysndiscountable', $discount,
			);

}

sub _prices {
	my ( $r, $log, $dbh, $variable ) = @_;

	foreach my $key ( keys %openprint::param ) {
		if ( $key =~ /min-(\d*)/ ) {
			my $Price = new openprint::PaperPrice( $1 );
			$Price->set( {
				'Min'	=>	$openprint::param{"min-$1"},
				'Max'	=>	$openprint::param{"max-$1"},
				'Units'	=>	$openprint::param{"units-$1"},
				'Cost'	=>	$openprint::param{"costcwt-$1"},
				'Markup'	=>	$openprint::param{"markup-$1"},
				'Price'	=>	$openprint::param{"pricecwt-$1"},
				'Discountable'	=>	$openprint::param{"discount-$1"},
} );
			$$variable{'error'} .= $Price->save();
			#jsrs_save_price( $r, $log, $dbh, $variable, $1, @openprint::param{"min-$1","max-$1","units-$1", "costcwt-$1", "markup-$1", "pricecwt-$1","discount-$1"} );
		} # end if
	} # end foreach
} # end sub jsrs_save_prices

sub import_export {
	my ( $r, $log, $dbh, $variable ) = @_;

	if ( $openprint::param{'btnFunction'} eq 'Export Paper' ) {
		my @header = ( 'ID', 'Owner','Manufacturer','Name', 'Finish', 'Colour', 'Weight', 'MWeight', 'gsm','Calliper', 'Type','Width', 'Height', 'Basis Width','Basis Height', 'Grain Direction','Supplier','DoubleSided?','Cuttable?','Multiple Parts?','Perfecting','Scoring Required?','Blade Cleaning Required?','Grade','Sheets Per Package','Supplied', 'Digital','Full Packages','Minimum Order','Inventory #','Recommendations');
		my @data;

		foreach my $Paper ( openprint::Paper::find( 'order'=>'name,finish,colour,weight,width,height' ) ) {
			push @data, $Paper->id(), $Paper->owner(), $Paper->manufacturer(), $Paper->name(), $Paper->finish(), $Paper->colour(), $Paper->weight(), $Paper->mweight(), $Paper->gsm(), $Paper->calliper(), $Paper->type(), $Paper->width(), $Paper->height(), $Paper->basis_width(), $Paper->basis_height(), $Paper->grain_direction(), '', $Paper->doublesided(), $Paper->cuttable(), $Paper->multipart(), $Paper->perfecting(), $Paper->score_required(), $Paper->bladecleaning(), $Paper->grade(), $Paper->sheets_per_package(), $Paper->supplied(), $Paper->digital(), $Paper->full_packages(), $Paper->minimum_order(), $Paper->inventory_number();
			push @data, join(',', $Paper->recommendations());
		} # end foreach
		misc::export_csv( $r, $log, $variable, 'paper.csv', \@header, \@data );

	} elsif ( $openprint::param{'btnFunction'} eq 'Import Paper' ) {

		my $error = '';
		if ( $openprint::param{'filePaper'} ne '' ) {
# get the upload.
			my $upload = $r->upload( 'filePaper' );
			my $io = $upload->io();
			$_ = <$io>;

			my $ac = sql::start_transaction( $openprint::dbh );
			my %project_types = sql::execute( $log, $dbh, 'SELECT strID, lngIndex FROM Project_Types' );
			my %owners = map { $_->name(), $_->id() } openprint::Company::find();
			my %papers = map { $_->id(), $_ } openprint::Paper::find();

			my $csv = Text::CSV_XS->new();
			while ( <$io> ) {
				my $status = $csv->parse($_);
				my ( $paper_id, $owner, $manufacturer, $name, $finish, $colour, $weight, $mweight, $gsm, $calliper, $type, $width, $height, $basis_width, $basis_height, $grain_direction, $supplier, $double_sided, $cuttable, $multipart, $perfecting, $scoring, $bladecleaning, $grade, $spp, $supplied, $digital, $full_packages, $minimum_order, $inventory_number, $recommendations ) = misc::trim($csv->fields());

				next if ! $paper_id;

				$mweight =~ s/[^\d\.]//g;
				$calliper =~ s/[^\d\.]//g;
				$width =~ s/[^\d\.]//g;
				$height =~ s/[^\d\.]//g;
				$gsm =~ s/[^\d]//g;
				$spp =~ s/[^\d]//g;

				my $Paper = $papers{$paper_id} ? $papers{$paper_id} : new openprint::Paper();
				$Paper->owner_id( $owners{$owner} ? $owners{$owner} : $openprint::session{'company_id'} );
				$Paper->manufacturer( $manufacturer );
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
				$Paper->recommendations( misc::trim(split(',', $recommendations)));
				my $rc = $Paper->save();	
				if ( $rc ) {
					$error .= "Error adding Paper: $rc<br>";
					next;
				} # end if
			} # end foreach
			sql::end_transaction( $openprint::dbh, $ac );
		} else {
			$error .= "No file given.<br>";
		} # end if
		if ( $error ) {
			return misc::error( $log, $dbh, $variable, 'The following errors occured during import:<br>', $error );
		} # end if
	} # end if

} # end sub import_export

sub inventory {
	my ( $r, $log, $dbh, $variable ) = @_;

	ssi::get_start_end_dates( $log, $dbh, $variable,
			$openprint::param{'ddmStartYear'},
			$openprint::param{'ddmStartMonth'},
			$openprint::param{'ddmStartDay'},
			$openprint::param{'ddmEndYear'},
			$openprint::param{'ddmEndMonth'},
			$openprint::param{'ddmEndDay'} );

} # end sub inventory

sub usage {
	my ( $r, $log, $dbh, $variable ) = @_;

	ssi::get_start_end_dates( $log, $dbh, $variable,
			$openprint::param{'ddmStartYear'},
			$openprint::param{'ddmStartMonth'},
			$openprint::param{'ddmStartDay'},
			$openprint::param{'ddmEndYear'},
			$openprint::param{'ddmEndMonth'},
			$openprint::param{'ddmEndDay'} );


	if ( $openprint::param{'ddmStockBrand'} ) {
		@{$$variable{'Brands'}} = ( $openprint::param{'ddmStockBrand'} );
	} else {
		@{$$variable{'Brands'}} = sql::execute( $log, $dbh, "SELECT DISTINCT Name FROM Paper ORDER BY name" );
	} # end if
	if ( $openprint::param{'ddmStockFinish'} ) {
		@{$$variable{'Finishes'}} = ( $openprint::param{'ddmStockFinish'} );
	} else {
		@{$$variable{'Finishes'}} = sql::execute( $log, $dbh, "SELECT DISTINCT Finish FROM Paper ORDER BY Finish" );
	} # end if
	if ( $openprint::param{'ddmStockColour'} ) {
		@{$$variable{'Colours'}} = ( $openprint::param{'ddmStockColour'} );
	} else {
		@{$$variable{'Colours'}} = sql::execute( $log, $dbh, "SELECT DISTINCT Colour FROM Paper ORDER BY Colour" );
	} # end if
	if ( $openprint::param{'ddmStockWeight'} ) {
		@{$$variable{'Weights'}} = ( $openprint::param{'ddmStockWeight'} );
	} else {
		@{$$variable{'Weights'}} = sql::execute( $log, $dbh, "SELECT DISTINCT calliper FROM Paper ORDER BY Calliper" );
	} # end if

	if ( $openprint::param{'ddmCustomer'} ) {
		$$variable{'ddmCustomer'} = "<option value=\"".$openprint::param{'ddmCustomer'}."\" selected></option>";
	} # end if


	my $query = "SELECT tbl_Projects.lngProjectIndex,lngDocketNumber, intQuantityIndex, (SELECT strName FROM Company WHERE Index=CompanyIndex) FROM tbl_Projects, Order_Contents WHERE tbl_Projects.Index=lngProjectIndex AND strStatus IN ( 'Ordered','Complete','Printed','Proofs Out','Approved','In Prepress' )\n";
	$query .= "AND due_date BETWEEN '$$variable{'StartDate'}' AND '$$variable{'EndDate'}' ";
	if ( $openprint::param{'ddmCustomer'} ) {
		$query .= "AND tbl_Projects.CompanyIndex = $openprint::param{'ddmCustomer'}\n";
	} # end if
	$query .= "ORDER BY due_date, tbl_Projects.Index";
	my @projects = sql::execute( $log, $dbh, $query );

	if ( 1 ) {
		while ( my ( $project_index, $docket_number, $qty_index, $company ) = splice @projects, 0, 4 ) {
			my $Project = new openprint::Project( $project_index );
			foreach my $signature_service_index ( $Project->signatures() ) {
				my $specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );
				if ( ! sets::isin( $$specs{'ddmStockBrand'}, @{$$variable{'Brands'}} ) ) {
					next;
				} # end if
				if ( ! sets::isin( $$specs{'ddmStockFinish'}, @{$$variable{'Finishes'}} ) ) {
					next;
				} # end if
				if ( ! sets::isin( $$specs{'ddmStockColour'}, @{$$variable{'Colours'}} ) ) {
					next;
				} # end if
				if ( ! sets::isin( $$specs{'ddmStockWeight'}, @{$$variable{'Weights'}} ) ) {
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
					my $price = openprint::paper::get_price( $log, $dbh, $variable, \%paper, @$specs{'ddmPress','hdnGrossSheetCount'.$qty_index} );
					push @{$$variable{'Results'.$$specs{'ddmStockBrand'}}}, $company,$project_index,$docket_number, @$specs{'hdnGrossSheetCount'.$qty_index,'UsedSheetQuantity'},
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
