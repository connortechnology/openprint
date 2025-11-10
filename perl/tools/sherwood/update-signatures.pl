#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use Date::Calc;
use strict;
require sql;
require logger;
require openprint::Object;
require openprint::Project;
require openprint::service;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'debug' );
my %sql_server;
$sql_server{'database'} = $ARGV[0];
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = $ARGV[1];
$sql_server{'password'} = $ARGV[2];

$openprint::Object::no_cache = 1;

$dbh = sql::open_sql( $log, %sql_server );
my @projects;
#push @projects, map { new openprint::Project( $_ ); } sql::execute( undef, undef, q{SELECT DISTINCT projectindex from Schedule} );
#push @projects, openprint::Project->find( 'id'=>222386, 'company_id'=>6, 'id_start'=>200000, 'order'=>'index desc');
push @projects, openprint::Project->find( $ARGV[3] ? (id=>$ARGV[3]) : ('id >='=>'163751'), order=>'id desc');
#@projects = sets::union( @projects );

foreach my $Project ( @projects ) {
	my $project_index = $Project->id();

	if ( ! $Project->currency_id() ) {
		$Project->currency_id( $Project->Company()->currency_id() );
		$Project->currency_id( 1 ) if ! $Project->currency_id();
		$Project->save();
	} # end if
	my %services = $Project->get_services();
#$log->warn("Looking at Project $project_index");
	my $ac = sql::start_transaction( $dbh );
	if ( $services{Book} ) {
    my $s_id = $services{Book}[0];
		my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );

    if (exists $$specs{final_height} and !exists $$specs{txtFinalHeight}) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtFinalHeight', $$specs{final_height});
    }
    if (exists $$specs{final_width} and !exists $$specs{txtFinalWidth}) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtFinalWidth', $$specs{final_width});
    }
    if (exists $$specs{flat_height} and !exists $$specs{txtHeight}) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtHeight', $$specs{flat_height});
    }
    if (exists $$specs{flat_width} and !exists $$specs{txtWidth}) {
      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtWidth', $$specs{flat_width});
    }
    if (exists $$specs{template}) {
      $$specs{template} = 'PerfectBound' if ($$specs{template} eq 'PerfectBinding');
      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'rdbTemplateType', $$specs{template});
    }
    if ($$specs{rdbCover} eq 'DifferentCover') {
      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'rdbCover', 'Different');
    } elsif ($$specs{rdbCover} eq 'SelfCover') {
      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'rdbCover', 'Self');
    }
		my $txtInteriorSpreadQuantity = $$specs{'txtTotalSpreadQuantity'} - $$specs{'txtGateFoldedSpreadQuantity'};
		if ( $$specs{'rdbCover'} eq 'Different' ) {
			if ( $$specs{'txtSpreadSize'} == 4 ) {
				$txtInteriorSpreadQuantity -= 1;
			} else {
				$txtInteriorSpreadQuantity -= 2;
			} # end if
		} # end if
    openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtInteriorSpreadQuantity',$txtInteriorSpreadQuantity );
    sql::end_transaction( $dbh, $ac );
  } # end if book

  my $p_specs = openprint::service::get_specs_ref( $Project->id(), $services{''}[0] );
  foreach my $s_id ($Project->signatures()) {
    my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );

    if ( exists $$specs{bleed_size} ) {
      foreach my $qty_index ( $Project->quantity_indexes()) {
        openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'ddmBleedSize'.$qty_index, $$specs{bleedsize} );
      } # end 
    } # end 

    if ($$specs{s0_process}) {
      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'chkProcessColourSideOne', 'ProcessColour' );
    }
    if ($$specs{s1_process}) {
      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'chkProcessColourSideTwo', 'ProcessColour' );
    }
    if ($$specs{stock_supplied}) {
      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'rdbSuppliedStock', 'Y' ) if ! $$specs{rdbSuppliedStock};
    }
    if ($$specs{stock_colour} and !$$specs{ddmStockColour}) {
      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, ddmStockColour=>$$specs{stock_colour});
    }
    if ($$specs{stock_finish} and !$$specs{ddmStockFinish}) {
      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, ddmStockFinish=>$$specs{stock_finish});
    }
    if ($$specs{stock_weight} and !$$specs{ddmStockWeight}) {
      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, ddmStockWeight=>$$specs{stock_weight});
    }
    if ($$specs{stock_name} and !$$specs{ddmStockBrand}) {
      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, ddmStockBrand=>$$specs{stock_name});
    }
    #openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtCustomMWeight', $$specs{'txtMWeight1'} ) if ! $$specs{'txtCustomMWeight'};
    #openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'CustomStockPrice', '0.00' ) if ! $$specs{'CustomStockPrice'};
    #openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtSpecificStockWidth', $$specs{'hdnSuppliedStockWidth1'} ) if ! $$specs{'txtSpecificStockWidth'};
    #openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtSpecificStockHeight', $$specs{'hdnSuppliedStockHeight1'} ) if ! $$specs{'txtSpecificStockHeight'};
    #
    #if ( $$specs{'txtSpecificStockFinish'} =~ /matte/i ) {
    #openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'StockGrade', 2 );
    #} elsif ( $$specs{'txtSpecificStockFinish'} =~ /gloss/i ) {
    #openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'StockGrade', 1 );
    #} else {
    #openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'StockGrade', 4 );
    #} # end if

    if ($$specs{bleed_sides}) {
      my %sides = map{$_=>$)} split(',',$$specs{bleed_sides});

      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'chkBleedTop','Top' ) if ($sides{0});
      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'chkBleedRight','Right' ) if ($sides{1});
      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'chkBleedTop','Bottom' ) if ($sides{2});
      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'chkBleedTop','Left' ) if ($sides{3});
    }

    if ( ! $$specs{'txtSpreadSize'} ) {
      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtSpreadSize', $$p_specs{'txtSpreadSize'} );
    } # end if
    openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'rdbColourBar', 'Y' ) if $$specs{colour_bar};

    # Now if this signature has txtSignatureQty > 1, duplicate it, and adjust the price accordingly.
    if ( $$specs{'txtSignatureQuantity'} > 1 ) {
      $log->debug("SPlitting Signatures");
      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtPrice1', $$specs{'txtPrice1'}/$$specs{'txtSignatureQuantity'} );
      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtPrice2', $$specs{'txtPrice2'}/$$specs{'txtSignatureQuantity'} );
      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtPrice3', $$specs{'txtPrice3'}/$$specs{'txtSignatureQuantity'} );
      $_ = q{SELECT MAX(strValue) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
      my ( $sig_index ) = sql::execute( $log, $dbh, $_, $Project->id() );
      foreach my $blah ( 2 .. $$specs{'txtSignatureQuantity'} ) {
        my $new_service_index = $Project->add_service( 'Signature' );
        die if $dbh->errstr();
        my $new_specs = openprint::service::get_specs_ref( $Project->id(), $new_service_index );
        $sig_index += 1;
        openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $new_service_index, 'SignatureIndex', $sig_index );

        openprint::service::status( $Project->id(), $new_service_index, openprint::service::status( $Project->id(), $s_id ) );
        my $ac = sql::start_transaction( $dbh );
        foreach my $key ( keys %$specs ) {
          next if $key eq 'ServiceIndex';
          next if $key eq 'SignatureIndex';
          if ( $$specs{$key} and ( $$specs{$key} ne $$new_specs{$key} ) ) {
            openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $new_service_index, $key, $$specs{$key}, exists $$new_specs{$key} );
            die if $dbh->errstr();
          } # end if
        } # end foreach
        openprint::service::delete_service_spec( $Project->id(), $new_service_index, 'txtSignatureQuantity' );
        sql::end_transaction( $dbh, $ac );
        die if $dbh->errstr();
      } # end foreach
    } # end if
    openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtSignatureQuantity' ) if exists $$specs{'txtSignatureQuantity'};
    die if $dbh->errstr();
  } # end foreach signature

  next;
