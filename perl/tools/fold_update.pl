#!/usr/bin/perl -w
use lib '/var/www/testing/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Paper;
require openprint::PaperPrice;
require openprint::Equipment;
require openprint::EquipmentSpecification;
require openprint::ServicePrice;
require openprint::ServiceType;
require openprint::Service;
require openprint::ServiceCategory;
require openprint::Project;
require openprint::service;
require openprint::Material;
require openprint::MaterialCategory;
require openprint::PaperInventory;
require openprint::Log;
require openprint::Host;
require openprint::Company;

use openprint ();
use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

$openprint::Object::no_cache = 1;

$log = new logger( 'debug' );

$ARGV[1] = $ARGV[0] if ! $ARGV[1];
$ARGV[2] = $ARGV[1] if ! $ARGV[2];

$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>$ARGV[3]) );
die if ! $dbh;
$config{db_name} = $ARGV[0];

my $FoldingService = openprint::Service->find_one('name'=>'Folding');
die if ! $FoldingService;

foreach my $E ( openprint::Equipment->find('Specifications'=>{'Folding Capable'=>['For Pocket Folders','Y','When Printing','When Stitching']}) ) {
	foreach my $Spec ( $E->Specifications() ) {
		# Standard Folder style folding
		if ( $Spec->name() =~ /^(\d+)PageSignatureFoldRunSpeed$/ ) {
			my $pages = $1;
			$log->debug("Upgrading simple $pages Page Fold on $$E{name}");
			my $Fold = openprint::Fold->find_one('equipment_id'=>$E->id(),'name'=>$pages.'PageFold',type=>$pages.'PageFold',pages=>$pages);
			if ( ! $Fold ) {
				$log->debug("Adding simple $pages Page Fold on $$E{name}");
				$Fold = new openprint::Fold();
				$Fold->equipment_id( $E->id() );
				$Fold->name( $pages.'PageFold' );
				$Fold->type( $pages . 'PageFold' );
				$Fold->pages( $pages );
				$Fold->max_imposition( 2 );
				$Fold->stitching( 1 );
				$Fold->perfectbind( 1 );
				if ( $_ = $E->Specification($pages.'PageSignatureFoldPrintingType') ) {
					$Fold->printing_type( $_->value() );
					$_->delete();
				} # end if
				if ( $_ = $E->Specification($pages.'PageSignatureFoldOvers') ) {
					$Fold->makeready_overs( $_->value() );
					$Fold->makeready_overs_units( $_->units() );
					$_->delete();
				} # end if
				$_ = $Fold->save();
				die $_ if $_;
			} # end if
			my $FS = new openprint::FoldSpecification();
			$FS->fold_id( $Fold->id() );
			$FS->runspeed( $Spec->value() );
			$FS->interpolate( $Spec->interpolate() );
			$_ =  $FS->save();
			die $_ if $_;
			$Spec->delete();
		} elsif ( $Spec->name() =~ /^(\w*)FoldRunSpeed/ ) {
			my $type = $1;
			$log->debug("Upgrading simple $type Page Fold on $$E{name}");
			my $Fold = openprint::Fold->find_one('equipment_id'=>$E->id(),'name'=>$type.'Fold',type=>$type.'Fold');
			if ( ! $Fold ) {
				$Fold = new openprint::Fold();
				$Fold->equipment_id( $E->id() );
				$Fold->name( $type.'Fold' );
				$Fold->type( $type.'Fold' );
				$Fold->max_imposition( 6 );
				$Fold->stitching( 1 );
				$Fold->perfectbind( 1 );
				if ( $_ = $E->Specification($type.'FoldPrintingType') ) {
					$Fold->printing_type( $_->value() );
					$_->delete();
				} # end if
				if ( $_ = $E->Specification($type.'FoldOvers') ) {
					$Fold->makeready_overs( $_->value() );
					$Fold->makeready_overs_units( $_->units() );
					$_->delete();
				} # end if
				$_ = $Fold->save();
				die $_ if $_;
			} # end if
			my $FS = new openprint::FoldSpecification();
			$FS->fold_id( $Fold->id() );
			$FS->runspeed( $Spec->value() );
			$FS->interpolate( $Spec->interpolate() );
			$_ =  $FS->save();
			die $_ if $_;
			$Spec->delete();
		} elsif ( $Spec->name() =~ /^(\d+)Panel(\d+)Pocket(\w*)RunSpeed/ ) {
			my ($panel, $pocket, $gusset ) = ( $1, $2, $3 );
			my $Fold = new openprint::Fold();
			$Fold->equipment_id( $E->id() );
			$Fold->name( $panel.'Panel'.$pocket.'Pocket'.$gusset );
			$Fold->type( $panel.'Panel'.$pocket.'Pocket'.$gusset );
			$Fold->max_imposition( 2 );
			$_ = $Fold->save();
			die $_ if $_;
			my $FS = new openprint::FoldSpecification();
			$FS->fold_id( $Fold->id() );
			$FS->runspeed( $Spec->value() );
			$FS->interpolate( $Spec->interpolate() );
			$_ =  $FS->save();
			die $_ if $_;
			$Spec->delete();
			if ( ! openprint::Service->find('name'=>$panel.'Panel'.$pocket.'Pocket'.$gusset) ) {
				my $Service = new openprint::Service();
				$Service->save({
					'name'=>$panel.'Panel'.$pocket.'Pocket'.$gusset,
					'description'=>$panel.'Panel'.$pocket.'Pocket'.$gusset,
					'category'=>'Bindery',
				});
			}
		}
	}  # end foreach Spec
	foreach my $Spec ( $E->Specifications() ) {
		my $found = 0;
		if ( $Spec->name() =~ /^Runspeed Adjustment$/ ) {
			$found = 1;
			foreach my $Fold ( openprint::Fold->find('equipment_id'=>$E->id()) ) {
				foreach my $FoldSpec ( $Fold->Specifications() ) {
					if ( ! ( $FoldSpec->min_weight() or $FoldSpec->max_weight() ) ) {
						my $FoldSpec2 = $FoldSpec->copy();
						$FoldSpec2->save({
							'runspeed'=>$FoldSpec->runspeed() - ( $FoldSpec->runspeed()*($Spec->value()/100) ),
							'min_weight'=>$Spec->min(), 
							'max_weight'=>$Spec->max(),
							'interpolate'	=>	$Spec->interpolate(),
						});
					} # end if
				} # end foreach FoldSpec
			} # end foreach
			$Spec->delete();
		} # end if Spec->name
		if ($found) {
			foreach my $Fold ( openprint::Fold->find('equipment_id'=>$E->id()) ) {
				foreach my $FoldSpec ( $Fold->Specifications() ) {
					if ( ! ( $FoldSpec->min_weight() or $FoldSpec->max_weight() ) ) {
						$FoldSpec->delete();
					} # endif
			} # end foreachd
			} # end foreachd
		} # end if found
	}  # end foreach Spec
} # end foreach Fold
	
