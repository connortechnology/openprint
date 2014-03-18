use strict;
package openprint::employee_inventory;
require MIME::QuotedPrint;
use Authen::Captcha ();
require sql;
require misc;

require openprint::pricelist;
require openprint::paper_price;
require openprint::paper_priceset;
require openprint::StockPurpose;
require openprint::PaperInventory;
require openprint::StockBrand;
require openprint::StockFinish;
require openprint::StockColour;
require openprint::StockQuality;
require openprint::StockPurpose;
require openprint::InventoryCondition;
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
require openprint::PurchaseOrder_Item;
require openprint::Label;
require openprint::Skid;
require openprint::SkidContent;
require openprint::Claim_Content;
require openprint::Log;

use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

use constant DEBUG => 1;
sub skids {
	if ( $param{'btnFunction'} eq 'move' )	{
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
			my $Location = new openprint::Location( $param{'location_id'} );
			if ( ! $Location->id() ) {
				$variable{'error'} .= 'Invalid location.<br/>';
			} else {
				foreach my $skid_id ( @skid_ids ) {
					my $Skid = new openprint::Skid( $skid_id );
					if ( my $e = $Skid->save({'location_id'=>$param{'location_id'}}) ) {
						$variable{'error'} .= "Skid $$Skid{'id'} has not been moved. Error: $e<br/>";
					} else {
						$variable{'information'} .= sprintf('<a href="/employee/inventory/skid_details.html?skid_id=%1$d">Skid %1$d</a> has been moved to %2$s.<br/>', $$Skid{id}, $$Location{name} );
					} # end if
				} # end foreach
			} # end if
		} # end if skid_id
	} elsif ( $param{'btnFunction'} eq 'Delete' )	{
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
				$variable{'information'} .= sprintf('<a href="/employee/inventory/skid_details.html?skid_id=%1$d">Skid %1$d</a> has been deleted.<br/>', $$Skid{id} );
				my $PI = new openprint::PaperInventory();
				$PI->save({skid_id=>$skid_id, user_id=>$session{user_id}, comment=>'Skid Deleted.'});
			} # end foreach
		} elsif ( $param{'skids'} ) {
			foreach my $skid_id ( ref $param{'skids'} eq 'ARRAY' ? @{$param{'skids'}} : $param{'skids'} ) {
				my $Skid = new openprint::Skid( $skid_id );
				$Skid->delete();
				$variable{'information'} .= sprintf('<a href="/employee/inventory/skid_details.html?skid_id=%1$d">Skid %1$d</a> has been deleted.<br/>', $$Skid{id} );
				my $PI = new openprint::PaperInventory();
				$PI->save({skid_id=>$skid_id, user_id=>$session{user_id}, comment=>'Skid Deleted.'});
			} # end foreach
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Destroy' )	{
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
					$variable{'information'} .= "Skid $$Skid{'id'} has been destroyed.<br/>";
				} # end if
			} # end foreach
		} elsif ( $param{skids} ) {
			foreach my $skid_id ( ref $param{skids} eq 'ARRAY' ? @{$param{skids}} : $param{skids} ) {
				my $Skid = new openprint::Skid( $skid_id );
				if ( $Skid->deleted() ) {
					$variable{information} .= sprintf('<a href="/employee/inventory/skid_details.html?skid_id=%1$d">Skid %1$d</a> is already deleted.<br/>', $$Skid{id} );
				} else {
					$_ = $Skid->delete();
					if ( $_ ) {
						$variable{error} .= $_;
					} else {
						$variable{information} .= sprintf('<a href="/employee/inventory/skid_details.html?skid_id=%1$d">Skid %1$d</a> has been deleted.<br/>', $$Skid{id} );
					} # end if
				} # end if
			} # end foreach
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Allocate' ) {
		if ( exists $param{'Captcha'} ) {
	# Remove spaces, because some people want to put spaces between the characters, etc.
			$param{'Captcha'} =~ s/\s//g;
			my $Captcha = new Authen::Captcha('data_folder' => '/tmp', 'output_folder' => $config{'SkinPath'}.'/images/captcha');
			if ( 1 != $Captcha->check_code( @param{'Captcha','MD5SUM'} ) ) {
				$variable{'error'} .= 'Captcha Validation Code incorrect.	Please try again.';
				return;
			} # end if
		} # end if
		if ( $param{skid_id} ) {
			$param{skid_id} =~ s/[^\d\,]//g;
			$param{Project} =~ s/\D//g;
			$param{Docket} =~ s/\D//g;
			my $Project = openprint::Project->find_one( 'id'=>$param{Project}, 'docket'=>$param{Docket} ) if $param{Project} or $param{Docket};
			if ( ! $Project ) {
				$variable{'error'} .= 'An invalid Docket or Project # was given. No paper allocated.<br/>';
				return;
			} # end if
			
			my %stocks;
			foreach my $skid_id ( split(',', $param{'skid_id'} ) ) {
				$skid_id =~ s/\D//g;
				next if ! $skid_id;
				my $Skid = new openprint::Skid( $skid_id );
				foreach my $C ( $Skid->Contents() ) {
					push @{$stocks{$C->paper_id()}}, $Skid;
				} # end foreach Paper
			} # end foreach Skid
			foreach my $paper_id ( keys %stocks ) {
				my $PA = new openprint::Paper( $paper_id )->allocate( $stocks{$paper_id}, $Project->id() );
				$PA->send_notifications();
			} # end foreach
		} # end if
	} # end if

	$session{'/employee/inventory/skids.html?empty'} = 'N' if ! exists $session{'/employee/inventory/skids.html?empty'};
	$session{'/employee/inventory/skids.html?contents'} = 'Y' if ! exists $session{'/employee/inventory/skids.html?contents'};
	$session{'/employee/inventory/skids.html?hasmanifest'} = '' if ! exists $session{'/employee/inventory/skids.html?hasmanifest'};
	$session{'/employee/inventory/skids.html?hasmanufacturers'} = '' if ! exists $session{'/employee/inventory/skids.html?hasmanufacturers'};
	$session{'/employee/inventory/skids.html?checked_out'} = '' if ! exists $session{'/employee/inventory/skids.html?checked_out'};

	ssi::setup_date_select( '/employee/inventory/skids.html', 'received_on_start', 0 );
	ssi::setup_date_select( '/employee/inventory/skids.html', 'received_on_end', 0 );
	ssi::setup_date_select( '/employee/inventory/skids.html', 'created_on_start', '' );
	ssi::setup_date_select( '/employee/inventory/skids.html', 'created_on_end', '' );
	ssi::setup_date_select( '/employee/inventory/skids.html', 'updated_on_start', '' );
	ssi::setup_date_select( '/employee/inventory/skids.html', 'updated_on_end', '' );
	ssi::setup_date_select( '/employee/inventory/skids.html', 'last_seen_start', '' );
	ssi::setup_date_select( '/employee/inventory/skids.html', 'last_seen_end', '' );

	_skids_results();
	$session{'/employee/inventory/skids.html?rfid'} = '' if ! defined $session{'/employee/inventory/skids.html?rfid'};
	$session{'/employee/inventory/skids.html?rfid_valid'} = '' if ! defined $session{'/employee/inventory/skids.html?rfid_valid'};
	$session{'/employee/inventory/skids.html?hasmanifest'} = '' if ! defined $session{'/employee/inventory/skids.html?hasmanifest'};
	$session{'/employee/inventory/skids.html?type'} = '' if ! defined $session{'/employee/inventory/skids.html?type'};
	$session{'/employee/inventory/skids.html?deleted'} = '0' if ! exists $session{'/employee/inventory/skids.html?deleted'};
 
} # end sub skids

sub inventory_report {
	my %param = @_;
	my @header = ('Paper ID','Type','Owner','Manufacturer','Name','Finish','Colour','Weight','Material','Group','Type','Width','Height','Quality', 'MWeight','GSM','Skid#','RFIDTag #','Received On', 'Date Added','Last Updated', 'Location', 'In Stock (sheets)','In Stock(lbs)', 'Condition', 'Last Seen', 'Cost', 'Value' );

	my @data;
	my $count = 0;
	my $total_weight = 0;
	openprint::Location->find();
	foreach my $Skid ( openprint::Skid->find(
				ssi::date_filter( 'added_on_start', 'created_on >=', \%param ),
				ssi::date_filter( 'added_on_end', 'created_on <=', \%param ),
				'quantity >='=>1,'type is null or in'=>$param{type} ) ) {
		foreach my $C ( $Skid->Contents() ) {
			next if ! $C;
			my $Paper = $C->Paper();
			my $weight = 0;
			if ( $Paper->type() eq 'Roll' ) {
				$weight = $C->quantity();
			} elsif ( $Paper->type() eq 'Sheet' ) {
				$weight += $Paper->sheet_weight() * $C->quantity();
			} else {
				$log->error("Unknown stock type! " . $Paper->to_string() );
			} # end if
			$total_weight += $weight;
			$count += 1;
			push @data,(
					$$Paper{id},
					$$Skid{type},
					new openprint::Company($Paper->owner_id())->name(),
					$Paper->manufacturer(),
					$Paper->brand(),
					$Paper->finish(),
					$Paper->colour(),
					$Paper->weight(),
					$Paper->material(),
					$Paper->group(),
					$Paper->type(),
					$Paper->width(),
					$Paper->height(),
					$Paper->quality(),
					$Paper->mweight(),
					$Paper->gsm(),
					$$Skid{id},
					$Skid->RFIDTag()->id_short(),
					$$Skid{'received_on'},
					$$Skid{'created_on'},
					$$Skid{'updated_on'},
					$Skid->Location()->name(),
					$Paper->type() eq 'Sheet' ? $C->quantity() : '',
					$weight,
					$C->condition(),
					$Skid->updated_on(),
					1*$C->cost(),
					1*$C->value(),
					);
		} # end foreach C
	} # end foreach Skid
	my $date = Date::Format::time2str('%Y-%m-%d %H:%M', time );
	push @data, ( 'Report generated',$date,'Count:',$count,undef,undef,undef,undef, undef,undef,undef, undef, undef, undef, undef, undef, undef, undef, undef, undef,undef, 'Total Weight (lbs):', $total_weight, undef, undef );
	return ( \@header, \@data );
} # end sub inventory_report