# Update plain cartons, etc
if ( $services{'PlainCartons'} ) {
  foreach my $s_id ( @{$services{'PlainCartons'}} ) {
    my $ac = sql::start_transaction( $dbh );
    my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
    openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtItemsPerPackage', $$specs{'txtItemsPerPackage1'}, ! exists $$specs{'txtItemsPerPackage'} ) if! $$specs{'txtItemsPerPackage'};
    openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtItemsPerPackage1' );
    openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtItemsPerPackage2' );
    openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtItemsPerPackage3' );

    openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtPackageWeight', $$specs{'txtPackageWeight1'}, ! exists $$specs{'txtPackageWeight'} ) if ! $$specs{'txtPackageWeight'};
    openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtPackageWeight1' );
    openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtPackageWeight2' );
    openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtPackageWeight3' );
    openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnSkidQuantity1' );
    openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnSkidQuantity2' );
    openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnSkidQuantity3' );
    openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtFinishedWeight', $$specs{'hdnProjectWeight'}, ! exists $$specs{'txtFinishedWeight'} );
    openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnProjectWeight' );
    openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'totalWeight1', $$specs{'txtFinishedWeight'}*$$specs{'txtQuantity1'}, ! exists $$specs{'txtFinishedWeight'} );
    openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'totalWeight2', $$specs{'txtFinishedWeight'}*$$specs{'txtQuantity2'}, ! exists $$specs{'txtFinishedWeight'} );
    openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'totalWeight3', $$specs{'txtFinishedWeight'}*$$specs{'txtQuantity3'}, ! exists $$specs{'txtFinishedWeight'} );
    sql::end_transaction( $dbh, $ac );
  } # end foreach
} # end if

