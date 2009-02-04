package openprint::Skid;
@ISA = qw( openprint::Object );

use strict;
use openprint ();
use vars qw( $log $dbh %variable %session  );
*variable = \%openprint::variable;
*session = \%openprint::session;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require sql;
require openprint::Location;
require openprint::Paper;
require openprint::RFIDTag;
require openprint::Skid_Verification;
require openprint::SkidContent;

my $debug = 1;

use vars qw( $log $dbh $table $serial %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$table = 'Skids';
$serial = 'skid_id_seq';
my %fields = (
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

%transforms = (
);
%defaults = (
	'location_id'	=>	undef,
	'rfidtag_id'	=>	undef,
	'updated_on'	=>	'NOW()',
	'created_on'	=>	'NOW()',
);

sub find {
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
	if ( $params{'allocated_to_docket'} ) {
		$sql .= ' AND id IN ( SELECT skid_id FROM paper_allocations WHERE project_id=(SELECT Index FROM tbl_Projects WHERE lngDocketNumber=?))';
		push @values, $params{'allocated_to_docket'};
	} # end if
	if ( $params{'fsc_code'} ) {
		$sql .= ' AND id IN ( SELECT skid_id FROM skid_contents WHERE paper_id=(SELECT id FROM papers WHERE fsc_code=?))';
		push @values, $params{'fsc_code'};
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
	
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug("Error loading skids SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No skidss loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded skids ($sql) (@values) " );
	} # end if
	return map { new openprint::Skid( $_->{id}, $_ ) } @$data;

} # end sub find

sub copy {
	my $self = shift;
	my $new = new openprint::Skid( );
	@$new{'location_id'} = @$self{'location_id'};
	if ( ! $$self{'Paper'} ) {
		$log->debug("Problem with paper on skid");
	} # end if
	%{$$new{'Paper'}} = %{$$self{'Paper'}};
	$new->save();
	foreach my $paper_id ( keys %{$$new{'Paper'}} ) {
		my $Paper = new openprint::Paper( $paper_id );
		$Paper->add_inventory( $new->id(), $$new{'Paper'}{$paper_id} );
		my @data = sql::execute( undef, undef, q{SELECT project_id, quantity, units FROM Paper_Allocations WHERE skid_id=? AND paper_id=?}, $$self{'id'}, $paper_id );
		while ( @data ) {
			$Paper->allocate( $new->id(), splice @data, 0, 3 );
		} # en d while
	} # end foreach paper
	return $new;
} # end sub copy

sub load {
	my ($self, $data ) = @_;

	if ( ! $data ) {
		$data = $dbh->selectrow_hashref( q{SELECT * FROM Skids WHERE id=?}, {}, $$self{'id'} );
	} # end if
	@$self{keys %$data} = @$data{keys %$data};

	delete $$self{'Contents'};
	@{$$self{'Contents'}} = $self->Contents();
	%{$$self{'Paper'}} = ();
	if ( $$self{'id'} ) {
		foreach my $C ( $self->Contents() ) {
			$$self{'Paper'}{$$C{'paper_id'}} += $$C{'quantity'};
		} # end foreach
	} # end if
} # end sub load

sub save {
	my $self = shift;
	$$self{'created_by_id'} = $session{'user_id'} if ! $$self{'created_by_id'};
	my $ac = sql::start_transaction( $dbh );
	my @sql = ( 
		'rfidtag_id',	$$self{'rfidtag_id'} ? $$self{'rfidtag_id'} : undef,
		'location_id',	$$self{'location_id'} ? $$self{'location_id'} : undef,
		'created_by_id',$$self{'created_by_id'},	
		'updated_on',	'NOW()',
		'updated_by',	$session{'user_id'},
		);
		
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('Skid_id_seq')} );
		if ( my $error = sql::insert( undef, undef, 'Skids', @sql, 'id', $$self{'id'} ) ) {
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if
	} else {
		if ( my $error = sql::update( undef, undef, 'Skids', ['id=?',$$self{'id'}], \@sql )) {
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if
	} # end if

	sql::execute( undef, undef, q{DELETE FROM Skid_Contents WHERE skid_id=?}, $$self{'id'} );
	foreach my $paper_id ( keys %{$$self{'Paper'}} ) {
        my $Paper = new openprint::Paper( $paper_id );
		sql::insert( undef, undef, 'skid_Contents', 'skid_id', $$self{'id'}, 'paper_id', $paper_id, 'quantity', int($$self{'Paper'}{$paper_id}), 'units', $Paper->type() eq 'Roll' ? 'lbs' : 'sheets' );
	} # end foreach paper_id
	$self->load();
	sql::end_transaction( $dbh, $ac );
	return;
} # end sub save

sub delete {
	my $self = shift;
	sql::update( undef, undef, 'Skids', ['id=?', $$self{'id'}], 'deleted', 1 );
} # end sub delete

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
	my ( $self, $Paper, $quantity ) = @_;
	my $old_quantity = $$self{'Paper'}{$$Paper{'id'}};

	if ( $quantity =~ /^\+/ ) {
		$quantity =~ s/[^\d]//g;
# Add
		$quantity = $$self{'Paper'}{$$Paper{'id'}} + $quantity;
	} elsif ( $quantity =~ /^\-/ ) {
		$quantity =~ s/[^\d]//g;
# Subtract
		$quantity = $$self{'Paper'}{$$Paper{'id'}} - $quantity;
	} else {
		$quantity =~ s/[^\d]//g;
# Set

	} # end if

	$$self{'Paper'}{$$Paper{'id'}} = $quantity;
	return $$self{'Paper'}{$$Paper{'id'}} - $old_quantity;

} # end sub add_inventory
sub remove {
	my ( $self, $Paper, $quantity ) = @_;
	$quantity =~ s/[^\-\d]//g;
	$quantity = int $quantity;
	$$self{'Paper'}{$$Paper{'id'}} -= $quantity;
	$$self{'Paper'}{$$Paper{'id'}} = 0 if $$self{'Paper'}{$$Paper{'id'}} < 0;
} # end sub add_inventory

