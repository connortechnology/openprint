use strict;
package openprint::Skid;
our @ISA = qw( openprint::Object );

use Carp;
use openprint ();
use vars qw( $log %session $debug $table $serial %fields %transforms %defaults %find_fields $debug );
*session = \%openprint::session;
*log = \$openprint::log;

require sql;
require openprint::Location;
require openprint::RFIDTag;
require openprint::Skid_Verification;
require openprint::Project;
require openprint::SkidContent;
require openprint::InventoryCondition;
require openprint::PaperAllocation;

$debug = 0;

$table = 'Skids';
$serial = 'skid_id_seq';
%fields = (
	id				=>	'id',
	location_id		=>	'location_id',
	created_on		=>	'created_on',
	created_by_id	=>	'created_by_id',
	owner_id		=>	'owner_id',
	updated_on		=>	'updated_on',
	updated_by		=>	'updated_by',
	used			=>	'used',
	rfidtag_id		=>	'rfidtag_id',
	type			=>	'type',
	deleted			=>	'deleted',
	manufacturers_id	=>	'manufacturers_id',
	received_on		=>	'received_on',
);
%find_fields = (
	verification_code => '(? IN (SELECT code FROM skid_verifications WHERE skid_id=skids.id))',
	manifest_id			=>	'(SELECT manifest_id FROM ManifestContents WHERE skid_id=skids.id)',
	paper_id			=>	'(SELECT paper_id FROM skid_contents where skid_id=skids.id)',
	quantity			=>	'(SELECT MAX(quantity) FROM skid_contents WHERE skid_id=skids.id)',
	last_seen			=>	'(SELECT updated_on FROM rfidtags WHERE rfidtags.id=skids.rfidtag_id)',
	allocated_to_docket =>	'(id IN ( SELECT skid_id FROM paper_allocations WHERE docket=?))',
	fsc_code			=>	'id IN ( SELECT skid_id FROM skid_contents WHERE paper_id=(SELECT id FROM papers WHERE fsc_code=?))',
	purpose_id 			=>	'id IN ( SELECT skid_id FROM skid_contents WHERE purpose_id=?)',
	condition_id 		=>	'(SELECT condition_id FROM skid_contents WHERE skid_contents.skid_id=skids.id )',
);

%transforms = (
	id			=>	[ 's/\D//g', '<2147483647' ],
	deleted	=>	[ 's/[^01]//g' ],
	manufacturers_id	=>	[ 'tr/[a-z]/[A-Z]/' ],
);
%defaults = (
	location_id	=>	undef,
	rfidtag_id	=>	undef,
	updated_on	=>	q`'NOW()'`,
	created_on	=>	q`'NOW()'`,
	received_on	=>	undef,
	deleted		=>	0,
	type		=>	undef,
	manufacturers_id	=>	undef,
);



sub copy {
	my $self = shift;
	my $new = new openprint::Skid( );
	@$new{'location_id','type'} = @$self{'location_id','type'};
	$$new{type} = $self->type();
	$new->save();

	foreach my $C ( $self->Contents() ) {
		$C = $C->copy();
		$C->save({ skid_id=>$$new{id} });
		$C->Paper()->add_inventory( $new->id(), $C->quantity() );
		foreach my $PA ( openprint::PaperAllocation->find('skid_ids any'=>$$self{id}, paper_id=>$C->paper_id()) ) {
			$C->Paper()->allocate( $new, $PA->docket(), $PA->quantity(), $PA->units(), $PA->reason() );
		} # end while
	} # end foreach Content
	return $new;
} # end sub copy

sub save {
	my ( $self, $data, $force_insert ) = @_;
	$$self{created_by_id} = $session{user_id} if ! $$self{created_by_id};
	$self->type() if ! $$self{type};
	$self->used(undef);

	# Why?
	#$self->location_id();
	return $self->SUPER::save( $data, $force_insert );
} # end sub save

sub destroy {
	my $self = $_[0];
	my $error;

	my $ac = sql::start_transaction( $openprint::dbh );
	sql::execute( undef, undef, q{UPDATE manifestcontents SET skid_id=NULL WHERE skid_id=?}, $$self{id} );
	foreach my $V ( openprint::Skid_Verification->find('skid_id'=>$$self{id}) ) {
		$error .= $V->delete();
		last if $error;
	} # end foreach V	
	sql::execute( undef, undef, q{DELETE FROM paper_allocations WHERE skid_id=?}, $$self{id} );
	sql::execute( undef, undef, q{DELETE FROM paper_inventory WHERE skid_id=?}, $$self{id} );
	sql::execute( undef, undef, q{DELETE FROM skid_contents WHERE skid_id=?}, $$self{id} );
	sql::execute( undef, undef, q{DELETE FROM skid_verifications WHERE skid_id=?}, $$self{id} );
	$self->SUPER::destroy();
	sql::end_transaction( $openprint::dbh, $ac );
	return $error;
} # end sub delete

