package openprint::Skid;
@ISA = qw( openprint::Object );

use strict;
use openprint ();
use vars qw(%variable %cache);
*variable = \%openprint::variable;

require sql;
require openprint::Location;
require openprint::Paper;

my $debug = 0;

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
		$openprint::log->debug("Find: Created: $params{'created_on'}");
	} # end if
	
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};

	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug("Error loading skids SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$openprint::log->debug('No skidss loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$openprint::log->debug("Debug loaded skids ($sql) (@values) " );
	} # end if
	return map { new openprint::Skid( $_->{id}, $_ ) } @$data;

} # end sub find

sub copy {
	my $self = shift;
	my $new = new openprint::Skid( );
	@$new{'location_id'} = @$self{'location_id'};
	if ( ! $$self{'Paper'} ) {
		$$self{'log'}->debug("Problem with paper on skid");
	} # end if
	%{$$new{'Paper'}} = %{$$self{'Paper'}};
	$new->save();
	foreach my $paper_id ( keys %{$$new{'Paper'}} ) {
		my $Paper = new openprint::Paper( $paper_id );
		$Paper->add_inventory( $new->id(), $$new{'Paper'}{$paper_id} );
		my @data = sql::execute( $openprint::log,$openprint::dbh, q{SELECT project_id, quantity, units FROM Paper_Allocations WHERE skid_id=? AND paper_id=?}, $$self{'id'}, $paper_id );
		while ( @data ) {
			$Paper->allocate( $new->id(), splice @data, 0, 3 );
		} # en d while
	} # end foreach paper
	return $new;
} # end sub copy

sub load {
	my ($self, $data ) = @_;

	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( q{SELECT * FROM Skids WHERE id=?}, {}, $$self{'id'} );
	} # end if
	@$self{keys %$data} = @$data{keys %$data};

	%{$$self{'Paper'}} = ();
	if ( $$self{'id'} ) {
		my @data = sql::execute( undef, undef, q{SELECT paper_id, quantity, units FROM Skid_Contents WHERE skid_id=?}, $$self{'id'} );
		while ( my ( $paper_id, $qty, $units ) = splice @data, 0, 3 ) {
			$$self{'Paper'}{$paper_id} += $qty;
		} # end while
	} # end if
} # end sub load

sub save {
	my $self = shift;
$$self{'log'}->warn("Saving skid");
	$$self{'created_by_id'} = $openprint::session{'user_id'} if ! $$self{'created_by_id'};
	my $ac = sql::start_transaction( $$self{'dbh'} );
	my @sql = ( 
		'location_id',	$$self{'location_id'} ? $$self{'location_id'} : undef,
		'created_by_id',$$self{'created_by_id'},	
		'updated_on',	'NOW()',
		'updated_by',	$openprint::session{'user_id'},
		);
		
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('Skid_id_seq')} );
		sql::insert( undef, undef, 'Skids', @sql, 'id', $$self{'id'} );
	} else {
		sql::update( undef, undef, 'Skids', "id=$$self{'id'}", @sql );
	} # end if

	sql::execute( undef, undef, q{DELETE FROM Skid_Contents WHERE skid_id=?}, $$self{'id'} );
	foreach my $paper_id ( keys %{$$self{'Paper'}} ) {
        my $Paper = new openprint::Paper( $paper_id );
		sql::insert( undef, undef, 'skid_Contents', 'skid_id', $$self{'id'}, 'paper_id', $paper_id, 'quantity', int($$self{'Paper'}{$paper_id}), 'units', $Paper->type() eq 'Roll' ? 'lbs' : 'sheets' );
	} # end foreach paper_id
	$self->load();
	sql::end_transaction( $$self{'dbh'}, $ac );

} # end sub save

sub delete {
	my $self = shift;

	my $ac = sql::start_transaction( $openprint::dbh );
	sql::execute( undef, undef, q{DELETE FROM paper_allocations WHERE skid_id=?}, $$self{'id'} );
	sql::execute( undef, undef, q{DELETE FROM paper_inventory WHERE skid_id=?}, $$self{'id'} );
	sql::execute( undef, undef, q{DELETE FROM skid_contents WHERE skid_id=?}, $$self{'id'} );
	sql::execute( undef, undef, q{DELETE FROM skids WHERE id=?}, $$self{'id'} );
	sql::end_transaction( $openprint::dbh, $ac );
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

sub created_on {
	my $self = shift;
	return $$self{'created_on'};
} # end sub created_on
sub created_by_id {
	my $self = shift;
	return $$self{'created_by_id'};
} # end sub created_by_id

sub allocation {
	my ( $self, %options ) = @_;
	if ( $options{'Paper'} ) {
		my ( $allocated ) = sql::execute( undef, undef, q{SELECT SUM(quantity) FROM Paper_Allocations WHERE skid_id=? AND paper_id=?}, $$self{'id'}, $options{'Paper'}->{id} );
		return $allocated;
	} # end if
} # end sub allocatiosn
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


1;
__END__
