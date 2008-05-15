package openprint::Skid;
@ISA = qw( openprint::Object );

use strict;
use openprint ();
use vars qw( $log $dbh %variable %cache);
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require sql;
require openprint::Location;
require openprint::Paper;
require openprint::SkidContent;
require openprint::RFIDTag;

my $debug = 1;

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
	if ( $params{'purpose_id'} ) {
		$sql .= ' AND id IN ( SELECT skid_id FROM skid_contents WHERE purpose_id=?)';
		push @values, $params{'purpose_id'};
	} # end if
	if ( $params{'created_on'} ) {
		$log->debug("Find: Created: $params{'created_on'}");
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
	foreach my $content ( $self->contents() ) {
		my $Paper = new openprint::Paper( $content->paper_id );
		my $newcontent = $content->copy();
		$newcontent->skid_id( $new->id() );
		$newcontent->save();

		$Paper->add_inventory( $new->id(), $content->quantity() );
		my @data = sql::execute( $openprint::log,$openprint::dbh, q{SELECT project_id, quantity, units FROM Paper_Allocations WHERE skid_id=? AND paper_id=?}, $$self{'id'}, $Paper->id );
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

	#%{$$self{'Paper'}} = ();
	#if ( $$self{'id'} ) {
		##$$self{'Paper'} = [ map ( $_->paper_id(), $_ ) openprint::SkidContent::find('skid_id'=>$$self{'id'}) ];
	#} # end if
} # end sub load

sub save {
	my $self = shift;
	$$self{'created_by_id'} = $openprint::session{'user_id'} if ! $$self{'created_by_id'};
	my $ac = sql::start_transaction( $dbh );
	my @sql = ( 
		'rfidtag_id',	$$self{'rfidtag_id'} ? $$self{'rfidtag_id'} : undef,
		'location_id',	$$self{'location_id'} ? $$self{'location_id'} : undef,
		'created_by_id',$$self{'created_by_id'},	
		'updated_on',	'NOW()',
		'updated_by',	$openprint::session{'user_id'},
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

	#sql::execute( undef, undef, q{DELETE FROM Skid_Contents WHERE skid_id=?}, $$self{'id'} );
	#foreach my $paper_id ( keys %{$$self{'Paper'}} ) {
		#$$self{'Paper'}{$paper_id}->save();
		#sql::insert( undef, undef, 'skid_Contents', 'skid_id', $$self{'id'}, 'paper_id', $paper_id, 'quantity', int($$self{'Paper'}{$paper_id}), 'units', $Paper->type() eq 'Roll' ? 'lbs' : 'sheets' );
	#} # end foreach paper_id
	sql::end_transaction( $dbh, $ac );
	$self->load();
	return;
} # end sub save

sub delete {
	my $self = shift;

	my $ac = sql::start_transaction( $dbh );
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
	my ( $self, $Paper, $quantity, $purpose_id ) = @_;

	my $content;
	my @contents = $self->contents( 'Paper'=>$Paper, 'purpose_id'=>$purpose_id );
	if ( ! @contents ) {
		$content = new openprint::SkidContent();
		$content->skid_id( $$self{'id'} );
		$content->paper_id( $Paper->id() );
		$content->purpose_id( $purpose_id );
	} else {
		$content = $contents[0];
		if ( $purpose_id and ! $content->purpose_id() ) {
			$content->purpose_id( $purpose_id );
		} # end if
	} # end if

	my $old_quantity = $content->quantity();

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

	$content->quantity( $quantity );
	$content->save();
	return $quantity - $old_quantity;
} # end sub add_inventory
sub remove {
	my ( $self, $Paper, $quantity, $purpose_id ) = @_;
	$quantity =~ s/[^\-\d]//g;
	$quantity = int $quantity;
	my @contents = $self->contents( 'Paper'=>$Paper, 'purpose_id'=>$purpose_id );
	if ( ! @contents ) {
		return 'Specified stock is not on this skid';
	} # end if
	my $content = $contents[0];
	$content->quantity( $content->quantity() - $quantity );
	$content->quantity( 0 ) if $content->quantity() < 0;
	$content->save();
	return '';
} # end sub remove

sub set {
	my ( $self, $Paper, $quantity, $purpose_id ) = @_;
	$quantity =~ s/[^\-\d]//g;
	$quantity = int $quantity;
	my @contents = $self->contents( 'Paper'=>$Paper, 'purpose_id'=>$purpose_id );
	if ( ! @contents ) {
		return 'Specified stock is not on this skid';
	} # end if
	my $content = $contents[0];
	$content->quantity( $quantity );
	$content->quantity( 0 ) if $content->quantity() < 0;
	$content->save();
	return '';
} # end sub set

sub location {
	my $self = shift;
	if ( @_ ) {
		my $name = shift;
		@$self{'location_id','location'} = sql::execute( undef, undef, q{SELECT id,name FROM Locations WHERE name=?}, $name );
		if ( ! $$self{'location'} ) {
			sql::insert( undef,undef, 'Locations', 'name', $name );
			@$self{'location_id','location'} = sql::execute( undef, undef, q{SELECT id,name FROM Locations WHERE name=?}, $name );
		} # end if
	} # end if
	if ( ( ! $$self{'location'} ) and $$self{'location_id'} ) {
		@$self{'location'} = new openprint::Location( $$self{'location_id'} )->name();
	} # end if
	return $$self{'location'};
} # end if

sub location_id {
	my ( $self, $new ) = @_;

	if ( $$self{'rfidtag_id'} ) {
		my $Tag = new openprint::RFIDTag( $$self{'rfidtag_id'} );
		if ( $new ) {
			$Tag->location_id( $new );
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

sub created_on {
	my $self = shift;
	return $$self{'created_on'};
} # end sub created_on
sub created_by_id {
	my $self = shift;
	return $$self{'created_by_id'};
} # end sub created_by_id

sub contents {
	my $self = shift;
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

# Checkout all paper on the skid
sub checkout {
	my ( $self ) = @_;
	foreach my $C ( openprint::SkidContent::find('skid_id'=>$$self{id}) ) {
		my ( $project_id ) = sql::execute( undef, undef, q{SELECT project_id FROM Paper_Allocations WHERE skid_id=? AND paper_id=?}, $$self{'id'}, $C->paper() );
		$C->Paper->add_inventory( $$self{id}, -1*$C->quantity(), $C->units(), 'Removed' . $project_id ? ' for docket ' . new openprint::Project($project_id)->docket() : '' );
		$C->quantity( 0 );
		$C->save();
	} # end foreach Content
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
	(new openprint::Project( $project_id ))->add_to_log( @openprint::session{'company_id','user_id'}, qq`Allocated $quantity $units on skid <a href="/employee/inventory/skids.html?skid_id=$$self{id}">$$self{id}</a>` ) if $project_id;
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

1;
__END__