sub to_string {
	my $self = shift;
	return sprintf('%s %d containing %s', 
		( $self->type() eq 'Roll' ? 'Roll' : 'Skid' ),
		$$self{id},
		join('<br/>', map { $_->to_string() } $self->Contents() ),
	);
} # end sub

sub add {
	my ( $self, $Paper, $quantity, $condition, $Purpose ) = @_;
	my $Condition;
	if ( ref $condition eq 'openprint::InventoryCondition' ) {
		$Condition = $condition;
	} elsif ( ! $condition ) {
		# Default to new
		$Condition = openprint::InventoryCondition->find_one( name=>'new' );
	} else {
		$log->debug("COndition is $condition");
	} # end if
	if ( ! $Condition ) {
		$log->error("Must specify condition");
		return 0;
	} # end if
	if ( ! $Paper ) {
		$log->error("Must specify Stock");
		return 0;
	} # end if

	my $C = $self->Content( $Paper );
	if ( ! $C ) {
		delete $$self{Contents};
		$C = new openprint::SkidContent();
	} # end if

	my $old_quantity = $C->quantity();

	if ( $quantity =~ /^\+/ ) {
		$quantity =~ s/[^\d]//g;
# Add
		$quantity = $old_quantity + $quantity;
	} elsif ( $quantity =~ /^\-/ ) {
		$quantity =~ s/[^\d]//g;
# Subtract
		$quantity = $old_quantity - $quantity;
	} else {
		$quantity =~ s/[^\d]//g;
# Set
	} # end if
	$_ = $C->save({
			skid_id			=>	$$self{id},
			paper_id		=>	$Paper->id(),
			condition_id	=>	$Condition->id(),
			quantity		=>	$quantity,
			( ( $Purpose and $Purpose->id() ) ? ( purpose_id => $Purpose->id() ) : () ),
			});
	if ( $_ ) {
		$openprint::log->error("Error adding skidcontent: $_");
	} # end if
	return $quantity - $old_quantity;
} # end sub add

sub remove {
	my ( $self, $Paper, $quantity ) = @_;
	$quantity =~ s/[^\-\d]//g;
	$quantity = int $quantity;
	my $C = $self->Content( $Paper );
	if ( ! $C ) {
		$log->error("Unable to find SkidContent for Skid $$self{id} for Paper $$Paper{id}");
		return;
	} # end if

	my $new_quantity = $C->quantity() - $quantity;
	$new_quantity = 0 if $new_quantity < 0;
	$C->save({ 'quantity'=>$new_quantity });
} # end sub remove

sub set_quantity {
	my ( $self, $Paper, $quantity, $purpose_id ) = @_;
	$quantity =~ s/[^\-\d]//g;
	$quantity = int $quantity;
	my @contents = $self->Contents( paper_id=>$Paper->id(), ( $purpose_id ? ( 'purpose_id'=>$purpose_id ) : () ) );
	if ( ! @contents ) {
		return 'Specified stock is not on this skid';
	} # end if
	my $content = $contents[0];
	$content->quantity( $quantity );
	$content->quantity( 0 ) if $content->quantity() < 0;
	$content->save();
	return '';
} # end sub set_quantity

sub print_label {
}

sub location {
	my $self = shift;
	if ( @_ ) {
		my $name = shift;
		my $Location = openprint::Location->find_one( 'name lc'=>lc openprint::Location->transform('name', $name) );
		if ( ! $Location ) {
			$Location = new openprint::Location();
			$Location->save({name=>$name});
		} # end if
		$self->location_id( $Location->id() );
	} # end if
	return new openprint::Location( $$self{location_id} )->name();
} # end sub location

