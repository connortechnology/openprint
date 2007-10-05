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

sub skids {
	my ( $r, $log, $dbh, $variable ) = @_;
	if ( $openprint::param{'btnFunction'} eq 'Delete' ) {
		if ( $openprint::param{'skid_id'} ) {
			$openprint::param{'skid_id'} =~ s/[^\d\-\,]//g;
			my @skid_ids;
			foreach my $range ( split ',', $openprint::param{'skid_id'} ) {
				if ( $range =~ /(\d*)\-(\d*)/ ) {
					push @skid_ids, ( $1 .. $2 );
				} else {
					push @skid_ids, $range;
				} # end if
			} # end foreach
			foreach my $skid_id ( @skid_ids ) {
				my $Skid = new openprint::Skid( $skid_id );
				$Skid->delete();
				$$variable{'information'} .= "Skid $$Skid{'id'} has been deleted.<br/>";
			} # end foreach

		} elsif ( $openprint::param{'skids'} ) {
			
			foreach my $skid_id ( ref $openprint::param{'skids'} eq 'ARRAY' ? @{$openprint::param{'skids'}} : $openprint::param{'skids'} ) {
				my $Skid = new openprint::Skid( $skid_id );
				$Skid->delete();
				$$variable{'information'} .= "Skid $$Skid{'id'} has been deleted.<br/>";
			} # end foreach
		} # end if
	} # end if
} # end sub skids

sub paper {
	my ( $r, $log, $dbh, $variable ) = @_;
	if ( $openprint::param{'btnFunction'} eq 'Download Log' ) {

		my @header = ('Date','Operator','Owner','Name','Finish','Colour','Weight','Width','Height','Quality', 'MWeight','GSM','Skid#','Amount','Comment');
		my @info = sql::execute( $log, $dbh, q{SELECT paper_id, skid_id, user_id, delta, units, updatetime, comment FROM paper_inventory ORDER BY updatetime DESC} );
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
		misc::export_csv( $r, $log, $variable, "PaperInventoryLog $date.csv", \@header, \@data );
	} elsif ( $openprint::param{'btnFunction'} eq 'Download Inventory' ) {

		my @header = ('ID','Owner','Manufacturer','Name','Finish','Colour','Weight','Width','Height','Quality', 'MWeight','GSM','Skid#','Date Added','Location', 'InStock');
		my @papers = openprint::Paper::find(
				'owner_id'	=>	( defined $openprint::param{'Owner'} ? $openprint::param{'Owner'} : '' ),
				'manufacturer_id'	=>	( defined $openprint::param{'PaperManufacturer'} ? $openprint::param{'PaperManufacturer'} : undef ),
				'name_id'	=>	( defined $openprint::param{'PaperBrand'} ? $openprint::param{'PaperBrand'} : undef ),
				'finish_id' =>	( defined $openprint::param{'PaperFinish'} ? $openprint::param{'PaperFinish'} : undef ),
				'colour_id' =>	( defined $openprint::param{'PaperColour'} ? $openprint::param{'PaperColour'} : undef ),
				'weight_id' =>	( defined $openprint::param{'PaperWeight'} ? $openprint::param{'PaperWeight'} : undef ),
				'type'		=>	$openprint::param{'type'},
				'order_by'	=> 'owner_id,manufacturer_id,name_id,finish_id,colour_id,weight_id,width,height',
				);
		my $date = Date::Format::time2str('%Y-%m-%d %H:%M', time );
		my @data;
		foreach my $Paper ( @papers ) {
			foreach my $Skid ( $Paper->skids() ) {
				push @data,
				$$Paper{'id'},
				new openprint::Company($Paper->owner_id())->name(),
				$Paper->manufacturer(),
				$Paper->name(),
				$Paper->finish(),
				$Paper->colour(),
				$Paper->weight(),
				$Paper->width(),
				$Paper->height(),
				$Paper->quality(),
				$Paper->mweight(),
				$Paper->gsm(),
				$$Skid{'id'},
				$$Skid{'created_on'},
				$Skid->location(),
				$$Skid{Paper}{$$Paper{'id'}},
			} # end foreach skid
		} # end foreach
		#my $date;
		push @data, ( 'Report generated',$date,undef,undef,undef,undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef );
		misc::export_csv( $r, $log, $variable, "PaperInventory $date.csv", \@header, \@data );
	} elsif ( $openprint::param{'btnFunction'} eq 'Delete' ) {
		if ( $openprint::param{'paper_id'} ) {
			my $Paper = new openprint::Paper( $openprint::param{'paper_id'} );
			$Paper->delete();
			$$variable{'information'} .= "Paper $$Paper{'id'} has been deleted.";
		} elsif ( $openprint::param{'papers'} ) {
			my $ac = sql::start_transaction( undef );		
			my @papers = openprint::Paper::find('id'=>$openprint::param{'papers'});

			foreach my $Paper ( @papers ) {
				$Paper->delete();
			} # end foreach
			sql::end_transaction( undef, $ac );
			$$variable{'information'} .= @papers . ' Papers have been deleted.';
		} # end if

	} elsif ( $openprint::param{'btnFunction'} eq 'Save' ) {
		foreach my $key ( keys %openprint::param ) {
			if ( $key =~ /txtInStock(\d*)/ ) {
				my $paper_index = $1;
				my $delta = 0;
				my ( $instock ) = sql::execute( $log, $dbh, 'SELECT InStock FROM Paper_Inventory WHERE PaperIndex=? AND UpdateTime = (SELECT MAX(UpdateTime) FROM Paper_Inventory WHERE PaperIndex=?)', $paper_index, $paper_index );
				if ( $openprint::param{$key} =~ /[\-\+]\d*/ ) {
					$delta = $openprint::param{$key};
				} else {
					$delta = $openprint::param{$key} - $instock;
				} # end if
				if ( $delta != 0 ) {
					sql::insert($log, $dbh, 'Paper_Inventory', [
						'PaperIndex',	$paper_index,
						'InStock',		$instock + $delta,
						'Delta',		$delta,
						'UserIndex',	$openprint::session{'user_id'},
						'UpdateTime',	'NOW()',
						'Comment',		'Stock Check',
						] );
				} # end if
				
			} # end if
		} # end foreach
	} # end if

} # end sub paper

