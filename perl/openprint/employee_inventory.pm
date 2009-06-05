package openprint::employee_inventory;
use MIME::QuotedPrint;
use Text::CSV_XS;
use strict;
require sql;
require misc;
require openprint::paper;

require openprint::pricelist;
require openprint::paper_price;
require openprint::paper_priceset;
require openprint::StockPurpose;
require openprint::PaperInventory;
require openprint::StockName;
require openprint::StockFinish;
require openprint::StockColour;
require openprint::RFIDTag;
require openprint::RFIDTagType;
require openprint::RFIDTagHistory;
require openprint::RFIDScanner;
require openprint::RFIDScannerHistory;
require openprint::Manifest;
require openprint::ManifestContent;
require openprint::Manifest_Content_Type;
require openprint::PaperAllocation;
require openprint::PurchaseOrder;

use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

sub skids {
	if ( $param{'btnFunction'} eq 'Delete' )  {
		if ( $param{'skid_id'} ) {
			$param{'skid_id'} =~ s/[^\d\-\,]//g;
			my @skid_ids;
			foreach my $range ( split ',', $param{'skid_id'} ) {
				if ( $range =~ /(\d*)\-(\d*)/ ) {
					push @skid_ids, ( $1 .. $2 );
				} else {
					push @skid_ids, $range;
				} # end if
			} # end foreach
			foreach my $skid_id ( @skid_ids ) {
				my $Skid = new openprint::Skid( $skid_id );
				$Skid->delete();
				$variable{'information'} .= "Skid $$Skid{'id'} has been deleted.<br/>";
			} # end foreach
		} elsif ( $param{'skids'} ) {
			foreach my $skid_id ( ref $param{'skids'} eq 'ARRAY' ? @{$param{'skids'}} : $param{'skids'} ) {
				my $Skid = new openprint::Skid( $skid_id );
				$Skid->delete();
				$variable{'information'} .= "Skid $$Skid{'id'} has been deleted.<br/>";
			} # end foreach
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Destroy' )  {
		if ( $param{'skid_id'} ) {
			$param{'skid_id'} =~ s/[^\d\-\,]//g;
			my @skid_ids;
			foreach my $range ( split ',', $param{'skid_id'} ) {
				if ( $range =~ /(\d*)\-(\d*)/ ) {
					push @skid_ids, ( $1 .. $2 );
				} else {
					push @skid_ids, $range;
				} # end if
			} # end foreach
			foreach my $skid_id ( @skid_ids ) {
				my $Skid = new openprint::Skid( $skid_id );
				if ( $_ = $Skid->destroy() ) {
					$variable{'error'} .= $_;
				} else {
					$variable{'information'} .= "Skid $$Skid{'id'} has been destoryed.<br/>";
				} # end if
			} # end foreach
		} elsif ( $param{'skids'} ) {
			foreach my $skid_id ( ref $param{'skids'} eq 'ARRAY' ? @{$param{'skids'}} : $param{'skids'} ) {
				my $Skid = new openprint::Skid( $skid_id );
				$Skid->delete();
				$variable{'information'} .= "Skid $$Skid{'id'} has been deleted.<br/>";
			} # end foreach
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Allocate' ) {
		if ( $param{'skid_id'} ) {
			$param{'skid_id'} =~ s/[^\d\-\,]//g;
			$param{Project} =~ s/\D//g;
			$param{Docket} =~ s/\D//g;
			my @Projects = openprint::Project::find( 'id'=>$param{Project}, 'docket'=>$param{Docket} ) if $param{Project} or $param{Docket};

			if ( ! @Projects ) {
				$variable{'error'} .= 'An invalid Docket or Project # was given. No paper allocated.<br/>';
				return;
			} # end if
			foreach my $skid_id ( split(',', $param{'skid_id'} ) ) {
				$skid_id =~ s/\D//g;
				next if ! $skid_id;
				my $Skid = new openprint::Skid( $skid_id );
				foreach my $C ( $Skid->Contents() ) {
					$C->Paper()->allocate( $skid_id, $Projects[0]->id(), $C->quantity(), $C->Paper()->type() eq 'Roll' ? 'lbs' : 'sheets' );
				} # end foreach Paper
			} # end foreach Skid
		} # end if

	} # end if
} # end sub skids

sub inventory_report {
	my %param = @_;
	my @header = ('ID','Owner','Manufacturer','Name','Finish','Colour','Weight','Type','Width','Height','Quality', 'MWeight','GSM','Skid#','RFIDTag #','Date Added','Location', 'In Stock (sheets)','In Stock(lbs)');
	my @papers = openprint::Paper::find(
			'owner_id'	=>	( defined $param{'Owner'} ? $param{'Owner'} : '' ),
			'manufacturer_id'	=>	( defined $param{'Manufacturer'} ? $param{'Manufacturer'} : undef ),
			'name_id'	=>	( defined $param{'Name'} ? $param{'Name'} : undef ),
			'finish_id' =>	( defined $param{'Finish'} ? $param{'Finish'} : undef ),
			'colour_id' =>	( defined $param{'Colour'} ? $param{'Colour'} : undef ),
			'weight_id' =>	( defined $param{'Weight'} ? $param{'Weight'} : undef ),
			'type'		=>	$param{'Type'},
			'created_on_start'  => defined $param{'StartYear'} ? sprintf('%.4d-%.2d-%.2d 00:00:00', @param{'StartYear','StartMonth','StartDay'} ) : undef,
			'created_on_end'    => sprintf('%.4d-%.2d-%.2d 23:59:59', @param{'EndYear','EndMonth','EndDay'} ),
			'allocated_to_docket'   => $param{'Docket'},
			'fsc_code'  =>  $param{'fsc_code'},
			'order_by'	=> 'owner_id,manufacturer_id,name_id,finish_id,colour_id,weight_id,width,height',
			);
	my $date = Date::Format::time2str('%Y-%m-%d %H:%M', time );
	my @data;
	my $total_weight = 0;
	foreach my $Paper ( @papers ) {
		if ( $param{'width'} ) {
			if ( $param{'OrLarger'} ) {
				next if $Paper->width() < $param{'width'};
			} else {
				next if $Paper->width() != $param{'width'};
			} # end if
		} # end if
		if ( $param{'height'} ) {
			if ( $param{'OrLarger'} ) {
				next if $Paper->height() < $param{'height'};
			} else {
				next if $Paper->height() != $param{'height'};
			} # end if
		} # end if
		foreach my $Skid ( $Paper->skids() ) {
			my $weight = 0;
			if ( $Paper->type() eq 'Roll' ) {
			$weight = $$Skid{Paper}{$$Paper{'id'}};
			} else {
			$weight += $Paper->wpsi() * $Paper->width() * $Paper->height() * $$Skid{Paper}{$$Paper{'id'}};
			} # end if
			$total_weight += $weight;
			push @data,(
					$$Paper{'id'},
					new openprint::Company($Paper->owner_id())->name(),
					$Paper->manufacturer(),
					$Paper->name(),
					$Paper->finish(),
					$Paper->colour(),
					$Paper->weight(),
					$Paper->type(),
					$Paper->width(),
					$Paper->height(),
					$Paper->quality(),
					$Paper->mweight(),
					$Paper->gsm(),
					$$Skid{'id'},
					$$Skid{'rfidtag_id'},
					$$Skid{'created_on'},
					$Skid->Location()->name(),
					$Paper->type() eq 'Sheet' ? $$Skid{Paper}{$$Paper{'id'}} : '',
					$weight,
					);
		} # end foreach skid
	} # end foreach
	#my $date;
	push @data, ( 'Report generated',$date,undef,undef,undef,undef,undef, undef, undef, undef, undef, undef, undef, undef, undef, undef,undef, 'Total Weight (lbs):', $total_weight );
	return ( \@header, \@data );
} # end sub paper_inventory

sub paper {
	if ( $param{'btnFunction'} eq 'Consumption Report' ) {
		my @header = ('Date','Operator','Owner','Name','Finish','Colour','Weight','Width','Height','Quality', 'MWeight','GSM','Skid#','Amount','Comment');
		my @data;
		my @inventory = openprint::PaperInventory::find(
				'updated_on_start'  => sprintf('%.4d-%.2d-%.2d 00:00:00', @param{'StartYear','StartMonth','StartDay'} ),
				'updated_on_end'    => sprintf('%.4d-%.2d-%.2d 23:59:59', @param{'EndYear','EndMonth','EndDay'} ),
				'order'=>'updated_on',
		);
		foreach my $I ( @inventory ) {
			my $Paper = $I->Paper();
			push @data, 
Date::Format::time2str('%Y-%m-%d %H:%M', Date::Parse::str2time($I->updated_on())),
				$I->User()->name(),
				$Paper->Owner()->name(),
				$Paper->name(),
				$Paper->finish(),
				$Paper->colour(),
				$Paper->weight(),
				$Paper->width(),
				$Paper->height(),
				$Paper->quality(),
				$Paper->mweight(),
				$Paper->gsm(),
				$I->skid_id(),
				$I->delta . $I->units,
				$I->comment;
		} # end while
		my $date = Date::Format::time2str('%Y-%m-%d %H:%M', time );
		push @data, ( 'Report generated',$date,undef,undef,undef,undef, undef, undef, undef, undef, undef, undef );
		misc::export_csv( $r, $log, \%variable, "PaperConsumption $date.csv", \@header, \@data );
	} elsif ( $param{'btnFunction'} eq 'Download Log' ) {

		my @header = ('Date','Operator','Owner','Name','Finish','Colour','Weight','Width','Height','Quality', 'MWeight','GSM','Skid#','Amount','Comment');
		my @info = sql::execute( $log, $dbh, q{SELECT paper_id, skid_id, user_id, delta, units, updated_on, comment FROM paper_inventory ORDER BY updated_on DESC} );
		my @data;
		while ( my ( $paper_id, $skid_id, $user_id, $delta, $units, $time, $comment ) = splice @info, 0, 7 ) {
			my $Paper = new openprint::Paper( $paper_id );
			push @data, $time, new openprint::User($user_id)->name(),
				 new openprint::Company($Paper->owner_id())->name(),
				 $Paper->name(),
				 $Paper->finish(),
				 $Paper->colour(),
				 $Paper->weight(),
				 $Paper->width(),
				 $Paper->height(),
				 $Paper->quality(),
				 $Paper->mweight(),
				 $Paper->gsm(),
				 $skid_id,
				 $delta . $units,
				 $comment;
		} # end while
		my $date = Date::Format::time2str('%Y-%m-%d %H:%M', time );
		push @data, ( 'Report generated',$date,undef,undef,undef,undef, undef, undef, undef, undef, undef, undef );
		misc::export_csv( $r, $log, \%variable, "PaperInventoryLog $date.csv", \@header, \@data );
	} elsif ( $param{'btnFunction'} eq 'Download Inventory' ) {
		my ( $header, $data ) = inventory_report( %param );
		my $date = Date::Format::time2str('%Y-%m-%d %H:%M', time );
		misc::export_csv( $r, $log, \%variable, "PaperInventory $date.csv", $header, $data );

	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		if ( $param{'paper_id'} ) {
			my $Paper = new openprint::Paper( $param{'paper_id'} );
			$Paper->delete();
			$variable{'information'} .= "Paper $$Paper{'id'} has been deleted.";
		} elsif ( $param{'papers'} ) {
			my $ac = sql::start_transaction( undef );		
			my @papers = openprint::Paper::find('id'=>$param{'papers'});

			foreach my $Paper ( @papers ) {
				$Paper->delete();
			} # end foreach
			sql::end_transaction( undef, $ac );
			$variable{'information'} .= @papers . ' Papers have been deleted.';
		} # end if

	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		foreach my $key ( keys %param ) {
			if ( $key =~ /txtInStock(\d*)/ ) {
				my $paper_index = $1;
				my $delta = 0;
				my ( $instock ) = sql::execute( $log, $dbh, 'SELECT InStock FROM Paper_Inventory WHERE PaperIndex=? AND updated_on = (SELECT MAX(updated_on) FROM Paper_Inventory WHERE PaperIndex=?)', $paper_index, $paper_index );
				if ( $param{$key} =~ /[\-\+]\d*/ ) {
					$delta = $param{$key};
				} else {
					$delta = $param{$key} - $instock;
				} # end if
				if ( $delta != 0 ) {
					sql::insert($log, $dbh, 'Paper_Inventory', [
						'PaperIndex',	$paper_index,
						'InStock',		$instock + $delta,
						'Delta',		$delta,
						'UserIndex',	$session{'user_id'},
						'updated_on',	'NOW()',
						'Comment',		'Stock Check',
						] );
				} # end if

			} # end if
		} # end foreach
	} # end if

} # end sub paper

sub paper_details {
	my $Paper = new openprint::Paper( $param{'paper_id'} );
	if ( $param{'btnFunction'} eq 'Previous' ) {
		$Paper = $Paper->previous();
	} elsif ( $param{'btnFunction'} eq 'Next' ) {
		$Paper = $Paper->next();
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		$Paper->owner_id( $param{'Owner'} );
		$Paper->manufacturer( $param{'txtManufacturer'} ) if $param{'txtManufacturer'};
		$Paper->manufacturer_id( $param{'Manufacturer'} ) if $param{'Manufacturer'};
		$Paper->name( $param{'txtName'} ) if $param{'txtName'};
		$Paper->name_id( $param{'Name'} ) if $param{'Name'};
		$Paper->finish( $param{'txtFinish'} ) if $param{'txtFinish'};
		$Paper->finish_id( $param{'Finish'} ) if $param{'Finish'};
		$Paper->colour( $param{'txtColour'} ) if $param{'txtColour'};
		$Paper->colour_id( $param{'Colour'} ) if $param{'Colour'};
		$Paper->weight( $param{'txtWeight'} ) if $param{'txtWeight'};
		$Paper->weight_id( $param{'Weight'} ) if $param{'Weight'};
		$Paper->quality( $param{'txtQuality'} ) if $param{'txtQuality'};
		$Paper->quality_id( $param{'Quality'} ) if $param{'Quality'};
		$Paper->type( $param{'type'} );
		if ( $param{'type'} eq 'Roll' ) {
			$Paper->width( $param{'width'} );
			$Paper->height( undef );
		} else { #Sheet
			$Paper->width( $param{'width'} );
			$Paper->height( $param{'height'} );
		} # end if
		$Paper->mweight( $param{'mweight'} );
		$Paper->basis_weight( $param{'basis_weight'} ) if exists $param{'basis_weight'};
		$Paper->basis_width( $param{'basis_width'} ) if exists $param{'basis_width'};
		$Paper->basis_height( $param{'basis_height'} ) if exists $param{'basis_height'};
		$Paper->gsm( $param{'gsm'} );
		$Paper->calliper( $param{'txtCalliper'} );
		$Paper->fsc_code( $param{'fsc_code'} );
		if ( ! $param{'paper_id'} ) {
			my @papers = openprint::Paper::find(
					'owner_id'	=>	$param{'Owner'},
					'manufacturer'		=>	$param{'txtManufacturer'},
					'manufacturer_id'	=>	$param{'Manufacturer'},
					'name'		=>	$param{'txtName'},
					'name_id'	=>	$param{'Name'},
					'finish'	=>	$param{'txtFinish'},
					'finish_id' =>	$param{'Finish'},
					'colour'	=>	$param{'txtColour'},
					'colour_id' =>	$param{'Colour'},
					'weight'	=>	$param{'txtWeight'},
					'weight_id' =>	$param{'Weight'},
					'width'	=> $param{'width'},
					'height'	=>	$param{'height'},
					'quality'	=>	$param{'txtQuality'},
					'quality_id'	=>	$param{'Quality'},
					);
			if ( @papers ) {
				$variable{'error'} .= qq`A paper matching those parameters already exists. Click here to edit it: <a href="paper_details.html?paper_id=$papers[0]{id}">paper $papers[0]{id}</a>`;
				$variable{'Paper'} = $Paper;
				return;
			} # end if
		} # end if
		if ( ! ( $variable{'error'} .= $Paper->save() ) ) {
			$variable{'information'} .= 'Paper successfully saved.<br/>';
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		if ( ! ( $variable{'error'} .= $Paper->delete() ) ) {
			$variable{'information'} .= 'Paper successfully deleted.<br/>';
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Allocate' ) {
		allocate( undef, @param{'paper_id','Quantity','Project','Docket','specific'} );
	} elsif ( $param{'btnFunction'} eq 'CheckOut' ) {
		check_out( undef, @param{'paper_id','Quantity','Project','Docket','reason'} );
	} elsif ( $param{'btnFunction'} eq 'Merge' ) {
		my @Duplicates = openprint::Paper::find(
				'manufacturer_id'	=> $Paper->manufacturer_id(),
				'name_id'			=> $Paper->name_id(),
				'finish_id'			=> $Paper->finish_id(),
				'colour_id'			=> $Paper->colour_id(),
				'weight_id'			=> $Paper->weight_id(),
				'width'				=> $Paper->width(),
				'height'			=> $Paper->height(),
				);

		foreach my $Duplicate ( @Duplicates ) {
			next if $Duplicate->id() == $Paper->id();
			my $ac = sql::start_transaction( $dbh );
			sql::update( undef, undef, 'Paper_allocations', [ 'paper_id=?', $Duplicate->id() ], 'paper_id', $Paper->id() );
			sql::update( undef, undef, 'Paper_Inventory', [ 'paper_id=?', $Duplicate->id() ], 'paper_id', $Paper->id() );
			sql::update( undef, undef, 'skid_contents', [ 'paper_id=?', $Duplicate->id() ], 'paper_id', $Paper->id() );
			$Duplicate->delete();
			sql::end_transaction( $dbh, $ac );
		} # end foreach
	} # end if
	$variable{'Paper'} = $Paper;
	$variable{'paper_id'} = $$Paper{'id'};
} # end sub paper_details

sub save_Paper {
	my ( $id ) = @_;

	my $weight;
	if ( $param{'txtWeight'.$id} ) {
		$weight = $param{'txtWeight'.$id};
	} elsif ( $param{'weight'.$id} ) {
		$weight = $param{'weight'.$id};
		$weight .= 'lb' if ! ( $param{'weight'.$id} =~ /lb/ );
	} elsif ( $param{'calliper'.$id} ) {
		if ( $param{'calliper'.$id} < 1 ) {
			$weight = ($param{'calliper'.$id}*1000).'PT';
		} else {
			$weight =( 1*$param{'calliper'.$id}) . 'PT';
		} # end if
	} # end if

	my @papers = openprint::Paper::find(
			'owner_id'	=>	$param{'Owner'.$id},
			'manufacturer_id'	=>	$param{'Manufacturer'.$id},
			'manufacturer'		=>	$param{'txtManufacturer'.$id},
			'name_id'	=>	$param{'Name'.$id},
			'name'		=>	$param{'txtName'.$id},
			'finish_id' =>	$param{'Finish'.$id},
			'finish'	=>	$param{'txtFinish'.$id},
			'colour_id' =>	$param{'Colour'.$id},
			'colour'	=>	$param{'txtColour'.$id},
			'weight_id' =>	$param{'Weight'.$id},
			'weight'	=>	$weight,
			'quality_id' => $param{'Quality'.$id},
			'quality'	=>	$param{'txtQuality'.$id},
			'width'	=> $param{'width'.$id},
			'height'	=>	$param{'type'.$id} ne 'Roll' ? $param{'height'.$id} : undef,
			'type'	=>	$param{'type'.$id},
			);
	my $Paper;

# Paper not found, this is the first time we are adding it to the skid
	if ( 0 == @papers ) {
		$Paper = new openprint::Paper( );
		$Paper->owner_id( $param{'Owner'.$id} );
		$Paper->manufacturer( $param{'txtManufacturer'.$id} ) if $param{'txtManufacturer'.$id};
		$Paper->manufacturer_id( $param{'Manufacturer'.$id} ) if $param{'Manufacturer'.$id};
		$Paper->name( $param{'txtName'.$id} ) if $param{'txtName'.$id};
		$Paper->name_id( $param{'Name'.$id} ) if $param{'Name'.$id};
		$Paper->finish( $param{'txtFinish'.$id} ) if $param{'txtFinish'.$id};
		$Paper->finish_id( $param{'Finish'.$id} ) if $param{'Finish'.$id};
		$Paper->colour( $param{'txtColour'.$id} ) if $param{'txtColour'.$id};
		$Paper->colour_id( $param{'Colour'.$id} ) if $param{'Colour'.$id};
		$Paper->weight( $weight ) if $weight;
		$Paper->weight_id( $param{'Weight'.$id} ) if $param{'Weight'.$id};
		$Paper->quality( $param{'txtQuality'.$id} ) if $param{'txtQuality'.$id};
		$Paper->quality_id( $param{'Quality'.$id} ) if $param{'Quality'.$id};
		$Paper->type( $param{'type'.$id} );
		$Paper->fsc_code( $param{'fsc_code'.$id} );
		if ( $param{'type'.$id} eq 'Roll' ) {
			$Paper->width( $param{'width'.$id} );
			$Paper->height( undef );
		} else { #Sheet
			$Paper->width( $param{'width'.$id} );
			$Paper->height( $param{'height'.$id} );
		} # end if
		if ( $param{'weight'.$id} ) {
			$Paper->basis_weight( $param{'weight'.$id} * 2 );
		} # end if
		$Paper->calliper( $param{'calliper'.$id} );
		$Paper->mweight( $param{'mweight'.$id} );
		$Paper->gsm( $param{'gsm'.$id} );
		if ( my $error = $Paper->save() ) {
			$variable{'error'} .= $error;
		} else {
			$variable{'information'} .= 'Paper created.<br/>';
		} # end if
	} elsif ( 1 == @papers ) {
		$Paper = shift @papers;
		my $changed = 0;
# This is so that papers that don't have mweights will get filled in
		if ( ( ! $Paper->basis_weight() ) and $param{'weight'.$id} ) {
			$Paper->basis_weight( $param{'weight'.$id} * 2 );
			$changed = 1;
		} # end if
		if ( ( ! $Paper->calliper() ) and $param{'calliper'.$id} ) {
			$Paper->calliper( $param{'calliper'.$id} );
			$changed = 1;
		} # end if
		if ( ( ! $Paper->mweight() ) and $param{'txtMWeight'.$id} ) {
			$Paper->mweight( $param{'txtMWeight'.$id} );
			$changed = 1;
		} # end if
		if ( ( ! $Paper->gsm() ) and $param{'gsm'.$id} ) {
			$Paper->gsm( $param{'gsm'.$id} );
			$changed = 1;
		} # end if
		$Paper->save() if $changed;
	} else {
		$variable{'error'} .= 'Duplicate Paper Detected!.<br/>';
		$variable{'information'} .= 'The following papers both match, please edit them:<br/>';
		foreach my $Paper ( @papers ) {
			$variable{'information'}	.= '<a href="paper_details.html?paper_id='.$Paper->id().'">'.$Paper->to_string().'</a><br/>';
		} # end foreach
	} # end if
	return $Paper;
} # end sub save_Paper

sub save_inventory {
	my ( $Skid, $Paper, $qty, $comment ) = @_;
	my $delta = $Skid->add( $Paper, $qty );
	$Paper->add_inventory( $Skid, $delta, $param{'Units'}, $comment );
#FIXME
	if ( $delta > 0 ) {
		$variable{'information'} .= sprintf( 'Added %1$d%2$s to inventory for skid <a href="/employee/inventory/skid_details.html?skid_id=%3$d">%3$d</a>.<br/>', $delta,$Paper->type() eq 'Roll' ? 'lbs' : 'sheets', $Skid->id() );
	} elsif ( $delta < 0 ) {
		$variable{'information'} .= sprintf( 'Removed %1$d%2$s from inventory for skid <a href="/employee/inventory/skid_details.html?skid_id=%3$d">%3$d</a>.<br/>', $delta,$Paper->type() eq 'Roll' ? 'lbs' : 'sheets', $Skid->id() );
	} else {
		$variable{'information'} .= sprintf( 'No change was made to inventory for skid <a href="/employee/inventory/skid_details.html?skid_id=%1$d">%1$d</a>.<br/>', $Skid->id() );
	}# end if

	$Skid->save();
} # end if

sub save_skid {
	my ( $Skid, $qty ) = @_;

	$qty = $param{'Quantity'} if ! defined $qty;

	$Skid->rfidtag_id( $param{'rfidtag_id'} ) if exists $param{'rfidtag_id'};
$openprint::log->debug("RFID: $param{'rfidtag_id'} $$Skid{'rfidtag_id'}");
	$Skid->location_id( $param{'location_id'} ) if $param{'location_id'};
	$Skid->location_id( $param{'ddmLocation'} ) if $param{'ddmLocation'};
	$Skid->location( $param{'txtLocation'} ) if $param{'txtLocation'};
	$Skid->id( $param{'skid_id'} ) if $param{'skid_id'} and ! $Skid->id();
	if ( my $error = $Skid->save() ) {
		$variable{'error'} .= $error;
		return;
	} # end if
	
	if ( $param{'Name'} or $param{'txtName'} ) {
		my $Paper = save_Paper();

		if ( $Paper and $Paper->id() ) {
			save_inventory( $Skid, $Paper, $qty );

			if ( $param{'Docket'} ) {
				my @Projects = openprint::Project::find('docket'=>$param{'Docket'} );

				if ( ! @Projects ) {
					$variable{'error'} .= "Docket $param{'Docket'} not found. No paper allocated. CSR not notified.<br/>";
				} else {
					my $Project = shift @Projects if @Projects;
					if ( exists $param{'allocate'} ) {
						if ( $param{'allocate'} eq 'Specific' ) {
							$Paper->allocate( $$Skid{'id'}, $Project->id(), $qty, $param{'Units'} );
						} # end if
					} else {
						$Paper->allocate( undef, $Project->id(), $qty, $param{'Units'} );
					} # end if
					$variable{'information'} .= sprintf('Allocated %1$d%2$s to docket <a href="/employee/project/view.html?ProjectIndex=%3$d">%4$d</a>.<br/>', $qty, $param{'Units'}, $Project->id(), $Project->docket() );
				} # end if
			} # end if
		} # end if Paper
	} elsif ( $param{'Docket'} ) {
		my @Projects = openprint::Project::find('docket'=>$param{'Docket'} );

		if ( ! @Projects ) {
			$variable{'error'} .= "Docket $param{'Docket'} not found. No paper allocated.<br/>";
		} else {
			$Skid->allocate( undef, $Projects[0]->id(), $qty, $param{'Units'} );
			$variable{'information'} .= sprintf('Allocated %1$d%2$s to docket <a href="/employee/project/view.html?ProjectIndex=%3$d">%4$d</a>.<br/>', $qty, $param{'Units'}, $Projects[0]->id(), $Projects[0]->docket() );
		} # end if
	} # end if
} # end sub save_skid

sub skid_details {
	if ( $param{'skids'} ) {
		$param{'skid_id'} = join(',', ref $param{'skids'} eq 'ARRAY' ? @{$param{'skids'}} : $param{'skids'} );
	} # end if
	$param{'skid_id'} =~ s/[^\d\-\,]//g;
	my @skid_ids;
	foreach my $range ( split ',', $param{'skid_id'} ) {
		if ( $range =~ /(\d*)\-(\d*)/ ) {
			push @skid_ids, ( $1 .. $2 );
		} else {
			push @skid_ids, $range;
		} # end if
	} # end foreach

	if ( $param{'skid_id'} and ! openprint::Skid::find( 'id'=>\@skid_ids, 'deleted'=>[0,1] ) ) {
		$variable{'error'} .= "Skid $param{'skid_id'} not found!<br/>";
		return;
	} # end if

	$variable{'Skid'} = new openprint::Skid( @skid_ids ? $skid_ids[0] : undef );
	$variable{'skid_id'} = $param{'skid_id'};
	@{$variable{'skid_ids'}} = @skid_ids;

	$variable{'similar'} = 1;
	my $Skid = new openprint::Skid( $skid_ids[0] );
	foreach ( @skid_ids ) {
		my $S = new openprint::Skid( $_ );
		if ( sets::intersection( map {$_->paper_id} ( $S->Contents(), $Skid->Contents() ) ) != scalar map { $_->paper_id } $S->Contents() ) {
			$variable{'similar'} = 0;
			last;
		} # end if
	} # end foreach

	if ( $param{'btnFunction'} eq 'Previous' ) {
		@skid_ids = ( (new openprint::Skid( @skid_ids ? $skid_ids[0] : undef ))->previous()->id());
		$param{'skid_id'} = $skid_ids[0];
	} elsif ( $param{'btnFunction'} eq 'Next' ) {
		@skid_ids = ( (new openprint::Skid( @skid_ids ? $skid_ids[0] : undef ))->next()->id());
		$param{'skid_id'} = $skid_ids[0];
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		my @quantities = misc::trim( split ',', $param{'Quantity'} );

		if ( @skid_ids and (@quantities>1) and ( @quantities != @skid_ids ) ) {
			$variable{'error'} .= 'When saving to multiple skids, the # of quantities must match the # of skids.';
			return;
		} # end if

		if ( $param{'skid_quantity'} ) {
			if ( (@quantities>1) and ( @quantities != $param{'skid_quantity'} ) ) {
				$variable{'error'} .= 'When saving to multiple skids, the # of quantities must match the # of skids.';
				return;
			} # end if
			@{$variable{'Skids'}} = ();
			foreach my $skid_count ( 1 .. $param{'skid_quantity'} ) {
				my $S = new openprint::Skid();
				$param{'Quantity'} = @quantities > 1 ? $quantities[$skid_count-1] : $quantities[0] if @quantities;
				save_skid( $S );
				push @{$variable{'Skids'}}, $S;
				if ( ! $variable{'Paper'} ) {
					if ( my @c = $S->contents() ) {
						$variable{'paper_id'} = $c[0]->paper_id();
						$variable{'Paper'} = new openprint::Paper( $variable{'paper_id'} );
					} # end of
				} # end of
				if ( $param{'verification_code'} ) {
					my $SV = new openprint::Skid_Verification();
					$SV->save({
						'skid_id'	=>	$S->id(),
						'code'		=>	$param{'verification_code'},
						'user_id'	=>	$session{'user_id'},
					});
				} # end if verification_code
			} # end foreach
			$variable{'information'} .= "Added $param{'skid_quantity'} skids.<br/>";
		} else {
			foreach my $skid_id ( @skid_ids ) {
				$param{'Quantity'} = @quantities > 1 ? shift @quantities : $quantities[0] if @quantities;
				save_skid( new openprint::Skid( $skid_id ) );
				if ( $param{'verification_code'} ) {
					my $SV = new openprint::Skid_Verification();
					$SV->save({
						'skid_id'	=>	$skid_id,
						'code'		=>	$param{'verification_code'},
						'user_id'	=>	$session{'user_id'},
					});
				} # end if verification_code
			} # end foreach
		} # end if

	} elsif ( sets::isin( $param{'btnFunction'}, 'Copy', 'Duplicate' ) ) {
		foreach my $skid_id ( @skid_ids ) {
			my $Skid = new openprint::Skid( $skid_id );
			$Skid = $Skid->copy();
			$Skid->save();
		} # end foreach
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		foreach my $skid_id ( @skid_ids ) {
			my $Skid = new openprint::Skid( $skid_id );
			$variable{'information'} .= $Skid->delete();
		} # end foreach
	} elsif ( $param{'btnFunction'} eq 'Print Label' ) {
		foreach my $skid_id ( @skid_ids ) {
			my $Skid = new openprint::Skid( $skid_id );
			$Skid->print_label();
		} # end foreach
	} elsif ( $param{'btnFunction'} eq 'Allocate' ) {
		foreach my $skid_id ( @skid_ids ) {
			allocate( $skid_id, @param{'paper_id', 'Quantity','Project','Docket'} );
		} # end foreach
	} elsif ( $param{'btnFunction'} eq 'Delete Allocation' ) {
		if ( $param{'allocation_id'} ) {
			my $PA = new openprint::PaperAllocation( $param{'allocation_id'} );
			$PA->delete();
		} # end if
	} elsif ( $param{'btnFunction'} eq 'CheckIn' ) {
		foreach my $skid_id ( @skid_ids ) {
			check_in( $skid_id, @param{'paper_id', 'Quantity','Project','Docket','reason'} );
		} # end foreach
	} elsif ( $param{'btnFunction'} eq 'CheckOut' ) {
		my $qty = $param{'Quantity'};
		foreach my $skid_id ( @skid_ids ) {
			$qty -= check_out( $skid_id, $param{'paper_id'}, $qty, @param{'Project','Docket','reason'} );
			last if ! $qty;
		} # end foreach
	} elsif ( $param{'btnFunction'} eq 'DeletePaper' ) {
		foreach my $skid_id ( @skid_ids ) {
			my $Skid = new openprint::Skid( $skid_id );
			foreach my $c ( $Skid->contents('paper_id'=>$param{paper_id}) ) {
				$c->delete();
			} # end foreach
		} # end foreach
	} # end if

	$variable{'Skid'} = new openprint::Skid( @skid_ids ? $skid_ids[0] : undef );
	$variable{'skid_id'} = $param{'skid_id'};
	@{$variable{'skid_ids'}} = @skid_ids;

} # end sub skid_details

sub check_out {
	my ( $skid_id, $paper_id, $quantity, $project_id, $docket, $reason ) = @_;

	if ( ! ( $paper_id or $skid_id ) ) {
		$variable{'error'} .= 'Skid or Paper not specified. No paper checked out.<br/>';
		return;
	} # end if
	my $Paper;
	if ( $paper_id ) {
		$Paper = new openprint::Paper( $paper_id );
	} elsif ( $skid_id ) {
		my $Skid = new openprint::Skid( $skid_id );
		my @cs = $Skid->contents();
		if ( 1 == @cs ) {
			$Paper = new openprint::Paper( $cs[0]->paper_id() );
			$paper_id = $Paper->id();
		} else {
			$variable{'error'} .= 'Skid contains more than one type of paper.	You must specify.<br/>';
			return;
		} # end if
	} # end if

	my $available_qty = $Paper->in_stock();
	my $units = $Paper->type() eq 'Roll' ? 'lbs' : 'sheets';
	$project_id =~ s/\D//g;
	$docket =~ s/\D//g;
	my @Projects = openprint::Project::find( 'id'=>$project_id, 'docket'=>$docket ) if $project_id or $docket;

	my @skids;
	if ( $skid_id ) {
		@skids = ( $skid_id );
	} else {
		@skids = sql::execute( undef, undef, q{SELECT skid_id FROM skid_contents WHERE paper_id=? ORDER BY skid_id}, $paper_id );
	} # end if
	if ( ! @skids ) {
		$variable{'error'} .= 'There are no skids for this paper. Cannot check out.<br/>';
		return;
	} # end if

	my $description =  'Checked out';
	if ( @Projects ) {
		$description .= sprintf( ' for docket <a href="/employee/project/view.html?ProjectIndex=%1$d">%2$d</a>', $Projects[0]->id(), $Projects[0]->docket() );
	} # end if
	if ( $reason ) {
		$description .= ': ' . $reason;
	} # end if

	my $qty = $quantity;
	foreach my $skid_id ( @skids ) {
		my $Skid = new openprint::Skid( $skid_id );
		foreach my $c ( $Skid->contents('paper_id'=>$paper_id) ) {
			if ( $c->quantity() < $qty ) {
				$Paper->add_inventory( $Skid->id(), -1*$c->quantity(), $units, 'Checked out' . @Projects ? ' for docket ' . $Projects[0]->docket() : '' );
				$Paper->allocate( $Skid->id(), $Projects[0]->id(), -1*$c->quantity() ) if $Paper->allocated( $Projects[0]->id() );
				$qty -= $c->quantity();
				$c->delete();
			} else {
				$Paper->add_inventory( $Skid, -1*$qty, $units, $description );
			} # end if
#$Skid->save();
			last if ! $qty;
		} # end foreach content
	} # end foreach skid

	if ( @Projects ) {
		$variable{'information'} .= sprintf('Checked out %1$d%2$s to docket <a href="/employee/project/view.html?ProjectIndex=%3$d">%4$d</a><br/>', $quantity, $units, $docket, $Projects[0]->id(), $Projects[0]->docket() );
	} else {
		$variable{'information'} .= "Checked out $quantity$units to unknown docket.<br/>";
	} # end if
	return $quantity;
} # end sub check_out

sub check_in {
	my ( $skid_id, $paper_id, $quantity, $project_id, $docket, $reason ) = @_;
	if ( ! ( $paper_id or $skid_id ) ) {
		$variable{'error'} .= 'Skid or Paper not specified. No paper checked in.<br/>';
		return;
	} # end if
	my $Paper;
	my $Skid = new openprint::Skid( $skid_id );

	if ( $paper_id ) {
		$Paper = new openprint::Paper( $paper_id );
	} elsif ( $skid_id ) {
		my @cs = $Skid->contents();
		if ( 1 == @cs ) {
			$Paper = new openprint::Paper( $cs[0]->paper_id() );
			$paper_id = $Paper->id();
		} else {
			$variable{'error'} .= 'Skid contains more than one type of paper. You must specify.<br/>';
			return;
		} # end if
	} # end if

	if ( ( $Paper->type() eq 'Roll' ) and ( $quantity > 0 ) ) {
		my $weight = 0;
		foreach my $c ( $Skid->contents('paper_id'=>$Paper->id() ) ) {
			$weight += $c->quantity();
		} # end foreach
		if ( $weight + $quantity > 10000 ) {
			$variable{'error'} .= "Skid cannot hold more than 10000lbs.<br/>";
			return;
		} # end if
	} # end if

	$project_id =~ s/\D//g;
	$docket =~ s/\D//g;
	my @Projects = openprint::Project::find( 'id'=>$project_id, 'docket'=>$docket ) if $project_id or $docket;

# Default to add
	if	( $quantity =~ /^\d/ ) {
		$quantity = '+' . $quantity;
	} # end if

	my $description = 'Added';
	if ( @Projects ) {
		$description .= sprintf(' from docket <a href="/employee/project/view.html?ProjectIndex=%1$d">%2$d</a>', $Projects[0]->id(), $Projects[0]->docket() );
	} # end if
	if ( $reason ) {
		$description .= ' : ' . $reason;
	} # end if

	my $units = $Paper->type() eq 'Roll' ? 'lbs' : 'sheets';
	my $delta = $Skid->add( $Paper, $quantity, $units );
	if ( ! @Projects ) {
		$Paper->add_inventory( $Skid, $delta, $units, $description );
		$variable{'information'} .= "Checked in $quantity$units from unknown docket.<br/>";
	} else {
		my $Project = shift @Projects;
		$Paper->add_inventory( $Skid, $delta, $units, $description );
		$variable{'information'} .= sprintf('Checked in %1$d%2$s from docket <a href="/employee/project/view.html?ProjectIndex=%3$d">%4$d</a><br/>', $quantity, $units, $Project->id(), $Project->docket() );
	} # end if
	$Skid->save();
} # end sub check_in

# allocate
# skid_ids is plural because it may be a comma delimited string of skid_ids
sub allocate {
	my ( $skid_ids, $paper_id, $quantity, $project_id, $docket, $specific ) = @_;
	if ( ! $paper_id ) {
		$variable{'error'} .= 'Paper not specified. No paper allocated.<br/>';
		return;
	} # end if

	my $Paper = new openprint::Paper( $paper_id );
	my $available_qty = $Paper->in_stock() - $Paper->allocated();
	my $units = $Paper->type() eq 'Roll' ? 'lbs' : 'sheets';
	if ( $available_qty < $quantity ) {
		$variable{'error'} .= "Only $available_qty$units are available to be allocated. Please try again.<br/>";
		return;
	} # end if
	$project_id =~ s/\D//g;
	$docket =~ s/\D//g;
	my @Projects = openprint::Project::find( 'id'=>$project_id, 'docket'=>$docket ) if $project_id or $docket;

	if ( $docket and ! @Projects ) {
		if ( my @Orders = openprint::Order::find('docket'=>$docket) ) {
			@Projects = $Orders[0]->Projects();
		} # end if
	} # end if
	if ( ! @Projects ) {
		$variable{'error'} .= 'An invalid Docket or Project # was given. No paper allocated. This can happen if the order has been left re-opened.<br/>';
		return;
	} # end if

	my @allocations = ();
	my @old_skids = ();
	my @skid_ids = split(',', $skid_ids );
	if ( $specific and ! @skid_ids ) {
		if ( $quantity < 0 ) {
			@skid_ids = sql::execute( undef, undef, q{SELECT skid_id FROM paper_allocations WHERE paper_id=? AND quantity > 0 AND project_id=? ORDER BY skid_id}, $paper_id, $Projects[0]->id() );
		} else {
			@skid_ids = sql::execute( undef, undef, q{SELECT skid_id FROM skid_contents WHERE paper_id=? AND quantity > 0 ORDER BY skid_id}, $paper_id );
		} # end if
	} # end if

	my $qty = $quantity;
	if ( @skid_ids ) {
		if ( $qty < 0 ) {
			foreach my $skid_id ( @skid_ids ) {
				my $Skid = new openprint::Skid( $skid_id );
				my $allocateable = $Skid->allocateable( $Paper );
				next if ! $allocateable;

				if ( $allocateable < -1*$qty ) {
					push @allocations, $Paper->allocate( $skid_id, $Projects[0]->id(), -1*$allocateable, $units );
					$qty += $allocateable;
				} else {
					push @allocations, $Paper->allocate( $skid_id, $Projects[0]->id(), $qty, $units );
					$qty = 0;
				} # end if
				last if ! $qty;
			} # end foreach
		} else {
			foreach my $skid_id ( @skid_ids ) {
				my $Skid = new openprint::Skid( $skid_id );
				my $allocateable = $Skid->allocateable( $Paper );
				next if ! $allocateable;

				my @a;
				if ( $allocateable < $qty ) {
					@a = $Paper->allocate( $skid_id, $Projects[0]->id(), $allocateable, $units );
					$qty -= $allocateable;
				} else {
					if ( $Paper->type() eq 'Roll' ) {
						# Must allocate whole rolls
						@a = $Paper->allocate( $skid_id, $Projects[0]->id(), $allocateable, $units );
					} else {
						@a = $Paper->allocate( $skid_id, $Projects[0]->id(), $qty, $units );
					} # end if
					$qty = 0;
				} # end if
				push @allocations, @a;
				if ( $Skid->last_seen_days() > 30 ) {
					push @old_skids, @a;
				} # end if
				last if ! $qty;
			} # end foreach
		} # end if
	} else {
		foreach my $PA ($Paper->allocate( undef, $Projects[0]->id(), $qty, $units ) ) {
			push @allocations, $PA;
			
			if ( $PA->skid_id() and $PA->Skid()->last_seen_days() > 30 ) {
				push @old_skids, $PA;
			} # end if
		} # end foreach PA
	} # end if
	
	if ( @allocations ) {
		stock_allocation_notification( $Projects[0], $Paper, \@allocations, \@old_skids );
		$variable{'information'} .= sprintf('Allocated %d%s to docket <a href="/employee/project/view.html?ProjectIndex=%d">%d</a><br/>', $quantity, $units, $Projects[0]->id(), $Projects[0]->docket() );
	} # end if
} # end sub allocate

sub stock_allocation_notification {
	my ( $Project, $Paper, $allocations, $old_skids ) = @_;

	my %info;
	$info{'Project'} = $Project;
	$info{'Paper'} = $Paper;
	$info{'Allocations'} = $allocations;
	$info{'OldSkids'} = $old_skids;

	my @recipients = openprint::User::find( 'usergroup'=>'InventoryManager' );

    my $offsite = 0;
	my $nolocation = 0;
    foreach my $sig_id ( $Project->signatures() ) {
        my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
        my @Presses;
        if ( $$sig_specs{'UsePress'} ) {
            @Presses = openprint::Equipment::find('strid'=>$$sig_specs{'UsePress'});
        } else {
            @Presses = openprint::Equipment::find('strid'=>$$sig_specs{'ddmPress'.$Project->ordered_quantity_index()});
        } # endif
		if ( @Presses ) {
			foreach my $PA ( @{$allocations} ) {
				if ( ! $PA->Skid()->location_id() ) {
					$nolocation = 1;
				} elsif ( $PA->Skid()->Location()->Root()->id() != $Presses[0]->Location()->Root()->id() ) {
					$offsite = 1;
				} # end if
			} # end foreach PA
		} # end if
    } # end foreach sig
	$info{'offsite'} = $offsite;
	$info{'nolocation'} = $nolocation;

	push @recipients, $Project->Company()->CSR() if $offsite or $nolocation or @$old_skids;

	foreach my $User ( @recipients ) {
		my $From = new openprint::User( $session{'user_id'} );
		my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );

		$info{'ReplacementText'} = "<!--#include virtual=\"/email_content/stock_allocation_notification.html\"-->";
		$_ = encode_qp( ssi::variable_substitution( undef, $log, $dbh, \$email_template, \%info ) );
		my @body = ('', $_, 'text/html', 'quoted-printable');
		my %mail = (
				SMTP    => $openprint::config{'Mail Server'},
				FROM    => sprintf( '"%s" <%s>', $From->name(), $From->email() ),
				TO      => sprintf( '"%s" <%s>', $User->name(), $User->email() ),
				#TO      => 'iconnor@Point-one.com',
				SUBJECT => 'Stock allocated for docket ' . $Project->docket(),
				);
            misc::send_email_with_attachment( $log, \%mail, @body );
	} # end foreach User

} # end sub stock_allocation_notification

sub send_paper_arrival_notification {
	my ( $Skid, @papers ) = @_;
	my %info;
	$info{'Skid'} = $Skid;

	@papers = map { new openprint::Paper( $_ ) } keys %{$Skid->paper()} if ! @papers;

	foreach my $Paper ( @papers ) {
		my $to;
		$info{'Paper'} = $Paper;
		foreach my $c ( $Skid->contents( 'paper_id'=>$Paper->id() ) ) {
			$info{'Quantity'} = $c->quantity();
			my @data = sql::execute( undef, undef, q{SELECT distinct quantity, project_id FROM Paper_Allocations WHERE skid_id=? AND paper_id=?}, $Skid->id(), $Paper->id() );
			while ( @info{'Quantity','project_id'} = splice @data, 0, 2 ) {
				my $Project = new openprint::Project( $info{'project_id'} );
				$info{'Docket'} = $Project->docket();
				my $csr = new openprint::User( $Project->Order()->salesrep_id() );
				$to .= sprintf('"%s" <%s>', $csr->name(), $csr->email() );
			} # end while

#$to .= sprintf(',"%s %s" <%s>', ( 'Duc', '', 'duc@point-one.com' ) );
#$to .= sprintf(',"%s %s" <%s>', ( 'Duc', '', 'iconnor@point-one.com' ) );

			if ( $to ) {
# Send notification to maybe CSR's
				my $From = new openprint::User( $session{'user_id'} );
				my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );

				$info{'ReplacementText'} = "<!--#include virtual=\"/email_content/paper_arrived_notification.html\"-->";
				$_ = encode_qp( ssi::variable_substitution( undef, $log, $dbh, \$email_template, \%info ) );
				my @body = ('', $_, 'text/html', 'quoted-printable');
				my %mail = (
						SMTP	=> $config{'Mail Server'},
						FROM	=> sprintf( '"%s" <%s>', $From->name(), $From->email() ),
						TO		=> $to,
						SUBJECT => 'Paper ' . $Paper->to_string() . ' has arrived',
						);
				misc::send_email_with_attachment( $log, \%mail, @body );
			} # end if to
		} # end foreach skid content
	} # end foreach Paper
} # end sub send_paper_arrival_notification

sub highlight_paper {
	my ( undef, undef, undef, undef, @params ) = @_;

	my %param;
	while ( @params ) {
		my ( $name, $value ) = splice @params, 0, 2;
		if ( exists $param{$name} ) {
			if ( ref($param{$name}) =~ /ARRAY/ ) {
				push @{$param{$name}}, $value;
			} else {
				$param{$name} = [ $param{$name}, $value ];
			} # end if
		} else {
			$param{$name} = $value;
		} # end if
	} # end while


	my @results;
	foreach my $P ( openprint::Paper::find(
				'in_stock_start'	=> 1,
				) ) {
		next if $P->in_stock() - $P->allocated() <= 0;
		if ( $param{Manufacturer} and ($P->manufacturer_id() != $param{Manufacturer} ) ) {
			push @results, $P->id().'~';
			next;
		} # end if
		if ( $param{Name} and ($P->name_id() != $param{Name} ) ) {
			push @results, $P->id().'~';
			next;
		} # end if
		if ( $param{Finish} and ($P->finish_id() != $param{Finish} ) ) {
			push @results, $P->id().'~';
			next;
		} # end if
		if ( $param{Colour} and ($P->colour_id() != $param{Colour} ) ) {
			push @results, $P->id().'~';
			next;
		} # end if
		if ( $param{Weight} and ($P->weight_id() != $param{Weight} ) ) {
			push @results, $P->id().'~';
			next;
		} # end if
		if ( $param{Type} and ! sets::isin( $P->type(), $param{Type} ) ) {
			push @results, $P->id().'~';
			next;
		} # end if
		if ( $param{fsc_code} and ($P->fsc_code() != $param{fsc_code} ) ) {
			push @results, $P->id().'~';
			next;
		} # end if
		if ( $param{Size} and ($P->size() ne $param{Size} ) ) {
			push @results, $P->id().'~';
			next;
		} # end if
		if ( $param{width} ) {
			if (
					($P->width() != $param{width} ) and ( (!$param{'OrLarger'}) or $P->width() < $param{width} )
			   ) {
				push @results, $P->id().'~';
				next;
			} # end if
		} # end if
		if ( $param{height} and ($P->height() ne $param{height} ) ) {
			push @results, $P->id().'~';
			next;
		} # end if
		push @results, $P->id().'~#f8df00';
	} # end foreach
	return join('|',@results );
} # end sub highlight_paper

sub rfidtags {
	if ( $param{'btnFunction'} eq 'Delete' ) {
		foreach my $rfidtag_id ( ref $param{'rfidtags'} eq 'ARRAY' ? @{$param{'rfidtags'}} : split(',',$param{'rfidtags'}) ) {
			my $RFIDTag = new openprint::RFIDTag( $rfidtag_id );
			$variable{'error'} .= $RFIDTag->delete();

		} # end foreach rfidtag_id
	} # end if
} # end sub rfidtags

sub rfidtag_details {
	if ( $param{'btnFunction'} eq 'Go' ) {
		if ( $param{'rfidtag_id'} =~ /^\s*\((.*)\)\s*$/ ) {
			$param{'rfidtag_id'} = hex( $1 );
		} # end if
		my @Tags = openprint::RFIDTag::find('id_like'=>'%'.$param{'rfidtag_id'} );
		if ( ! @Tags ) {
			$variable{'error'} .= 'Tag ID not found.';
		} elsif ( @Tags > 1 ) {
			@{$variable{'Tags'}} = @Tags;
		} else {
			$param{'rfidtag_id'} = $Tags[0]->id();
		} # end if
	} # end if
		
	my $RFIDTag = new openprint::RFIDTag( $param{'rfidtag_id'} );
	$RFIDTag->id( $param{'rfidtag_id'} ) if ! $RFIDTag->id();
	
	if ( $param{'btnFunction'} eq 'Save' ) {
		$variable{'error'} .= $RFIDTag->save( \%param );
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		$variable{'error'} .= $RFIDTag->delete();
	} elsif ( $param{'btnFunction'} eq 'AllocateSkid' ) {
		if ( ! $RFIDTag->skid_id() ) {
			my $Skid = new openprint::Skid();
			$Skid->rfidtag_id( $RFIDTag->id() );
			$Skid->location_id( $RFIDTag->location_id() );
			$variable{'error'} .= $Skid->save();
		} else {
			$variable{'error'} .= 'Skid already allocated<br/>';
		} # end if
	} # end if

	@param{'end_year','end_month','end_day'} = Date::Calc::Today() if ! $param{'end_year'};
	$param{'limit'} = 10 if ! $param{'limit'};
	_rfidtag_log();

	$variable{'RFIDTag'} = $RFIDTag;
} # end sub rfidtag_details

sub rfidscanners {
	if ( $param{'btnFunction'} eq 'Delete' ) {
		if ( $param{'rfidscanners'} ) {
			foreach my $id ( ref $param{'rfidscanners'} eq 'ARRAY' ? @{$param{'rfidscanners'}} : split(',',$param{'rfidscanners'}) ) {
				$variable{'error'} .= new openprint::RFIDScanner( $id )->delete();
			} # end foreach
		} elsif ( $param{'rfidscanner_id'} ) {
			my $RFIDScanner = new openprint::RFIDScanner( $param{'rfidscanner_id'} );
			$variable{'error'} .= $RFIDScanner->delete();
		} # end if
	} # end if
} # end sub rfidtags

sub rfidscanner_details {
	my $RFIDScanner = new openprint::RFIDScanner( $param{'rfidscanner_id'} );
	
	if ( $param{'btnFunction'} eq 'Previous' ) {
		$RFIDScanner = $RFIDScanner->Previous();
		$param{'rfidscanner_id'} = $RFIDScanner->id();
	} elsif ( $param{'btnFunction'} eq 'Next' ) {
		$RFIDScanner = $RFIDScanner->Next();
		$param{'rfidscanner_id'} = $RFIDScanner->id();
	} # end if

	if ( $param{'btnFunction'} eq 'Save' ) {
		$variable{'error'} .= $RFIDScanner->save( \%param );
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		$variable{'error'} .= $RFIDScanner->delete();
	} else {
		@param{'StartYear','StartMonth','StartDay'} = Date::Calc::Today();
		@param{'EndYear','EndMonth','EndDay'} = Date::Calc::Today();
		_rfidscanner_log();
	} # end if

	$variable{'RFIDScanner'} = $RFIDScanner;
} # end sub rfidscanner_details

sub _rfidscanner_log { 
	@param{'StartYear','StartMonth','StartDay'} = Date::Calc::Today() if ! $param{'StartYear'};
	$param{'limit'} = 10 if ! $param{'limit'};

	@{$variable{'Entries'}} = openprint::RFIDScannerHistory::find( 
			'scanner_id'		=>	$param{'rfidscanner_id'},
			'updated_on_start'  =>  Date::Calc::check_date( @param{'StartYear','StartMonth','StartDay'} ) ? sprintf('%.4d-%.2d-%.2d 00:00:00', @param{'StartYear','StartMonth','StartDay'} ) : undef,
			'updated_on_end'    =>  Date::Calc::check_date( @param{'EndYear','EndMonth','EndDay'} ) ?  sprintf('%.4d-%.2d-%.2d 23:59:59', @param{'EndYear','EndMonth','EndDay'} ) : undef,
			'limit'     =>  $param{'limit'},
			'order'     =>  'updated_on DESC',
			);
	if ( ! @{$variable{'Entries'}} ) {
		my @Entries = openprint::RFIDScannerHistory::find(
				'scanner_id'=>	$param{'rfidscanner_id'},
				'limit'		=>	1,
				'order'     =>  'updated_on DESC',
				);
		if ( @Entries ) {
			@param{'StartYear','StartMonth','StartDay'} = $Entries[0]->updated_on() =~ /^(\d+)-(\d+)-(\d+)/;
			@{$variable{'Entries'}} = openprint::RFIDScannerHistory::find( 
					'scanner_id'=>$param{'rfidscanner_id'},
					'updated_on_start'  =>  Date::Calc::check_date( @param{'StartYear','StartMonth','StartDay'} ) ? sprintf('%.4d-%.2d-%.2d 00:00:00', @param{'StartYear','StartMonth','StartDay'} ) : undef,
					'updated_on_end'    =>  Date::Calc::check_date( @param{'EndYear','EndMonth','EndDay'} ) ?  sprintf('%.4d-%.2d-%.2d 23:59:59', @param{'EndYear','EndMonth','EndDay'} ) : undef,
					'limit'     =>  $param{'limit'},
					'order'     =>  'updated_on DESC',
					);
		} # end if
	} # end if

} # end sub rfid_scanner_log

sub manifest {
	$param{'manifest_id'} =~ s/\s//g;
	my $Manifest = new openprint::Manifest( $param{'manifest_id'} );
	if ( $param{'btnFunction'} eq 'Submit' ) {
		$Manifest->id( $param{'manifest_id'} ) if ! $Manifest->id();
		$Manifest->received_on( join('-', @param{'received_on_year','received_on_month','received_on_day'} ) );

		if ( $param{'supplier'} and ! $param{'supplier_id'} ) {
			my @Companies = openprint::Company::find( 'name'=>$param{'supplier'} );
			if ( ! @Companies ) {
				my $C = new openprint::Company();
				$C->save({
						'supplier'      => 'Y',
						'name'          => $param{'supplier'},
						'business_name' => $param{'supplier'},
						} );
				$param{'supplier_id'} = $C->id();
			} elsif ( @Companies == 1 ) {
				if ( $Companies[0]->supplier() ne 'Y' ) {
					$Companies[0]->save( {'supplier'=>'Y'} );
				} # end if
				$param{'supplier_id'} = $Companies[0]->id();
			} # end if
		} # end if

		$variable{'error'} .= $Manifest->save( \%param );

		my @Types = openprint::Manifest_Content_Type::find('manifest_id'=>$Manifest->id());
		if ( ! @Types ) {
			my $Type = new openprint::Manifest_Content_Type();
			$variable{'error'} .= $Type->save({'manifest_id'=>$Manifest->id()});
		} else {
			foreach my $Type ( openprint::Manifest_Content_Type::find('manifest_id'=>$Manifest->id()) ) {
				my $Paper = save_Paper('-'.$Type->id());
				if ( ! $Paper ) {
					$variable{'error'} .= 'Unable to get Stock.<br/>';
					next;
				} # end if
				my %data = (
					'docket'	=>	$param{'docket-'.$Type->id()},
					'paper_id'	=>	$Paper->id(),
					'po_id'		=>	$param{'po_id-'.$Type->id()},
				);
				$data{'cost'} = $param{'cost-'.$Type->id()} if exists $param{'cost-'.$Type->id()};
				$data{'supplier_invoice'} = $param{'supplier_invoice-'.$Type->id()} if exists $param{'supplier_invoice-'.$Type->id()};
				$variable{'error'} .= $Type->save(\%data);

				my $Project;
				if ( $param{'docket-'.$Type->id()} ) {
					my @Projects = openprint::Project::find('docket'=>$param{'docket-'.$Type->id()});
					if ( ! @Projects ) {
						$variable{'error'} .= 'Docket ' . $param{'docket-'.$Type->id()} . ' not found.  No allocations made.<br/>';
					} else {
						$Project = $Projects[0];
					} # end if
				} # end if
				if ( $param{'po_id-'.$Type->id()} ) {
					my $PO = new openprint::PurchaseOrder( $param{'po_id-'.$Type->id()} );
					if ( $PO->id() ) {
						$variable{'error'} .= $PO->save({'manifest_id'=>$Manifest->id()});
					} else {
						$variable{'error'} .= 'Purchase Order ' . $param{'po_id-'.$Type->id()} . ' was not found in the system.<br/>';
					} # end if
				} # end if po_id

				# Save any new entries that might have been entered but not added.
				if ( $param{"rfidtag_id-$$Type{id}-"} or $param{"skid_id-$$Type{id}-"} ) {
					@param{"rfidtag_id-$$Type{id}-","skid_id-$$Type{id}-"} = misc::trim(@param{"rfidtag_id-$$Type{id}-","skid_id-$$Type{id}-"});
					my $Tag = new openprint::RFIDTag( $param{"rfidtag_id-$$Type{id}-"} );
					$variable{'error'} .= $Tag->save({'id'=>$param{"rfidtag_id-$$Type{id}-"}}) if $param{"rfidtag_id-$$Type{id}-"} and ! $Tag->id();
					my $Skid = new openprint::Skid( $param{"skid_id-$$Type{id}-"} );
					$Skid = $Tag->Skid() if $Tag->id() and ! $Skid->id();
					$variable{'error'} .= $Skid->save() if ! $Skid->id();

					if ( $Tag->id() and sets::isin( $Tag->id(), map { $_->Skid()->rfidtag_id() } $Manifest->Contents() ) ) {
						#$variable{'error'} .= 'RFID Tag ' . $Tag->id() . ' has already been scanned.';
					} elsif ( $Skid->id() and sets::isin( $Skid->id(), map { $_->skid_id() } $Manifest->Contents() ) ) {
						#$variable{'error'} .= 'Skid ' . $Skid->id(). ' has already been scanned.';
					} else {
						my $MC = new openprint::ManifestContent();
						$variable{'error'} .= $MC->save( {
								'type_id'		=>	$Type->id(),
								'skid_id'		=>	$Skid->id(),
								'manifest_id'	=>	$Manifest->id(),
								'quantity'		=>	sprintf('%d', $param{"qty_lbs-$$Type{id}-"}),
								} );
					} # end if
				} # end if
				my $total_qty = 0;
				# Save data for the rest of the contents
				foreach my $C ( $Manifest->Contents( 'type_id' => $Type->id() ) ) {
					if ( exists $param{"qty_lbs-$$Type{id}-$$C{id}"} ) {
						$variable{'error'} .= $C->save( {
								'quantity'		=>	sprintf('%d', $param{"qty_lbs-$$Type{id}-$$C{id}"}),
								} );
					} # end if
					$total_qty += $C->quantity();
					save_inventory( $C->Skid(), $Paper, $C->quantity(), sprintf('Inventory adjusted from manifest <a href=/employee/inventory/manifest_id=%1$s">%1$s</a>.', $Manifest->id() ) );
					#if ( $Project and ( $param{"allocate-$$Type{id}"} eq 'Specific' ) ) {
					if ( $Project ) {
						my @PAs = openprint::PaperAllocation::find('skid_id'=>$C->skid_id());
						if ( ! @PAs ) {
							$Paper->allocate( $C->Skid(), $Project->id(), $C->quantity(), $Paper->type() eq 'Roll' ? 'lbs' : 'sheets' );
							$variable{'information'} .= sprintf('Allocated %1$d%2$s to docket <a href="/employee/project/view.html?ProjectIndex=%3$d">%4$d</a>.<br/>', $C->quantity(), ($Paper->type() eq 'Roll' ? 'lbs' : 'sheets'), $Project->id(), $Project->docket() );
						} elsif ( $PAs[0]->project_id() != $Project->id() ) {
							$variable{'information'} .= sprintf('Skid <a href="/employee/inventory/skid_details.html?skid_id=%1$d">%1$d</a> already allocated to docket <a href="/employee/project/view.html?ProjectIndex=%3$d">%4$d</a>.<br/>', $C->skid_id(), $PAs[0]->project_id(), $PAs[0]->docket() );
						} # end if
					} # end if
					if ( openprint::PaperInventory::find('skid_id'=>$C->Skid()->id(), 'paper_id'=>undef, 'comment_like'=>'Checked out%' ) ) {
						# If the stock has already been checked out, add a subtraction to keep counts in line.
						save_inventory( $C->Skid(), $Paper, -1*$C->quantity(), 'Automatic checkout after manifest inventory update.' );
					} # end if
				} # end foreach tag_id

if ( 0 ) {
				if ( $total_qty and $Project and ( $param{"allocate-$$Type{id}"} ne 'Specific' ) ) {
					$Paper->allocate( undef, $Project->id(), $total_qty, $Paper->type() eq 'Roll' ? 'lbs' : 'sheets' );
					$variable{'information'} .= sprintf('Allocated %1$d%2$s to docket <a href="/employee/project/view.html?ProjectIndex=%3$d">%4$d</a>.<br/>', $total_qty, ($Paper->type() eq 'Roll' ? 'lbs' : 'sheets'), $Project->id(), $Project->docket() );
				} # end if
} # end if
			} # end foreach Type
		} # end if has Types
		if ( ! $variable{'error'} ) {
			$variable{'information'} .= 'Information successfully stored.<br/>';
		} # end if
		%param = ();
	} # end if btnfunction
	$variable{'Manifest'} = $Manifest;
} # end sub manifest

sub _manifest_content {
	if ( $param{'action'} eq 'Remove' ) {
		my $C = new openprint::ManifestContent( $param{'content_id'} );
		$variable{'type_id'} = $C->type_id();
		$variable{'Manifest'} = $C->Manifest();
		$variable{'error'} .= $C->delete();
	} elsif ( $param{'action'} eq 'Add' ) {
		if ( ! $param{'manifest_id'} ) {
			$variable{'error'} .= 'No manifest id.  Please enter the manifest id before adding items to it.<br/>';
			return;
		} # end if
		my $Manifest = new openprint::Manifest( $param{'manifest_id'} );
		$variable{'Manifest'} = $Manifest;
		if ( $param{'manifest_id'} and ! $Manifest->id() ) {
			$variable{'error'} .= $Manifest->save({'id'=>$param{'manifest_id'}});
		} # end if
		if ( $param{'rfidtag_id'} or $param{'skid_id'} ) {
			@param{'rfidtag_id','skid_id'} = misc::trim(@param{'rfidtag_id','skid_id'});
			my $Tag = new openprint::RFIDTag( $param{'rfidtag_id'} );
			$variable{'error'} .= $Tag->save({'id'=>$param{'rfidtag_id'}}) if $param{'rfidtag_id'} and ! $Tag->id();
			my $Skid = new openprint::Skid( $param{'skid_id'} );
			$Skid = $Tag->Skid() if $Tag->id() and ! $Skid->id();
$log->debug("RFID: $param{'rfidtag_id'}");
			$variable{'error'} .= $Skid->save({'rfidtag_id'=>$param{'rfidtag_id'}}) if ! $Skid->id();
			return if $variable{'error'};

			if ( $Tag->id() and sets::isin( $Tag->id(), map { $_->Skid()->rfidtag_id() } $Manifest->Contents() ) ) {
				$variable{'error'} .= 'RFID Tag ' . $Tag->id() . ' has already been scanned.';
			} elsif ( $Skid->id() and sets::isin( $Skid->id(), map { $_->skid_id() } $Manifest->Contents() ) ) {
				$variable{'error'} .= 'Skid ' . $Skid->id(). ' has already been scanned.';
			} else {
				my $MC = new openprint::ManifestContent();
				$variable{'error'} .= $MC->save( {
						'type_id'		=>	$param{'type_id'},
						'skid_id'		=>	$Skid->id(),
						'manifest_id'	=>	$Manifest->id(),
						'docket'		=>	$param{'docket'},
						'quantity'		=>	sprintf('%d', $param{"qty_lbs"}),
						} );
				$variable{'C'} = $MC;
				$variable{'type_id'} = $param{'type_id'};
			} # end if
		} # end if
	} # end if
} # end sub _manifest_content

sub manifests {
	if ( $param{'btnFunction'} eq 'Delete' ) {
		foreach my $manifest_id ( ref $param{'manifests'} eq 'ARRAY' ? @{$param{'manifests'}} : split(',',$param{'manifests'}) ) {
			my $Manifest = new openprint::Manifest( $manifest_id );
			$variable{'error'} .= $Manifest->delete();

		} # end foreach manifest_id
	} # end if
	ssi::save_params( '/employee/inventory/manifests.html', ( 'received_on_start_year','received_on_start_month','received_on_start_day','received_on_end_year','received_on_end_month','received_on_end_day','supplier_id' ) );
} # end sub manifests

sub _manifests {
	ssi::save_params( '/employee/inventory/manifests.html', ( 'received_on_start_year','received_on_start_month','received_on_start_day','received_on_end_year','received_on_end_month','received_on_end_day','supplier_id' ) );
} # end sub _manifests

sub inventory_log {
  if ( $param{'btnFunction'} eq 'Download' ) {
        my @Header = ('When','Skid','RFIDTag','Paper','Amount','Allocated','In Stock','Location','Comment' );
        my @Data;

        my @data = sql::execute( $log, $dbh, q{SELECT updated_on, user_id, delta, instock, units, comment, poindex, skid_id, paper_id FROM Paper_Inventory WHERE (updated_on BETWEEN ? AND ? ) ORDER BY updated_on},
        sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', @param{'StartYear','StartMonth','StartDay','StartHour','StartMinute'}),
        sprintf('%.4d-%.2d-%.2d %.2d:%.2d:59', @param{'EndYear','EndMonth','EndDay','EndHour','EndMinute'}),
        );
        my $total = 0;
        while ( my ( $time, $user_id, $delta, $instock, $units, $comment, $po_id, $skid_id, $paper_id ) = splice @data, 0, 9 ) {
            next if $delta <= 0 and ! $param{'outs'};
            next if $delta > 0 and ! $param{'ins'};
            my $Paper = new openprint::Paper( $paper_id );
            my $Skid = new openprint::Skid( $skid_id );
            next if $Paper->type() and ! sets::isin( $Paper->type(), $param{'Type'} );
            next if ( ! $Paper->type() ) and ! sets::isin( 'Unknown', $param{'Type'} );
            
            push @Data, (
                Date::Format::time2str('%Y-%m-%d %H:%M', Date::Parse::str2time($time) ),
                $skid_id,
                $Skid->rfidtag_id(),
                $Paper->to_string(),
                $delta,
                join(',', map { sprintf('%d%s to %d', $_->quantity(),$_->units(),new openprint::Project( $_->project_id() )->docket() ) } openprint::PaperAllocation::find('skid_id'=>$skid_id,'paper_id'=>$paper_id)),
                $instock,
                $Skid->Location()->name(),
                $comment,
                );
            $total += $delta;
        } # end while
        push @Data, '','','','Totals:',$total,'','','','';
        misc::export_csv( $r, $log, \%variable, 'InventoryLog.csv', \@Header, \@Data );
    } # end if
} # end sub inventory_log

sub _inventory_log {
	$variable{'Skid'} = new openprint::Skid( $param{'skid_id'} );
} # end sub inventory_log

sub _paper_allocations {
	$param{'paper_id'} =~ s/\D//g;
	$variable{'Paper'} = new openprint::Paper( $param{'paper_id'} );
	if ( $param{'action'} eq 'Add' ) {
		$param{'skid_id'} =~ s/\D//g;
		$param{'Docket'} =~ s/\D//g;
		$param{'AllocationQuantity'} =~ s/[^\d\-]//g;
		my @Projects = openprint::Project::find( 'docket'=>$param{'Docket'} ) if $param{'Docket'};
		if ( ! @Projects ) {
			$variable{'error'} .= "Docket $param{'Docket'} not found.";
		} else {
			$variable{'Paper'}->allocate( $param{'skid_id'}, $Projects[0]->id(), $param{'AllocationQuantity'} );
        } # end if
        delete $param{'skid_id'};
	} elsif ( $param{'action'} eq 'Delete Allocation' ) {
		if ( $param{'allocation_id'} ) {
			my $PA = new openprint::PaperAllocation( $param{'allocation_id'} );
			$variable{'error'} .= $PA->delete($param{'reason'});
		} # end if
    } # end if
} # end sub _paper_allocations

sub _skid_allocations {
    if ( $param{'action'} eq 'Add' ) {
        my $Paper = new openprint::Paper( $param{'paper_id'} );
        my @Projects = openprint::Project::find( 'id'=>$param{'ProjectID'}, 'docket'=>$param{'Docket'} ) if $param{'ProjectID'} or $param{'Docket'};
        my $Skid = new openprint::Skid( $param{'skid_id'} );

        if ( ! @Projects ) {
            $variable{'error'} .= 'Docket not found. No paper allocated.<br/>';
        } elsif ( $Skid->allocateable() < $param{'AllocationQuantity'} ) {
            $variable{'error'} .= 'Only ' .  $Skid->allocateable() . ' on this skid. No paper allocated.<br/>';
        } else {
            my $Project = shift @Projects;
            $Paper->allocate( $param{'skid_id'}, $Project->id(), @param{'AllocationQuantity','Units'} );
            $variable{'information'} .= sprintf('Allocated %s%s to docket %d<br/>', @param{'AllocationQuantity','Units'}, $Project->docket() );
        } # end if
    } elsif ( $param{'action'} eq 'delete' ) {
        my $Allocation = new openprint::PaperAllocation( $param{'allocation_id'} );
		if ( $Allocation->id() ) {
			$Allocation->Project()->add_to_log( @session{'company_id','user_id'}, 'Paper Allocation for skid ' . $Allocation->skid_id() . ' deleted.' );
			$Allocation->delete();
		} else {
			$openprint::log->warn('Non-existent Paper Allocation deleted.');
		} # end if
    } # end if
    $variable{'skid_id'} = $param{'skid_id'};
} # end sub _skid_allocations


sub available_paper {
	if ( $param{'btnFunction'} eq 'Allocate' ) {
		allocate( @param{'skid_id','paper_id','Quantity','Project','Docket','specific','reason'} );
	} # end if
} # end sub available_paper

sub _allocate_popup {
    if ( $param{'referer'} ) {
        $variable{'referer'} = $param{'referer'};
    } elsif ( $ENV{'HTTP_REFERER'} ) {
        $log->debug($ENV{'HTTP_REFERER'});
        $ENV{'HTTP_REFERER'} =~ /.*\/(.*\.html)/;
        $variable{'referer'} = $1;
    } # end if
    $variable{'Paper'} = new openprint::Paper( $param{'paper_id'} );
    if ( exists $param{'quantity'} ) {
        $variable{'quantity'} = $param{'quantity'};
    } else {
        $variable{'quantity'} = $variable{Paper}->in_stock() - $variable{Paper}->allocated();
    } # end if
} # end sub _allocate_popup

sub purchase_order_view {
	my $PO = new openprint::PurchaseOrder( $param{'po_id'} );

	if ( $param{'btnFunction'} eq 'Delete' ) {
		$variable{'error'} .= $PO->delete();
		if ( ! $variable{'error'} ) {
			my $L = new openprint::PurchaseOrder_Log();
			$L->save({
					'user_id'	=>	$session{'user_id'},
					'po_id'		=>	$PO->id(),
					'reason'	=>	'deleted.',
					});
			delete $param{'po_id'};
			$variable{'Redirect'} = '/employee/inventory/purchase_orders.html';
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Undelete' ) {
		$variable{'error'} .= $PO->undelete();
		if ( ! $variable{'error'} ) {
			my $L = new openprint::PurchaseOrder_Log();
			$L->save({
					'user_id'	=>	$session{'user_id'},
					'po_id'		=>	$PO->id(),
					'reason'	=>	'undeleted.',
					});
			delete $param{'po_id'};
			$variable{'Redirect'} = '/employee/inventory/purchase_orders.html';
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Send' ) {
	} elsif ( $param{'btnFunction'} eq 'Email Vendor' ) {
		$variable{'error'} = $PO->send_to_vendor();
	} elsif ( $param{'btnFunction'} eq 'Received' ) {
	} elsif ( $param{'btnFunction'} eq 'Copy' ) {
		my $New = $PO->copy();
		if ( ! ( $variable{'error'} = $New->save() ) ) {
			foreach my $C ( $PO->Contents() ) {
				$C = $C->copy();
				$C->po_id( $New->id() );
				$C->save();
			} # end foreach
			$New->save();
			$variable{'information'} .= 'PO ' . $PO->id() . ' copied to PO ' . $New->id() .'<br/>';
			$PO = $New;
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		if ( ! $param{'po_id'} ) {
			$variable{'error'} .= $PO->save( { 'created_by'	=>	$session{'user_id'}, 'company_id'=>new openprint::User( $session{'user_id'} )->company_id() } );
		} # end if
		foreach my $k ( keys %param ) {
			my ( $content_id ) = $k =~ /qty-(.*)/;
			if ( defined $content_id ) {
				next if ( $content_id eq 'new' and ! $param{'qty-'.$content_id} );
				my $C = new openprint::PurchaseOrder_Content( $content_id );
				$variable{'error'} .= $C->save( {
						'po_id'         =>  $PO->id(),
						'qty'           =>  $param{'qty-'.$content_id},
						'item'          =>  $param{'item-'.$content_id},
						'description'   =>  $param{'description-'.$content_id},
						'docket'        =>  $param{'docket-'.$content_id},
						'price'         =>  $param{'price-'.$content_id},
						'total'         =>  $param{'total-'.$content_id},
						'type_id'		=>	$param{'type_id-'.$content_id},
						});
				if ( $C->docket() ) {
					foreach my $P ( openprint::Project::find('docket'=>$C->docket()) ) {
						$P->add_to_log( @session{'company_id','user_id'}, 
								sprintf('<a href="/employee/inventory/purchase_order_view.html?po_id=%1$d">%2$s%3$s %4$s ordered on PO%1$d</a>',
									$PO->id(), $C->qty(), $C->units(), $C->description() ) );
					} # end foreach Project
				} # end if docket
			} # end if
		} # end foreach
		if ( ! $param{'supplier_id'} ) {
			my @Companies = openprint::Company::find( 'name'=>$param{'vendor_name'} );
			if ( ! @Companies ) {
				my $C = new openprint::Company();
				$C->save({
						'supplier'		=> 'Y',
						'name'			=> $param{'vendor_name'},
						'business_name'	=> $param{'vendor_name'},
						'address1'		=> $param{'vendor_address1'},
						'address2'		=> $param{'vendor_address2'},
						'city'			=> $param{'vendor_city'},
						'state'			=> $param{'vendor_state'},
						'country'		=> $param{'vendor_country'},
						'postalcode'	=> $param{'vendor_postalcode'},
						'phone'			=> $param{'vendor_phone'},
						'fax'			=> $param{'vendor_fax'},
						} );
				$param{'supplier_id'} = $C->id();
			} elsif ( @Companies == 1 ) {
				if ( $Companies[0]->supplier() ne 'Y' ) {
					$Companies[0]->save( {'supplier'=>'Y'} );
				} # end if
				$param{'supplier_id'} = $Companies[0]->id();
			} # end if
		} # end if
		if ( ! $param{'contact_id'} ) {
			my @Users = openprint::User::find( 'company_id'=>$param{'supplier_id'}, 'email'=> lc $param{'vendor_email'} );
			if ( ! @Users ) {
				my $User = new openprint::User();
				my ( $first, $last ) = $param{'vendor_contact'} =~ /(\S+)\s*(\S*)/;
				$User->save( {
						'company_id'=>	$param{'supplier_id'},
						'email'		=>	$param{'vendor_email'},
						'firstname'	=>	$first,
						'lastname'	=>	$last,
						'phone'		=>	$param{'vendor_phone'},
						'fax'		=>	$param{'vendor_fax'},
						'sms'		=>	$param{'vendor_sms'},
						'change_password'	=>	'N',
						'administrator'	=>	'N',
						'ftp_active'	=>	0,
						'web_active'	=>	0,
					} );
			} # end if
		} # end if
		if ( $param{'delivered_on_switch'} eq 'DATE' ) {
			$param{'delivered_on'} = sprintf('%.4d-%.2d-%.2d', @param{'delivered_on_year','delivered_on_month','delivered_on_day'}) if ! $param{'delivered_on'};
		} else {
			$param{'delivered_on'} = undef;
		} # end if
		$param{'federaltax_charge'} = $param{'federaltax_charge'} ? 1 : 0;
		$param{'statetax_charge'} = $param{'statetax_charge'} ? 1 : 0;
		$variable{'error'} .= $PO->save( \%param );
		if ( ( ! $variable{'error'} ) and $param{'reason'} ) {
			my $L = new openprint::PurchaseOrder_Log();
			$L->save({
				'user_id'	=>	$session{'user_id'},
				'po_id'		=>	$PO->id(),
				'reason'	=>	$param{'reason'},
				});
		} # end if
		if ( $PO->is_FSC() or $PO->is_PEFC() ) {
			my @notifications;
			foreach my $user_id ( openprint::usergroup::users_in( 'FSC/PEFC Notifications' ) ) {
				my $found = 0;
				foreach my $notification_id ( $PO->notifications() ) {
					if ( $notification_id == $user_id ) {
						$found = 1;
						last;
					} # end if	
				} # end foreach
				if ( ! $found ) {
					push @notifications, $user_id;
				} # end if
			} # end foreach
			if ( @notifications ) {
				$PO->notifications([$PO->notifications(),@notifications]);
			} # end if
		} # end if
	} # end if btnFunction

	$variable{'PurchaseOrder'} = $PO;
} # end sub purchase_order_view

sub purchase_order_edit {

	my $PO = new openprint::PurchaseOrder( $param{'po_id'} );
	
	if ( $param{'btnFunction'} eq 'Delete' ) {
		return;
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
	} # end if btnFunction

	if ( ! $PO->id() ) {
		my $U = new openprint::User( $session{'user_id'} );
		my $C = $U->Company();
		$PO->set( {
			'currency_id'		=>	openprint::Currency::get_current()->id(),
			'company_id'		=>	$C->id(),
			'created_by'		=>	$U->id(),
			'shipto_contact'	=>	$U->name(),
			'shipto_name'		=>	$C->name(),
			'shipto_address1'	=>	$C->address1(),
			'shipto_address2'	=>	$C->address2(),
			'shipto_city'		=>	$C->city(),
			'shipto_state'		=>	$C->state(),
			'shipto_country'	=>	$C->country(),
			'shipto_postalcode'	=>	$C->postalcode(),
			'shipto_phone'		=>	$C->phone(),
			'shipto_fax'		=>	$C->fax(),
			'shipto_email'		=>	$U->email(),
			'shipto_sms'		=>	$U->sms(),
		} );
		$variable{'error'} .= $PO->save();
	} # end if
	$variable{'PurchaseOrder'} = $PO;
} # end sub purchase_order_edit

sub purchase_orders {
    foreach my $key ( 'starting_start_year','starting_start_month','starting_start_day','starting_end_year','starting_end_month','starting_end_day','authorized', 'supplier_id','created_by' ) {
        $session{'/employee/inventory/purchase_orders.html?'.$key} = $param{$key} if exists $param{$key};
    } # end foreach
	ssi::setup_date_select( '/employee/inventory/purchase_orders.html', 'created_on', -31 );
	if ( $param{'btnFunction'} eq 'Delete' ) {
		foreach my $po_id ( ref $param{'po_id'} eq 'ARRAY' ? @{$param{'po_id'}} : $param{'po_id'} ) {
			my $PO = new openprint::PurchaseOrder( $po_id );
			if ( $_ = $PO->delete() ) {
				$variable{'error'} .= $_ . '<br/>';
			} else {
				my $L = new openprint::PurchaseOrder_Log();
				$L->save({
						'user_id'	=>	$session{'user_id'},
						'po_id'		=>	$PO->id(),
						'reason'	=>	'deleted.',
						});
				$variable{'information'} .= 'PO ' . $po_id . ' has been deleted.<br/>';
			} # end if
		} # end foreach po_id
		delete $param{'po_id'};
	} elsif ( $param{'btnFunction'} eq 'Undelete' ) {
		foreach my $po_id ( ref $param{'po_id'} eq 'ARRAY' ? @{$param{'po_id'}} : $param{'po_id'} ) {
			my $PO = new openprint::PurchaseOrder( $po_id );
			if ( $_ = $PO->undelete() ) {
				$variable{'error'} .= $_ . '<br/>';
			} else {
				my $L = new openprint::PurchaseOrder_Log();
				$L->save({
						'user_id'	=>	$session{'user_id'},
						'po_id'		=>	$PO->id(),
						'reason'	=>	'undeleted.',
						});
			} # end if
		} # end foreach
		delete $param{'po_id'};
	} elsif ( $param{'btnFunction'} eq 'Authorize' ) {
		foreach my $po_id ( ref $param{'po_id'} eq 'ARRAY' ? @{$param{'po_id'}} : $param{'po_id'} ) {
			my $PO = new openprint::PurchaseOrder( $po_id );
			if ( $_ = $PO->authorize() ) {
				$variable{'error'} .= $_ . '<br/>';
			} else {
				$variable{'information'} .= 'PO ' . $po_id . ' has been authorized.<br/>';
			} # end if
		} # end foreach po_id
		delete $param{'po_id'};
	} elsif ( $param{'btnFunction'} eq 'Decline' ) {
		foreach my $po_id ( ref $param{'po_id'} eq 'ARRAY' ? @{$param{'po_id'}} : split(',',$param{'po_id'}) ) {
			my $PO = new openprint::PurchaseOrder( $po_id );
			if ( $_ = $PO->decline( $param{'reason'} ) ) {
				$variable{'error'} .= $_ . '<br/>';
			} else {
				$variable{'information'} .= 'PO ' . $po_id . ' has been declined.<br/>';
			} # end if
		} # end foreach po_id
		delete $param{'po_id'};
	} elsif ( $param{'btnFunction'} eq 'Email Vendor' ) {
		my $PO = new openprint::PurchaseOrder( $param{'po_id'} );
		$variable{'error'} .= $PO->send_to_vendor();
		delete $param{'po_id'};
	} # end if
} # end sub purchase_orders

sub _purchase_orders {
    foreach my $key ( 'starting_start_year','starting_start_month','starting_start_day','starting_end_year','starting_end_month','starting_end_day','authorized','supplier_id','created_by' ) {
        $session{'/employee/inventory/purchase_orders.html?'.$key} = $param{$key} if exists $param{$key};
    } # end foreach
} # end sub _purchase_orders

sub _po_autocomplete {
} # end sub _po_autocomplete

sub _purchase_order_supplier_address {
	my $PO = new openprint::PurchaseOrder( $param{'po_id'} );
	$PO->supplier_id( $param{'supplier_id'} );
	$PO->save() if $PO->id();
	$variable{'PurchaseOrder'} = $PO;
} # end sub _purchase_order_supplier_address

sub _po_content_line {
	my $PO = new openprint::PurchaseOrder( $param{'po_id'} );
	$variable{'PurchaseOrder'} = $PO;
    if ( $param{'action'} eq 'add' ) {
		my $C = new openprint::PurchaseOrder_Content( $param{'po_content_id'} );
        $C->save( {
            'po_id'         =>  $param{'po_id'},
            'qty'           =>  $param{'qty'},
            'item'          =>  $param{'item'},
            'description'   =>  $param{'description'},
            'docket'        =>  $param{'docket'},
            'price'         =>  $param{'price'},
            'total'         =>  $param{'total'},
            'type_id'       =>  $param{'type_id'},
            });
		$variable{'C'} = $C;
	} elsif ( $param{'action'} eq 'delete' ) {
		my $PO_Content = new openprint::PurchaseOrder_Content( $param{'id'} );
		$PO_Content->delete();
	} # end if
} # end sub _purchase_order_content_line

sub _po_notifications {
	my $PO = new openprint::PurchaseOrder( $param{'po_id'} );
	if ( ( $param{'action'} eq 'add' ) and $param{'new_notification_id'} ) {
		$PO->notifications( [ split(',', $param{'notifications'}), $param{'new_notification_id'} ] );
	} elsif ( $param{'action'} eq 'delete' ) {
		$PO->notifications( [ sets::exclude( [$param{'notification_id'}], [$PO->notifications()] ) ] );
	} # end if
	$variable{'PurchaseOrder'} = $PO;
} # end if

sub _manifest_purchase_orders {
} # end sub _manifest_purchase_orders

sub _rfidtags_results {
} # end sub _rfidtags_results

sub _rfidtag_log {
    @{$variable{'Entries'}} = openprint::RFIDTagHistory::find( 
        'rfidtag_id'	=>	$param{'rfidtag_id'},
        'updated_on_start'  =>  Date::Calc::check_date( @param{'start_year','start_month','start_day'} ) ? sprintf('%.4d-%.2d-%.2d 00:00:00', @param{'start_year','start_month','start_day'} ) : undef,
        'updated_on_end'    =>  Date::Calc::check_date( @param{'end_year','end_month','end_day'} ) ?  sprintf('%.4d-%.2d-%.2d 23:59:59', @param{'end_year','end_month','end_day'} ) : undef,
        'order'     =>  'updated_on DESC',
        'limit'     =>  $param{'limit'},
        );

	if ( ! @{$variable{'Entries'}} ) {
		@{$variable{'Entries'}} = openprint::RFIDTagHistory::find( 
				'rfidtag_id'	=>	$param{'rfidtag_id'},
				'updated_on_start'  =>  Date::Calc::check_date( @param{'start_year','start_month','start_day'} ) ? sprintf('%.4d-%.2d-%.2d 00:00:00', @param{'start_year','start_month','start_day'} ) : undef,
				'updated_on_end'    =>  Date::Calc::check_date( @param{'end_year','end_month','end_day'} ) ?  sprintf('%.4d-%.2d-%.2d 23:59:59', @param{'end_year','end_month','end_day'} ) : undef,
				'limit'     =>  $param{'limit'},
				'order'     =>  'updated_on DESC',
				);
		if ( @{$variable{'Entries'}} ) {
			@param{'start_year','start_month','start_day'} = $variable{'Entries'}[@{$variable{'Entries'}}-1]->updated_on() =~ /^(\d+)-(\d+)-(\d+)/;
		} # end if
	} elsif ( ! $param{'start_year'} ) {
		@param{'start_year','start_month','start_day'} = $variable{'Entries'}[@{$variable{'Entries'}}-1]->updated_on() =~ /^(\d+)-(\d+)-(\d+)/;
	} # end if
} # end sub _rfidtag_log

sub _manifest_type {
	$variable{'Manifest'} = new openprint::Manifest( $param{'manifest_id'} );
	if ( $param{'action'} eq 'Add' ) {
		$variable{'Type'} = new openprint::Manifest_Content_Type();
		$variable{'error'} .= $variable{'Type'}->save({'manifest_id'=>$param{'manifest_id'}});
		$variable{'type_id'} = $variable{'Type'}->id();
	} # end if
}

sub _po_select_vendor {
}

sub _verification_log {
	$variable{'Skid'} = new openprint::Skid( $param{'skid_id'} );
} # end sub _verification_log

sub paper_label_window {
} # end sub paper_label_window

1;
__END__