sub location_id {

	if ( @_ > 1 ) {
		$_[0]{location_id} = $_[1];
		if ( $_[0]{rfidtag_id} ) {
			my $Tag = $_[0]->RFIDTag();
			if ( $_[1] != $Tag->location_id() ) {
				$Tag->save({location_id=>$_[1]});
			} # end if
		} # end if
	} # end if


	if ( ! $_[0]{location_id} ) {
		if ( $_[0]{rfidtag_id} ) {
			my $Tag = $_[0]->RFIDTag();
			if ( $Tag->location_id() != $_[0]{location_id} ) {
				$_[0]{location_id} = $Tag->location_id();
			} # end if
		} 
	} # end if
	return $_[0]{location_id};
} # end sub location_id

sub Location {
	return new openprint::Location( $_[0]->location_id() );
} # end sub Location

sub Content {
    my ( $self, $Paper ) = @_;
	return if ! $$self{id};
	foreach my $C ( $self->Contents() ) {
		if ( $C->paper_id() == $Paper->id() ) {
			return $C;
		} # end if	
	} # end foreach C
} # end sub Content

sub Contents {
	return () if ! $_[0]{id};
    my $self = shift;

	if ( @_ ) {
		if ( ! defined $_[0] ) {
			$$self{Contents} = [ openprint::SkidContent->find( skid_id=>$$self{id}, 'deleted in'=>[0,1] ) ];
		} elsif ( ref $_[0] eq 'ARRAY' ) {
			$$self{Contents} = $_[0];
		} else {
			my %params = @_;
			$params{skid_id} = $$self{id};
			$params{deleted} = [0,1] if ! exists $params{'deleted in'};
			return openprint::SkidContent->find( %params );
		} # end if
	} elsif ( ! $$self{Contents} ) {
		$$self{Contents} = [ openprint::SkidContent->find( skid_id=>$$self{id}, 'deleted in'=>[0,1] ) ];
	} # end if
	return @{$$self{Contents}};
} # end sub Contents

sub allocation {
	my ( $self, %options ) = @_;
	if ( $options{Paper} ) {
		my $allocated = misc::sum( map { $_->quantity() } openprint::PaperAllocation->find('skid_ids any'=>$$self{id},paper_id=>$options{Paper}->{id}) );
		return $allocated;
	} # end if
} # end sub allocatiosn

sub allocateable {
	my ( $self, $Paper ) = @_;
	my $C = $self->Content( $Paper );
	if ( ! $C ) {
		$log->error("Unable to find SkidContent for Skid $$self{id} for Paper $$Paper{id}");
		return;
	} # end if
	return $C->allocateable();
} # end sub allocateable

# Checkout all paper on the skid
# Shoudl take comment, docket, force
# If docket isn't passed, try to find it by allocation.

sub checkout {
	my ( $self, $docket, $c, $force ) = @_;
	require openprint::PaperInventory;
	my @contents = openprint::SkidContent->find( skid_id=>$$self{id} );
	if ( ! @contents ) {
		
		# When there is no content... this basically means the stock is used before it is entered in the system.
		if ( ! openprint::PaperInventory->find( skid_id=>$$self{id}, 'comment like'=>'Checked out%' ) ) {
			my $PI = new openprint::PaperInventory();
			my $e = $PI->save({
					'paper_id'	=>	undef,
					'user_id'	=>	$session{user_id},
					'instock'	=>	0,
					'delta'		=>	0,
					'comment'	=>	'Checked out' . $c,
					'skid_id'	=>	$$self{id},
					'units'		=>	'unknown',
					docket		=>	$docket,
					});
			$log->error($e);
		} else {
$log->error("No contents foudn, but inventory log entries found for skid $$self{id}");
		} # end if
$log->debug("No contents found for skid $$self{id} Checking out anyways");
		return 1;
	} # end if

	if ( 0 and ! $docket ) {
		# DOn't do this because we might be using it on another docket.
		# We might eb able to look at what job is being run but for now, just don't
		my $PA = openprint::PaperAllocation->find_one( 'skid_ids any'=>$$self{id} );
		if ( $PA ) {
			$docket = $PA->docket();
		}
	} # end if

	my $rc = 0;
	foreach my $C ( @contents ) {
		next if ! $C->quantity();

		if ( 0 ) {
			# DOn't do this.  Just because it is allocated doesn't mean it is being used for this docket
			my $PA = openprint::PaperAllocation->find_one( 'skid_ids any'=>$$self{id}, paper_id=>$C->paper_id());
		}

		my $desc = 'Checked out' . ( $docket ? ' for docket ' .$docket : '' );
			
		my $Paper = $C->Paper();
# This is neccessary because different skids can be doing the checkout
		$Paper->lock();

		# SHouldn't have to..
		$Paper->SkidContents(undef);
		my $e = $Paper->save(); # Must update in_stock
		my $PI = new openprint::PaperInventory();
		$e .= $PI->save({
				paper_id  =>  $C->paper_id(),
				user_id   =>  $session{user_id},
				instock   =>  $Paper->in_stock() - $C->quantity(),
				delta     =>  -1*$C->quantity(),
				comment   =>  $desc.$c,
				skid_id   =>  $$self{id},
				units     =>  $C->units(),
				( $docket ? (docket=>$docket) : () ),
				} );
		$e .= $C->save( { quantity => 0 } );
		$Paper->SkidContents(undef);
		$e .= $Paper->save(); # Must update in_stock
		if ( $Paper->in_stock() != $PI->instock ) {
			$log->error("What just happened?! $$Paper{in_stock} != $$PI{instock}");
		} # end if
		$log->error( $e ) if $e;
		$Paper->unlock();
		$rc = 1;
	} # end foreach Content

	#Update any PAs
	foreach my $PA ( openprint::PaperAllocation->find( 'skid_ids any' => $$self{id} ) ) {
		if ( $PA->docket() != $docket ) {
			# FIXME Send alerta
		}
		$PA->save({skid_ids=>[ sets::exclude( [ $self->id() ], $PA->skid_ids() ) ] });
		if ( ! $PA->Skids() ) {
			$PA->delete();
		} # end if
	} # end foreach PA
	return $rc;
} # end sub checkout

