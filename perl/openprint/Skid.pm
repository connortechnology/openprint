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

$debug = 1;

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
);

%transforms = (
	id			=>	[ 's/\D//g' ],
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

sub find {
	shift @_ if $_[0] eq 'openprint::Skid';
	shift @_ if ref $_[0] eq 'openprint::Skid';

	my %params = @_;
	my @values;

	my $sql = 'SELECT * FROM Skids WHERE 1>0';
	if ( $params{id} ) {
        if ( ref $params{id} eq 'ARRAY' ) {
            $sql .= ' AND id IN (' . join(',', map { '?' } @{$params{id}} ) . ')';
            push @values, @{$params{id}};
        } else {
            $sql .= ' and id=?';
            push @values, $params{id};
        } # end if
    } # end if
	if ( $params{'id >='} ) {
		$sql .= ' AND id >= ?';
		push @values, $params{'id >='};
	}  # end if
	if ( $params{'id <='} ) {
		$sql .= ' AND id <= ?';
		push @values, $params{'id <='};
	} # end if
	if ( ref $params{'id not in'} eq 'ARRAY' ) {
		$sql .= ' AND id NOT IN (' . join(',', map { '?' } @{$params{'id not in'}} ) . ')';
		push @values, @{$params{'id not in'}};
	} # end if
	if ( $params{'id ilike'} ) {
		$sql .= ' AND id ilike ?';
		push @values, $params{'id ilike'};
	} # end if

	if ( $params{verification_code} ) {
		$sql .= ' AND id IN (SELECT skid_id FROM skid_verifications WHERE code=?)';
		push @values, $params{verification_code};
	} # end if

	if ( exists $params{has_manifest_id} ) {
		if ( $params{has_manifest_id} ) {
			$sql .= ' AND id IN (SELECT skid_id FROM ManifestContents)';
		} else {
			$sql .= ' AND id NOT IN (SELECT skid_id FROM ManifestContents)';
		} # end if
	} # end if

	if ( $params{paper_id} and $params{'quantity >='} ) {
		$sql .= ' AND id IN (SELECT skid_id FROM skid_contents WHERE quantity >= ?';
		if ( ref $params{paper_id} eq 'ARRAY' ) {
			$sql .= ' AND paper_id IN (' . join(',', map { '?' } @{$params{paper_id}} ) . ') )';
			push @values, $params{'quantity >='}, @{$params{paper_id}};
		} else {
			$sql .= ' AND paper_id=?)';
			push @values, $params{'quantity >='}, $params{paper_id};
		} # en dif
	} elsif ( $params{paper_id} ) {
		if ( ref $params{paper_id} eq 'ARRAY' ) {
			$sql .= ' AND id IN (SELECT skid_id FROM skid_contents WHERE paper_id IN (' . join(',', map { '?' } @{$params{paper_id}} ) . ') )';
			push @values, @{$params{paper_id}};
		} else {
			$sql .= ' AND id IN (SELECT skid_id FROM skid_contents WHERE paper_id=?)';
			push @values, $params{paper_id};
		} # end if
	} elsif ( $params{'quantity >='} ) {
		$sql .= ' AND ((SELECT MAX(quantity) FROM skid_contents where skid_id=skids.id) >= ?)';
		push @values, $params{'quantity >='};
	} # end if

	if ( $params{owner_id} ) {
		$sql .= ' AND owner_id=?';
		push @values, $params{owner_id};
	} # end if
	if ( $params{rfidtag_id} ) {
		$sql .= ' AND rfidtag_id=?';
		push @values, $params{rfidtag_id};
	} # end if
	if ( $params{'rfidtag_id ilike'} ) {
		$sql .= ' AND rfidtag_id ilike ?';
		push @values, $params{'rfidtag_id ilike'};
	} # end if
	if ( exists $params{manufacturers_id} ) {
        if ( ref $params{manufacturers_id} eq 'ARRAY' ) {
            $sql .= ' AND manufacturers_id IN (' . join(',', map { '?' } @{$params{manufacturers_id}} ) . ')';
            push @values, @{$params{manufacturers_id}};
        } else {
            $sql .= ' AND manufacturers_id=?';
            push @values, $params{manufacturers_id};
        } # end if
	} # end if
	if ( $params{'manufacturers_id ilike'} ) {
		$sql .= ' AND manufacturers_id ilike ?';
		push @values, $params{'manufacturers_id ilike'};
	} # end if
	if ( exists $params{'has manufacturers_id'} ) {
		if ( $params{'has manufacturers_id'} ) {
			$sql .= q` AND NOT (manufacturers_id IS NULL OR manufacturers_id='')`;
		} else {
			$sql .= q` AND (manufacturers_id IS NULL OR manufacturers_id='')`;
		} # end if
	} # end if
	if ( $params{created_on_start} and $params{created_on_end} ) {
		$sql .= ' AND ( created_on BETWEEN ? AND ? )';
		push @values, @params{'created_on_start','created_on_end'};
	} elsif ( $params{created_on_start} ) {
		$sql .= ' AND created_on >= ?';
		push @values, $params{created_on_start};
	} elsif ( $params{created_on_end} ) {
		$sql .= ' AND created_on <= ?';
		push @values, $params{created_on_end};
	} # end if

	if ( $params{'created_on >='} ) {
		$sql .= ' AND created_on >= ?';
		push @values, $params{'created_on >='};
	} 
	if ( $params{'created_on <='} ) {
		$sql .= ' AND created_on <= ?';
		push @values, $params{'created_on <='};
	} # end if
	if ( $params{updated_on_start} and $params{updated_on_end} ) {
		$sql .= ' AND ( updated_on BETWEEN ? AND ? )';
		push @values, @params{'updated_on_start','updated_on_end'};
	} elsif ( $params{updated_on_start} ) {
		$sql .= ' AND updated_on >= ?';
		push @values, $params{updated_on_start};
	} elsif ( $params{updated_on_end} ) {
		$sql .= ' AND updated_on <= ?';
		push @values, $params{updated_on_end};
	} # end if

	if ( $params{'updated_on >='} ) {
		$sql .= ' AND updated_on >= ?';
		push @values, $params{'updated_on >='};
	} # end if
	if ( $params{'updated_on <='} ) {
		$sql .= ' AND updated_on <= ?';
		push @values, $params{'updated_on <='};
	} # end if
	if ( $params{received_on_start} and $params{received_on_end} ) {
		$sql .= ' AND ( received_on BETWEEN ? AND ? )';
		push @values, @params{'received_on_start','received_on_end'};
	} elsif ( $params{received_on_start} ) {
		$sql .= ' AND received_on >= ?';
		push @values, $params{received_on_start};
	} elsif ( $params{received_on_end} ) {
		$sql .= ' AND received_on <= ?';
		push @values, $params{received_on_end};
	} # end if

	if ( $params{'received_on >='} ) {
		$sql .= ' AND received_on >= ?';
		push @values, $params{'received_on >='};
	} # end if
	if ( $params{'received_on <='} ) {
		$sql .= ' AND received_on <= ?';
		push @values, $params{'received_on <='};
	} # end if

	if ( $params{last_seen_start} and $params{last_seen_end} ) {
		$sql .= ' AND ( (SELECT updated_on FROM Rfidtags where rfidtags.id=skids.rfidtag_id) BETWEEN ? AND ? )';
		push @values, @params{'last_seen_start','last_seen_end'};
	} elsif ( $params{last_seen_start} ) {
		$sql .= ' AND (SELECT updated_on FROM Rfidtags where rfidtags.id=skids.rfidtag_id) >= ?';
		push @values, $params{last_seen_start};
	} elsif ( $params{last_seen_end} ) {
		$sql .= ' AND ( (SELECT updated_on FROM Rfidtags where rfidtags.id=skids.rfidtag_id) <= ? OR (SELECT updated_on FROM Rfidtags where rfidtags.id=skids.rfidtag_id) IS NULL)';
		push @values, $params{updated_on_end};
	} # end if
	if ( $params{'last_seen >='} ) {
		$sql .= ' AND (SELECT updated_on FROM Rfidtags where rfidtags.id=skids.rfidtag_id) >= ?';
		push @values, $params{'last_seen >='};
	} # end if
	if ( $params{'last_seen <='} ) {
		$sql .= ' AND ( (SELECT updated_on FROM Rfidtags where rfidtags.id=skids.rfidtag_id) <= ? OR (SELECT updated_on FROM Rfidtags where rfidtags.id=skids.rfidtag_id) IS NULL)';
		push @values, $params{'updated_on <='};
	} # end if
	if ( $params{allocated_to_docket} ) {
# FIXME
		$sql .= ' AND id IN ( SELECT skid_id FROM paper_allocations WHERE project_id=(SELECT id FROM Projects WHERE lngDocketNumber=?))';
		push @values, $params{allocated_to_docket};
	} # end if
	if ( $params{fsc_code} ) {
		$sql .= ' AND id IN ( SELECT skid_id FROM skid_contents WHERE paper_id=(SELECT id FROM papers WHERE fsc_code=?))';
		push @values, $params{fsc_code};
	} # end if
	if ( $params{purpose_id} ) {
		$sql .= ' AND id IN ( SELECT skid_id FROM skid_contents WHERE purpose_id=?)';
		push @values, $params{purpose_id};
	} # end if
	if ( $params{created_on} ) {
		$log->debug("Find: Created: $params{created_on}");
	} # end if
	if ( $params{condition_id} ) {
		$sql .= ' AND exists ( SELECT skid_id FROM skid_contents WHERE condition_id=? and skid_contents.skid_id=skids.id )';
		push @values, $params{condition_id};
	} # end if
	if ( exists $params{deleted} ) {
		if ( ref $params{deleted} eq 'ARRAY' ) {
			$sql .= ' AND deleted IN (' . join(',', map {'?'} @{$params{deleted}}) . ')';
			push @values, @{$params{deleted}};
		} else {
			$sql .= ' AND deleted=?';
			push @values, $params{deleted};
		} # end if
	} else {
		$sql .= ' AND deleted=?';
		push @values, 0;
	} # end if

	if ( exists $params{type} ) {
		if ( ref $params{type} eq 'ARRAY' ) {
			if ( @{$params{type}} ) {
				$sql .= ' AND type IN (' . join(',', map {'?'} @{$params{type}}) . ')';
				push @values, @{$params{type}};
			} else {
				$sql .= ' AND type IS NULL';
			} # en dif
		} else {
			$sql .= ' AND type=?';
			push @values, $params{type};
		} # end if
	} elsif ( exists $params{'type !='} ) {
			$sql .= ' AND (type IS NULL OR type!=?)';
			push @values, $params{'type !='};
	} elsif ( exists $params{'type is null or in'} ) {
		if ( ref $params{'type is null or in'} eq 'ARRAY' ) {
			$sql .= ' AND ( type IS NULL OR type IN (' . join(',', map {'?'} @{$params{'type is null or in'}}) . '))';
			push @values, @{$params{'type is null or in'}};
		} elsif ( $params{'type is null or in'} ) {
			$sql .= ' AND (type IS NULL OR type = ?)';
			push @values, $params{'type is null or in'};
		} else {
			$sql .= ' AND type IS NULL';
		} # en dif
	} elsif ( exists $params{'type is null'} ) {
	if ( $params{'type is null'} ) {
			$sql .= ' AND type IS NULL';
		} else {
			$sql .= ' AND type IS NOT NULL';
		}	
	} # end if
	if ( exists $params{location_id} ) {
		if ( ref $params{location_id} eq 'ARRAY' ) {
			if ( @{$params{location_id}} ) {
				$sql .= ' AND location_id IN (' . join(',', map {'?'} @{$params{location_id}}) . ')';
				push @values, @{$params{location_id}};
			} else {
				$sql .= ' AND location_id IS NULL';
			} # en dif
		} else {
			$sql .= ' AND location_id=?';
			push @values, $params{location_id};
		} # end if
	} # end if
	
	$sql .= " ORDER BY $params{order}" if $params{order};
	if ( @values == 1) {
		$log->warn("Loading all skids!");
		#Carp::cluck("Loading all skids?! $sql");
	} # end if

	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->error("Error loading skids SQL($sql)" . $openprint::dbh->errstr );
	} elsif ( $debug ) {
		$log->debug("Debug loaded skids ($sql) (@values) # of results: " . @$data );
	} # end if
	#if ( $data and @$data >= 100 ) {
		#Carp::cluck("Loading a lot of skids?! $sql : #". @$data );
	#} # end if
	return map { new openprint::Skid( $_->{id}, $_ ) } @$data;

} # end sub find

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

