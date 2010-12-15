package openprint::Skid;
@ISA = qw( openprint::Object );

use strict;
use openprint ();
use vars qw( $log $dbh %variable %session $debug $table $serial %fields %transforms %defaults %find_fields $debug );
*variable = \%openprint::variable;
*session = \%openprint::session;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require sql;
require openprint::Location;
require openprint::Paper;
require openprint::PaperInventory;
require openprint::SkidContent;
require openprint::RFIDTag;
require openprint::Skid_Verification;
require openprint::Project;
require openprint::SkidContent;
require openprint::Manifest;
require openprint::ManifestContent;

$debug = 0;

$table = 'Skids';
$serial = 'skid_id_seq';
%fields = (
	'id'			=>	'id',
	'location_id'	=>	'location_id',
	'created_on'	=>	'created_on',
	'created_by_id'	=>	'created_by_id',
	'owner_id'		=>	'owner_id',
	'updated_on'	=>	'updated_on',
	'updated_by'	=>	'updated_by',
	'used'			=>	'used',
	'rfidtag_id'	=>	'rfidtag_id',
	'type'			=>	'type',
	'deleted'		=>	'deleted',
);
%find_fields = (
);

%transforms = (
	'deleted'	=>	[ 's/[^01]//g' ],
);
%defaults = (
	'location_id'	=>	undef,
	'rfidtag_id'	=>	undef,
	'updated_on'	=>	q`'NOW()'`,
	'created_on'	=>	q`'NOW()'`,
	'deleted'		=>	0,
	'type'		=>	undef,
);