sub paper_details {
	my ( $r, $log, $dbh, $variable ) = @_;
	my $Paper = new openprint::Paper( $openprint::param{'paper_id'} );
	if ( $openprint::param{'btnFunction'} eq 'Previous' ) {
		$Paper = $Paper->previous();
	} elsif ( $openprint::param{'btnFunction'} eq 'Next' ) {
		$Paper = $Paper->next();
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
		$Paper->type( $openprint::param{'type'} );
		if ( $openprint::param{'type'} eq 'Roll' ) {
			$Paper->width( $openprint::param{'width'} );
			$Paper->height( undef );
		} else { #Sheet
			$Paper->width( $openprint::param{'width'} );
			$Paper->height( $openprint::param{'height'} );
		} # end if
		$Paper->mweight( $openprint::param{'mweight'} );
		$Paper->gsm( $openprint::param{'gsm'} );
		$Paper->calliper( $openprint::param{'txtCalliper'} );
		$Paper->fsc_code( $openprint::param{'fsc_code'} );
		if ( ! $openprint::param{'paper_id'} ) {
			my @papers = openprint::Paper::find(
					'owner_id'	=>	$openprint::param{'ddmOwner'},
					'manufacturer'		=>	$openprint::param{'txtManufacturer'},
					'manufacturer_id'	=>	$openprint::param{'ddmManufacturer'},
					'name'		=>	$openprint::param{'txtName'},
					'name_id'	=>	$openprint::param{'ddmName'},
					'finish'	=>	$openprint::param{'txtFinish'},
					'finish_id' =>	$openprint::param{'ddmFinish'},
					'colour'	=>	$openprint::param{'txtColour'},
					'colour_id' =>	$openprint::param{'ddmColour'},
					'weight'	=>	$openprint::param{'txtWeight'},
					'weight_id' =>	$openprint::param{'ddmWeight'},
					'width'	=> $openprint::param{'width'},
					'height'	=>	$openprint::param{'height'},
					'quality'	=>	$openprint::param{'txtQuality'},
					'quality_id'	=>	$openprint::param{'ddmQuality'},
					);
			if ( @papers ) {
				$$variable{'error'} .= qq`A paper matching those parameters already exists. Click here to edit it: <a href="paper_details.html?paper_id=$papers[0]{id}">paper $papers[0]{id}</a>`;
				$$variable{'Paper'} = $Paper;
				return;
			} # end if
		} # end if
		$$variable{'error'} .= $Paper->save();
	} elsif ( $openprint::param{'btnFunction'} eq 'Delete' ) {
		$Paper->delete();
	} elsif ( $openprint::param{'btnFunction'} eq 'Allocate' ) {
		allocate( $variable, undef, @openprint::param{'paper_id','Quantity','Project','Docket'} );
	} elsif ( $openprint::param{'btnFunction'} eq 'Delete Allocation' ) {
		if ( $openprint::param{'allocation_id'} ) {
			sql::execute( $log, $dbh, 'DELETE FROM Paper_allocations WHERE id=?', $openprint::param{'allocation_id'} );
		} # end if
	} elsif ( $openprint::param{'btnFunction'} eq 'CheckOut' ) {
		check_out( $variable, undef, @openprint::param{'paper_id','Quantity','Project','Docket'} );
	} elsif ( $openprint::param{'btnFunction'} eq 'Merge' ) {
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
			my $ac = sql::start_transaction( $openprint::dbh );
			sql::update( undef, undef, 'Paper_allocations', [ 'paper_id=?', $Duplicate->id() ], 'paper_id', $Paper->id() );
			sql::update( undef, undef, 'Paper_Inventory', [ 'paper_id=?', $Duplicate->id() ], 'paper_id', $Paper->id() );
			sql::update( undef, undef, 'skid_contents', [ 'paper_id=?', $Duplicate->id() ], 'paper_id', $Paper->id() );
			$Duplicate->delete();
			sql::end_transaction( $openprint::dbh, $ac );
		} # end foreach
	} # end if
	$$variable{'Paper'} = $Paper;
	$$variable{'paper_id'} = $$Paper{'id'};
} # end sub paper_details