#sub to_string {
	#my $self = shift;
	#return 
#} # end sub

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
sub checkout {
	my ( $self, $c ) = @_;
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
					});
			$log->error($e);
		} # end if
		return 1;
	} # end if


	my $rc = 0;
	foreach my $C ( @contents ) {
		if ( ! openprint::PaperInventory->find( skid_id=>$$self{id}, 'comment like'=>'Checked out%' ) ) {
			my $PA = openprint::PaperAllocation->find_one( 'skid_ids any'=>$$self{id}, paper_id=>$C->paper_id());
			my $desc = 'Checked out';
			$desc .= ($PA->docket() ? ' for docket ' . $PA->docket() : '') if $PA;

			my $Paper = $C->Paper();
# This is neccessary because different skids can be doing the checkout
			$Paper->lock();
			my $PI = new openprint::PaperInventory();
			my $e = $PI->save({
					paper_id  =>  $C->paper_id(),
					user_id   =>  $session{user_id},
					instock   =>  $Paper->in_stock() - $C->quantity(),
					delta     =>  -1*$C->quantity(),
					comment   =>  $desc.$c,
					skid_id   =>  $$self{id},
					units     =>  $C->units(),
					( ($PA and $PA->docket() ) ? ( docket		=>	$PA->docket() ) : () ),
					} );
			$C->quantity( 0 );
			$e .= $C->save();
			$e .= $Paper->save(); # Must update in_stock
			if ( $Paper->in_stock() != $PI->instock ) {
				$log->error("What just happened?! $$Paper{in_stock} != $$PI{instock}");
			} # end if
			$log->error( $e ) if $e;
			$Paper->unlock();
			$rc = 1;
		} # end if not already checked out
	} # end foreach Content
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
				$_[0]{checked_out} = 1;
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

sub link_to {
	return sprintf('<a href="/employee/inventory/skid_details.html?skid_id=%1$d">%2$s %1$d</a>', $_[0]{id}, $_[0]->type() eq 'Roll' ? 'Roll':'Skid' );
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
		my @Contents = $_[0]->Contents();
		if ( @Contents ) {
			$_[0]{quantity} = $Contents[0]->quantity();
		} # end if
	} # end if
	return $_[0]{quantity};
}

1;
__END__