sub find {
	my $self = shift;
	my %params = @_;
	my @values;

	my $sql = 'SELECT * FROM Skids WHERE 1>0';
	if ( $params{'id'} ) {
        if ( ref $params{'id'} eq 'ARRAY' ) {
            $sql .= ' AND id IN (' . join(',', map { '?' } @{$params{'id'}} ) . ')';
            push @values, @{$params{'id'}};
        } else {
            $sql .= ' and id=?';
            push @values, $params{id};
        } # end if
    } # end if

	if ( $params{'verification_code'} ) {
		$sql .= ' AND id IN (SELECT skid_id FROM skid_verifications WHERE code=?)';
		push @values, $params{'verification_code'};
	} # end if

	if ( exists $params{'has_manifest_id'} ) {
		if ( $params{'has_manifest_id'} ) {
			$sql .= ' AND id IN (SELECT skid_id FROM ManifestContents)';
		} else {
			$sql .= ' AND id NOT IN (SELECT skid_id FROM ManifestContents)';
		} # end if
	} # end if

	if ( $params{'paper_id'} ) {
		$sql .= ' AND id IN (SELECT skid_id FROM skid_contents WHERE paper_id=?)';
		push @values, $params{'paper_id'};
	} # end if
	if ( $params{'quantity_>='} ) {
		$sql .= ' AND id IN (SELECT skid_id FROM skid_contents WHERE quantity >= ?)';
		push @values, $params{'quantity_>='};
	} # end if
	if ( $params{'quality_id'} ) {
		$sql .= ' AND id IN (SELECT skid_id FROM skid_contents WHERE quality_id = ?)';
		push @values, $params{'quality_id'};
	} # end if
	if ( $params{'owner_id'} ) {
		$sql .= ' AND owner_id=?';
		push @values, $params{'owner_id'};
	} # end if
	if ( $params{'rfidtag_id'} ) {
		$sql .= ' AND rfidtag_id=?';
		push @values, $params{'rfidtag_id'};
	} # end if
	if ( $params{'created_on_start'} and $params{'created_on_end'} ) {
		$sql .= ' AND ( created_on BETWEEN ? AND ? )';
		push @values, @params{'created_on_start','created_on_end'};
	} elsif ( $params{'created_on_start'} ) {
		$sql .= ' AND created_on >= ?';
		push @values, $params{'created_on_start'};
	} elsif ( $params{'created_on_end'} ) {
		$sql .= ' AND created_on <= ?';
		push @values, $params{'created_on_end'};
	} # end if
	if ( $params{'updated_on_start'} and $params{'updated_on_end'} ) {
		$sql .= ' AND ( updated_on BETWEEN ? AND ? )';
		push @values, @params{'updated_on_start','updated_on_end'};
	} elsif ( $params{'updated_on_start'} ) {
		$sql .= ' AND updated_on >= ?';
		push @values, $params{'updated_on_start'};
	} elsif ( $params{'updated_on_end'} ) {
		$sql .= ' AND updated_on <= ?';
		push @values, $params{'updated_on_end'};
	} # end if
	if ( $params{'last_seen_start'} and $params{'last_seen_end'} ) {
		$sql .= ' AND ( (SELECT updated_on FROM Rfidtags where rfidtags.id=skids.rfidtag_id) BETWEEN ? AND ? )';
		push @values, @params{'last_seen_start','last_seen_end'};
	} elsif ( $params{'last_seen_start'} ) {
		$sql .= ' AND (SELECT updated_on FROM Rfidtags where rfidtags.id=skids.rfidtag_id) >= ?';
		push @values, $params{'last_seen_start'};
	} elsif ( $params{'last_seen_end'} ) {
		$sql .= ' AND ( (SELECT updated_on FROM Rfidtags where rfidtags.id=skids.rfidtag_id) <= ? OR (SELECT updated_on FROM Rfidtags where rfidtags.id=skids.rfidtag_id) IS NULL)';
		push @values, $params{'updated_on_end'};
	} # end if
	if ( $params{'allocated_to_docket'} ) {
		$sql .= ' AND id IN ( SELECT skid_id FROM paper_allocations WHERE project_id=(SELECT Index FROM Projects WHERE lngDocketNumber=?))';
		push @values, $params{'allocated_to_docket'};
	} # end if
	if ( $params{'fsc_code'} ) {
		$sql .= ' AND id IN ( SELECT skid_id FROM skid_contents WHERE paper_id=(SELECT id FROM papers WHERE fsc_code=?))';
		push @values, $params{'fsc_code'};
	} # end if
	if ( $params{'purpose_id'} ) {
		$sql .= ' AND id IN ( SELECT skid_id FROM skid_contents WHERE purpose_id=?)';
		push @values, $params{'purpose_id'};
	} # end if
	if ( $params{'created_on'} ) {
		$log->debug("Find: Created: $params{'created_on'}");
	} # end if
	if ( exists $params{'deleted'} ) {
		if ( ref $params{'deleted'} eq 'ARRAY' ) {
			$sql .= ' AND (deleted IS NULL OR deleted IN (' . join(',', map {'?'} @{$params{'deleted'}}) . '))';
			push @values, @{$params{'deleted'}};
		} else {
			$sql .= ' AND deleted=?';
			push @values, $params{'deleted'};
		} # end if
	} else {
		$sql .= ' AND (deleted=? OR deleted IS NULL)';
		push @values, 0;
	} # end if

	if ( exists $params{'type'} ) {
		if ( ref $params{'type'} eq 'ARRAY' ) {
			if ( @{$params{'type'}} ) {
				$sql .= ' AND type IN (' . join(',', map {'?'} @{$params{'type'}}) . ')';
				push @values, @{$params{'type'}};
			} else {
				$sql .= ' AND type IS NULL';
			} # en dif
		} else {
			$sql .= ' AND type=?';
			push @values, $params{'type'};
		} # end if
	} # end if
	if ( exists $params{'location_id'} ) {
		if ( ref $params{'location_id'} eq 'ARRAY' ) {
			if ( @{$params{'location_id'}} ) {
				$sql .= ' AND location_id IN (' . join(',', map {'?'} @{$params{'location_id'}}) . ')';
				push @values, @{$params{'location_id'}};
			} else {
				$sql .= ' AND location_id IS NULL';
			} # en dif
		} else {
			$sql .= ' AND location_id=?';
			push @values, $params{'location_id'};
		} # end if
	} # end if
	
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug("Error loading skids SQL($sql)" . DBI->errstr );
	} elsif ( $debug ) {
		$log->debug("Debug loaded skids ($sql) (@values) # of results: " . @$data );
	} # end if
	return map { new openprint::Skid( $_->{id}, $_ ) } @$data;

} # end sub find