sub set {
	my ( $self, $Paper, $quantity ) = @_;
	$quantity =~ s/[^\-\d]//g;
	$quantity = int $quantity;
	$$self{'Paper'}{$$Paper{'id'}} = $quantity;
	$$self{'Paper'}{$$Paper{'id'}} = 0 if $$self{'Paper'}{$$Paper{'id'}} < 0;
} # end sub add_inventory

sub paper {
	my $self = shift;
	return $$self{'Paper'};
} # end sub paper

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
			$Tag->location_id( $new );
			$Tag->save();
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

sub Contents {
    my $self = shift;
	return if ! $$self{'id'};

	if ( $$self{'Contents'} ) {
		return @{$$self{'Contents'}};
	} # end if

    my %params = @_;
    $params{'skid_id'} = $$self{'id'};

    return openprint::SkidContent::find( %params );

} # end sub contents

sub allocation {
	my ( $self, %options ) = @_;
	if ( $options{'Paper'} ) {
		my ( $allocated ) = sql::execute( undef, undef, q{SELECT SUM(quantity) FROM Paper_Allocations WHERE skid_id=? AND paper_id=?}, $$self{'id'}, $options{'Paper'}->{id} );
		return $allocated;
	} # end if
} # end sub allocatiosn

sub allocateable {
	my ( $self, $Paper ) = @_;
	return $$self{'Paper'}{$Paper->id()} - $self->allocation( 'Paper'=>$Paper );
} # end sub allocateable

# Checkout all paper on the skid
sub checkout {
	my ( $self, $c ) = @_;
	my @contents = openprint::SkidContent::find('skid_id'=>$$self{id});
	if ( ! @contents ) {
		if ( ! openprint::PaperInventory::find( 'skid_id'=>$$self{'id'}, 'comment_like'=>'Checked out%' ) ) {
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
		if ( ! openprint::PaperInventory::find( 'skid_id'=>$$self{'id'}, 'comment_like'=>'Checked out%' ) ) {
			my ( $project_id ) = sql::execute( undef, undef, q{SELECT project_id FROM Paper_Allocations WHERE skid_id=? AND paper_id=?}, $$self{'id'}, $C->paper() );
			my $desc = 'Checked out' . ($project_id ? ' for docket ' . new openprint::Project($project_id)->docket() : '');
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
			'skid_id',		$$self{'id'},
			'paper_id',		$paper_id,
			'quantity',		1*$quantity,
			'units',		$units,
			'project_id',	$project_id ? $project_id : undef,
			'operator_id',	$variable{'user_id'},
			);
	(new openprint::Project( $project_id ))->add_to_log( @session{'company_id','user_id'}, qq`Allocated $quantity $units on skid <a href="/employee/inventory/skid_details.html?skid_id=$$self{id}">$$self{id}</a>` ) if $project_id;
	sql::end_transaction( undef, $ac );
} # end sub allocate

sub empty {
	my ( $self ) = @_;
	foreach my $paper_id ( keys %{$$self{'Paper'}} ) {
		if ( $$self{'Paper'}{$paper_id} > 0 ) {
			return 0;
		} # end if
	} # end foreach
	return 1;
} # end sub empty

sub contents {
	my ( $self, $Paper ) = @_;
	return $$self{'Paper'}{$Paper->id()};
} # end sub contents

sub rfidtag_id {
	my $self = shift;

	if ( @_ ) {
		my $rfidtag_id = shift;	
		my $RFIDTag = new openprint::RFIDTag( $rfidtag_id );
		my $error = $RFIDTag->save({'id'=>$rfidtag_id}) if ! $RFIDTag->id();
		$log->error( $error ) if $error;
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
				$$self{'type'} = 'Skid';	
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

sub Manifest {
	my $self = $_[0];
	foreach my $MC ( openprint::ManifestContent::find('skid_id'=>$$self{id}) ) {
		return $MC->Manifest();
	} # end foreach MC
	return new openprint::Manifest();
} # end sub Manifest

1;
__END__