sub previous {
	my $self = shift;
	if ( ! ( ( $_ ) = sql::execute( undef, undef, q{SELECT MAX(id) FROM Skids WHERE id<?}, $$self{id} ) ) ) {
		$_ = $$self{id};
	} # end if
	return new openprint::Skid( $_ );
} # end sub previous
sub next {
	my $self = shift;
	if ( ! ( ( $_ ) = sql::execute( undef, undef, q{SELECT MIN(id) FROM Skids WHERE id>?}, $$self{id} ) ) ) {
		$_ = $$self{id};
	} # end if
	return new openprint::Skid( $_ );
} # end sub next

sub allocate {
	my ( $self, $paper_id, $docket, $quantity, $units ) = @_;

	my $Order = openprint::Order->find_one( docket=>$docket ) if $docket;

	my $ac = sql::start_transaction( $openprint::dbh );
	my $PA = new openprint::PaperAllocation();
	my $error = $PA->save({
			skid_ids	=>	[ $$self{id} ],
			paper_id	=>	$paper_id,
			quantity	=>	1*$quantity,
			units	=>	$units,
			( $Order ? ( docket => $Order->docket() ) : () ),
			operator_id	=>	$session{user_id},
			} );
	if ( $Order ) {
		$Order->add_log( qq`Allocated $quantity $units on ` . $self->link_to() );
	} # end if
	sql::end_transaction( $openprint::dbh, $ac );
	return $error;
} # end sub allocate

sub empty {
	return $_[0]->is_empty();
} # end sub empty

sub is_empty {
	if ( ! exists $_[0]{empty} ) {
		$_[0]{empty} = 1;
		foreach my $C ( $_[0]->Contents() ) {
			if ( $C->quantity() > 0 ) {
				$_[0]{empty} = 0;
				last;
			} # end if
		} # end foreach
	} # end if
	return $_[0]{empty};
} # end sub is_empty

sub contents {
	my ( $self, $Paper ) = @_;

	my $total;
	foreach my $C ( $self->Contents() ) {
		next if $C->paper_id() != $Paper->id();
		$total += $C->quantity();
	} # end foreach C
	return $total;
} # end sub contents

sub rfidtag_id {
	if ( @_ > 1 ) {
		my $rfidtag_id = $_[1];
		if ( $rfidtag_id ) {
			my $RFIDTag = new openprint::RFIDTag( $rfidtag_id );
			$RFIDTag->set({id=>$rfidtag_id}) if ! $RFIDTag->id();
		} # end if
		$_[0]{rfidtag_id} = $rfidtag_id;
	} # end if
	return $_[0]{rfidtag_id};
} # end sub rfidtag_id

sub RFIDTag {
	return new openprint::RFIDTag( $_[0]{rfidtag_id} );
} # end sub RFIDTag