foreach my $E ( openprint::Equipment->find('Specifications'=>{'Folding Capable'=>['When Printing','When Stitching']}) ) {
	foreach my $Spec ( $E->Specifications() ) {
		if ( $Spec->name() =~ /^(\d)x(\d)-(\d+)Page-(\w*)SignatureFoldDescription$/ ) {
			my ( $columns, $rows, $pages, $spine_direction ) = ( $1, $2, $3, $4 );
			my $spread_size = $pages/($columns*$rows);
			my $fold = sprintf('%dx%d-%dPage-%sSignatureFold', $columns, $rows, $pages, $spine_direction );
			$log->debug("Doing complex fold: $fold");
			#my $Fold = openprint::Fold->find_one( equipment_id =>$E->id(), name=>$Spec->value(),type=>$pages.'PageFold',pages=>$pages,spine_direction=>$spine_direction);
			#if ( ! $Fold ) {
				$log->debug("Adding complex fold: $fold");
				my $Fold = new openprint::Fold();
				$Fold->equipment_id( $E->id() );
				$Fold->name( $Spec->value() );
				$Fold->type( $pages . 'PageFold' );
				$Fold->pages( $pages );
				if ( $spread_size == 4 ) {
					$Fold->stitching(1);
					$Fold->perfectbind(0);
					$Fold->spinepaste(0);
					if ( $spine_direction eq 'Vertical' ) {
						$columns *= 2;
					} else {
						$rows *= 2;
					} # end if
				} else {
					$Fold->stitching(0);
					$Fold->perfectbind(1);
					$Fold->spinepaste(1);
				} # end if
				$Fold->cutting(0);
				$Fold->page_columns( $columns );
				$Fold->page_rows( $rows );
				$Fold->spine_direction( $spine_direction );
				if ( $_ = $E->Specification( $fold.'MinimumWidth' ) ) {
					if ( $_->value() ) {
						if ( $spine_direction eq 'Vertical' ) {
							$Fold->min_width( Math::Round::nearest( 0.001, ($_->value()/$columns)) );
						} else {
							$Fold->min_height( Math::Round::nearest( 0.001, ($_->value()/$columns)) );
						} # end if
					} # end if
					$_->delete();
				} #end if
				if ( $_ = $E->Specification( $fold.'MaximumWidth' ) ) {
					if ( $_->value() ) {
						if ( $spine_direction eq 'Vertical' ) {
							$Fold->max_width( Math::Round::nearest(0.001, ($_->value()/$columns)) );
						} else {
							$Fold->max_height( Math::Round::nearest(0.001, ($_->value()/$columns)) );
						} # end if
					} # end if
					$_->delete();
				} # en dif
				if ( $_ = $E->Specification( $fold.'MinimumHeight' ) ) {
					if ( $_->value() ) {
						if ( $spine_direction eq 'Vertical' ) {
							$Fold->min_height( Math::Round::nearest(0.001, ($_->value()/$rows)) );
						} else {
							$Fold->min_width( Math::Round::nearest(0.001, ($_->value()/$Fold->page_rows())) );
						} # end if
					} # end if
					$_->delete();
				} # end if
				if ( $_ = $E->Specification( $fold.'MaximumHeight' ) ) {
					if ( $_->value() ) {
						if ( $spine_direction eq 'Vertical' ) {
							$Fold->max_height( Math::Round::nearest( 0.001, ($_->value()/$rows)) );
						} else {
							$Fold->max_width( Math::Round::nearest( 0.001, ($_->value()/$columns)) );
						} # end if
					} # end if
					$_->delete();
				} # end if
				if ( $_ = $E->Specification( $fold.'MaximumImposition' ) ) {
					$Fold->max_imposition( $_->value() );
					$_->delete();
				} # end if
				if ( $_ = $E->Specification( $fold.'MinimumImposition' ) ) {
					$Fold->min_imposition( $_->value() );
					$_->delete();
				} # end if
				$_ = $Fold->save();
				die $_ if $_;
			#} # end if
			while ( my $S = $E->Specification( $fold.'RunSpeed' ) ) {
				my $FS = new openprint::FoldSpecification();
				$FS->fold_id( $Fold->id() );
				$FS->min_weight( $S->min() );
				$FS->max_weight( $S->max() );
				$FS->weight_units( $S->units() );
				$FS->runspeed( $S->value() );
				$FS->interpolate( $S->interpolate() );
				$_ =  $FS->save();
				die $_ if $_;
				$S->delete();
				delete $$E{'Specifications'};
			} # end while
			$Spec->delete();
		} # end if
	} # end foreach Spec
	if ( ! openprint::ServicePrice->find('service_id'=>$FoldingService->id(), 'equipment_id'=>$E->id() ) ) {
		foreach my $Pricelist ( openprint::Pricelist->find() ) {
			if ( ! $Pricelist->id() ) {
				print "ERror pricelits: " . $Pricelist->name() . "\n";
			} else {
				my $ServicePrice = new openprint::ServicePrice();
				$_ = $ServicePrice->save({
						'service_id'	=>	$FoldingService->id(),
						'pricelist_id'	=>	$Pricelist->id(),
						'equipment_id'	=>	$E->id(),
						'units'			=>	'Per M',
						'cost'			=>	0,
						'price'			=>	0,
						});
				die $_ if $_;
			}
		} # end foreach Pricelist
	} # end if
} # end foreach Web Press

foreach my $E ( openprint::Equipment->find() ) {
	foreach my $Fold ( openprint::Fold->find('equipment_id'=>$E->id()) ) {
		if ( $Fold->type() =~ /(\d*)PageSignatureFold/ ) {
			$Fold->type( "$1PageFold" );
			$Fold->save();
		} # end if
	} # end foreach
} # end foreach

foreach my $E ( openprint::Equipment->find() ) {
	foreach my $Fold ( openprint::Fold->find('equipment_id'=>$E->id()) ) {
		if ( $Fold->type() =~ /(\d*)PageFold/ ) {
			sql::update( undef, undef, 'Services', ['name=?', "$1PageSignatureFold"], 'name', "$1PageFold" );
			sql::update( undef, undef, 'Services', ['name=?', "$1PageSignatureFoldMakeReady"], 'name', "$1PageFoldMakeReady" );
		} # end if
	} # end foreach
} # end foreach

$dbh->do('UPDATE folds set max_calliper=0.04/(pages/4) where equipment_id=7');

$dbh->disconnect();
print "Finished\n";
1;
__END__