sub paper {
	if ( $param{'btnFunction'} eq 'Consumption Report' ) {
		my @header = ('Date','Operator','Owner','Brand','Finish','Colour','Weight','Width','Height','Quality', 'MWeight','GSM','Skid#','Amount','Comment');
		my @data;
		my @inventory = openprint::PaperInventory->find(
				ssi::date_filter( 'added_on_start', 'updated_on >=', \%param ),
				ssi::date_filter( 'added_on_end', 'updated_on <=', \%param ),
				order=>'updated_on',
		);
		foreach my $I ( @inventory ) {
			my $Paper = $I->Paper();
			push @data, 
Date::Format::time2str('%Y-%m-%d %H:%M', Date::Parse::str2time($I->updated_on())),
				$I->User()->name(),
				$Paper->Owner()->name(),
				$Paper->brand(),
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

		my @header = ('Date','Operator','Owner','Brand','Finish','Colour','Weight','Width','Height','Quality', 'MWeight','GSM','Skid#','Amount','Comment');
		my @info = sql::execute( $log, $dbh, q{SELECT paper_id, skid_id, user_id, delta, units, updated_on, comment FROM paper_inventory ORDER BY updated_on DESC} );
		my @data;
		while ( my ( $paper_id, $skid_id, $user_id, $delta, $units, $time, $comment ) = splice @info, 0, 7 ) {
			my $Paper = new openprint::Paper( $paper_id );
			push @data, $time, new openprint::User($user_id)->name(),
				 new openprint::Company($Paper->owner_id())->name(),
				 $Paper->brand(),
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
			my @papers = openprint::Paper->find('id'=>$param{'papers'});

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

	_paper_results();
	$session{'/employee/inventory/paper.html?owner_id_exclude'} = $param{'owner_id_exclude'} if exists $param{'owner_id'};
    $session{'/employee/inventory/paper.html?owner_id'} = $session{'company_id'} if ! exists $session{'/employee/inventory/paper.html?owner_id'};
    $session{'/employee/inventory/paper.html?type'} = 'Roll,Sheet' if ! exists $session{'/employee/inventory/paper.html?type'};
	ssi::setup_date_select( '/employee/inventory/paper.html', 'added_on_start', -7 );
	ssi::setup_date_select( '/employee/inventory/paper.html', 'added_on_end', '' );
	$session{'/employee/inventory/paper.html?instock'} = 'B' if ! $session{'/employee/inventory/paper.html?instock'};

} # end sub paper

sub _paper_results {
	ssi::save_params( '/employee/inventory/paper.html', ( 
				'manufacturer_id','brand_id','finish_id','colour_id','weight_id','quality_id', 
				'type','owner_id','material_id','group_id', 'condition_id',
				( map { 'added_on_start_'.$_ } ( 'year','month','day' ) ),
				( map { 'added_on_end_'.$_ } ( 'year','month','day' ) ),
				'Docket','fsc_code','width','height','OrLarger','instock','owner_id_exclude','allocated',
			) );
	$session{'/employee/inventory/paper.html?owner_id_exclude'} = $param{'owner_id_exclude'} if exists $param{'owner_id'};
	$session{'/employee/inventory/paper.html?OrLarger'} = $param{'OrLarger'};
} # end sub _paper_results

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
		$Paper->brand( $param{'txtBrand'} ) if $param{'txtBrand'};
		$Paper->brand_id( $param{'Brand'} ) if $param{'Brand'};
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
		$Paper->mweight( $param{'mweight'} ) if $param{'mweight'};
		$Paper->basis_mweight( $param{'basis_weight'} ) if exists $param{'basis_weight'};
$openprint::log->debug("Basis:: " . $Paper->basis_mweight() );
		$Paper->basis_width( $param{'basis_width'} ) if exists $param{'basis_width'};
		$Paper->basis_height( $param{'basis_height'} ) if exists $param{'basis_height'};
		if ( exists $param{manufacturers_name} ) {
			s/^\s+//, s/\s+$//, s/\s+/ /g for $param{manufacturers_name};
			$Paper->manufacturers_name( $param{manufacturers_name} );
		} # end if
		$Paper->gsm( $param{'gsm'} ) if $param{gsm};
		$Paper->calliper( $param{'txtCalliper'} );
		$Paper->fsc_code( $param{'fsc_code'} );
		if ( ! $param{'paper_id'} ) {
			my @papers = openprint::Paper->find(
					( $param{'Owner'} ? ( 'owner_id'	=>	$param{'Owner'} ) : () ),
					( $param{'txtManufacturer'} ? ( 'manufacturer'		=>	$param{'txtManufacturer'} ) : () ),
					( $param{'Manufacturer'} ? ( 'manufacturer_id'	=>	$param{'Manufacturer'} ) : () ),
					( $param{'txtBrand'} ? ( 'brand'		=>	$param{'txtBrand'} ) : () ),
					( $param{Brand} ? ( 'brand_id'	=>	$param{'Brand'} ) : () ),
					( $param{txtFinish} ? ( 'finish'	=>	$param{'txtFinish'} ) : () ),
					( $param{Finish} ? ( 'finish_id' =>	$param{'Finish'} ) : () ),
					( $param{txtColour} ? ( 'colour'	=>	$param{'txtColour'} ) : () ),
					( $param{Colour} ? ( 'colour_id' =>	$param{'Colour'} ) : () ),
					( $param{txtWeight} ? ( 'weight'	=>	$param{'txtWeight'} ) : () ),
					( $param{Weight} ? ( 'weight_id' =>	$param{'Weight'} ) : () ),
					( $param{txtQuality} ? ( 'quality'	=>	$param{'txtQuality'} ) : () ),
					( $param{Quality} ? ( 'quality_id'=>	$param{'Quality'} ) : () ),
					( $param{width} ? ( 'width'		=> $param{'width'} ) : () ),
					( $param{height} ? ( 'height'	=>	$param{'height'} ) : () ),
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
		if ( exists $param{'Captcha'} ) {
	# Remove spaces, because some people want to put spaces between the characters, etc.
			$param{'Captcha'} =~ s/\s//g;
			my $Captcha = new Authen::Captcha('data_folder' => '/tmp', 'output_folder' => $config{'SkinPath'}.'/images/captcha');
			if ( 1 != $Captcha->check_code( @param{'Captcha','MD5SUM'} ) ) {
				$variable{'error'} .= 'Captcha Validation Code incorrect.	Please try again.';
				return;
			} # end if
		} # end if
		foreach my $condition_id ( sets::union( map { $_->condition_id() } openprint::SkidContent->find(paper_id=>$param{paper_id},deleted=>0,
						( $param{skid_id} ? ( skid_id=>$param{skid_id} ) : () ),'quantity >' =>0 ) ) ) {
			next if ! $param{'quantity-'.$condition_id};
			allocate( @param{'skid_id','paper_id','quantity-'.$condition_id,'Project','Docket','specific','reason'}, $condition_id );
		} # end foreach condition
		@session{'error','warning','information'} = @variable{'error','warning','information'};
		$variable{'ExternalRedirect'} = '/employee/inventory/paper_details.html?paper_id='.$Paper->id();
		%param = ();
		return;
	} elsif ( $param{'btnFunction'} eq 'CheckOut' ) {
		check_out( undef, @param{'paper_id','Quantity','Project','Docket','reason'} );
	} elsif ( $param{'btnFunction'} eq 'Merge' ) {
		if ( ! $Paper->id() ) {
			$variable{error} .= 'Cant merge.  No given stock.';
			return;
		} # end if
		my @Duplicates = openprint::Paper->find(
				'manufacturer_id'	=> $Paper->manufacturer_id(),
				'brand_id'			=> $Paper->brand_id(),
				'finish_id'			=> $Paper->finish_id(),
				'colour_id'			=> $Paper->colour_id(),
				'weight_id'			=> $Paper->weight_id(),
				'quality_id'		=> $Paper->quality_id(),
				'width'				=> $Paper->width(),
				'height'			=> $Paper->height(),
				fsc_code			=>	$Paper->fsc_code(),
				);

		foreach my $Duplicate ( @Duplicates ) {
			next if $Duplicate->id() == $Paper->id();
			$Paper->merge( $Duplicate );
		} # end foreach
		$variable{'ExternalRedirect'} = '/employee/inventory/paper_details.html?paper_id='.$Paper->id();
	} # end if
	$variable{'Paper'} = $Paper;
	$variable{'paper_id'} = $$Paper{'id'};
} # end sub paper_details

sub save_Paper {
	my ( $id ) = @_;

	if ( $param{'calliper'.$id} > 1 ) {
		$param{'calliper'.$id} /= 1000;
	} # end if

	my $weight;
	if ( $param{'txtWeight'.$id} ) {
		$weight = $param{'txtWeight'.$id};
	} elsif ( $param{'weight'.$id} ) {
		if ( $param{'weight'.$id} =~ /([\d\.]+)PT/i ) {
			$param{'calliper'.$id} = $1 if ! $param{'calliper'.$id};
			$weight = '';
		} else {
			$weight = $param{'weight'.$id};
			$weight .= 'lb' if ! ( $param{'weight'.$id} =~ /lb/ );
		} # end if
	} elsif ( $param{'calliper'.$id} ) {
		$weight = ($param{'calliper'.$id}*1000).'PT';
	} # end if

	my @Papers = openprint::Paper->find(
			( $param{'Owner'.$id} ? ( 'owner_id'	=>	$param{'Owner'.$id} ) : () ),
			( $param{'Manufacturer'.$id} ? ( 'manufacturer_id'	=>	$param{'Manufacturer'.$id} ) : () ),
			( $param{'txtManufacturer'.$id} ? ( 'manufacturer'		=>	$param{'txtManufacturer'.$id} ) : () ),
			( $param{'Brand'.$id} ? ( 'brand_id'	=>	$param{'Brand'.$id} ) : () ),
			( $param{'txtBrand'.$id} ? ( 'brand'		=>	$param{'txtBrand'.$id} ) : () ),
			( $param{'Finish'.$id} ? ( 'finish_id' =>	$param{'Finish'.$id} ) : () ),
			( $param{'txtFinish'.$id} ? ( 'finish'	=>	$param{'txtFinish'.$id} ) : () ),
			( $param{'Colour'.$id} ? ( 'colour_id' =>	$param{'Colour'.$id} ) : () ),
			( $param{'txtColour'.$id} ? ( 'colour'	=>	$param{'txtColour'.$id} ) : () ),
			( $param{'Weight'.$id} ? ( 'weight_id' =>	$param{'Weight'.$id} ) : () ),
			'weight'	=>	$weight,
# We might 
			( $param{'width'.$id} ? ( 'width'		=> $param{'width'.$id} ) : () ),
			( $param{'height'.$id} ? ( 'height'	=>	$param{'type'.$id} ne 'Roll' ? $param{'height'.$id} : undef ) : () ),
			( $param{'type'.$id} ? ( 'type'		=>	$param{'type'.$id} ) : () ),
			( $param{'calliper'.$id} ? ( 'calliper'	=>	$param{'calliper'.$id} ) : () ),
			( $param{'fsc_code'.$id} ? ( 'fsc_code'	=>	$param{'fsc_code'.$id} ) : ( 'fsc_code is null or =' => $param{'fsc_code'.$id} ) ),
			);
	my $Paper;

# Paper not found, this is the first time we are adding it to the skid
	if ( 0 == @Papers ) {
		$Paper = new openprint::Paper( );
		$Paper->owner_id( $param{'Owner'.$id} );
		$Paper->manufacturer( $param{'txtManufacturer'.$id} ) if $param{'txtManufacturer'.$id};
		$Paper->manufacturer_id( $param{'Manufacturer'.$id} ) if $param{'Manufacturer'.$id};
		$Paper->brand( $param{'txtBrand'.$id} ) if $param{'txtBrand'.$id};
		$Paper->brand_id( $param{'Brand'.$id} ) if $param{'Brand'.$id};
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
		if ( $weight =~ /^([\d\.]+)lb$/ ) {
			$Paper->basis_mweight( $1 * 2 );
		} # end if
		$Paper->calliper( $param{'calliper'.$id} );
		$Paper->mweight( $param{'mweight'.$id} );
		$Paper->basis_weight( $param{'basis_weight'.$id} ) if exists $param{'basis_weight'.$id};
		$Paper->gsm( $param{'gsm'.$id} );
		if ( my $error = $Paper->save() ) {
			$variable{'error'} .= $error;
		} else {
			$variable{'information'} .= 'Paper created.<br/>';
		} # end if
	} else {
		if ( 1 < @Papers ) {
			$variable{'error'} .= 'Duplicate Paper Detected!.<br/>';
			$variable{'information'} .= 'The following papers both match, please edit them:<br/>';
			foreach my $Paper ( @Papers ) {
				$variable{'information'}	.= '<a href="paper_details.html?paper_id='.$Paper->id().'">'.$Paper->to_string().'</a><br/>';
			} # end foreach
		} # end if
		$Paper = shift @Papers;
		my $changed = 0;
# This is so that papers that don't have mweights will get filled in
		if ( ( ! $Paper->basis_mweight() ) and $param{'weight'.$id} ) {
			$Paper->basis_mweight( $param{'weight'.$id} * 2 );
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
		if ( ( ! $Paper->fsc_code() ) and $param{'fsc_code'.$id} ) {
			$Paper->fsc_code( $param{'fsc_code'.$id} );
			$changed = 1;
		} # end if
		if ( $param{'Quality'} ) {
			if ( $param{'Quality'} != $Paper->quality_id() ) {
				$Paper->quality_id( $param{'Quality'} );
				$changed = 1;
			} # end if
		} elsif ( $param{'txtQuality'} ) {
			$Paper->quality($param{'txtQuality'});
			$changed = 1;
		} # end if
		if ( $changed ) {
			$Paper->save();
		} # end if
	} # end if
	return $Paper;
} # end sub save_Paper

sub save_inventory {
	my ( $Skid, $Paper, $qty, $comment, $Condition, $Purpose ) = @_;
	my $delta = $Skid->add( $Paper, $qty, $Condition, $Purpose );
	$Paper->add_inventory( $Skid, $delta, $param{'Units'}, $comment ) if ( $delta or $comment );
#FIXME
	if ( $delta > 0 ) {
		$variable{'information'} .= sprintf( 'Added %1$d%2$s to inventory for skid <a href="/employee/inventory/skid_details.html?skid_id=%3$d">%3$d</a>.<br/>', $delta,$Paper->type() eq 'Roll' ? 'lbs' : 'sheets', $Skid->id() );

	} elsif ( $delta < 0 ) {
		$variable{'information'} .= sprintf( 'Removed %1$d%2$s from inventory for skid <a href="/employee/inventory/skid_details.html?skid_id=%3$d">%3$d</a>.<br/>', $delta,$Paper->type() eq 'Roll' ? 'lbs' : 'sheets', $Skid->id() );
	} else {
		$variable{'information'} .= sprintf( 'No change was made to inventory for skid <a href="/employee/inventory/skid_details.html?skid_id=%1$d">%1$d</a>.<br/>', $Skid->id() );
	}# end if

} # end if save_inventory

sub save_Skid {
	my ( $Skid, $qty ) = @_;

	$qty = $param{'Quantity'} if ! defined $qty;

	my $info;
	if ( ( exists $param{rfidtag_id} ) and ( $param{rfidtag_id} ne $Skid->rfidtag_id() ) ) {
		$info .= sprintf( 'Changed rfid tag from %s to %s<br/>', $Skid->rfidtag_id(), $param{rfidtag_id} );
		$Skid->rfidtag_id( $param{'rfidtag_id'} );
	} # end if
	if ( ( exists $param{location_id} ) and $param{location_id} and ( $param{location_id} != $Skid->location_id() ) ) {
		$info .= sprintf( 'Changed location from %s to %s<br/>', $Skid->Location()->name(), new openprint::Location( $param{location_id} )->name() );
		$Skid->location_id( $param{location_id} );
	} # end if
	if ( ( exists $param{ddmLocation} ) and $param{ddmLocation} and ( $param{ddmLocation} != $Skid->location_id() ) ) {
		$info .= sprintf( 'Changed location from %s to %s<br/>', $Skid->Location()->name(), new openprint::Location( $param{ddmLocation} )->name() );
		$Skid->location_id( $param{ddmLocation} );
	} # end if
	if ( ( exists $param{txtLocation} ) and $param{txtLocation} and ( $param{txtLocation} != $Skid->Location()->name() ) ) {
		$info .= sprintf( 'Changed location from %s to %s<br/>', $Skid->Location()->name(), $param{txtLocation} );
		$Skid->location( $param{'txtLocation'} );
	} # end if
	if ( ( exists $param{manufacturers_id} ) and $param{manufacturers_id} and ( $param{manufacturers_id} != $Skid->manufacturers_id() ) ) {
		$info .= sprintf( 'Changed manufacturers id from %s to %s<br/>', $Skid->manufacturers_id(), $param{manufacturers_id} );
		$Skid->manufacturers_id( $param{manufacturers_id} );
	} # end if
	if ( exists $param{received_on_year} ) {
		if ( openprint::usergroup::is_user_in( ['InventoryManager'], $session{'user_id'} ) or ! $Skid->id() ) {
			if ( ! Date::Calc::check_date( @param{'received_on_year','received_on_month','received_on_day'} ) ) {
				$variable{error} .= 'Invalid Received On Date.';
			} else {
				my $date = sprintf('%.4d-%.2d-%.2d', @param{'received_on_year','received_on_month','received_on_day'});
				if ( $Skid->received_on() ne $date ) {
					$info .= sprintf( 'Changed received on date from %s to %s<br/>', $Skid->received_on(), $date );
					$Skid->received_on( $date );
				} # end if
			} # end if
		} else {
			$variable{error} .= 'You are not authorized to change the received on date.<br/>';
		} # end if
	} # end if
	if ( ! $Skid->received_on() ) {
		$info .= 'Set received on date to today<br/>';
		$Skid->received_on( join('-', Date::Calc::Today() ) );
	} # end if
	if ( $param{skid_id} and ! $Skid->id() ) {
		$info .= 'Assigning id ' . $param{skid_id} . '<br/>';	
		$Skid->id( $param{skid_id} );
	} # end if
	if ( $info and ( my $error = $Skid->save() ) ) {
		$variable{error} .= $error;
		return;
	} # end if

	my $Condition;
	if ( $param{txtCondition} ) {
		if ( ! ( $Condition = openprint::InventoryCondition->find_one('name lc'=>lc openprint::InventoryCondition->transform('name',$param{txtCondition})) ) ) {
			$Condition = new openprint::InventoryCondition();
			$variable{error} .= $Condition->save({name=>$param{txtCondition}});
		} # end if
		$param{Condition} = $Condition->id();
	} else {
		$Condition = new openprint::InventoryCondition( $param{Condition} );
	} # end if

	my $Purpose;
	if ( $param{txtPurpose} ) {
		if ( ! ( $Purpose = openprint::StockPurpose->find_one('name lc'=>lc openprint::StockPurpose->transform('name',$param{txtPurpose})) ) ) {
			$Purpose = new openprint::StockPurpose();
			$variable{error} .= $Purpose->save({name=>$param{txtPurpose}});
		} # end if
		$param{Purpose} = $Purpose->id();
	} else {
		$Purpose = new openprint::StockPurpose( $param{Purpose} );
	} # end if
	
	if ( $param{'Brand'} or $param{'txtBrand'} ) {
		my $Paper = save_Paper();

		if ( $Paper and $Paper->id() ) {
			save_inventory( $Skid, $Paper, $qty, $info, $Condition, $Purpose );

			if ( $param{'Docket'} ) {
				my @Projects = openprint::Project->find('docket'=>$param{'Docket'} );

				if ( ! @Projects ) {
					$variable{'error'} .= "Docket $param{'Docket'} not found. No paper allocated. CSR not notified.<br/>";
				} else {
					my $Project = $Projects[0] if @Projects;
					my $Allocation = openprint::PaperAllocation->find_one( 'skid_ids any'=>$$Skid{id} );
					if ( $Allocation ) {
						if ( ! sets::isin( $Allocation->project_id(), [ map { $_->id() } @Projects ] ) ) {
							$variable{error} .= sprintf('Skid is already allocated to project <a href="/employee/project/view.html?project_id=%1$d">%1$d</a>.<br/>',$Allocation->project_id() );
						} else {
							# Already allocated
						} # end if
					} else {
						$Paper->allocate( $$Skid{'id'}, $Project->id(), $qty, $param{'Units'} );
						$variable{'information'} .= sprintf('Allocated %1$d%2$s to docket <a href="/employee/project/view.html?ProjectIndex=%3$d">%4$d</a>.<br/>', $qty, $param{'Units'}, $Project->id(), $Project->docket() );
					} # end if
				} # end if
			} # end if
		} # end if Paper
	} elsif ( $param{'Docket'} ) {
		my @Projects = openprint::Project->find('docket'=>$param{'Docket'} );

		if ( ! @Projects ) {
			$variable{'error'} .= "Docket $param{'Docket'} not found. No paper allocated.<br/>";
		} else {
			my $Allocation = openprint::PaperAllocation->find_one( 'skid_ids any'=>$$Skid{id} );
			if ( $Allocation ) {
				if ( ! sets::isin( $Allocation->project_id(), [ map { $_->id() } @Projects ] ) ) {
					$variable{error} .= sprintf('Skid is already allocated to project <a href="/employee/project/view.html?project_id=%1$d">%1$d</a>.<br/>',$Allocation->project_id() );
				} else {
# Already allocated
				} # end if
			} else {
				$Skid->allocate( undef, $Projects[0]->id(), $qty, $param{'Units'} );
				$variable{'information'} .= sprintf('Allocated %1$d%2$s to docket <a href="/employee/project/view.html?ProjectIndex=%3$d">%4$d</a>.<br/>', $qty, $param{'Units'}, $Projects[0]->id(), $Projects[0]->docket() );
			} # end if
		} # end if
	} # end if
} # end sub save_Skid

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

	if ( ! @skid_ids ) {
		if ( $param{'rfidtag_id'} ) {
			my @RFIDTags = openprint::RFIDTag->find( 'id like' => '%'.$param{'rfidtag_id'}, 'order' => 'id','type'=>'Skid');
			if ( @RFIDTags == 1 ) {
				@skid_ids = ( $RFIDTags[0]->skid_id() );
				#$param{'skid_id'} = $skid_ids[0];
			} # end if
		} elsif ( $param{'rfidtag_hex'} ) {
			my @RFIDTags = openprint::RFIDTag->find( 'id like' => '%'.hex($param{'rfidtag_hex'}).'%', 'order' => 'id','type'=>'Skid');
			if ( @RFIDTags == 1 ) {
				@skid_ids = ( $RFIDTags[0]->skid_id() );
				#$param{'skid_id'} = $skid_ids[0];
			} # end if
		} # end if
	} # end if

	my $Skid = $variable{'Skid'} = new openprint::Skid( @skid_ids ? $skid_ids[0] : undef );
	$variable{skid_ids} = \@skid_ids;

	if ( $param{skid_id} and ! openprint::Skid->find( id=>\@skid_ids, deleted=>[0,1] ) and $param{'btnFunction'} ne 'Save' ) {
		$variable{error} .= "Skid $param{skid_id} not found!<br/>";
		return;
	} # end if

	$variable{'similar'} = 1;
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
		$session{'/employee/inventory/skid_details.html?verification_code'} = $param{'verification_code'} if $param{'verification_code'};
		my @quantities = misc::trim( split ',', $param{'Quantity'} );

		if ( @skid_ids and (@quantities>1) and ( @quantities != @skid_ids ) ) {
			$variable{'error'} .= 'When saving to multiple skids, the # of quantities must match the # of skids.You entered '.@quantities . ' but specified ' . @skid_ids . ' skids<br/>';
			return;
		} # end if
		if ( $param{'rfidtag_id'} ) {
			my @rfidtags = misc::trim( split ',', $param{'rfidtag_id'} );
			if ( @skid_ids and ( @rfidtags != @skid_ids ) ) {
				$variable{'error'} .= 'When saving to multiple skids, the # of rfidtags must match the # of skids.<br/>';
				return;
			} # end if

			foreach my $rfidtag_id ( @rfidtags ) {
				#$log->debug( $rfidtag_id );
				if ( $_ = openprint::RFIDTag::is_invalid_id( $rfidtag_id ) ) {
					$variable{'error'} .= "RFIDTAG $rfidtag_id is invalid: $_.<br/>";
					next;
				} # end if
				my $RFIDTag = new openprint::RFIDTag( $rfidtag_id );
				if ( $RFIDTag->id() ) {
					my $skid_id = $RFIDTag->skid_id();
					if ( $skid_id and ( $skid_id != $param{'skid_id'} ) ) {
						$variable{'error'} .= "RFIDTAG $rfidtag_id is already assigned to skid <a href=\"/employee/inventory/skid_details.html?skid_id=$skid_id\">$skid_id</a>.<br/>";
						next;
					} # end if
				} # end if RFIDTag->id()
			} # end foreach rfidtag_id
		} # end if param{rfidtag_id}
		if ( $param{manufacturers_id} ) {
			my @manufacturers_ids = split(',', $param{manufacturers_id} );
		
			if ( @skid_ids ) {
				if ( @skid_ids != @manufacturers_ids ) {
					$variable{error} .= 'When saving to multiple skids, the # of manufacturer_ids must match the # of skids<br/>';
					return;
				} # en dif
				if ( my @mismatched = openprint::Skid->find( manufacturers_id => \@manufacturers_ids, 'id not in' => \@skid_ids ) ) {
					$variable{error} .= join("\n", map { sprintf('Manufacturer id %1$s is already assigned to skid <a href="/employee/inventory/skid_details.html?skid_id=%2$d">%2$d</a>.<br/>', $_->manufacturers_id(), $_->id() ) } @mismatched );
				} # end if		
			} else {
				
				if ( my @mismatched = openprint::Skid->find( manufacturers_id => \@manufacturers_ids ) ) {
					$variable{error} .= join("\n", map { sprintf('Manufacturer id %1$s is already assigned to skid <a href="/employee/inventory/skid_details.html?skid_id=%2$d">%2$d</a>.<br/>', $_->manufacturers_id(), $_->id() ) } @mismatched );
				} # end if		
			} # end if
		} # end if
		return if $variable{'error'};

		# Skid_quantity only exists if adding new stock
		if ( $param{skid_quantity} ) {
			if ( @quantities != $param{'skid_quantity'} ) {
				$variable{'error'} .= 'When saving to multiple skids, the # of quantities must match the # of skids.';
				return;
			} # end if
			if ( $param{'skid_quantity'} > 100 ) {
				$variable{'error'} .= 'Cannot enter more than 100 skids/rolls at a time.';
				return;
			} # end if
			$variable{'Skids'} = [];
			foreach my $skid_count ( 1 .. $param{'skid_quantity'} ) {
$log->debug("Entering skid $skid_count");
				my $S = new openprint::Skid();
				$param{'Quantity'} = @quantities > 1 ? $quantities[$skid_count-1] : $quantities[0] if @quantities;
				save_Skid( $S );
				push @{$variable{'Skids'}}, $S;
				if ( ! $variable{'Paper'} ) {
					if ( my @C = $S->Contents() ) {
						$variable{'paper_id'} = $C[0]->paper_id();
						$variable{'Paper'} = new openprint::Paper( $variable{'paper_id'} );
					} # end of
				} # end of
				if ( $param{'verification_code'} ) {
					my $SV = new openprint::Skid_Verification();
					$variable{error} .= $SV->save({
						skid_id	=>	$S->id(),
						code	=>	$param{verification_code},
						user_id	=>	$session{user_id},
					});
				} # end if verification_code
			} # end foreach
			$variable{'information'} .= "Added $param{'skid_quantity'} skids/rolls.<br/>";
		} elsif ( @skid_ids ) {
$log->debug("sacing @skid_ids,");
			foreach my $skid_id ( @skid_ids ) {
				my $Skid = new openprint::Skid( $skid_id );
				if ( exists $param{Quantity} ) {
					$param{Quantity} = @quantities > 1 ? shift @quantities : $quantities[0] if @quantities;
					$Skid->id( $skid_id );
				} # end if
				save_Skid( $Skid );
				if ( $param{'verification_code'} ) {
					my $SV = new openprint::Skid_Verification();
					$SV->save({
						skid_id	=>	$skid_id,
						code	=>	$param{verification_code},
						user_id	=>	$session{user_id},
					});
				} # end if verification_code
			} # end foreach
		} else {
			$variable{'error'} .= 'Please enter the # of skids/rolls to enter.';
			return;
		} # end if

	} elsif ( sets::isin( $param{'btnFunction'}, 'Copy', 'Duplicate' ) ) {
		my @new_skid_ids;
		foreach my $skid_id ( @skid_ids ) {
			my $Skid = new openprint::Skid( $skid_id );
			$Skid = $Skid->copy();
			push @new_skid_ids, $Skid->id() if $Skid->id();
		} # end foreach
		@skid_ids = @new_skid_ids;
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		foreach my $skid_id ( @skid_ids ) {
			my $Skid = new openprint::Skid( $skid_id );
			$variable{'information'} .= $Skid->delete();
			my $PI = new openprint::PaperInventory();
			$PI->save({skid_id=>$skid_id, user_id=>$session{user_id}, comment=>'Skid Deleted.'});
		} # end foreach
		$variable{ExternalRedirect} = '/employee/inventory/skid_details.html?skid_id='.join(',',@skid_ids);
	} elsif ( $param{'btnFunction'} eq 'Undelete' ) {
		foreach my $skid_id ( @skid_ids ) {
			my $Skid = new openprint::Skid( $skid_id );
			$variable{'information'} .= $Skid->undelete();
			my $PI = new openprint::PaperInventory();
			$PI->save({skid_id=>$skid_id, user_id=>$session{user_id}, comment=>'Skid Undeleted.'});
		} # end foreach
		$variable{ExternalRedirect} = '/employee/inventory/skid_details.html?skid_id='.join(',',@skid_ids);
	} elsif ( $param{'btnFunction'} eq 'Print Label' ) {
		foreach my $skid_id ( @skid_ids ) {
			my $Skid = new openprint::Skid( $skid_id );
			$Skid->print_label();
		} # end foreach
	} elsif ( $param{'btnFunction'} eq 'Allocate' ) {
		if ( exists $param{'Captcha'} ) {
	# Remove spaces, because some people want to put spaces between the characters, etc.
			$param{'Captcha'} =~ s/\s//g;
			my $Captcha = new Authen::Captcha('data_folder' => '/tmp', 'output_folder' => $config{'SkinPath'}.'/images/captcha');
			if ( 1 != $Captcha->check_code( @param{'Captcha','MD5SUM'} ) ) {
				$variable{'error'} .= 'Captcha Validation Code incorrect.	Please try again.';
				return;
			} # end if
		} # end if
		foreach my $skid_id ( @skid_ids ) {
			foreach my $condition_id ( sets::union( map { $_->condition_id() } openprint::SkidContent->find(skid_id=>$skid_id, paper_id=>$param{paper_id},'quantity >' =>0 ) ) ) {
				next if ! $param{'quantity-'.$condition_id};
				allocate( $skid_id, @param{'paper_id','quantity-'.$condition_id,'Project','Docket','specific','reason'}, $condition_id );
			} # end foreach condition
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
		$variable{ExternalRedirect} = '/employee/inventory/skid_details.html?skid_id='.join(',',@skid_ids);
	} elsif ( $param{'btnFunction'} eq 'CheckOut' ) {
		my $qty = $param{'Quantity'};
		foreach my $skid_id ( @skid_ids ) {
			$qty -= check_out( $skid_id, $param{'paper_id'}, $qty, @param{'Project','Docket','reason'} );
			last if ! $qty;
		} # end foreach
		$variable{ExternalRedirect} = '/employee/inventory/skid_details.html?skid_id='.join(',',@skid_ids);
	} elsif ( $param{'btnFunction'} eq 'DeletePaper' ) {
		my $C = new openprint::SkidContent($param{'content_id'});
		if ( ! $C->id() ) {
			$variable{error} .= 'Paper not found on skid. No changes made.<br/>';
			$log->error("Paper not found on skid. WHy?!");
		} else {
			my $PI = new openprint::PaperInventory();
			$PI->save({ user_id=>$session{user_id}, skid_id=>$C->Skid()->id(), paper_id=>$$C{paper_id}, comment=>'Deleted from skid.'});
			$variable{'error'} .= $C->delete();
			$variable{ExternalRedirect} = '/employee/inventory/skid_details.html?skid_id=>'.$$C{skid_id};
		} # end if
	} # end if

	$variable{'Skid'} = new openprint::Skid( @skid_ids ? $skid_ids[0] : undef );
	$variable{'skid_id'} = $variable{'Skid'}->id() ? $variable{'Skid'}->id() : $param{'skid_id'};
	$variable{'skid_ids'} = \@skid_ids;

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
		my @papers = $Skid->Contents();
		if ( 1 == @papers ) {
			$Paper = $papers[0]->Paper();
			$paper_id = $Paper->id();
		} else {
			$variable{'error'} .= 'Skid contains more than one type of paper.	You must specify.<br/>';
			return;
		} # end if
	} # end if

	my $available_qty = $Paper->in_stock();
	my $units = $Paper->type() eq 'Roll' ? 'lbs' : 'sheets';
	$project_id = openprint::Project->transform( 'id', $project_id );
	$docket = openprint::Project->transform( 'docket', $docket );
	my @Projects = openprint::Project->find( 
		( $project_id ? ( id=>$project_id ) : () ),
		( $docket ? ( docket=>$docket ) : () ),
	) if $project_id or $docket;

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

	my $description =	'Checked out';
	if ( @Projects ) {
		$description .= sprintf( ' for docket <a href="/employee/project/view.html?ProjectIndex=%1$d">%2$d</a>', $Projects[0]->id(), $Projects[0]->docket() );
	} # end if
	if ( $reason ) {
		$description .= ': ' . $reason;
	} # end if

	my $qty = $quantity;
	foreach my $skid_id ( @skids ) {
		my $Skid = new openprint::Skid( $skid_id );
		my $C = $Skid->Content( $Paper );
		if ( $C->quantity() <= 0 ) {
			# No paper on skid
		} elsif ( $C->quantity() < $qty ) {
			my $amount = $C->quantity();
			$qty -= $amount;
			$amount *= -1;
			$C->save({'quantity'=>0});
			$Paper->add_inventory( $Skid, $amount, $units, $description, @Projects ? $Projects[0] : () );
			$Paper->allocate( $Skid->id(), $Projects[0]->id(), $amount ) if @Projects and $Paper->allocated( $Projects[0]->id() );
		} else {
			$C->save({ quantity=>($C->quantity() - $qty)});
			if ( @Projects ) {
				$Paper->add_inventory( $Skid, -1*$qty, $units, $description, $Projects[0] );
				$Paper->allocate( $Skid->id(), $Projects[0]->id(), -1*$qty ) if $Paper->allocated( $Projects[0]->id() );
			} else {
				$Paper->add_inventory( $Skid, -1*$qty, $units, $description );
			} # end if
			$qty = 0;
		} # end if
		delete $$Skid{'Contents'};
		last if ! $qty;
	} # end foreach

	if ( @Projects ) {
		$variable{'information'} .= sprintf('Checked out %1$d%2$s to docket <a href="/employee/project/view.html?ProjectIndex=%3$d">%4$d</a><br/>', $quantity, $units, $Projects[0]->id(), $Projects[0]->docket() );
	} else {
		$variable{'information'} .= "Checked out $quantity$units to unknown docket.<br/>";
	} # end if
	return $quantity;
} # end sub check_out

sub check_in {
	my ( $skid_id, $paper_id, $quantity, $project_id, $docket, $reason, $Condition ) = @_;
	if ( ! ( $paper_id or $skid_id ) ) {
		$variable{error} .= 'Skid or Paper not specified. No paper checked in.<br/>';
		return;
	} # end if
	my $Paper;
	my $Skid = new openprint::Skid( $skid_id );

	if ( $paper_id ) {
		$Paper = new openprint::Paper( $paper_id );
	} elsif ( $skid_id ) {
		my @papers = $Skid->Contents();
		if ( 1 == @papers ) {
			$Paper = $papers[0]->Paper();
			$paper_id = $Paper->id();
		} else {
			$variable{error} .= 'Skid contains more than one type of paper. You must specify.<br/>';
			return;
		} # end if
	} # end if
	if ( ! $Condition ) {
		my $C = $Skid->Content( $Paper );
		$Condition = $C->Condition();
	} elsif ( DEBUG ) {
		$log->debug("check_in: Condition is $Condition");
	} # end if
	$project_id =~ s/\D//g;
	$docket =~ s/\D//g;
	my @Projects = openprint::Project->find( 
		( $project_id ? ( id=>$project_id ) : () ),
		( $docket ? ( docket=>$docket ) : () ) 
		) if $project_id or $docket;

# Default to add
	$quantity =~ s/[^\d\.\-]//g;
$log->debug("Checking in $quantity");
	if	( $quantity =~ /^\d/ ) {
		$quantity = '+' . $quantity;
	} # end if

	my $description = 'Added';
	if ( @Projects ) {
		$description .= sprintf(' from docket <a href="/employee/project/view.html?ProjectIndex=%d">%d</a>', $Projects[0]->id(), $Projects[0]->docket() );
	} # end if
	if ( $reason ) {
		$description .= ' : ' . $reason;
	} # end if

	my $units = $Paper->units();
	my $delta = $Skid->add( $Paper, $quantity, $Condition );
	if ( ! @Projects ) {
		$Paper->add_inventory( $Skid, $delta, $units, $description );
		$variable{'information'} .= "Checked in $quantity$units from unknown docket.<br/>";
	} else {
		my $Project = shift @Projects;
		$Paper->add_inventory( $Skid, $delta, $units, $description, $Project );
		$variable{'information'} .= sprintf('Checked in %1$d%2$s from docket <a href="/employee/project/view.html?ProjectIndex=%3$d">%4$d</a><br/>', $quantity, $units, $Project->id(), $Project->docket() );
	} # end if
	$Skid->save();
} # end sub check_in

# allocate
# skid_ids is plural because it may be a comma delimited string of skid_ids
sub allocate {
	my ( $skid_ids, $paper_id, $quantity, $project_id, $docket, $specific, $reason, $condition_id ) = @_;
	if ( ! $paper_id ) {
		$variable{'error'} .= 'Paper not specified. No paper allocated.<br/>';
		return;
	} # end if
	my $Paper = new openprint::Paper( $paper_id );
	if ( ! $Paper->id() ) {
		$variable{'error'} .= 'Invalid stock specified. No stock allocated.<br/>';
		return;
	} # end if
	my $units = $Paper->units();
	$project_id =~ s/\D//g;
	$docket =~ s/\D//g;
	$quantity =~ s/[^\d\.]//g;
	$quantity =~ s/(\d+)\..*/$1/g;
	my @Projects = openprint::Project->find( ( $project_id ? ( id=>$project_id ) : () ), ( $docket ? ( docket=>$docket ) : () ) ) if $project_id or $docket;

	if ( $docket and ! @Projects ) {
		if ( my $Order = openprint::Order->find_one(docket=>$docket) ) {
			@Projects = $Order->Projects();
		} # end if
	} # end if
	if ( ! @Projects ) {
		$variable{'error'} .= 'An invalid Docket or Project # was given. No paper allocated. This can happen if the order has been left re-opened.<br/>';
		return;
	} # end if

	my @skid_ids = split(',', $skid_ids );
	if ( $specific and ! @skid_ids ) {
		if ( $quantity < 0 ) {
			@skid_ids = map { $_->skid_id() } openprint::PaperAllocation->find(paper_id=>$paper_id, project_id=>$Projects[0]->id(), ( $condition_id ? ( condition_id=>$condition_id ) : () ) );
		} else {
			@skid_ids = map { $_->skid_id() } openprint::SkidContent->find(deleted=>0,paper_id=>$paper_id, project_id=>$Projects[0]->id(), ( $condition_id ? ( condition_id=>$condition_id ) : () ) );
		} # end if
	} # end if

	my $qty = $quantity;
	my @allocated_skids;

	if ( @skid_ids ) {
		if ( $qty < 0 ) {
			foreach my $skid_id ( @skid_ids ) {
				my $Skid = new openprint::Skid( $skid_id );
				my $allocateable = $Skid->allocateable( $Paper );
				next if ! $allocateable;

				if ( $allocateable < -1*$qty ) {
					push @allocated_skids, $skid_id;
					#push @allocations, $Paper->allocate( $skid_id, $Projects[0]->id(), -1*$allocateable, $units );
					$qty += $allocateable;
				} else {
					push @allocated_skids, $skid_id;
					#push @allocations, $Paper->allocate( $skid_id, $Projects[0]->id(), $qty, $units );
					$qty = 0;
				} # end if
				last if ! $qty;
			} # end foreach
		} else {
			foreach my $skid_id ( @skid_ids ) {
				my $Skid = new openprint::Skid( $skid_id );
				my $allocateable = $Skid->allocateable( $Paper );
				next if ! $allocateable;
				push @allocated_skids, $skid_id;
				$qty -= $allocateable;
				last if $qty <= 0;
			} # end foreach
		} # end if
		if ( $qty > 0 ) {
			$variable{warning} .= 'There is not enough available paper to allocate.';
		} # end if
	} else {
		my @SkidContents = openprint::SkidContent->find(
				condition_id	=>	$condition_id,
				paper_id		=>	$paper_id,
				'quantity >'	=>	1,
				deleted			=>	0,
				);
		next if ! @SkidContents;
		my @Allocations = openprint::PaperAllocation->find(
				condition_id	=>	$condition_id,
				paper_id		=>	$paper_id,
				);

		my $available = misc::sum(map { $_->quantity() } @SkidContents) - misc::sum(map { $_->quantity() } @Allocations );
		if ( $available < $qty ) {
			$variable{warning} .= 'There is not enough available paper to allocate.';
		} # end if
	} # end if
	my $PA = $Paper->allocate( \@allocated_skids, $Projects[0]->id(), $quantity, $units, $condition_id );
	
	$PA->send_notification();
	$variable{'information'} .= sprintf('Allocated %d%s to docket <a href="/employee/project/view.html?ProjectIndex=%d">%d</a><br/>', $quantity, $units, $Projects[0]->id(), $Projects[0]->docket() );
} # end sub allocate


sub send_paper_arrival_notification {
	my ( $Skid, @papers ) = @_;
	my %info;
	$info{'Skid'} = $Skid;

	@papers = map { new openprint::Paper( $_ ) } keys %{$Skid->paper()} if ! @papers;

	foreach my $Paper ( @papers ) {
		$info{'Paper'} = $Paper;
		my $C = $Skid->Content( $Paper );
		$info{'Quantity'} = $C ? $C->quantity() : 0;
		
		my @To = map { new openprint::User( $_ ); } sets::union( map { $_->Project->Order()->salesrep_id() } openprint::PaperAllocation->find('skid_ids any'=>$Skid->id(),paper_id=>$Paper->id()) );

		if ( @To ) {
# Send notification to maybe CSR's
			my $email_template = ssi::slurp_content( '/email_template.html' );

			$info{'ReplacementText'} = ssi::include( '/email_content/paper_arrived_notification.html', \%info );
			(new openprint::Email())->send(
					FROM	=> new openprint::User( $session{'user_id'} ),
					TO	=> @To,
					SUBJECT => 'Paper ' . $Paper->to_string() . ' has arrived',
					ATTACHMENTS=>['', MIME::QuotedPrint::encode_qp( ssi::variable_substitution( \$email_template, \%info ) ), 'text/html', 'quoted-printable'],
					);
		} # end if to
	} # end foreach Paper
} # end sub send_paper_arrival_notification

sub rfidtags {
	if ( $param{'btnFunction'} eq 'Delete' ) {
		foreach my $rfidtag_id ( ref $param{'rfidtags'} eq 'ARRAY' ? @{$param{'rfidtags'}} : split(',',$param{'rfidtags'}) ) {
			my $RFIDTag = new openprint::RFIDTag( $rfidtag_id );
			$variable{'error'} .= $RFIDTag->delete();
		} # end foreach rfidtag_id
	} elsif ( $param{'btnFunction'} eq 'Validate' ) {
		foreach my $rfidtag_id ( ref $param{'rfidtags'} eq 'ARRAY' ? @{$param{'rfidtags'}} : split(',',$param{'rfidtags'}) ) {
			my $RFIDTag = new openprint::RFIDTag( $rfidtag_id );
			$variable{'error'} .= $RFIDTag->save({'valid'=>1});
		} # end foreach rfidtag_id
	} else {
		ssi::save_params( '/employee/inventory/rfidtags.html', 'Type', 'created_on_start_year','created_on_start_month','created_on_start_day','created_on_end_year','created_on_end_month','created_on_end_day','updated_on_start_year','updated_on_start_month','updated_on_start_day','updated_on_end_year','updated_on_end_month','updated_on_end_day', 'assigned', 'notassigned','valid', 'location_id' );
		ssi::setup_date_select( '/employee/inventory/rfidtags.html', 'created_on_start', 0 );
		ssi::setup_date_select( '/employee/inventory/rfidtags.html', 'created_on_end', '' );
		ssi::setup_date_select( '/employee/inventory/rfidtags.html', 'updated_on_start', '' );
		ssi::setup_date_select( '/employee/inventory/rfidtags.html', 'updated_on_end', '' );
		if ( ! exists $session{'/employee/inventory/rfidtags.html?assigned'} ) {
			$session{'/employee/inventory/rfidtags.html?assigned'} = 1;
		} # end if
		if ( ! exists $session{'/employee/inventory/rfidtags.html?notassigned'} ) {
			$session{'/employee/inventory/rfidtags.html?notassigned'} = 1;
		} # end if
	} # end if
} # end sub rfidtags

sub _rfidtags_results {
	ssi::save_params( '/employee/inventory/rfidtags.html', 'Type', 'created_on_start_year','created_on_start_month','created_on_start_day','created_on_end_year','created_on_end_month','created_on_end_day','updated_on_start_year','updated_on_start_month','updated_on_start_day','updated_on_end_year','updated_on_end_month','updated_on_end_day', 'assigned', 'notassigned','valid','location_id' );
} # end sub _rfidtags_results

sub rfidtag_details {
	if ( $param{'btnFunction'} eq 'Go' ) {
		if ( $param{'rfidtag_id'} =~ /^\s*\((.*)\)\s*$/ ) {
			$param{'rfidtag_id'} = hex( $1 );
		} # end if
		if ( $param{rfidtag_id} ) {
			my @Tags = openprint::RFIDTag->find('id like'=>( $param{rfidtag_id} =~ /%/ ? $param{rfidtag_id} : '%'.$param{rfidtag_id} ) );
			if ( ! @Tags ) {
				$variable{'error'} .= 'Tag ID not found.';
			} elsif ( @Tags > 1 ) {
				@{$variable{'Tags'}} = @Tags;
			} else {
				$param{'rfidtag_id'} = $Tags[0]->id();
			} # end if
		} else {
			$variable{error} .= 'Please specify an id (or part).<br/>';
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

	_rfidtag_log_entries();

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
	_rfidscanners();
} # end sub rfidscanners
sub _rfidscanners {
	ssi::save_params( '/employee/inventory/rfidscanners.html', ( 'Type','created_on_start_year','created_on_start_month','created_on_start_day','created_on_end_year','created_on_end_month','created_on_end_day','assigned','notassigned','updated_on_start_year','updated_on_start_month','updated_on_start_day','updated_on_end_year','updated_on_end_month','updated_on_end_day' ) );
} # end sub _rfidscanners

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
	my $url = '';

	$variable{'Entries'} = [ openprint::RFIDScannerHistory->find( 
			scanner_id		=>	$param{'rfidscanner_id'},
			ssi::date_filter( $url.'location_log_start', 'updated_on_start', \%param ),
			ssi::date_filter( $url.'location_log_end', 'updated_on_end', \%param ),
			( $param{limit} ? ( $param{limit} eq 'All' ? () : ( limit	 =>	$param{limit} ) ) : ( limit=>10 ) ),
			order	 =>	'updated_on DESC',
			) ];
} # end sub rfid_scanner_log

sub save_Manifest {
	my ( $Manifest ) = @_;

	my $error;
	my $ac = sql::start_transaction( $dbh );
	$dbh->do( 'LOCK TABLE companies IN EXCLUSIVE MODE' ) or $log->error( DBI->errstr );

	$Manifest->received_on( join('-', @param{'received_on_year','received_on_month','received_on_day'} ) );

	if ( $param{supplier} and ! $param{supplier_id} ) {
		my @Companies = openprint::Company->find( name=>$param{supplier} );
		if ( ! @Companies ) {
			my $C = new openprint::Company();
			$error .= $C->save({
					supplier		=> 'Y',
					name			=> $param{supplier},
					business_name	=> $param{supplier},
					} );
			$param{supplier_id} = $C->id();
		} elsif ( @Companies == 1 ) {
			if ( $Companies[0]->supplier() ne 'Y' ) {
				$error .= $Companies[0]->save( { supplier=>'Y' } );
			} # end if
			$param{supplier_id} = $Companies[0]->id();
		} # end if
	} # end if supplier and ! supplier_id
	sql::end_transaction( $dbh, $ac );

	$ac = sql::start_transaction( $dbh );
	$dbh->do( 'LOCK TABLE Manifests IN EXCLUSIVE MODE' ) or $log->error( DBI->errstr );

	$error .= $Manifest->save( \%param );
	my $Log = new openprint::Log();
	$Log->save({object_type => 'openprint::Manifest', object_id=>$$Manifest{id}, action=>'Save Manifest',user_id=>$session{user_id},company_id=>$session{company_id} });

	my @Types = openprint::Manifest_Content_Type->find( manifest_id=>$Manifest->id());
	if ( ! @Types ) {
		# It's an empty, brand new manifest
		my $Type = new openprint::Manifest_Content_Type();
		$error .= $Type->save({ manifest_id=>$Manifest->id() });
		sql::end_transaction( $dbh, $ac );
		return $error;
	} # end if

	foreach my $Type ( openprint::Manifest_Content_Type->find( manifest_id=>$Manifest->id()) ) {
		my $Paper = save_Paper('-'.$Type->id());
		
		my %data = (
			docket		=>	$param{'docket-'.$Type->id()},
			paper_id	=>	$Paper->id(),
			po_id		=>	$param{'po_id-'.$Type->id()},
			manufacturers_name	=>	$param{'manufacturers_name-'.$$Type{id}},
			item_count	=>	$param{'item_count-'.$$Type{id}},
			condition_id	=>	$param{'condition_id-'.$$Type{id}},
		);
		$data{cost} = $param{'cost-'.$Type->id()} if exists $param{'cost-'.$Type->id()};
		$data{supplier_invoice} = $param{'supplier_invoice-'.$Type->id()} if exists $param{'supplier_invoice-'.$Type->id()};
		$variable{error} .= $Type->save(\%data);

		my $NewMC = new openprint::ManifestContent();
		$NewMC->set({manifest_id=>$$Manifest{id}, type_id=>$$Type{id}});

		my $total_qty = 0;
		# Save data for the rest of the contents
		foreach my $MC ( $NewMC, $Manifest->Contents( type_id => $$Type{id} ) ) {
			my $changed = 0;

			$param{"skid_id-$$Type{id}-$$MC{id}"} = openprint::Skid->transform( 'id', $param{"skid_id-$$Type{id}-$$MC{id}"} );

			if ( $param{"skid_id-$$Type{id}-$$MC{id}"} != $$MC{skid_id} ) {
				$MC->skid_id( $param{"skid_id-$$Type{id}-$$MC{id}"} );
				$changed = 1;
			} # end if

			if ( exists $param{"rfidtag_id-$$Type{id}-$$MC{id}"} ) {
				$param{"rfidtag_id-$$Type{id}-$$MC{id}"} = openprint::RFIDTag->transform( 'id', $param{"rfidtag_id-$$Type{id}-$$MC{id}"} );
				$MC->rfidtag_id( $param{"rfidtag_id-$$Type{id}-$$MC{id}"} );
				$changed = 1;
			} # end if
			my $Tag = $MC->RFIDTag();
			if ( $param{"manufacturers_id-$$Type{id}-$$MC{id}"} ne $$MC{manufacturers_id} ) {
				$$MC{manufacturers_id} = $param{"manufacturers_id-$$Type{id}-$$MC{id}"};
				$changed = 1;
			} # end if

			my $Skid = $MC->Skid();
$log->debug("Skid: " . $Skid->to_string() );
			if ( $$MC{manufacturers_id} ) {
				my $found_other_skid = 0;
				if ( my $S = openprint::Skid->find_one(manufacturers_id=>$$MC{manufacturers_id}) ) {
$log->debug("manufact Skid: " . $S->to_string() );
					if ( $Skid->id() ) {
						if ( $S->id() != $Skid->id() ) {
							$error .= "Manufacturers ID $$MC{manufacturers_id} for skid <a href=\"/employee/inventory/skid_details.html?skid_id=$$MC{skid_id}\">$$MC{skid_id}</a> is already assigned to <a href=\"/employee/inventory/skid_details.html?skid_id=$$S{id}\">$$S{id}</a>.";
							$error .= ssi::button( 'Replace'.$$MC{id}, { href=>'/employee/inventory/manifest.html?manifest_content_id='.$$MC{id}.'&action=replace&skid_id='.$$S{id}, text=>'Replace' } ) . '<br/>';
							$found_other_skid = 1;
						} # end if
					} else {
						$Skid = $S;
					} # end if
				} # end if
			} # end if manufacturers_id
				
			if ( ( ! $$MC{skid_id} ) and $Skid->id() ) {
				$MC->skid_id( $$Skid{id} );
				$changed = 1;
			} # end if

			my $qty_param = $Type->type() eq 'Sheet' ? "qty_sheets-$$Type{id}-$$MC{id}" : "qty_lbs-$$Type{id}-$$MC{id}";
$log->debug("param: $qty_param $param{$qty_param}");
			if ( exists $param{$qty_param} and ( $MC->quantity() != $param{$qty_param} ) ) {
$log->debug("param: $qty_param $param{$qty_param} $$MC{quantity}");
				$MC->quantity( Math::Round::nearest(1, $param{$qty_param}) );
				$changed = 1;
			} # end if

			if ( ! ( $$MC{id} or $$MC{skid_id} or $$MC{rfidtag_id} or $$MC{quantity} ) ) {
				next;
			} # end if
$log->debug( " location: " . $param{"location_id-$$Type{id}-$$MC{id}"} . ' != ' . $MC->location_id() );
			if ( $param{"location_id-$$Type{id}-$$MC{id}"} != $MC->location_id() ) {
$log->debug( "Updaating location: " . $param{"location_id-$$Type{id}-$$MC{id}"} . ' != ' . $MC->location_id() );
				$$MC{location_id} = $param{"location_id-$$Type{id}-$$MC{id}"};
				$changed = 1;
			} # end if changed location_id
			$error .= $MC->save() if $changed;
			$total_qty += $MC->quantity();
		} # end foreach Manifest_Content for this type

if ( 0 ) {
		if ( $param{'po_id-'.$Type->id()} ) {
			my $PO = new openprint::PurchaseOrder( $param{'po_id-'.$Type->id()} );
			if ( $PO->id() ) {
				$variable{error} .= $PO->save({manifest_id=>$Manifest->id()}) if $PO->manifest_id() != $Manifest->id();;

				# Run through, and warn if the PO is not satisfied
				my $PO_Content = $Type->PurchaseOrder_Content();
				if ( $PO_Content->qty() > $total_qty ) {
					$variable{warning} .= 'There is not enough stock to satisfy PO ' . $PO->id().'<br/>
						Manifest has ' . $total_qty . $Type->Paper()->units() . ' of '. $Paper->to_string()	.'<br/>
						PO wants ' . $PO_Content->qty() . $PO_Content->units() . ' of ' . $PO_Content->item().'<br/>';
				} # end if	
			} else {
				$variable{'error'} .= 'Purchase Order ' . $param{'po_id-'.$Type->id()} . ' was not found in the system.<br/>';
			} # end if
		} # end if po_id
} 

	} # end foreach Type
	sql::end_transaction( $dbh, $ac );
	return $error;
} # end sub save_Manifest

sub apply_Manifest {

	my ( $Manifest ) = @_;

	my $error;

	my $Log = new openprint::Log();
	$Log->save({object_type => 'openprint::Manifest', object_id=>$$Manifest{id}, action=>'Apply Manifest',user_id=>$session{user_id},company_id=>$session{company_id} });
	my $ac = sql::start_transaction( $dbh );
	$dbh->do( 'LOCK TABLE Manifests IN EXCLUSIVE MODE' ) or $log->error( DBI->errstr );

	foreach my $Type ( openprint::Manifest_Content_Type->find( manifest_id=>$Manifest->id()) ) {
		my $Paper = $Type->Paper();
			
		# If there is a change of paper in the type, then go through each skid and update them, nicluding allocations, and add a log entry so we know that it happened.
		if ( $Type->manufacturers_name() and $Type->paper_id() and ! $Paper->manufacturers_name() ) {
			$error .= $Paper->save({manufacturers_name=>$Type->manufacturers_name()});
		} # end if

		my $Project;
		if ( $param{'docket-'.$Type->id()} ) {
			if ( ! ( $Project = openprint::Project->find_one( docket=>$param{'docket-'.$Type->id()}) ) ) {
				$error .= 'Docket ' . $param{'docket-'.$Type->id()} . ' not found.	No allocations made.<br/>';
			} # end if
		} # end if

		my $total_qty = 0;
# Save data for the rest of the contents
		foreach my $MC ( $Manifest->Contents( type_id => $$Type{id} ) ) {
			$error .= $MC->apply( $Project );

			$total_qty += $MC->quantity();
		} # end foreach Manifest_Content for this type

		if ( $param{'po_id-'.$Type->id()} ) {
			my $PO = new openprint::PurchaseOrder( $param{'po_id-'.$Type->id()} );
			if ( $PO->id() ) {
				$error .= $PO->save({manifest_id=>$Manifest->id()}) if $PO->manifest_id() != $Manifest->id();;

# Run through, and warn if the PO is not satisfied
				my $PO_Content = $Type->PurchaseOrder_Content();
				if ( $PO_Content->qty() > $total_qty ) {
					$variable{'warning'} .= 'There is not enough stock to satisfy PO ' . $PO->id().'<br/>
						Manifest has ' . $total_qty . $Type->Paper()->units() . ' of '. $Paper->to_string()	.'<br/>
						PO wants ' . $PO_Content->qty() . $PO_Content->units() . ' of ' . $PO_Content->item().'<br/>';
				} # end if	
			} else {
				$error .= 'Purchase Order ' . $param{'po_id-'.$Type->id()} . ' was not found in the system.<br/>';
			} # end if
		} # end if po_id

		# Update in_stock
		$error .= $Paper->save();
	} # end foreach Type
	sql::end_transaction( $dbh, $ac );
	return $error;
} # end sub apply_Manifest

sub manifest {
	$param{'manifest_id'} =~ s/\s//g;
	my $Manifest = new openprint::Manifest( $param{'manifest_id'} );
	if ( $param{action} eq 'import' ) {
		manifest_import();
		return;
	} elsif ( $param{action} eq 'replace' ) {
		my $MC = new openprint::ManifestContent( $param{manifest_content_id} );
		
		if ( ! $$MC{id} ) {
			$variable{error} .= 'Manifest Content not found.  No change made.';
		} elsif ( $$MC{skid_id} == $param{skid_id} ) {
			$variable{error} .= 'Skid already replaced. No change made.';
		} else {
			my $Skid_to_delete = $MC->Skid();
			$variable{error} .= $MC->save({skid_id=>$param{skid_id}});
			$variable{error} .= $Skid_to_delete->delete();
			$variable{ExternalRedirect} = '/employee/inventory/manifest.html?manifest_id='.$$MC{manifest_id};
		} # end if
		$Manifest = $MC->Manifest();
	
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		$variable{'error'} .= $Manifest->delete();
		if ( ! $variable{'error'} ) {
			$variable{'Redirect'} = '/employee/inventory/manifests.html';
			%param = ();
		} # end if
	} elsif ( $param{'btnFunction'} eq 'undelete' ) {
		$variable{error} .= $Manifest->undelete();
		if ( ! $variable{error} ) {
			$variable{Redirect} = '/employee/inventory/manifests.html';
			%param = ();
		} # end if
	} elsif ( $param{'btnFunction'} eq 'destroy' ) {
		$variable{error} .= $Manifest->destroy();
		if ( ! $variable{error} ) {
			$variable{Redirect} = '/employee/inventory/manifests.html';
			%param = ();
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		$variable{error} = save_Manifest( $Manifest );
		if ( ! $variable{error} ) {
			$variable{ExternalRedirect} = '/employee/inventory/manifest.html?manifest_id='.$Manifest->id();
		} # end if
	} elsif ( $param{btnFunction} eq 'ChangePaper' ) {
		foreach my $Type ( openprint::Manifest_Content_Type->find( manifest_id=>$Manifest->id()) ) {
			foreach my $MC ( $Manifest->Contents( type_id => $$Type{id} ) ) {
				$variable{error} .= $MC->fix();
			} # end foreach MC
		} # end foreach Type
		if ( ! $variable{error} ) {
			$variable{ExternalRedirect} = '/employee/inventory/manifest.html?manifest_id='.$Manifest->id();
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Submit' ) {
		$variable{error} = save_Manifest( $Manifest );
		$variable{error} .= apply_Manifest( $Manifest ) if ! $variable{error};

		if ( ! $variable{'error'} ) {
			$variable{information} .= 'Information successfully stored.<br/>';
			$variable{ExternalRedirect} = '/employee/inventory/manifest.html?manifest_id='.$Manifest->id();
		} # end if
		%param = ();
	} # end if btnfunction
	$variable{'Manifest'} = $Manifest;
} # end sub manifest

sub _manifest_contents {
	if ( ! $param{type_id} ) {
		$log->error( 'Loading _manifest_contents without type_id' );
	} # end if
	my $Type = $variable{Type} = new openprint::Manifest_Content_Type( $param{type_id} );
	if ( ( $Type->type() ne $param{"type-$$Type{id}"} ) and $param{"type-$$Type{id}"} ) {
		$Type->save({type => $param{"type-$$Type{id}"} });
	} # end if

	if ( ! $$Type{id} ) {
		$log->error( 'Loading _manifest_contents with invalid type_id' );
	} # end if
	$variable{Manifest} = $Type->Manifest();
	$variable{type_id} = $$Type{id};

	foreach my $Content ( openprint::ManifestContent->find( type_id=>$param{type_id} ) ) {
		my $quantity = $Type->type() eq 'Roll' ? $param{"qty_lbs-$$Type{id}-$$Content{id}"} : $param{"qty_sheets-$$Type{id}-$$Content{id}"};

		if ( ( $Content->skid_id != $param{"skid_id-$$Type{id}-$$Content{id}"} ) and ( $Content->quantity() != $quantity ) ) {
if ( 0 ) {
			$variable{error} .= $Content->save({
				skid_id		=>	$param{"skid_id-$$Type{id}-$$Content{id}-$$Content{id}"},
				quantity	=>	$quantity,
			});
} else {
$log->debug("WOuld update");
}
		} else {
			$log->debug("No save needed for " . $Content->to_string() );
		} # end if
	} # end foreach Content
} # end sub _manifest_contents

sub _manifest_content {
	if ( $param{action} eq 'Remove' ) {
		my $C = new openprint::ManifestContent( $param{content_id} );
		if ( $$C{id} ) {
			$variable{type_id} = $C->type_id();
			$variable{Manifest} = $C->Manifest();
			$variable{error} .= $C->delete();
		} # end if
	} elsif ( $param{action} eq 'Fix' ) {
		my $MC = $variable{C} = new openprint::ManifestContent( $param{content_id} );
		$variable{error} .= $MC->fix();
		$variable{type_id} = $MC->type_id();
		$variable{Manifest} = $MC->Manifest();
	} elsif ( $param{action} eq 'Apply' ) {
		my $MC = $variable{C} = new openprint::ManifestContent( $param{content_id} );
		$variable{error} .= $MC->apply();
		$variable{type_id} = $MC->type_id();
		$variable{Manifest} = $MC->Manifest();
	} elsif ( $param{'action'} eq 'Add' ) {
		# The goal is to store as much info as possible in the manifest, but not commit to the other objects until we Submit the manifest.
		if ( ! $param{manifest_id} ) {
			$variable{error} .= 'No manifest id. Please enter the manifest id before adding items to it.<br/>';
			return;
		} # end if
		my $Type = new openprint::Manifest_Content_Type( $param{type_id} );
		if ( ! $Type->id() ) {
			$variable{error} .= 'No type.  This should not happen.<br/>';
			return;
		} # end if
		my $Manifest = $variable{Manifest} = new openprint::Manifest( $param{manifest_id} );
		if ( $param{manifest_id} and ! $Manifest->id() ) {
			$variable{error} .= $Manifest->save({ id=>$param{manifest_id} });
		} # end if

		if ( ! ( $param{rfidtag_id} or $param{skid_id} or $param{manufacturers_id} or $param{quantity} ) ) {
			$variable{error} .= 'No RFID, Skid ID or manufacturers ID or quantity given.  No changes made.<br/>';
			return;
		} # end if

		@param{'rfidtag_id','skid_id','manufacturers_id'} = misc::trim(@param{'rfidtag_id','skid_id','manufacturers_id'});
		my $Skid = new openprint::Skid( $param{skid_id} );

		my $Tag = new openprint::RFIDTag( $param{rfidtag_id} );
		if ( $param{rfidtag_id} and ! $Tag->id() ) {
			my $invalid = openprint::RFIDTag::is_invalid_id($param{rfidtag_id});
			if ( ! $invalid ) {
				$Tag->save({id=>$param{'rfidtag_id'}});
			} else {
				$variable{error} .= 'RFID Tag appears to be invalid: ' . $invalid.'<br/>';
				$Tag->id($param{rfidtag_id});
			} # end if
		} elsif ( $Tag->id() ) {
			$Skid = $Tag->Skid() if $Tag->id() and ! $Skid->id();
		} # end if

		if ( $Skid->id() and $Tag->id() and $Skid->rfidtag_id() and ( $Skid->rfidtag_id() != $Tag->id() ) ) {
			$variable{error}  .= "Skid $$Skid{id} already has RFID Tag " . $Skid->rfidtag_id(). '.<br/>';
		} # end if

		if ( $param{manufacturers_id} ) {
			my $S = openprint::Skid->find_one(manufacturers_id=>$param{manufacturers_id} );

			if ( ! $Skid->id() ) {
				$Skid = $S if $S;
			} elsif ( ! $Skid->manufacturers_id() ) {
				if ( $Skid->id() != $S->id() ) {
					$variable{error} .= 'Manufacturers id '.$param{manufacturers_id}. ' has already been assigned to <a href="/employee/inventory/skid_details.html?skid_id='.$S->id().'">'.$S->id().'</a>.<br/>';
				} # end if
			} # end if
# FIXME: Should look at paper type as well.
		} # end if

		if ( ( ! $Tag->id() ) and $Skid and $Skid->rfidtag_id() ) {
			$Tag = $Skid->RFIDTag();
		} # end if

		if ( $Tag->id() and sets::isin( $Tag->id(), [ map { $_->rfidtag_id() } $Manifest->Contents() ] ) ) {
			$variable{'error'} .= 'RFID Tag ' . $Tag->id() . ' has already been entered.';
		} elsif ( $Skid->id() and sets::isin( $Skid->id(), [ map { $_->skid_id() } $Manifest->Contents() ] ) ) {
			$variable{'error'} .= 'Skid ' . $Skid->id(). ' has already been entered.';
		} elsif ( $param{manufacturers_id} and sets::isin( $param{manufacturers_id}, [ map { $_->manufacturers_id() } $Manifest->Contents() ] ) ) {
			$variable{'error'} .= 'Manufacturers id ' . $param{manufacturers_id} . ' has already been entered.';
		} # end if

		my $MC = new openprint::ManifestContent();
		if ( $$Skid{id} ) {
# Now check for warnings
			if ( my $otherMC = openprint::ManifestContent->find_one( skid_id=>$$Skid{id}) ) {
				$variable{'warning'} .= 'Warning: Skid ' . $Skid->id(). ' is also on manifest '.$otherMC->Manifest()->name().'.';
			} # end if

# Auto load data
			my @SC = $Skid->Contents();
			if ( ! $param{qty_lbs} ) {
				if ( @SC == 1 ) {
					$param{qty_lbs} = $SC[0]->quantity();
				} # end if
			} # end if
			if ( ! $param{location_id} ) {
				$param{location_id} = $Skid->location_id();
			} # end if
		} # end if
		$variable{error} .= $MC->save( {
				type_id		=>	$param{type_id},
				Skid		=>	$Skid,
				RFIDTag		=>	$Tag,
				manifest_id	=>	$Manifest->id(),
				manufacturers_id	=>	$param{manufacturers_id},
				docket		=>	$param{docket},
				quantity	=>	Math::Round::nearest( 1, $param{quantity} ),
				} );
		$variable{'C'} = $MC;
		$variable{'type_id'} = $param{'type_id'};
		$variable{'Type'} = $Type;
	} # end if
} # end sub _manifest_content

sub manifests {
	if ( $param{'btnFunction'} eq 'Delete' ) {
		foreach my $manifest_id ( ref $param{'manifests'} eq 'ARRAY' ? @{$param{'manifests'}} : split(',',$param{'manifests'}) ) {
			my $Manifest = new openprint::Manifest( $manifest_id );
			$variable{'error'} .= $Manifest->delete();
		} # end foreach manifest_id
		return;
	} # end if
	_manifests();
	ssi::setup_date_select( '/employee/inventory/manifests.html', 'received_on_start', -7 );
	ssi::setup_date_select( '/employee/inventory/manifests.html', 'received_on_end', '' );
	ssi::setup_date_select( '/employee/inventory/manifests.html', 'created_on_start', -7 );
	ssi::setup_date_select( '/employee/inventory/manifests.html', 'created_on_end', '' );
	$session{'/employee/inventory/manifests.html?deleted'} = '0' if ! exists $session{'/employee/inventory/manifests.html?deleted'};
	$session{'/employee/inventory/manifests.html?has'} = '' if ! exists $session{'/employee/inventory/manifests.html?has_errors'};
} # end sub manifests

sub _manifests {
	ssi::save_params( '/employee/inventory/manifests.html', ( 
				( map { 'received_on_start_'.$_ } ( 'year','month','day' ) ),
				( map { 'received_on_end_'.$_ } ( 'year','month','day' ) ),
				( map { 'created_on_start_'.$_ } ( 'year','month','day' ) ),
				( map { 'created_on_end_'.$_ } ( 'year','month','day' ) ),
				( map { 'updated_on_start_'.$_ } ( 'year','month','day' ) ),
				( map { 'updated_on_end_'.$_ } ( 'year','month','day' ) ),
				'supplier_id', 'delivery','deleted','has_errors','type',
				) );
} # end sub _manifests

sub inventory_log {
	if ( $param{'btnFunction'} eq 'Download' ) {
		my @Header = ('When','Who', 'Skid','RFIDTag','Paper','Amount','Allocated','In Stock','Location','Comment' );
		my @Data;

		my @PIs = openprint::PaperInventory->find(
			ssi::date_filter( 'updated_on_start', 'updated_on_start', \%param ),
			ssi::date_filter( 'updated_on_end', 'updated_on_end', \%param ),
			($param{employee_id} ? ( user_id		=>	$param{employee_id} ) : () ),
		);
		my $total = 0;
		my %locations = map { $_, $_ } ( ref $param{location_id} eq 'ARRAY' ? @{$param{location_id}} : ($param{location_id}) );
		my %types = map { $_, $_ } ( ref $param{Type} eq 'ARRAY' ? @{$param{Type}} : ($param{Type}) );
		foreach my $PI ( @PIs ) {
			if ( $PI->delta < 0 and ! $param{'outs'} ) {
				$log->debug("Not wanting outs");
				next;
			}
			if ( $PI->delta > 0 and ! $param{'ins'} ) {
				$log->debug("Not wanting ins");
				next;
			}
			my $Paper = $PI->Paper();
			if ( $Paper->type() and ! $types{$Paper->type()} ) {
				$log->debug("Not in types " . join(',', keys %types ) );
				next;
			} # end if
			if ( ( ! $Paper->type() ) and ! $types{Unknown} ) {
				$log->debug("Unknnown type");
				next;
			} # end if
			my $Skid = $PI->Skid();
			if ( ( ! $locations{All} ) and ! $locations{$Skid->Location()->Root()->id()} ) {
				$log->debug("Not in locations: " . $Skid->Location()->Root()->name() . ' in ' . join(',', keys %locations ) );
				next;
			} # end if
			
			push @Data, (
				Date::Format::time2str('%Y-%m-%d %H:%M', Date::Parse::str2time($PI->updated_on) ),
				$PI->User()->name(),
				$PI->skid_id,
				$Skid->RFIDTag()->id_short(),
				$Paper->to_string(),
				$PI->delta,
				join(',', map { sprintf('%d%s to %d', $_->quantity(),$_->units(),new openprint::Project( $_->project_id() )->docket() ) } openprint::PaperAllocation->find( 'skid_ids any'=>$PI->skid_id, paper_id=>$PI->paper_id)),
				$PI->instock,
				$Skid->Location()->name(),
				$PI->comment,
				);
			$total += $PI->delta;
		} # end while
		push @Data, '','','','','Totals:',$total,'','','','';
		misc::export_csv( $r, $log, \%variable, 'InventoryLog.csv', \@Header, \@Data );
	} # end if
	if ( ! exists $session{'/employee/inventory/inventory_log.html?ins'} ) {
		$session{'/employee/inventory/inventory_log.html?ins'} = 1;
	} # end if
	if ( ! exists $session{'/employee/inventory/inventory_log.html?outs'} ) {
		$session{'/employee/inventory/inventory_log.html?outs'} = 1;
	} # end if
	ssi::setup_date_select( '/employee/inventory/inventory_log.html', 'updated_on_start', 0 );
	ssi::setup_date_select( '/employee/inventory/inventory_log.html', 'updated_on_end', 0 );
	
	ssi::save_params( '/employee/inventory/inventory_log.html', ( 
				( map { 'updated_on_start_'.$_ } ( 'year','month','day', 'hour', 'minute' ) ),
				( map { 'updated_on_end_'.$_ } ( 'year','month','day', 'hour', 'minute' ) ),
				( 'ins', 'outs', 'Type', 'location_id', 'manifests_within_days', 'show_manifests' ) ) );
	$session{'/employee/inventory/inventory_log.html?manifests_within_days'} = 7 if ! defined $session{'/employee/inventory/inventory_log.html?manifests_within_days'};
	$session{'/employee/inventory/inventory_log.html?manifests_within_lbs'} = 100 if ! defined $session{'/employee/inventory/inventory_log.html?manifests_within_lbs'};
	$session{'/employee/inventory/inventory_log.html?show_manifests'} = 0 if ! defined $session{'/employee/inventory/inventory_log.html?show_manifests'};
	$session{'/employee/inventory/inventory_log.html?show_stock_on_manifests'} = 0 if ! defined $session{'/employee/inventory/inventory_log.html?show_stock_on_manifests'};
	$session{'/employee/inventory/inventory_log.html?Type'} = [ 'Sheet','Roll','Unknown'] if ! defined $session{'/employee/inventory/inventory_log.html?Type'};
} # end sub inventory_log

sub _inventory_log {
	ssi::save_params( '/employee/inventory/inventory_log.html', ( 
( map { 'updated_on_start_'.$_ } ( 'year','month','day', 'hour', 'minute' ) ),
( map { 'updated_on_end_'.$_ } ( 'year','month','day', 'hour', 'minute' ) ),
( 'ins', 'outs', 'Type', 'location_id', 'manifests_within_days', 'manifests_within_lbs','show_manifests', 'employee_id' ) ) );
	$session{'/employee/inventory/inventory_log.html?ins'} = $param{ins};
	$session{'/employee/inventory/inventory_log.html?outs'} = $param{outs};
	$session{'/employee/inventory/inventory_log.html?show_stock_on_manifests'} = $param{show_stock_on_manifests};

	$variable{'Skid'} = new openprint::Skid( $param{'skid_id'} );
} # end sub inventory_log

sub _paper_allocations {
	$param{'paper_id'} =~ s/\D//g;
	$variable{'Paper'} = new openprint::Paper( $param{'paper_id'} );
	if ( $param{'action'} eq 'Add' ) {
		$param{'skid_id'} =~ s/\D//g;
		$param{'Docket'} =~ s/\D//g;
		$param{'AllocationQuantity'} =~ s/[^\d\-]//g;
		my @Projects = openprint::Project->find( docket=>$param{Docket} ) if $param{Docket};
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
        my @Projects = openprint::Project->find( 
			( $param{ProjectID} ? ( id=>$param{ProjectID} ) : () ),
			( $param{Docket} ? ( docket=>$param{Docket} ) : () ) ) if $param{ProjectID} or $param{Docket};
        my $Skid = new openprint::Skid( $param{'skid_id'} );

        if ( ! @Projects ) {
            $variable{'error'} .= 'Docket not found. No paper allocated.<br/>';
        } elsif ( $Skid->allocateable() < $param{'AllocationQuantity'} ) {
            $variable{'error'} .= 'Only ' .  $Skid->allocateable() . ' on this skid. No paper allocated.<br/>';
        } else {
            my $Project = shift @Projects;
            $Paper->allocate( $Skid, $Project->id(), @param{'AllocationQuantity','Units'} );
            $variable{'information'} .= sprintf('Allocated %s%s to docket %d<br/>', @param{'AllocationQuantity','Units'}, $Project->docket() );
        } # end if
    } elsif ( $param{'action'} eq 'delete' ) {
        my $Allocation = new openprint::PaperAllocation( $param{'allocation_id'} );
		if ( $Allocation->id() ) {
			$Allocation->Project()->add_to_log( @session{'company_id','user_id'}, 'Paper Allocation for skid ' . $param{'skid_id'} . ' deleted.' );
			$Allocation->delete();
		} else {
			$openprint::log->warn('Non-existent Paper Allocation deleted.');
		} # end if
	} # end if
	$variable{'skid_id'} = $param{'skid_id'};
	$variable{'Skid'} = new openprint::Skid( $param{'skid_id'} );
} # end sub _skid_allocations


sub available_paper {
	if ( $param{'btnFunction'} eq 'Allocate' ) {
		if ( exists $param{'Captcha'} ) {
	# Remove spaces, because some people want to put spaces between the characters, etc.
			$param{'Captcha'} =~ s/\s//g;
			my $Captcha = new Authen::Captcha('data_folder' => '/tmp', 'output_folder' => $config{'SkinPath'}.'/images/captcha');
			if ( 1 != $Captcha->check_code( @param{'Captcha','MD5SUM'} ) ) {
				$variable{'error'} .= 'Captcha Validation Code incorrect.	Please try again.';
				return;
			} # end if
		} # end if
		foreach my $condition_id ( sets::union( map { $_->condition_id() } openprint::SkidContent->find(deleted=>0,paper_id=>$param{paper_id},'quantity >' =>0 ) ) ) {
			next if ! $param{'quantity-'.$condition_id};
			allocate( @param{'skid_id','paper_id','quantity-'.$condition_id,'Project','Docket','specific','reason'}, $condition_id );
		} # end foreach condition
		@session{'error','warning','information'} = @variable{'error','warning','information'};
		$variable{'ExternalRedirect'} = '/employee/inventory/available_paper.html';
		%param = ();
	} # end if
	_available_paper();
	$session{'/employee/inventory/available_paper.html?owner_id_exclude'} = $param{'owner_id_exclude'} if exists $param{'owner_id'};
	$session{'/employee/inventory/available_paper.html?type'} = 'Roll' if ! $session{'/employee/inventory/available_paper.html?type'};
	$session{'/employee/inventory/available_paper.html?Owner'} = new openprint::User( $session{'user_id'} )->company_id() if ! exists $session{'/employee/inventory/available_paper.html?Owner'};
	if ( ! exists $session{'/employee/inventory/available_paper.html?condition_id'} ) {
		my $New = openprint::InventoryCondition->find_one( name=>'new' );
		$session{'/employee/inventory/available_paper.html?condition_id'} = $New->id() if $New;
	} # end if
} # end sub available_paper
sub _available_paper {
	ssi::save_params( '/employee/inventory/available_paper.html', 
			'owner_id', 'manufacturer_id', 'brand_id', 'finish_id', 'colour_id', 'weight_id', 
			'material_id','quality_id','group_id','condition_id',
			'width','height','OrLarger', 'type', 'fsc_code', 'last_seen', 'location_id', 'unmatched' );
	$session{'/employee/inventory/available_paper.html?owner_id_exclude'} = $param{'owner_id_exclude'} if exists $param{'owner_id'};
	$session{'/employee/inventory/available_paper.html?type'} = 'Roll' if ! $session{'/employee/inventory/available_paper.html?type'};
	$session{'/employee/inventory/available_paper.html?OrLarger'} = $param{'OrLarger'};
} # end sub _available_paper

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
		$variable{'quantity'} = $variable{'Paper'}->available();
	} # end if
} # end sub _allocate_popup

sub _manifest_purchase_orders {
} # end sub _manifest_purchase_orders

sub _rfidtag_log {
	if ( ! exists $param{start_year} ) {
		my $Entry = openprint::RFIDTagHistory->find_one( 
			( $param{rfidtag_id} ? ( rfidtag_id	=>	$param{rfidtag_id} ) : () ),
			( $param{scanner_id} ? ( scanner_id	=>	$param{scanner_id} ) : () ),
			order		=>	'updated_on DESC',
			limit		=>	$param{limit},
			);
		if ( $Entry ) {
			@param{'start_year','start_month','start_day'} = $Entry->updated_on() =~ /^(\d+)-(\d+)-(\d+)/;
		} # end if
	} # end if

} # end sub _rfidtag_log

sub _rfidtag_log_entries {
} # end sub _rfidtag_log_entries

sub _manifest_type {
	$variable{'Manifest'} = new openprint::Manifest( $param{'manifest_id'} );
	if ( $param{'action'} eq 'Add' ) {
		$variable{'Type'} = new openprint::Manifest_Content_Type();
		$variable{'error'} .= $variable{'Type'}->save({'manifest_id'=>$param{'manifest_id'}});
		$variable{'type_id'} = $variable{'Type'}->id();
	} # end if
}

sub _verification_log {
	$variable{'Skid'} = new openprint::Skid( $param{'skid_id'} );
} # end sub _verification_log

sub paper_label_window {
} # end sub paper_label_window

sub move_skids_window {
} # end sub move_skids_window

sub allocations {
	ssi::save_params( '/employee/inventory/allocations.html', ( 'Type','created_on_start_year','created_on_start_month','created_on_start_day','created_on_end_year','created_on_end_month','created_on_end_day','Docket','stock_age_start_year','stock_age_start_month','stock_age_start_day','stock_age_end_year','stock_age_end_month','stock_age_end_day' ) );
} # end sub allocations

sub _allocations {
	ssi::save_params( '/employee/inventory/allocations.html', ( 'Type','created_on_start_year','created_on_start_month','created_on_start_day','created_on_end_year','created_on_end_month','created_on_end_day','Docket','stock_age_start_year','stock_age_start_month','stock_age_start_day','stock_age_end_year','stock_age_end_month','stock_age_end_day' ) );
} # end sub _allocations

sub _deallocate_popup {
}
sub _skids_results {
	ssi::save_params( '/employee/inventory/skids.html', ( 'PaperManufacturer','PaperBrand','PaperFinish','PaperColour','PaperWeight','type',
				( map { 'received_on_start_' . $_ } ( 'year','month','day' ) ),
				( map { 'received_on_end_' . $_ } ( 'year','month','day' ) ),
				( map { 'created_on_start_' . $_ } ( 'year','month','day' ) ),
				( map { 'created_on_end_' . $_ } ( 'year','month','day' ) ),
				( map { 'updated_on_start_' . $_ } ( 'year','month','day' ) ),
				( map { 'updated_on_end_' . $_ } ( 'year','month','day' ) ),
				( map { 'last_seen_start_' . $_ } ( 'year','month','day' ) ),
				( map { 'last_seen_end_' . $_ } ( 'year','month','day' ) ),
				'Docket','fsc_code','empty', 'rfid','rfid_valid','location_id','verification_code', 'allocated','contents','hasmanifest',
				'condition_id', 'skid_id', 'rfid_id', 'manufacturers_id', 'hasmanufacturers','deleted','checked_out',
				) );
}

sub _paper_log {
	ssi::save_params( '/employee/inventory/paper_details.html', ( 'ddmStartYear','ddmStartMonth','ddmStartDay','ddmEndYear','ddmEndMonth','ddmEndDay','limit' ) );
} # end _paper_log
sub _skid_log {
} # end _skid_log

sub skid_label {
} # end sub skid_label

sub _check_out_popup {
} # end sub _check_out_popup

sub _add_paper_show {
} # end sub _add_paper_show
sub _add_paper_hide {
} # end sub _add_paper_hide

sub docket_labels {
} # end sub docket_labels

sub _check_in_popup {
} # end sub _check_in_popup

sub packingslips {
	ssi::save_params( '/employee/inventory/packingslips.html', ( 'company_id','docket','type_id',
				'created_on_start_year','created_on_start_month','created_on_start_day',
				'created_on_end_year','created_on_end_month','created_on_end_day',
				) );
	ssi::setup_date_select( '/employee/inventory/packingslips.html', 'created_on_start', -7 );
	ssi::setup_date_select( '/employee/inventory/packingslips.html', 'created_on_end', '' );
} # end sub packingslips
sub _packingslips {
	ssi::save_params( '/employee/inventory/packingslips.html', ( 'company_id','docket','type_id',
				'created_on_start_year','created_on_start_month','created_on_start_day',
				'created_on_end_year','created_on_end_month','created_on_end_day',
				) );
} # end sub _packingslips

sub _rfidscanners_results {
} # end sub _rfidscanners_results

sub _map {
} # end sub _map

sub _docket_label {
} # end sub _docket_label

sub _paper_inventory_entries {
	$variable{'Paper'} = new openprint::Paper( $param{'paper_id'} );

	if ( $param{'Action'} eq 'Add' ) {
		my $Skid = new openprint::Skid( $param{'skid_id'} );
		my $Paper = new openprint::Paper( $param{'paper_id'} );
		my $Condition = new openprint::InventoryCondition( $param{'condition_id'} );
		$Skid->location_id( $param{'Location'} );
		$Skid->add( $Paper, $param{'quantity'}, $Condition );
		$Skid->save();
		$Paper->add_inventory( $Skid->id(), $param{'quantity'} );
	} # end if
} # end sub _paper_inventory_entries

sub manifest_import {
	if ( my $upload = $r->upload('import') ) {
		require openprint::Manifest_Import_Rule;
		my %Rules = map { $_->match(), $_ } openprint::Manifest_Import_Rule->find();

		my $io =$upload->io();
		if ( $upload->filename() =~ /txt$/i ) {

			@{$variable{Types}} = ();

			my ( $width, $basis_weight, $product, $manufacturer );
			my $line_count = 1;
			my $roll_count = 0;
			my $Type;
			my $Manifest = $variable{Manifest} = new openprint::Manifest();
			$variable{error} .= $Manifest->save({name=>$param{import}});

			while ( my $line = <$io> ) {
				s/^\s+//, s/\s+$//, s/\s+/ /g, s/\.\s+/\./g for $line;
				

				if ( $line =~ /(.+)Page\s+(\d+) of (\d+)$/ ) {
					# Start a new page
					$log->debug("Line $line_count: Starting new page for $1 page $2 of $3");
				} elsif ( my ( $d, $m, $y, $H, $M ) = $line =~ /.+\s+(\d\d)\.(\d\d)\.(\d\d)\s*(\d\d:\d\d)$/ ) {
					$log->debug("Line $line_count: Date: $y-$m-$d $H:$M");
				} elsif ( ( $product ) = $line =~ /^PRODUCT NUMBER\s+(.+)$/ ) {
					$log->debug("Line $line_count: Product ($product)");
				} elsif ( ( $manufacturer ) = $line =~ /^Customer[^A-Z]+([A-Z]+)\s+.+$/ ) {
					$manufacturer = $Rules{$manufacturer}->replacement() if $Rules{$manufacturer};
					$log->debug("Line $line_count: Manufacturer ($manufacturer)");
			
				} elsif ( 
					( $width, $basis_weight, my $manufacturers_id, my $location, my $received_on, my $available_quantity, my $available_lbs, my $hold_quantity, my $hold_lbs ) = 
					$line =~ /^([\d\s\/\.]+)X *([\d\/\.]+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S)RO\S+\s+(\S+)\s+(\S)RO\S+\s+([\d\.]+)$/ ) {
					if ( my ($n,$m) = $width =~ /(\d+)\/(\d+)/ ) {
						my $r = $n/$m;
						$r =~ s/\d+(\.\d+)/$1/;
						$width =~ s/$n\/$m/$r/;
					} # end if
					$width =~ s/\s//g;

					$available_quantity =~ s/l/1/;
					$available_quantity =~ s/[OD]/0/;
					$available_lbs =~ s/[^\d\.]//g;
					$hold_lbs =~ s/[^\d\.]//g;

					$manufacturers_id =~ s/[^A-Z0-9]//g;

					$log->debug("Line $line_count: width: $width, weight: $basis_weight, id: $manufacturers_id, qty: $available_quantity, lbs: $available_lbs");
					$roll_count += 1;
					my @Papers = openprint::Paper->find_one( manufacturers_name=>$product, width=>$width, basis_weight=>$basis_weight, manufacturer=>$manufacturer );
					$Type->save() if $Type;
					$Type = new openprint::Manifest_Content_Type();
					$Type->set({ manifest_id=> $$Manifest{id} } );
					if ( @Papers == 1 ) {
						$Type->paper_id( $Papers[0]->id() );
					} # end if
					$variable{error} .= $Type->save();
					push @{$variable{Types}}, $Type;

					my $Content = new openprint::ManifestContent();
					$variable{error} .= $Content->save({manifest_id=>$$Manifest{id}, type_id=>$$Type{id}, quantity=>$available_quantity });
					
				} elsif ( 
					( my $manufacturers_id, my $location, my $received_on, my $available_quantity, my $available_lbs, my $hold_quantity, my $hold_lbs ) = 
						$line =~ /^(\S+)\s+(\S+)\s+([\d\.]+)\s+(\S)RO\S+\s+(\S+)\s+(\S)RO\S+\s+([\d\.]+)$/ ) {
					$log->debug("Line $line_count: width: $width, weight: $basis_weight, id: $manufacturers_id, qty: $available_quantity, lbs: $available_lbs");
					$roll_count += 1;
				} elsif ( my ( $total_rolls, $total_weight ) = $line =~ /^TOTALS:\s+Available Quantity\s+(\d+)\s+EA\s+Available\s+.+eight\s+([\d\,\.]+)$/ ) {
					if ( ! $Type ) {
						$variable{error} .= "Line $line_count: No Type yet for $product<br/>";
						$Type = new openprint::Manifest_Content_Type();
						$Type->set({ manifest_id=> $$Manifest{id} } );
					} # end if
					$Type->item_count( $total_rolls );
					if ( $roll_count != $total_rolls ) {
						$log->warn("Line $line_count: Roll count($roll_count) != total rolls: $total_rolls");
					} # end if
					$roll_count = 0;
				} else {
					$log->debug("Line $line_count: unparsed line: $line");
				} # end if
				$line_count += 1;
			} # end while io
		} elsif ( $upload->filename() =~ /csv$/i ) {
			require Text::CSV_XS;
			my $csv = Text::CSV_XS->new();
			$_ = <$io>; # drop the title row
			my $ac = sql::start_transaction( $dbh );
			my $Manifest = $variable{Manifest} = new openprint::Manifest();
			$variable{error} .= $Manifest->save({name=>$param{import}});

			@{$variable{Types}} = ();
			my $Type;
			my $product;
			my $item_count = 0;

			my %Skids_by_mfg;

			while ( my $line = <$io> ) {
				my $status = $csv->parse($line);        # parse a CSV string into fields
				my @data = misc::trim($csv->fields());
				#Cust Code,Invt Lev1,Invt Lev2,Invt Lev3,On Hand Qty,On Hand Wgt,On Ord Qty,On Rcpt Qty,Hold Non Ship Qty
				my ( $cust_code, $desc1, $desc2, $mfg_name, $on_hand_qty, $weight_qty ) = @data;
				if ( ! $cust_code ) {
					$variable{warning} .= "Invalid line ($line)<br/>";
					next;
				} # end if
				my ( $width, $weight ) = ( $1, $2 );
				if ( $desc2 =~ /^([\.\d]+)\s?X\s?([\.\d]+)$/ ) {
					( $width, $weight ) = ( $1, $2 );
				} # end if
				if ( $product ne $desc1.' '.$desc2 ) {
					$variable{error} .= $Type->save({item_count=>$item_count}) if $Type;
					$item_count = 0;

					push @{$variable{Types}}, $Type if $Type;

					my $Paper;
					my @Papers = openprint::Paper->find( manufacturers_name=>($desc1.' '.$desc2) );
					if ( @Papers == 1 ) {
						$Paper = $Papers[0];
					} else {
					} # end if

					$Type = new openprint::Manifest_Content_Type();
					$variable{error} .= $Type->save({
						manifest_id => $$Manifest{id},
						manufacturers_name	=>	($desc1.' '.$desc2),
						type	=>	'Roll',
						( $Paper ? ( paper_id=>$Paper->id() ) : () ),
					});
					$product = $desc1.' '.$desc2;
				} # end if
				$item_count += 1;
				$Skids_by_mfg{$mfg_name} = openprint::Skid->find_one( manufacturers_id=>$mfg_name ) if ! exists $Skids_by_mfg{$mfg_name};
				my $Skid = $Skids_by_mfg{$mfg_name};
				if ( $Skid ) {
					my @SC = $Skid->Contents();
					if ( ! $$Type{paper_id} ) {
						foreach my $SC ( @SC ) {
							if ( $$SC{paper_id} ) {
								$Type->save({paper_id=>$$SC{paper_id}});
							} # end if
						} # end foreach SC
					} else {
						# Don't need to do anything, because the inequality will be shown when displaying the manifest
					} # end if
				} # end if


				my $MC = new openprint::ManifestContent();
				$variable{error} .= $MC->save({
					type_id		=>	$$Type{id},
					manifest_id	=>	$$Manifest{id},
					quantity	=>	$weight_qty,
					manufacturers_id	=>	$mfg_name,
					( $Skid ? ( skid_id=>$$Skid{id} ) : () ),
				});
			} # end while  io
			$variable{error} .= $Type->save({item_count=>$item_count}) if $Type;
			sql::end_transaction( $dbh, $ac );
		} else {
			$log->error("unknown import format: " . $upload->filename() );
		} # end if
	} # end if
} # end sub manifest_import

sub manifest_view {
	my $Manifest = $variable{Manifest} = new openprint::Manifest( $param{manifest_id} );
	if ( $param{action} eq 'Delete' ) {
		$variable{error} .= $Manifest->delete();
		$variable{ExternalRedirect} = '/employee/inventory/manifests.html' if ! $variable{error};
	} elsif ( $param{action} eq 'Undelete' ) {
		$variable{error} .= $Manifest->undelete();
		$variable{ExternalRedirect} = '/employee/inventory/manifest_view.html?manifest_id='.$Manifest->id();
	} elsif ( $param{action} eq 'Apply' ) {
		$variable{error} .= apply_Manifest( $Manifest ) if ! $variable{error};
		$variable{ExternalRedirect} = '/employee/inventory/manifest_view.html?manifest_id='.$Manifest->id();
	} elsif ( $param{action} eq 'Verify' ) {
		my $Log = new openprint::Log();
		$variable{error} .= $Log->save({
			object_type => 'openprint::Manifest',
			object_id	=> $$Manifest{id},
			action		=> 'Verify Manifest',
			user_id		=> $session{user_id},
			company_id	=> $session{company_id},
			});
		$variable{ExternalRedirect} = '/employee/inventory/manifest_view.html?manifest_id='.$Manifest->id();
	} # end if
} # end sub manifest_view

sub _stock {
}

1;
__END__