sub save_skid {
	my ( $r, $variable, $Skid ) = @_;

	$Skid->location_id( $openprint::param{'location_id'} ) if $openprint::param{'location_id'};
	$Skid->location_id( $openprint::param{'ddmLocation'} ) if $openprint::param{'ddmLocation'};
	$Skid->location( $openprint::param{'txtLocation'} ) if $openprint::param{'txtLocation'};
	$Skid->save();

	if ( $openprint::param{'ddmName'} or $openprint::param{'txtName'} ) {
		my @papers = openprint::Paper::find(
				'owner_id'	=>	$openprint::param{'Owner'},
				'manufacturer_id'	=>	$openprint::param{'ddmManufacturer'},
				'manufacturer'		=>	$openprint::param{'txtManufacturer'},
				'name_id'	=>	$openprint::param{'ddmName'},
				'name'		=>	$openprint::param{'txtName'},
				'finish_id' =>	$openprint::param{'ddmFinish'},
				'finish'	=>	$openprint::param{'txtFinish'},
				'colour_id' =>	$openprint::param{'ddmColour'},
				'colour'	=>	$openprint::param{'txtColour'},
				'weight_id' =>	$openprint::param{'ddmWeight'},
				'weight'	=>	$openprint::param{'txtWeight'},
				'quality_id' => $openprint::param{'ddmQuality'},
				'quality'	=>	$openprint::param{'txtQuality'},
				'width'	=> $openprint::param{'width'},
				'height'	=>	$openprint::param{'height'},
				'type'	=>	$openprint::param{'type'},
				);
		my $Paper;

# Paper not found, this is the first time we are adding it to the skid
		if ( 0 == @papers ) {
			$Paper = new openprint::Paper( );
			$Paper->owner_id( $openprint::param{'Owner'} );
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
			$Paper->type( $openprint::param{'type'} );
			$Paper->fsc_code( $openprint::param{'fsc_code'} );
			if ( $openprint::param{'type'} eq 'Roll' ) {
				$Paper->width( $openprint::param{'width'} );
				$Paper->height( undef );
			} else { #Sheet
				$Paper->width( $openprint::param{'width'} );
				$Paper->height( $openprint::param{'height'} );
			} # end if
			$Paper->mweight( $openprint::param{'mweight'} );
			$Paper->gsm( $openprint::param{'gsm'} );
			$Paper->save();
			$$variable{'information'} .= 'Paper created.<br/>';
		} elsif ( 1 == @papers ) {
			$Paper = shift @papers;
# This is so that papers that don't have mweights will get filled in
			if ( ( ! $Paper->mweight() ) and $openprint::param{'txtMWeight'} ) {
				$Paper->mweight( $openprint::param{'txtMWeight'} );
				$Paper->save();
			} # end if
			if ( ( ! $Paper->gsm() ) and $openprint::param{'gsm'} ) {
				$Paper->gsm( $openprint::param{'gsm'} );
				$Paper->save();
			} # end if
		} else {
			$$variable{'error'} .= 'Duplicate Paper Detected!.<br/>';
			$$variable{'information'} .= 'The following papers both match, please edit them:<br/>';
			foreach my $Paper ( @papers ) {
				$$variable{'information'}	.= '<a href="paper_details.html?paper_id='.$Paper->id().'">'.$Paper->to_string().'</a><br/>';
			} # end foreach
		} # end if
		if ( $Paper ) {
			my $delta = $Skid->add( $Paper, @openprint::param{'Quantity','Units'} );
			$Paper->add_inventory( $Skid->id(), $delta, $openprint::param{'Units'} );
#FIXME
			if ( $delta > 0 ) {
				$$variable{'information'} .= "Added $delta $openprint::param{'Units'} to inventory.<br/>";
			} elsif ( $delta < 0 ) {
				$$variable{'information'} .= "Removed $delta $openprint::param{'Units'} from inventory.<br/>";
			} else {
				$$variable{'information'} .= "No change was made to inventory.<br/>";
			}# end if

			$Skid->save();

			if ( $openprint::param{'Docket'} ) {
				my @Projects = openprint::Project::find('docket'=>$openprint::param{'Docket'} );

				if ( ! @Projects ) {
					$$variable{'error'} .= "Docket $openprint::param{'Docket'} not found. No paper allocated. CSR not notified.<br/>";
				} else {
					my $Project = shift @Projects if @Projects;
					$Paper->allocate( $$Skid{'id'}, $Project->id(), $delta, $openprint::param{'Units'} );
					$$variable{'information'} .= "Allocated $delta $openprint::param{'Units'} to docket $openprint::param{'Docket'}.<br/>";
				} # end if
			} # end if
		} # end if Paper
	} elsif ( $openprint::param{'Docket'} ) {
		my @Projects = openprint::Project::find('docket'=>$openprint::param{'Docket'} );

		if ( ! @Projects ) {
			$$variable{'error'} .= "Docket $openprint::param{'Docket'} not found. No paper allocated.<br/>";
		} else {
			$Skid->allocate( undef, $Projects[0]->id(), @openprint::param{'Quantity','Units'} );
			$$variable{'information'} .= "Allocated $openprint::param{'Quantity'} $openprint::param{'Units'} to docket $openprint::param{'Docket'}.<br/>";
		} # end if
	} # end if
} # end sub save_skid

