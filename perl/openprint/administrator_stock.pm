use strict;
package openprint::administrator_stock;
use Text::CSV_XS ();
require sql;
require misc;
require openprint::Paper;

require openprint::pricelist;
require openprint::paper_price;
require openprint::paper_priceset;
require openprint::StockBrand;
require openprint::StockFinish;
require openprint::StockColour;
require openprint::StockWeight;
require openprint::Manufacturer;
require openprint::PaperPrice;
require openprint::Supplier;

use openprint ();
use vars qw( %variable %session %param %config $log $dbh $r );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*r = \$openprint::r;

sub _stocks {
	if ( %param and ! $param{'btnFunction'} ) {
		ssi::save_params('/administrator/stock/list.html', 'group_id','owner_id','manufacturer_id','supplier_id', 'brand_id','finish_id','colour_id','weight_id','fsc_code','material_id', 'Types', 'recommendations','grain_direction', 'digital', 'width','height' );
		$session{'/administrator/stock/list.html?OrLarger'} = $param{OrLarger};
	} # end if
} # end sub _stocks

sub list {
	my @Papers;
	if ( $param{'chkStock'} ) {
		@Papers = openprint::Paper->find( id=>$param{'chkStock'} );
	} elsif ( $param{'stock_ids'} ) {
		@Papers = openprint::Paper->find( id=> (ref $param{'stock_ids'} eq 'ARRAY' ? $param{'stock_ids'} : [split(',', $param{'stock_ids'} )] ) );
	} # end if
		
	if ( $param{'btnFunction'} eq 'Delete' ) {
		foreach my $Paper ( @Papers ) {
			$Paper->delete();
		} # end foreach
	} elsif ( $param{'btnFunction'} eq 'Export' ) {
		my @header = ( 'ID', 'Owner','Manufacturer','Supplier','Group','Brand', 'Finish', 'Colour', 'Weight', 'Quality', 'MWeight', 'gsm','Calliper', 'Type','Width', 'Height', 'Basis Width','Basis Height', 'Grain Direction','Supplier','DoubleSided?','Cuttable?','Multiple Parts?','Perfecting','Scoring Required?','Blade Cleaning Required?','Grade','Sheets Per Package','Supplied', 'Digital','Full Packages','Minimum Order','Inventory #','Material Type','Message', 'Recommendations');
		my @data;

		foreach my $Stock ( openprint::Paper->find( order=>'brand,finish,colour,weight,width,height', 
					columns=>'*,(SELECT name FROM StockBrands WHERE Stockbrands.id=brand_id) AS brand,(SELECT name FROM StockFinishes WHERE StockFinishes.id=finish_id) AS finish,(SELECT name FROM StockColours WHERE StockColours.id=colour_id) AS colour,(SELECT name FROM StockWeights WHERE StockWeights.id=weight_id) AS weight ',
					( $param{group_id} ? ( group_id => $param{group_id} ) : () ),
					( $param{owner_id} ? ( owner_id => $param{owner_id} ) : () ),
					( $param{manufacturer_id} ? ( manufacturer_id => $param{manufacturer_id} ) : () ),
					( $param{supplier_id} ? ( suopplier_id => $param{supplier_id} ) : () ),
					( $param{brand_id} ? ( 'brand_id'    => $param{brand_id} ) : () ),
					( $param{finish_id} ? ( 'finish_id'  => $param{'finish_id'} ) : () ),
					( $param{colour_id} ? ( 'colour_id'  => $param{'colour_id'} ) : () ),
					( $param{weight_id} ? ( 'weight_id'  => $param{'weight_id'} ) : () ),
					( $param{quality_id} ? ( 'quality_id'        => $param{'quality_id'} ) : () ),
					( $param{material_id} ? ( 'material_id'      => $param{'material_id'} ) : () ),
					( $param{Types} ? ( 'type'           => $param{'Types'} ) : () ),
					( $param{fsc_code} ? ( 'fsc_code'    => $param{'fsc_code'} ) : () ),
					( $param{width} ? ( 'width'=>$param{width} ) : () ),
					( $param{height} ? ( 'height'=>$param{'height'} ) : () ),
					( $param{grain_direction} ? ( grain_direction => $param{grain_direction} ) : () ),
					( $param{digital} ne '' ? ( digital=>$param{digital} ) : () ),
					'order'         => 'brand,finish,colour,weight, width, height'
					) ) {
			next if $param{recommendations} eq '0' and $Stock->recommendations();
			next if $param{recommendations} eq '1' and ! $Stock->recommendations();
			if ( $param{setup_prices} eq '1' ) {
				next if ! openprint::PaperPrice->find_one(paper_id=>$$Stock{id}, service=>'Setup');
			} elsif ( $param{setup_prices} eq '0' ) {
				next if openprint::PaperPrice->find_one(paper_id=>$$Stock{id}, service=>'Setup');
			} # end if
			push @data, $Stock->id(), $Stock->owner(), $Stock->manufacturer(), $Stock->Supplier()->name(), $Stock->group(), $Stock->brand(), $Stock->finish(), $Stock->colour(), $Stock->weight(), $Stock->quality(), 
				 $Stock->mweight(), $Stock->gsm(), $Stock->calliper(), $Stock->type(), $Stock->width(), $Stock->height(), $Stock->basis_width(), $Stock->basis_height(), $Stock->grain_direction(), '', $Stock->doublesided(), $Stock->cuttable(), $Stock->multipart(), $Stock->perfecting(), $Stock->score_required(), $Stock->bladecleaning(), $openprint::Paper::grades{$Stock->grade()}, $Stock->sheets_per_package(), $Stock->supplied(), $Stock->digital(), $Stock->full_packages(), $Stock->minimum_order(), $Stock->inventory_number(), $Stock->material(), $Stock->message();
			push @data, join(',', map { new openprint::ProjectType($_)->name() } $Stock->recommendations());
		} # end foreach
		misc::export_csv( $r, $log, \%variable, 'stock.csv', \@header, \@data );

	} elsif ( $param{'btnFunction'} eq 'Export Prices' ) {
		my @header = ( 'Paper Brand', 'Finish','Colour','Weight','Width','Height','Pricelist', 'Service', 'Equipment', 'Min', 'Max', 'Units', 'Cost', 'Markup', 'Price', 'Discountable' );
		my @data;
		foreach my $Stock ( openprint::Paper->find( order=>'brand,finish,colour,weight,width,height',
                    columns=>'*,(SELECT name FROM StockBrands WHERE Stockbrands.id=brand_id) AS brand,(SELECT name FROM StockFinishes WHERE StockFinishes.id=finish_id) AS finish,(SELECT name FROM StockColours WHERE StockColours.id=colour_id) AS colour,(SELECT name FROM StockWeights WHERE StockWeights.id=weight_id) AS weight ',
                    ( $param{group_id} ? ( group_id => $param{group_id} ) : () ),
                    ( $param{owner_id} ? ( owner_id => $param{owner_id} ) : () ),
                    ( $param{manufacturer_id} ? ( manufacturer_id => $param{manufacturer_id} ) : () ),
                    ( $param{supplier_id} ? ( supplier_id => $param{supplier_id} ) : () ),
                    ( $param{brand_id} ? ( 'brand_id'    => $param{brand_id} ) : () ),
                    ( $param{finish_id} ? ( 'finish_id'  => $param{'finish_id'} ) : () ),
                    ( $param{colour_id} ? ( 'colour_id'  => $param{'colour_id'} ) : () ),
                    ( $param{weight_id} ? ( 'weight_id'  => $param{'weight_id'} ) : () ),
                    ( $param{quality_id} ? ( 'quality_id'        => $param{'quality_id'} ) : () ),
                    ( $param{material_id} ? ( 'material_id'      => $param{'material_id'} ) : () ),
                    ( $param{Types} ? ( 'type'           => $param{'Types'} ) : () ),
                    ( $param{fsc_code} ? ( 'fsc_code'    => $param{'fsc_code'} ) : () ),
                    ( $param{width} ? ( 'width'=>$param{width} ) : () ),
                    ( $param{height} ? ( 'height'=>$param{'height'} ) : () ),
                    ( $param{grain_direction} ? ( grain_direction => $param{grain_direction} ) : () ),
                    ( $param{digital} ne '' ? ( digital=>$param{digital} ) : () ),
                    'order'         => 'brand,finish,colour,weight, width, height'
                    ) ) {
            next if $param{recommendations} eq '0' and $Stock->recommendations();
            next if $param{recommendations} eq '1' and ! $Stock->recommendations();
            if ( $param{setup_prices} eq '1' ) {
                next if ! openprint::PaperPrice->find_one(paper_id=>$$Stock{id}, service=>'Setup');
            } elsif ( $param{setup_prices} eq '0' ) {
                next if openprint::PaperPrice->find_one(paper_id=>$$Stock{id}, service=>'Setup');
            } # end if

            foreach my $Price ( openprint::PaperPrice->find( paper_id=>$$Stock{id}, order=>'lnglistindex, lngmin NULLS FIRST, lngmax NULLS FIRST') ) {
                push @data, $Stock->brand(), $Stock->finish(),$Stock->colour(), $Stock->weight(), $Stock->width(), $Stock->height();
                push @data, $Price->Pricelist()->name(), $Price->service(), $Price->Equipment()->strid(), $Price->min(), $Price->max(), $Price->units(), $Price->cost(), $Price->markup(), $Price->price(), $Price->discountable();
            } # end foreach
        } # end foreach Paper
        misc::export_csv( $r, $log, \%variable, 'PaperPrices.csv', \@header, \@data );

	} elsif ( $param{'btnFunction'} eq 'Copy' ) {
		foreach my $Paper ( @Papers ) {
			my $NewPaper = $Paper->copy();
			$NewPaper->save();
			foreach my $Setting ( openprint::Equipment_Stock_Setting->find('stock_id'=>$Paper->id()) ) {
				$Setting = $Setting->copy();
				$Setting->save({'stock_id'=>$NewPaper->id()});
			} # end foreach
		} # end foreach
	} elsif ( $param{'btnFunction'} eq 'ApplyChanges' ) {
		foreach my $Paper ( @Papers ) {
			my $ac = sql::start_transaction( $dbh );
			if ( $param{'mode'} eq 'modify' ) {
				foreach my $Price ( $Paper->Prices() ) {
					if ( $param{'amount'} ne '' ) {
						if ( $param{'amount'} =~ /^\+(.*)/ ) {
							$Price->cost( $Price->cost() + $1 );
						} elsif ( $param{'amount'} =~ /^\-(.*)/ ) {
							$Price->cost( $Price->cost() - $1 );
						} else {
$openprint::log->debug("Setting: $param{'amount'} " );
							$Price->cost( $param{'amount'} );
						} # end if
					} elsif ( $param{'markup'} ne '' ) {
						if ( $param{'markup'} =~ /^\+(.*)/ ) {
							$Price->markup( $Price->markup() + $1 );
						} elsif ( $param{'markup'} =~ /^\-(.*)/ ) {
							$Price->markup( $Price->markup() - $1 );
						} else {
							$Price->markup( $param{'markup'} );
						} # end if
					} # end if
					$Price->price( $Price->cost() * ( 1+($Price->markup()/100) ) );
					$variable{'error'} .= $Price->save();
				} # end foreach Price
			} elsif ( $param{'mode'} eq 'new' ) {
				foreach my $Price ( $Paper->Prices() ) {
					$Price->delete();
				} # end foreach Price
				foreach my $key ( keys %param ) {
					if ( my ( $pricelist_id, $id ) = $key =~ /min-(\d*)-(\d*)/ ) {
						next if ! $param{"pricecwt-$pricelist_id-$id"};

						my $Price = new openprint::PaperPrice( );
						$variable{'error'} .= $Price->save( {
								'pricelist_id'	=>	$pricelist_id,
								'paper_id'	=> $Paper->id(),
								'min'	=>	$param{"min-$pricelist_id-$id"},
								'max'	=>	$param{"max-$pricelist_id-$id"},
								'units'	=>	$param{"units-$pricelist_id-$id"},
								'cost'	=>	$param{"cost-$pricelist_id-$id"},
								'markup'	=>	$param{"markup-$pricelist_id-$id"},
								'price'	=>	$param{"price-$pricelist_id-$id"},
								'discountable'	=>	$param{"discount-$pricelist_id-$id"},
								} );
						
						# Force reload
						delete $$Paper{'Prices'};
					} # end if
				} # end foreach param key
			} # end if
			sql::end_transaction( $dbh, $ac );
		} # end foreach Paper
	} elsif ( $param{btnFunction} ) {
		$log->error("Unknown function $param{btnFunction}");
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
		my $NewPaper = $Paper->copy();
		$NewPaper->save();
		foreach my $Setting ( openprint::Equipment_Stock_Setting->find('stock_id'=>$Paper->id()) ) {
			$Setting = $Setting->copy();
			$Setting->save({'stock_id'=>$NewPaper->id()});
		} # end foreach
		$Paper = $NewPaper;
		$param{'stock_id'} = $Paper->id();
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		$Paper->owner_id( $param{'ddmOwner'} );
		$Paper->manufacturer( $param{'txtManufacturer'} ) if $param{'txtManufacturer'};
		$Paper->manufacturer_id( $param{'ddmManufacturer'} ) if ! $param{'txtManufacturer'};
		$param{ddmSupplier} = openprint::Supplier::get_or_create( $param{txtSupplier} ) if $param{txtSupplier} and ! $param{ddmSupplier};
		$Paper->supplier_id( $param{'ddmSupplier'} );
		$Paper->group( $param{'txtGroup'} ) if $param{'txtGroup'};
		$Paper->group_id( $param{'Group'} ) if ! $param{'txtGroup'};
		$Paper->brand( $param{'txtBrand'} ) if $param{'txtBrand'};
		$Paper->brand_id( $param{'ddmBrand'} ) if ! $param{'txtBrand'};
		$Paper->finish( $param{'txtFinish'} ) if $param{'txtFinish'};
		$Paper->finish_id( $param{'ddmFinish'} ) if ! $param{'txtFinish'};
		$Paper->colour( $param{'txtColour'} ) if $param{'txtColour'};
		$Paper->colour_id( $param{'ddmColour'} ) if ! $param{'txtColour'};
		$Paper->weight( $param{'txtWeight'} ) if $param{'txtWeight'};
		$Paper->weight_id( $param{'ddmWeight'} ) if ! $param{'txtWeight'};
		$Paper->quality( $param{'txtQuality'} ) if $param{'txtQuality'};
		$Paper->quality_id( $param{'ddmQuality'} ) if ! $param{'txtQuality'};
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
		$Paper->available_to_order( $param{available_to_order} );
		$Paper->cuttable( $param{'cuttable'} );
		$Paper->doublesided( $param{'doublesided'} );
		$Paper->multipart( $param{'multipart'} );
		$Paper->perfecting( $param{'perfecting'} );
		$Paper->score_required( $param{'scoring'} );
		$Paper->die_score_required( $param{'die_score_required'} );
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
		$Paper->user_type( $param{'user_type'} );

		@{$$Paper{'recommendations'}} = ();
		foreach my $Type ( openprint::ProjectType->find() ) {
			push @{$$Paper{'recommendations'}}, $Type->id() if $param{'chkPRF'.$Type->id()};
		} # end foreach

# Save prices
		foreach my $Price ( $Paper->Prices() ) {
			if (
					( $Price->price() != $param{"price-$$Price{id}"} ) 
					or ( $Price->min() != $param{"min-$$Price{id}"} )
					or ( $Price->max() != $param{"max-$$Price{id}"} )
					or ( $Price->units() ne $param{"units-$$Price{id}"} )
					or ( $Price->discountable() ne $param{"discountable-$$Price{id}"} )
					or ( $Price->equipment_id() ne $param{"equipment_id-$$Price{id}"} )
			   ) {
			$variable{error} .= $Price->save({
					equipment_id	=> $param{"equipment_id-$$Price{id}"},
					min				=> $param{"min-$$Price{id}"},
					max				=> $param{"max-$$Price{id}"},
					units			=> $param{"units-$$Price{id}"},
					cost			=> $param{"cost-$$Price{id}"},
					markup			=> $param{"markup-$$Price{id}"},
					price			=> $param{"price-$$Price{id}"},
					discountable	=> $param{"discountable-$$Price{id}"},
					});
			} # end if Price has changed
		} # end foreach Price

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
		my $PaperPrice = new openprint::PaperPrice( $param{'price_id'} );
		$PaperPrice->delete();
	} elsif ( $param{'action'} eq 'Add' ) {
		my $PaperPrice = new openprint::PaperPrice( );
		$PaperPrice->paper_id( $param{'stock_id'} );
		$PaperPrice->pricelist_id( $param{'pricelist_id'} );
		$PaperPrice->save();
	} elsif ( $param{'action'} eq 'Copy' ) {
		my $PaperPrice = new openprint::PaperPrice( $param{'price_id'} );
		my $NewPrice = $PaperPrice->copy();
		$NewPrice->save();
	} # end if
} # end sub _prices