sub copy {
	my $self = shift;
	my $new = new openprint::Skid( );
	@$new{'location_id','type'} = @$self{'location_id','type'};
	$$new{'type'} = $self->type();
	$new->save();

	foreach my $C ( $self->Contents() ) {
		$C = $C->copy();
		$C->save({'skid_id'=>$$new{id}});
		$C->Paper()->add_inventory( $new->id(), $C->quantity() );
		foreach my $PA ( openprint::PaperAllocation->find('skid_id'=>$$self{'id'}, 'paper_id'=>$C->paper_id()) ) {
			$C->Paper()->allocate( $new, $PA->project_id(), $PA->quantity(), $PA->units(), $PA->reason() );
		} # end while
	} # end foreach Content
	return $new;
} # end sub copy

sub save {
	my ( $self, $data ) = @_;
	$$self{'created_by_id'} = $session{'user_id'} if ! $$self{'created_by_id'};
	$self->type() if ! $$self{'type'};
	$self->location_id();
	return $self->SUPER::save( $data );
} # end sub save

sub destroy {
	my $self = shift;

	my $ac = sql::start_transaction( $dbh );
	sql::execute( undef, undef, q{DELETE FROM manifestcontents WHERE skid_id=?}, $$self{'id'} );
	sql::execute( undef, undef, q{DELETE FROM paper_allocations WHERE skid_id=?}, $$self{'id'} );
	sql::execute( undef, undef, q{DELETE FROM paper_inventory WHERE skid_id=?}, $$self{'id'} );
	sql::execute( undef, undef, q{DELETE FROM skid_contents WHERE skid_id=?}, $$self{'id'} );
	sql::execute( undef, undef, q{DELETE FROM skids WHERE id=?}, $$self{'id'} );
	sql::end_transaction( $dbh, $ac );
} # end sub delete

sub to_string {
	my $self = shift;
	return join('-', sql::execute( undef, undef, q{SELECT (SELECT shortname FROM PaperNames WHERE id=name_id),(SELECT shortname FROM PaperFinishes WHERE id=finish_id),(SELECT shortname FROM PaperColours WHERE id=colour_id),(SELECT shortname FROM PaperWeights WHERE id=weight_id),width,height FROM Papers WHERE Id=?}, $$self{'id'} ) );
} # end sub