sub skid_details {
	my ( $r, $log, $dbh, $variable ) = @_;

	if ( $openprint::param{'skids'} ) {
		$openprint::param{'skid_id'} = join(',', ref $openprint::param{'skids'} eq 'ARRAY' ? @{$openprint::param{'skids'}} : $openprint::param{'skids'} );
	} # end if
	$openprint::param{'skid_id'} =~ s/[^\d\-\,]//g;
	my @skid_ids;
	foreach my $range ( split ',', $openprint::param{'skid_id'} ) {
		if ( $range =~ /(\d*)\-(\d*)/ ) {
			push @skid_ids, ( $1 .. $2 );
		} else {
			push @skid_ids, $range;
		} # end if
	} # end foreach

	if ( $openprint::param{'skid_id'} and ! openprint::Skid::find( 'id'=>\@skid_ids ) ) {
		$$variable{'error'} .= "Skid $openprint::param{'skid_id'} not found!<br/>";
		return;
	} # end if

	$$variable{'Skid'} = new openprint::Skid( @skid_ids ? $skid_ids[0] : undef );
	$$variable{'skid_id'} = $openprint::param{'skid_id'};
	@{$$variable{'skid_ids'}} = @skid_ids;

	$$variable{'similar'} = 1;
	my $Skid = new openprint::Skid( $skid_ids[0] );
	foreach ( @skid_ids ) {
		my $S = new openprint::Skid( $_ );
		if ( sets::intersection( keys %{$$S{Paper}}, keys %{$$Skid{Paper}} ) != keys %{$$S{Paper}} ) {
			$$variable{'similar'} = 0;
			last;
		} # end if
	} # end foreach

	if ( $openprint::param{'btnFunction'} eq 'Previous' ) {
		@skid_ids = ( (new openprint::Skid( @skid_ids ? $skid_ids[0] : undef ))->previous()->id());
		$openprint::param{'skid_id'} = $skid_ids[0];
	} elsif ( $openprint::param{'btnFunction'} eq 'Next' ) {
		@skid_ids = ( (new openprint::Skid( @skid_ids ? $skid_ids[0] : undef ))->next()->id());
		$openprint::param{'skid_id'} = $skid_ids[0];
	} elsif ( $openprint::param{'btnFunction'} eq 'Save' ) {
		my @quantities = misc::trim( split ',', $openprint::param{'Quantity'} );

		if ( @skid_ids and (@quantities>1) and ( @quantities != @skid_ids ) ) {
			$$variable{'error'} .= 'When saving to multiple skids, the # of quantities must match the # of skids.';
			return;
		} # end if

		if ( $openprint::param{'skid_quantity'} ) {
			if ( (@quantities>1) and ( @quantities != $openprint::param{'skid_quantity'} ) ) {
				$$variable{'error'} .= 'When saving to multiple skids, the # of quantities must match the # of skids.';
				return;
			} # end if
			@{$$variable{'Skids'}} = ();
			foreach my $skid_count ( 1 .. $openprint::param{'skid_quantity'} ) {
				my $S = new openprint::Skid();
				$openprint::param{'Quantity'} = @quantities > 1 ? $quantities[$skid_count-1] : $quantities[0] if @quantities;
				save_skid( $r, $variable, $S );
				push @{$$variable{'Skids'}}, $S;
				if ( ! $$variable{'Paper'} ) {
					if ( $$S{Paper} ) {
						my @paper_ids = keys %{$$S{Paper}};
						$$variable{'paper_id'} = $paper_ids[0] if @paper_ids;
					} # end of
				} # end of
			} # end foreach
			$$variable{'information'} .= "Added $openprint::param{'skid_quantity'} skids.<br/>";
		} else {
			foreach my $skid_id ( @skid_ids ) {
				$openprint::param{'Quantity'} = @quantities > 1 ? shift @quantities : $quantities[0] if @quantities;
				save_skid( $r, $variable, new openprint::Skid( $skid_id ) );
			} # end foreach
		} # end if


	} elsif ( sets::isin( $openprint::param{'btnFunction'}, 'Copy', 'Duplicate' ) ) {
		foreach my $skid_id ( @skid_ids ) {
			my $Skid = new openprint::Skid( $skid_id );
			$Skid = $Skid->copy();
			$Skid->save();
		} # end foreach
	} elsif ( $openprint::param{'btnFunction'} eq 'Delete' ) {
		foreach my $skid_id ( @skid_ids ) {
			my $Skid = new openprint::Skid( $skid_id );
			$Skid->delete();
		} # end foreach
	} elsif ( $openprint::param{'btnFunction'} eq 'Print Label' ) {
		foreach my $skid_id ( @skid_ids ) {
			my $Skid = new openprint::Skid( $skid_id );
			$Skid->print_label();
		} # end foreach
	} elsif ( $openprint::param{'btnFunction'} eq 'Allocate' ) {
		foreach my $skid_id ( @skid_ids ) {
			allocate( $variable, $skid_id, @openprint::param{'paper_id', 'Quantity','Project','Docket'} );
		} # end foreach
	} elsif ( $openprint::param{'btnFunction'} eq 'Delete Allocation' ) {
		if ( $openprint::param{'allocation_id'} ) {
			sql::execute( $log, $dbh, 'DELETE FROM Paper_allocations WHERE id=?', $openprint::param{'allocation_id'} );
		} # end if
	} elsif ( $openprint::param{'btnFunction'} eq 'CheckIn' ) {
		foreach my $skid_id ( @skid_ids ) {
			check_in( $variable, $skid_id, @openprint::param{'paper_id', 'Quantity','Project','Docket'} );
		} # end foreach
	} elsif ( $openprint::param{'btnFunction'} eq 'CheckOut' ) {
		foreach my $skid_id ( @skid_ids ) {
			check_out( $variable, $skid_id, @openprint::param{'paper_id', 'Quantity','Project','Docket'} );
		} # end foreach
	} elsif ( $r->param('btnFunction') eq 'DeletePaper' ) {
		foreach my $skid_id ( @skid_ids ) {
			my $Skid = new openprint::Skid( $skid_id );
			delete $$Skid{Paper}{$openprint::param{paper_id}};
			$Skid->save();
		} # end foreach
	} # end if
} # end sub skid_details