sub import_export {

	if ( $param{'btnFunction'} eq 'Export Stock' ) {
		my @header = ( 'ID', 'Owner','Manufacturer','Group','Brand', 'Finish', 'Colour', 'Weight', 'Quality', 'MWeight', 'gsm','Calliper', 'Type','Width', 'Height', 'Basis Width','Basis Height', 'Grain Direction','Supplier','DoubleSided?','Cuttable?','Multiple Parts?','Perfecting','Scoring Required?','Blade Cleaning Required?','Grade','Sheets Per Package','Supplied', 'Digital','Full Packages','Minimum Order','Inventory #','Material Type','Message', 'Recommendations');
		my @data;

		foreach my $Paper ( openprint::Paper->find( 'order'=>'brand,finish,colour,weight,width,height', 
					columns=>'*,(SELECT name FROM StockBrands WHERE Stockbrands.id=brand_id) AS brand,(SELECT name FROM StockFinishes WHERE StockFinishes.id=finish_id) AS finish,(SELECT name FROM StockColours WHERE StockColours.id=colour_id) AS colour,(SELECT name FROM StockWeights WHERE StockWeights.id=weight_id) AS weight ') ) {
			push @data, $Paper->id(), $Paper->owner(), $Paper->manufacturer(), $Paper->group(), $Paper->brand(), $Paper->finish(), $Paper->colour(), $Paper->weight(), $Paper->quality(), 
			$Paper->mweight(), $Paper->gsm(), $Paper->calliper(), $Paper->type(), $Paper->width(), $Paper->height(), $Paper->basis_width(), $Paper->basis_height(), $Paper->grain_direction(), '', $Paper->doublesided(), $Paper->cuttable(), $Paper->multipart(), $Paper->perfecting(), $Paper->score_required(), $Paper->bladecleaning(), $openprint::Paper::grades{$Paper->grade()}, $Paper->sheets_per_package(), $Paper->supplied(), $Paper->digital(), $Paper->full_packages(), $Paper->minimum_order(), $Paper->inventory_number(), $Paper->material(), $Paper->message();
			push @data, join(',', map { new openprint::ProjectType($_)->name() } $Paper->recommendations());
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
			my %project_types = map { $_->name(), $_->id() } openprint::ProjectType->find();
			my %owners = map { $_->name(), $_->id() } openprint::Company->find();
			my %papers = map { $_->id(), $_ } openprint::Paper->find();
			my %reverse_grades = reverse %openprint::Paper::grades;

			my $csv = Text::CSV_XS->new();
			while ( <$io> ) {
				my $status = $csv->parse($_);
				my ( $paper_id, $owner, $manufacturer, $group, $brand, $finish, $colour, $weight, $quality, $mweight, $gsm, $calliper, $type, $width, $height, $basis_width, $basis_height, $grain_direction, $supplier, $double_sided, $cuttable, $multipart, $perfecting, $scoring, $bladecleaning, $grade, $spp, $supplied, $digital, $full_packages, $minimum_order, $inventory_number, $material, $message, $recommendations ) = misc::trim($csv->fields());

				next if ! $paper_id;

				$mweight =~ s/[^\d\.]//g;
				$calliper =~ s/[^\d\.]//g;
				$width =~ s/[^\d\.]//g;
				$height =~ s/[^\d\.]//g;
				$gsm =~ s/[^\d\.]//g;
				$spp =~ s/[^\d]//g;

				my @recommendations = ();
				foreach my $ProjectType_name ( split(',',$recommendations ) ) {
					next if ! $ProjectType_name;
					my $ProjectType = openprint::ProjectType->find_one('name lc'=>lc openprint::ProjectType->transform('name',$ProjectType_name));
					if ( ! $ProjectType ) {
					$ProjectType = new openprint::ProjectType();
					$ProjectType->save({'name'=>$ProjectType_name});
					} # end if
					push @recommendations, $ProjectType->id();
				} # end foreach

				my $Paper = $papers{$paper_id} ? $papers{$paper_id} : new openprint::Paper();
				$Paper->owner_id( $owners{$owner} ? $owners{$owner} : $session{'company_id'} );
				$Paper->manufacturer( $manufacturer );
				$Paper->group( $group );
				$Paper->brand( $brand );
				$Paper->finish( $finish );
				$Paper->colour( $colour );
				$Paper->weight( $weight );
				$Paper->quality( $quality );
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
				$Paper->bladecleaning( $bladecleaning );
				$Paper->grade( $reverse_grades{$grade} );
				$Paper->supplied( $supplied );
				$Paper->digital( $digital );
				$Paper->full_packages( $full_packages );
				$Paper->sheets_per_package( $spp );
				$Paper->minimum_order( $minimum_order );
				$Paper->inventory_number( $inventory_number );
				$Paper->material( $material );
				$Paper->message( $message );
				$Paper->recommendations( @recommendations );
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


	my $query = "SELECT Projects.lngProjectIndex,lngDocketNumber, intQuantityIndex, (SELECT name FROM Companies WHERE id=Company_id) FROM Projects, Order_Contents WHERE Projects.Index=lngProjectIndex AND strStatus IN ( 'Ordered','Complete','Printed','Proofs Out','Approved','In Prepress' )\n";
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
				my $specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
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

sub filters {
} # end sub filters

sub _filters_load {
} # end sub _filters_load

sub _filters_save {
} # end sub _filters_save

sub _price_tr {
	$variable{'Pricelist'} = new openprint::Pricelist( $param{'pricelist_id'} );
	$variable{'Stock'} = new openprint::Paper( $param{'stock_id'} );
	$variable{'Price'} = new openprint::PaperPrice( $param{'price_id'} );
	my @Equipment = openprint::Equipment->find('order'=>'lower(strid)');
	$variable{'Equipment'} = \@Equipment;
    $variable{'company_ids'} = [ map { $_->id(), $_->name() } openprint::Company->find( 'supplier'=>'Y', 'order'=>'lower(name)' ) ];
	if ( $param{'action'} eq 'Add' ) {
		$variable{'error'} .= $variable{'Price'}->save({
			'pricelist_id'	=>	$param{'pricelist_id'},
			'stock_id'		=>	$param{'stock_id'},
			'service'		=>	$param{'service'},
		});
	} elsif ( $param{'action'} eq 'Delete' ) {
		$variable{'error'} = $variable{'Price'}->delete();
		$variable{'Price'} = new openprint::PaperPrice();
	} elsif ( $param{'action'} eq 'Copy' ) {
		$variable{'Price'} = $variable{'Price'}->copy();
		$variable{'error'} .= $variable{'Price'}->save( \%param );
	} # end if

} # end sub _price_tr

sub _stock { 
} # end sub _stock

1;
__END__