sub add {
	my ( $self, $Paper, $quantity, $quality ) = @_;
	my $Quality;
	if ( ref $quality eq 'openprint::StockQuality' ) {
		$Quality = $quality;
	} elsif ( ! $quality ) {
		# Default to new
		$Quality = openprint::StockQuality->find_one('name'=>'new');
	} # end if
	if ( ! $Quality ) {
		$log->error("Must specify quality");
		return 0;
	} # end if
	if ( ! $Paper ) {
		$log->error("Must specify Stock");
		return 0;
	} # end if

	my $C = $self->Content( $Paper );
	if ( ! $C ) {
		delete $$self{'Contents'};
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
	$C->save({
			'skid_id' => $$self{'id'},
			'paper_id'	=>	$Paper->id(),
			'quality_id'	=>	$Quality->id(),
			'quantity'=>$quantity,
			});
	return $quantity - $old_quantity;
} # end sub add

sub remove {
	my ( $self, $Paper, $quantity, $purpose_id ) = @_;
	$quantity =~ s/[^\-\d]//g;
	$quantity = int $quantity;
	my $C = $self->Content( $Paper );
	if ( ! $C ) {
		$log->error("Unable to find SkidContent for Skid $$self{'id'} for Paper $$Paper{id}");
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
	my @contents = $self->Contents( 'Paper'=>$Paper, 'purpose_id'=>$purpose_id );
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
		@$self{'location_id'} = sql::execute( undef, undef, q{SELECT id FROM Locations WHERE name=?}, $name );
		if ( ! $$self{'location'} ) {
			sql::insert( undef,undef, 'Locations', 'name', $name );
			@$self{'location_id'} = sql::execute( undef, undef, q{SELECT id FROM Locations WHERE name=?}, $name );
		} # end if
	} # end if
	return new openprint::Location( $$self{'location_id'} )->name();
} # end if

sub location_id {
	my ( $self, $new ) = @_;

	if ( $$self{'rfidtag_id'} ) {
		my $Tag = new openprint::RFIDTag( $$self{'rfidtag_id'} );
		if ( $new ) {
			if ( $new != $Tag->location_id() ) {
				$Tag->save({'location_id'=>$new});
			} # end if
			$$self{'location_id'} = $new;
		} elsif ( $Tag->location_id() != $$self{'location_id'} ) {
			$$self{'location_id'} = $Tag->location_id();
		} # end if
	} elsif ( $new ) {
		$$self{'location_id'} = $new;
	} # end if
	return $$self{'location_id'};
} # end sub location_id

sub Location {
	my ( $self ) = @_;

	if ( $$self{'rfidtag_id'} ) {
		return new openprint::RFIDTag( $$self{'rfidtag_id'} )->Location();
	} # end if

	return new openprint::Location( $$self{'location_id'} );
} # end sub Location

sub Content {
    my ( $self, $Paper ) = @_;
	return if ! $$self{'id'};
	foreach my $C ( $self->Contents() ) {
		if ( $C->paper_id() == $Paper->id() ) {
			return $C;
		} # end if	
	} # end foreach C
} # end sub Content

sub Contents {
    my $self = shift;
	return if ! $$self{'id'};

	if ( @_ ) {
		my %params = @_;
		$params{'skid_id'} = $$self{'id'};
		return openprint::SkidContent->find( %params );
	} elsif ( ! $$self{'Contents'} ) {
		@{$$self{'Contents'}} = openprint::SkidContent->find( 'skid_id'=>$$self{'id'} );
	} # end if
	return @{$$self{'Contents'}};
} # end sub contents

sub allocation {
	my ( $self, %options ) = @_;
	if ( $options{'Paper'} ) {
		my $allocated = misc::sum( map { $_->quantity() } openprint::PaperAllocation->find('skid_id'=>$$self{'id'},'paper_id'=>$options{'Paper'}->{id}) );
		return $allocated;
	} # end if
} # end sub allocatiosn

sub allocateable {
	my ( $self, $Paper ) = @_;
	my $C = $self->Content( $Paper );
	if ( ! $C ) {
		$log->error("Unable to find SkidContent for Skid $$self{'id'} for Paper $$Paper{id}");
		return;
	} # end if
	return $C->allocateable();
} # end sub allocateable

# Checkout all paper on the skid
sub checkout {
	my ( $self, $c ) = @_;
	my @contents = openprint::SkidContent->find('skid_id'=>$$self{id});
	if ( ! @contents ) {
		if ( ! openprint::PaperInventory->find( 'skid_id'=>$$self{'id'}, 'comment_like'=>'Checked out%' ) ) {
			my $PI = new openprint::PaperInventory();
			my $e = $PI->save({
					'paper_id'	=>	undef,
					'user_id'	=>	$session{'user_id'},
					'instock'	=>	0,
					'delta'		=>	0,
					'comment'	=>	'Checked out' . $c,
					'skid_id'	=>	$$self{'id'},
					'units'		=>	'unknown',
					});
			$log->error($e);
		} # end if
		return 1;
	} # end if

	foreach my $C ( @contents ) {
		if ( ! openprint::PaperInventory->find( 'skid_id'=>$$self{'id'}, 'comment_like'=>'Checked out%' ) ) {
			my $PA = openprint::PaperAllocation->find_one('skid_id'=>$$self{'id'}, 'paper_id'=>$C->paper_id());
			my $desc = 'Checked out' . ($PA->project_id() ? ' for docket ' . $PA->Project()->docket() : '');
			my $PI = new openprint::PaperInventory();
			my $e = $PI->save({
					'paper_id'  =>  $C->paper_id(),
					'user_id'   =>  $session{'user_id'},
					'instock'   =>  $C->Paper()->in_stock() - $C->quantity(),
					'delta'     =>  -1*$C->quantity(),
					'comment'   =>  $desc.$c,
					'skid_id'   =>  $$self{id},
					'units'     =>  $C->units(),
					} );
			$C->quantity( 0 );
			$e .=   $C->save();
			$log->error( $e ) if $e;
			return 1;
		} # end if not already checked out
	} # end foreach Content
	return 0;
} # end sub checkout

sub previous {
	my $self = shift;
	if ( ! ( ( $_ ) = sql::execute( undef, undef, q{SELECT MAX(id) FROM Skids WHERE id<?}, $$self{'id'} ) ) ) {
		$_ = $$self{'id'};
	} # end if
	return new openprint::Skid( $_ );
} # end sub previous
sub next {
	my $self = shift;
	if ( ! ( ( $_ ) = sql::execute( undef, undef, q{SELECT MIN(id) FROM Skids WHERE id>?}, $$self{'id'} ) ) ) {
		$_ = $$self{'id'};
	} # end if
	return new openprint::Skid( $_ );
} # end sub next

sub allocate {
	my ( $self, $paper_id, $project_id, $quantity, $units ) = @_;

	my $ac = sql::start_transaction();
	sql::insert( undef, undef, 'Paper_Allocations',
			'skid_ids',		[ $$self{'id'} ],
			'paper_id',		$paper_id,
			'quantity',		1*$quantity,
			'units',		$units,
			'project_id',	$project_id ? $project_id : undef,
			'operator_id',	$variable{'user_id'},
			);
	if ( $project_id ) {
	(new openprint::Project( $project_id ))->add_to_log( @session{'company_id','user_id'}, qq`Allocated $quantity $units on skid <a href="/employee/inventory/skid_details.html?skid_id=$$self{id}">$$self{id}</a>` ) if $project_id;
	} # end if
	sql::end_transaction( undef, $ac );
} # end sub allocate

sub empty {
	my ( $self ) = @_;
	my @Contents = $self->Contents('quantity_>'=>0);
	return ! @Contents;
} # end sub empty

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
	my $self = shift;

	if ( @_ ) {
		my $rfidtag_id = shift;	
		if ( $rfidtag_id ) {
			my $RFIDTag = new openprint::RFIDTag( $rfidtag_id );
			my $error = $RFIDTag->save({'id'=>$rfidtag_id}) if ! $RFIDTag->id();
			$log->error( $error ) if $error;
		} # end if
		$$self{'rfidtag_id'} = $rfidtag_id;
	} # end if
	return $$self{'rfidtag_id'};
} # end sub rfidtag_id