sub check_out {
	my ( $variable, $skid_id, $paper_id, $quantity, $project_id, $docket ) = @_;

	if ( ! ( $paper_id or $skid_id ) ) {
		$$variable{'error'} .= 'Skid or Paper not specified. No paper checked out.<br/>';
		return;
	} # end if
	my $Paper;
	if ( $paper_id ) {
		$Paper = new openprint::Paper( $paper_id );
	} elsif ( $skid_id ) {
		my $Skid = new openprint::Skid( $skid_id );
		my @papers = keys %{$$Skid{Paper}};
		if ( 1 == @papers ) {
			$Paper = new openprint::Paper( shift @papers );
			$paper_id = $Paper->id();
		} else {
			$$variable{'error'} .= "Skid contains more than one type of paper.	You must specify.<br/>";
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
		$$variable{'error'} .= "There are no skids for this paper. Cannot check out.<br/>";
		return;
	} # end if

	my $qty = $quantity;
	foreach my $skid_id ( @skids ) {
		my $Skid = new openprint::Skid( $skid_id );
		if ( $$Skid{Paper}{$paper_id} < $qty ) {
			$Paper->add_inventory( $Skid->id(), -1*$$Skid{Paper}{$paper_id}, $units, 'Removed' . @Projects ? ' for docket ' . $Projects[0]->docket() : '' );
			$Paper->allocate( $Skid->id(), $Projects[0]->id(), -1*$$Skid{Paper}{$paper_id} ) if $Paper->allocated( $Projects[0]->id() );
			$qty -= $$Skid{Paper}{$paper_id};
			$$Skid{Paper}{$paper_id} = 0;
		} else {
			$$Skid{Paper}{$paper_id} -= $qty;
			$Paper->add_inventory( $Skid->id(), -1*$qty, $units, 'Removed' . @Projects ? ' for docket ' . $Projects[0]->docket() : '' );
			$Paper->allocate( $Skid->id(), $Projects[0]->id(), -1*$qty ) if $Paper->allocated( $Projects[0]->id() );
			$qty = 0;
		} # end if
		$Skid->save();
		last if ! $qty;
	} # end foreach

	if ( @Projects ) {
		$$variable{'information'} .= "Checked out $quantity $units to docket " . $Projects[0]->docket() . '<br/>';
	} else {
		$$variable{'information'} .= "Checked out $quantity $units to unknown docket.<br/>";
	} # end if
} # end sub check_out

sub check_in {
	my ( $variable, $skid_id, $paper_id, $quantity, $project_id, $docket ) = @_;
	if ( ! ( $paper_id or $skid_id ) ) {
		$$variable{'error'} .= "Skid or Paper not specified. No paper allocated.<br/>";
		return;
	} # end if
	my $Paper;
	my $Skid = new openprint::Skid( $skid_id );

	if ( $paper_id ) {
		$Paper = new openprint::Paper( $paper_id );
	} elsif ( $skid_id ) {
		my @papers = keys %{$$Skid{Paper}};
		if ( 1 == @papers ) {
			$Paper = new openprint::Paper( shift @papers );
			$paper_id = $Paper->id();
		} else {
			$$variable{'error'} .= "Skid contains more than one type of paper.	You must specify.<br/>";
			return;
		} # end if
	} # end if
	$project_id =~ s/\D//g;
	$docket =~ s/\D//g;
	my @Projects = openprint::Project::find( 'id'=>$project_id, 'docket'=>$docket ) if $project_id or $docket;

	if ( ($Paper->type() eq 'Roll') and ($quantity > 0) and ( $$Skid{Paper}{$Paper->id()} + $quantity > 10000 ) ) {
		$$variable{'error'} .= "Skid cannot hold more than 10000lbs.<br/>";
		return;
	} # end if

# Default to add
	if	( $quantity =~ /^\d/ ) {
		$quantity = '+' . $quantity;
	} # end if

	my $units = $Paper->type() eq 'Roll' ? 'lbs' : 'sheets';
	my $delta = $Skid->add( $Paper, $quantity, $units );
	if ( ! @Projects ) {
		$Paper->add_inventory( $Skid->id(), $delta, $units, 'Added' );
		$$variable{'information'} .= "Checked in $quantity $units to unknown docket.<br/>";
	} else {
		my $Project = shift @Projects;
		$Paper->add_inventory( $Skid->id(), $delta, $units, 'Added for docket ' . $Project->docket() );
		$$variable{'information'} .= "Checked in $quantity $units from docket " . $Project->docket() . '<br/>';
	} # end if
	$Skid->save();
} # end sub check_in

sub allocate {
	my ( $variable, $skid_id, $paper_id, $quantity, $project_id, $docket ) = @_;
	if ( ! $paper_id ) {
		$$variable{'error'} .= "Paper not specified. No paper allocated.<br/>";
		return;
	} # end if

	my $Paper = new openprint::Paper( $paper_id );
	my $available_qty = $Paper->in_stock();
	my $units = $Paper->type() eq 'Roll' ? 'lbs' : 'sheets';
	if ( $available_qty < $quantity ) {
		$$variable{'error'} .= "Only $available_qty $units are available to be allocated. Please try again.<br/>";
		return;
	} # end if
	$project_id =~ s/\D//g;
	$docket =~ s/\D//g;
	my @Projects = openprint::Project::find( 'id'=>$project_id, 'docket'=>$docket ) if $project_id or $docket;

	if ( ! @Projects ) {
		$$variable{'error'} .= "An invalid Docket or Project # was given. No paper allocated.<br/>";
		return;
	} # end if

	my $qty = $quantity;
	if ( $quantity < 0 ) {
		foreach my $skid_id ( sql::execute( undef, undef, q{SELECT skid_id FROM paper_allocations WHERE paper_id=? AND quantity > 0 AND project_id=? ORDER BY skid_id}, $paper_id, $Projects[0]->id() ) ) {
			my $Skid = new openprint::Skid( $skid_id );
			if ( $$Skid{Paper}{$paper_id} < -1*$qty ) {
				$Paper->allocate( $skid_id, $Projects[0]->id(), -1*$$Skid{Paper}{$paper_id}, $units );
				$qty += $$Skid{Paper}{$paper_id};
			} else {
				$Paper->allocate( $skid_id, $Projects[0]->id(), $qty, $units );
				$qty = 0;
			} # end if
			last if ! $qty;
		} # end foreach
	} else {
		my @skids;
		if ( ! $skid_id ) {
			@skids = sql::execute( undef, undef, q{SELECT skid_id FROM skid_contents WHERE paper_id=? AND quantity > 0 ORDER BY skid_id}, $paper_id );
		} else {
			push @skids, $skid_id;
		} # end if

		foreach my $skid_id ( @skids ) {
			my $Skid = new eprint::Skid( $skid_id );

			if ( $$Skid{Paper}{$paper_id} < $qty ) {
				$Paper->allocate( $skid_id, $Projects[0]->id(), $$Skid{Paper}{$paper_id}, $units );
				$qty -= $$Skid{Paper}{$paper_id};
			} else {
				$Paper->allocate( $skid_id, $Projects[0]->id(), $qty, $units );
				$qty = 0;
			} # end if
			last if ! $qty;
		} # end foreach
	} # end if
	$$variable{'information'} .= "Allocated $quantity $units to docket " . $Projects[0]->docket() . '<br/>';
} # end sub allocate


sub send_paper_arrival_notification {
	my ( $Skid, @papers ) = @_;
	my %info;
	$info{'Skid'} = $Skid;

	@papers = map { new openprint::Paper( $_ ) } keys %{$Skid->paper()} if ! @papers;

	foreach my $Paper ( @papers ) {
		my $to;
		$info{'Paper'} = $Paper;
		$info{'Quantity'} = $$Skid{Paper}{$Paper->id()};
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
			my $From = new openprint::User( $openprint::session{'user_id'} );
			my $email_template = misc::load_file( $openprint::log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );

			$info{'ReplacementText'} = "<!--#include virtual=\"/email_content/paper_arrived_notification.html\"-->";
			$_ = encode_qp( ssi::variable_substitution( undef, $openprint::log, $openprint::dbh, $email_template, \%info ) );
			my @body = ('', $_, 'text/html', 'quoted-printable');
			my %mail = (
					SMTP	=> $openprint::config{'Mail Server'},
					FROM	=> sprintf( '"%s" <%s>', $From->name(), $From->email() ),
					TO		=> $to,
					SUBJECT => 'Paper ' . $Paper->to_string() . ' has arrived',
					);
			misc::send_email_with_attachment( $openprint::log, \%mail, @body );
		} # end if to
	} # end foreach Paper
} # end sub send_paper_arrival_notification

sub highlight_paper {
	my ( $r, $log, $dbh, $variable, @params ) = @_;

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

1;

__END__
~		