sub type {
	my $self = shift;
	if ( @_ ) {
		$$self{type} = $_[1];
	}
	if ( ! $$self{type} ) {
		my @Contents = $self->Contents();
		foreach my $C ( @Contents ) {
			if ( $C->Paper()->type() eq 'Roll' ) {
				if ( @Contents > 1 ) {
					$log->error('A Roll Skid cannot contain more than 1 paper.');
				} # end if
				$$self{type} = 'Roll';	
				last;
			} else {
				$$self{type} = 'Sheet';
				last;
			} # end if
		} # end foreach C
	} # end if	
	return $$self{type};
} # end sub type


sub last_seen_days {
	if ( ! exists $_[0]{last_seen_days} ) {
		$_[0]{last_seen_days} = int( (time - Date::Parse::str2time($_[0]{updated_on})) / 86400 );
	} # end if
	return $_[0]{last_seen_days};
}
sub age_days {
	return int( (time - Date::Parse::str2time($_[0]{created_on})) / 86400 );
}

sub Manifest {
	if ( my $MC = $_[0]->ManifestContent() ) {
		return $MC->Manifest();
	} # end if
	require openprint::Manifest;
	return new openprint::Manifest();
} # end sub Manifest

sub ManifestContent {
	if ( ! $_[0]{ManifestContent} ) {
		require openprint::ManifestContent;
		$_[0]{ManifestContent} = openprint::ManifestContent->find_one('skid_id'=>$_[0]{id});
	} # end if
	return $_[0]{ManifestContent};
} # end sub ManifestContents

sub manifest_id {
	return $_[0]->ManifestContent()->manifest_id();
} # end sub manifest_id

sub value {
	my $self = $_[0];
	if ( ! $$self{value} ) {
		$$self{value} = misc::sum( map { $_->value() } ($self->Contents()) );
	} # end if
	return $$self{value};
} # end sub value

sub cost {
	if ( ! $_[0]{cost} ) {
		my $ManifestContent = $_[0]->ManifestContent();
		return undef if ! $ManifestContent;
		my $ManifestType = $ManifestContent->Type();
		my ( $cost, $units );
		if ( $ManifestType->cost() ) {
			$cost = $ManifestType->cost();
			$units = $ManifestType->cost_units();
		} else {
			my $POC = $ManifestType->PurchaseOrder_Content();
			return undef if ! $POC;
			$cost = $POC->price();
			$units = $POC->price_units();
		} # end if
		$_[0]{cost} = $cost.$units;
	} # end if
	return $_[0]{cost};
} # end sub cost

sub PurchaseOrders {
	if ( @_ > 1 ) {
		$_[0]{PurchaseOrders} = $_[1];
	} # end if
	if ( ! $_[0]{PurchaseOrders} ) {
		require openprint::Manifest_Content_Type;
		my @POs;
		foreach my $MCT ( openprint::Manifest_Content_Type->find( 'skid_id any'=>$_[0]->id() ) ) {
			push @POs, $MCT->PurchaseOrder() if $MCT->po_id();
		} # end foreach MCT
		$_[0]{PurchaseOrders} = \@POs;
	} # end if
	return @{$_[0]{PurchaseOrders}} if ref $_[0]{PurchaseOrders} eq 'ARRAY';
	return ();
} # end sub PurchaseOrders

sub used {
	if ( @_ > 1 ) {
		$_[0]{used} = $_[1];
	} # end if
	if ( ! defined $_[0]{used} ) {
		$_[0]{used} = openprint::PaperInventory->find( skid_id=>$_[0]->id(), 'comment like'=>'Checked out%' ) ? 1 : 0;
	} # end if
	return $_[0]{used};
} # end sub used