sub RFIDTag {
	return new openprint::RFIDTag( $_[0]{rfidtag_id} );
} # end sub RFIDTag

sub type {
	my $self = shift;
	if ( ! $$self{'type'} ) {
		my @Contents = $self->Contents();
		foreach my $C ( @Contents ) {
			if ( $C->Paper()->type() eq 'Roll' ) {
				if ( @Contents > 1 ) {
					$log->error('A Roll Skid cannot contain more than 1 paper.');
				} # end if
				$$self{'type'} = 'Roll';	
				last;
			} else {
				$$self{'type'} = 'Sheet';
				last;
			} # end if
		} # end foreach C
	} # end if	
	return $$self{'type'};
} # end sub type

sub is_empty {
	my $self = $_[0];
	foreach my $C ( $self->Contents() ) {
		return 0 if $C->quantity() > 0;
	} # end foreach
	return 1;
} # end sub is_empty

sub last_seen_days {
	my $self = $_[0];
	return int( (time - Date::Parse::str2time($$self{'updated_on'})) / (24*60*60) );
}
sub age_days {
	my $self = $_[0];
	return int( (time - Date::Parse::str2time($$self{'created_on'})) / (24*60*60) );
}

sub Manifest {
	my $self = $_[0];
	foreach my $MC ( openprint::ManifestContent->find_one('skid_id'=>$$self{id}) ) {
		return $MC->Manifest();
	} # end foreach MC
	return new openprint::Manifest();
} # end sub Manifest

sub ManifestContents {
	return openprint::ManifestContent->find('skid_id'=>$_[0]{id});
} # end sub ManifestContents

sub manifest_id {
	return $_[0]->Manifest()->id();
} # end sub manifest_id

1;
__END__