next;

if ( $services{'BulkSkids'} ) {
  my $ac = sql::start_transaction( $dbh );
  foreach my $s_id ( @{$services{'BulkSkids'}} ) {
    my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
    openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtItemsPerPackage', $$specs{'txtItemsPerPackage1'}, 1 ) if ! $$specs{'txtItemsPerPackage1'};
    openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtItemsPerPackage1' );
    openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtItemsPerPackage2' );
    openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtItemsPerPackage3' );
    openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtPackageWeight', $$specs{'txtPackageWeight1'}, 1 ) if ! $$specs{'txtPackageWeight1'};
    openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtPackageWeight1' );
    openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtPackageWeight2' );
    openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtPackageWeight3' );
    openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnSkidQuantity1' );
    openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnSkidQuantity2' );
    openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnSkidQuantity3' );
    openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtFinishedWeight', $$specs{'hdnProjectWeight'}, 1 );
    openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnProjectWeight' );
    openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'totalWeight1', $$specs{'txtFinishedWeight'}*$$specs{'txtQuantity1'}, ! exists $$specs{'txtFinishedWeight'} );
    openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'totalWeight2', $$specs{'txtFinishedWeight'}*$$specs{'txtQuantity2'}, ! exists $$specs{'txtFinishedWeight'} );
    openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'totalWeight3', $$specs{'txtFinishedWeight'}*$$specs{'txtQuantity3'}, ! exists $$specs{'txtFinishedWeight'} );
  } # end foreach

  sql::end_transaction( $dbh, $ac );
} # end if
if ( $services{'Folding'} ) {
  foreach my $s_id ( @{$services{'Folding'}} ) {
    my $ac = sql::start_transaction( $dbh );
    my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
    foreach my $fold ( keys %openprint::Estimating::Folding::fold_types ) {
      foreach my $qty_index ( 1 .. 3 ) {
        if ( $$specs{'chkOverride-txt'.$fold.'Qty'} eq 'Y' ) {
          openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "chkOverrideFoldType-0-$qty_index", $$specs{'chkOverride-txt'.$fold.'Qty'} );
        } # end if
        openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "$fold-Qty-0-$qty_index", $$specs{'txt'.$fold.'Qty'} );
        my @Equipment = openprint::Equipment->find( 'strid'=>$$specs{'ddmEquipment'.$qty_index} );
        if ( @Equipment ) {
          my $Equipment = shift @Equipment;
          openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "ddmEquipment-0-$qty_index", $Equipment->id() );
          openprint::service::delete_service_spec( $Project->id(), $s_id, 'ddmEquipment'.$qty_index );
        } # end if
      } # end foreach
      openprint::service::delete_service_spec( $Project->id(), $s_id, 'chkOverride-txt'.$fold.'Qty' );
      openprint::service::delete_service_spec( $Project->id(), $s_id, 'txt'.$fold.'Qty' );

    } # end foreach
    sql::end_transaction( $dbh, $ac );
  } # end foreach
} # end if
if ( $services{'Perforating'} ) {
  foreach my $s_id ( @{$services{'Perforating'}} ) {
    my $ac = sql::start_transaction( $dbh );
    my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
    foreach my $qty_index ( 1 .. 3 ) {
      next if ! $$specs{'txtQuantity'.$qty_index};
      foreach my $ss_id ( $Project->signatures() ) {
        my $sig_specs = openprint::service::get_specs_ref( $Project->id(), $ss_id );
        openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index", $$specs{'ddmEquipment'.$qty_index.'-'. $$sig_specs{SignatureIndex}} );
        openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "txtImposition-$$sig_specs{SignatureIndex}-$qty_index", $$specs{'txtImposition'.$qty_index.'-'. $$sig_specs{SignatureIndex}} );
        openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "txtLayoutWidth-$$sig_specs{SignatureIndex}-$qty_index", $$specs{'txtImageWidth'.$qty_index.'-'. $$sig_specs{SignatureIndex}} );
        openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "txtLayoutHeight-$$sig_specs{SignatureIndex}-$qty_index", $$specs{'txtImageHeight'.$qty_index.'-'. $$sig_specs{SignatureIndex}} );
      } # end foreach
    } # end foreach
    sql::end_transaction( $dbh, $ac );
  } # end foreach
} # end if
if ( $services{'Scoring'} ) {
  foreach my $s_id ( @{$services{'Scoring'}} ) {
    my $ac = sql::start_transaction( $dbh );
    my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
    foreach my $qty_index ( 1 .. 3 ) {
      foreach my $ss_id ( $Project->signatures() ) {
        my $sig_specs = openprint::service::get_specs_ref( $Project->id(), $ss_id );
        openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index", $$specs{'ddmEquipment'.$qty_index.'-'. $$sig_specs{SignatureIndex}} );
        openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "txtImposition-$$sig_specs{SignatureIndex}-$qty_index", $$specs{'txtImposition'.$qty_index.'-'. $$sig_specs{SignatureIndex}} );
        openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "txtLayoutWidth-$$sig_specs{SignatureIndex}-$qty_index", $$specs{'txtImageWidth'.$qty_index.'-'. $$sig_specs{SignatureIndex}} );
        openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "txtLayoutHeight-$$sig_specs{SignatureIndex}-$qty_index", $$specs{'txtImageHeight'.$qty_index.'-'. $$sig_specs{SignatureIndex}} );
      } # end foreach
    } # end foreach
    sql::end_transaction( $dbh, $ac );
  } # end foreach
} # end if
if ( $services{'Cutting'} ) {
  foreach my $s_id ( @{$services{'Cutting'}} ) {
    my $ac = sql::start_transaction( $dbh );
    my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
    foreach my $ss_id ( $Project->signatures() ) {
      my $sig_specs = openprint::service::get_specs_ref( $Project->id(), $ss_id );
      foreach my $qty_index ( 1 .. 3 ) {
        openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "txtCalculatedCuts-$$sig_specs{'SignatureIndex'}-$qty_index", $$specs{"txtCalculatedCuts$$sig_specs{'SignatureIndex'}"} );
      } # end foreach
    } # end foreach
    sql::end_transaction( $dbh, $ac );
  } # end foreach
} # end if
if ( $services{'SaddleStitching'} ) {
  foreach my $s_id ( @{$services{'SaddleStitching'}} ) {
    my $ac = sql::start_transaction( $dbh );
    my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
    foreach my $qty_index ( 1 .. 3 ) {
      foreach my $pages ( 4, 8, 12, 16, 20, 24, 32 ) {
        openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtSignatureQty'.$pages.'Page-'.$qty_index, $$specs{'txtSignatureQty'.$pages.'Page'} );
      } # end foreach

    } # end foreach
    sql::end_transaction( $dbh, $ac );
  } # end foreach
} # end if
if ( $services{'LoopStitching'} ) {
  foreach my $s_id ( @{$services{'SaddleStitching'}} ) {
    my $ac = sql::start_transaction( $dbh );
    my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
    foreach my $qty_index ( 1 .. 3 ) {
      foreach my $pages ( 4, 8, 12, 16, 20, 24, 32 ) {
        openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtSignatureQty'.$pages.'Page-'.$qty_index, $$specs{'txtSignatureQty'.$pages.'Page'} );
      } # end foreach

    } # end foreach
    sql::end_transaction( $dbh, $ac );
  } # end foreach
} # end if
if ( $services{'Bundling'} ) {
  foreach my $s_id ( @{$services{'Bundling'}} ) {
    my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
    openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'ServiceType', 'Bundling' );
    openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtItemsPerPackage', $$specs{'txtWrapQuantity'} );
    openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'rdbCardboardBacking', 'N' );
    my @qtys = split(',', $$specs{'txtQuantity'} );
    foreach my $qty_index ( 1 .. 3 ) {
      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtPackageQuantity'.$qty_index, $qtys[$qty_index-1] );
    } # end foreach

  } # end foreach
} #Ne dif
if ( $services{'ShrinkWrap'} ) {
  foreach my $s_id ( @{$services{'ShrinkWrap'}} ) {
    my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
    openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtItemsPerPackage', $$specs{'txtWrapQuantity'} );
    openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'rdbCardboardBacking', 'N' );
    my @qtys = split(',', $$specs{'txtQuantity'} );
    foreach my $qty_index ( 1 .. 3 ) {
      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtPackageQuantity'.$qty_index, $qtys[$qty_index-1] );
    } # end foreach
  } # end foreach
} #Ne dif
if ( $services{'KraftWrap'} ) {
  foreach my $s_id ( @{$services{'KraftWrap'}} ) {
    my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
    openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtItemsPerPackage', $$specs{'txtWrapQuantity'} );
    openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'rdbCardboardBacking', 'N' );
    my @qtys = split(',', $$specs{'txtQuantity'} );
    foreach my $qty_index ( 1 .. 3 ) {
      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtPackageQuantity'.$qty_index, $qtys[$qty_index-1] );
    } # end foreach
  } # end foreach
} #Ne dif
if ( $services{'Scanning'} ) {
  foreach my $s_id ( @{$services{'Scanning'}} ) {
    my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
    if ( exists $$specs{'ddmLineScreen'} or exists $$specs{'txtLineScreenOther'} ) {
      openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'LineScreen', $$specs{'ddmLineScreen'} ? $$specs{'ddmLineScreen'} : $$specs{'txtLineScreenOther'} );
      openprint::service::delete_service_spec( $Project->id(), $s_id, 'ddmLineScreen' );
      openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtLineScreenOther' );
    } # end if
  } # end foreach
} #Ne dif

# Do this after every project to keep the cache from growing out of control
openprint::service::init_cache();

} # end foreach Project
1;
__END__