sub merge {
	my ( $Keep, $Merge ) = @_;
	
	require openprint::ManifestContent;
	my $ac = sql::start_transaction( $openprint::dbh );
	foreach my $MC ( openprint::ManifestContent->find( skid_id=>$$Merge{id} ) ) {
		if ( $MC->rfidtag_id() and $Keep->rfidtag_id() and ( $MC->rfidtag_id() ne $Keep->rfidtag_id() ) ) {
			$openprint::dbh->rollback();
			return 'Cant merge skids due to rfidtag mismatch in manifests. Please do it manually.';
		}
		$MC->save({skid_id=>$$Keep{id},
			( ( ( ! $MC->rfidtag_id() ) and $Keep->rfidtag_id() ) ? ( rfidtag_id => $Keep->rfidtag_id() ) : () )
		});
	} # end foreach
	my @MergeContents = $Merge->Contents();
	if ( @MergeContents > 1 ) {
		$openprint::dbh->rollback();
		return qq`Cant merge skids because skid <a href="/employee/inventory/skid_details.html?skid_id=$$Merge{id}">$$Merge{id}</a> has more than 1 Stock on it. Please fix it manually.`;
	} # end if
	my @KeepContents = $Keep->Contents();
	if ( @KeepContents > 1 ) {
		$openprint::dbh->rollback();
		return qq`Cant merge skids because skid <a href="/employee/inventory/skid_details.html?skid_id=$$Keep{id}">$$Keep{id}</a> has more than 1 Stock on it. Please fix it manually.`;
	} # end if
		
	if ( ! @KeepContents ) {
		
	} elsif ( @MergeContents ) {
		if ( $MergeContents[0]{paper_id} != $KeepContents[0]{paper_id} ) {
			$openprint::dbh->rollback();
			return qq`Cant merge skids because stocks do not match. Please fix it manually.`;
		} # end if
	} # end if
	foreach my $PI ( openprint::PaperInventory->find(skid_id=>$$Merge{id}) ) {
		$PI = $PI->copy();
		$PI->save({skid_id => $$Keep{id} });
	} # end foreach PI	

	my $PI = new openprint::PaperInventory();
	my $e = $PI->save({
			'paper_id'  =>  undef,
			'user_id'   =>  $openprint::session{user_id},
			'instock'   =>  0,
			'delta'     =>  0,
			'comment'   =>  qq`Merged skid <a href="/employee/inventory/skid_details.html?skid_id=$$Merge{id}">$$Merge{id}</a>`,
			'skid_id'   =>  $$Keep{id},
			});
	$PI = new openprint::PaperInventory();
	$e .= $PI->save({
			'paper_id'  =>  undef,
			'user_id'   =>  $openprint::session{user_id},
			'instock'   =>  0,
			'delta'     =>  0,
			'comment'   =>  qq`Merged to skid <a href="/employee/inventory/skid_details.html?skid_id=$$Keep{id}">$$Keep{id}</a>`,
			'skid_id'   =>  $$Merge{id},
			});

	$Merge->delete();
	sql::end_transaction( $openprint::dbh, $ac );
	return '';
} # end sub merge

sub checked_out {
	if ( ! exists $_[0]{checked_out} ) {
		foreach my $SC ( $_[0]->Contents() ) {
			if ( $SC->checked_out() ) {
				$_[0]{checked_out} = $SC->checked_out();
				last;
			} # end if
		} # end foreach SC
	} # end if
	return $_[0]{checked_out};
} # end sub checked_out

sub description {
	if ( ! exists $_[0]{description} ) {
		$_[0]{description} = '';
		foreach my $SC ( $_[0]->Contents() ) {
			$_[0]{description} .= $SC->Paper()->link_to().'<br/>';
		} # end foreach
	} # end if
	return $_[0]{description};
} # end sub description

sub url_to {
	return '/employee/inventory/skid_details.html?skid_id='.$_[0]{id};
}

sub link_to {
	return sprintf('<a href="%3$s">%2$s %1$d</a>', $_[0]{id}, 
		( @_ > 1 ? $_[1] : $_[0]->type() eq 'Roll' ? 'Roll':'Skid' ),
		$_[0]->url_to(),
	);
} # end sub link_to

sub units {
	if ( ! $_[0]{units} ) {
		my @Contents = $_[0]->Contents();
		if ( @Contents ) {
			$_[0]{units} = $Contents[0]->Paper()->units();
		} # end if
	} # end if
	return $_[0]{units};
}

sub quantity {
	if ( ! $_[0]{quantity} ) {
		foreach my $C ( openprint::SkidContent->find( skid_id=>$_[0]{id}, order=>'paper_id' ) ) {
			$_[0]{quantity} = $C->quantity();
			last;
		} # end foreach
	} # end if
	return $_[0]{quantity};
}

sub last_seen {
	if ( @_ > 1 ) {
		$_[0]{last_seen} = $_[1];
	}
	if ( ! $_[0]{last_seen} ) {
		if ( $_[0]{rfidtag_id} ) {
			my $RFID = $_[0]->RFIDTag();
			$_[0]{last_seen} = $RFID->updated_on();
		} else {
			$_[0]{last_seen} = $_[0]{updated_on};
		}
	} # end if
	return $_[0]{last_seen};
}

1;
__END__
