package openprint::PaperInventory;
@ISA = qw(openprint::Object);
require openprint::Object;
use MIME::QuotedPrint;

use strict;
use openprint ();
use vars qw(%variable %fields);
*variable = \%openprint::variable;


require sql;
require ssi;
require misc;
require configuration;
require openprint::Skid;
require openprint::PaperPrice;
require openprint::logs;
require openprint::Manufacturer;

my $debug = 1;

%fields = (
	'id'			=>	'id',
	'paper_id'		=>	'paper_id',
	'user_id'		=>	'user_id',
	'poindex'		=>	'poindex',
	'instock'		=>	'instock',
	'updated_on'	=>	'updated_on',
	'delta'			=>	'delta',
	'comment'		=>	'comment',
	'skid_id'		=>	'skid_id',
	'units'			=>	'units',
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my @values;
	my $sql = 'SELECT * FROM Paper_Inventory WHERE 1>0';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( $params{'owner_id'} ) {
		$sql .= ' AND owner_id=?';
		push @values, $params{'owner_id'};
	} # end if
	if ( $params{'manufacturer_id'} ) {
		$sql .= ' AND manufacturer_id=?';
		push @values, $params{'manufacturer_id'};
	} # end if
	if ( $params{'manufacturer'} ) {
		$sql .= ' AND manufacturer_id=(SELECT id FROM Manufacturers WHERE longname=?)';
		push @values, $params{'manufacturer'};
	} # end if
	if ( $params{'name_id'} ) {
		$sql .= ' AND name_id=?';
		push @values, $params{'name_id'};
	} # end if
	if ( $params{'name'} ) {
		$sql .= ' AND name_id=(SELECT id FROM PaperNames WHERE longname=?)';
		push @values, $params{'name'};
	} # end if
	if ( $params{'finish_id'} ) {
		$sql .= ' AND finish_id=?';
		push @values, $params{'finish_id'};
	} # end if
	if ( $params{'finish'} ) {
		$sql .= ' AND finish_id=(SELECT id FROM PaperFinishes WHERE longname=?)';
		push @values, $params{'finish'};
	} # end if
	if ( $params{'colour_id'} ) {
		$sql .= ' AND colour_id=?';
		push @values, $params{'colour_id'};
	} # end if
	if ( $params{'colour'} ) {
		$sql .= ' AND colour_id=(SELECT id FROM PaperColours WHERE longname=?)';
		push @values, $params{'colour'};
	} # end if
	if ( $params{'weight_id'} ) {
		$sql .= ' AND weight_id=?';
		push @values, $params{'weight_id'};
	} # end if
	if ( $params{'weight'} ) {
		$sql .= ' AND weight_id=(SELECT id FROM PaperWeights WHERE longname=?)';
		push @values, $params{'weight'};
	} # end if
	if ( $params{'quality_id'} ) {
		$sql .= ' AND quality_id=?';
		push @values, $params{'quality_id'};
	} # end if
	if ( $params{'quality'} ) {
		$sql .= ' AND quality_id=(SELECT id FROM PaperQualities WHERE longname=?)';
		push @values, $params{'quality'};
	} # end if
	if ( $params{'updated_on_start'} and $params{'updated_on_end'} ) {
		$sql .= ' AND ( updated_on BETWEEN ? AND ? )';
		push @values, @params{'updated_on_start','updated_on_end'}
	} elsif ( $params{'updated_on_start'} ) {
		$sql .= ' AND ( updated_on >= ?)';
		push @values, $params{'updated_on_start'};
	} elsif ( $params{'updated_on_end'} ) {
		$sql .= ' AND ( updated_on <= ?)';
		push @values, $params{'updated_on_end'};
	} # end if
	if ( $params{'size'} ) {
		$sql .= ' AND width=? AND height=?';
		push @values, split 'x', $params{'size'};
	} # end if
	if ( $params{'width'} ) {
		$params{'width'} =~ s/[^\d\.]//g;
		$sql .= ' AND width=?';
		push @values, 1*$params{'width'};
	} # end if
	if ( $params{'width_start'} ) {
		$params{'width_start'} =~ s/[^\d\.]//g;
		$sql .= ' AND width>=?';
		push @values, 1*$params{'width_start'};
	} # end if
	if ( $params{'height'} ) {
		$params{'height'} =~ s/[^\d\.]//g;
		$sql .= ' AND height=?';
		push @values, 1*$params{'height'};
	} # end if
	if ( $params{'height_start'} ) {
		$params{'height_start'} =~ s/[^\d\.]//g;
		$sql .= ' AND height>=?';
		push @values, 1*$params{'height_start'};
	} # end if
	if ( $params{'allocated_to_docket'} ) {
		$sql .= ' AND id IN (SELECT paper_id FROM paper_allocations WHERE project_id = (SELECT Index FROM tbl_Projects WHERE lngDocketNumber=?))';
		push @values, $params{'allocated_to_docket'};
	} # end if
	if ( $params{'project_type_name'} ) {
		$sql .= ' AND id IN (SELECT lngPaperIndex FROM Paper_Recommendations WHERE lngProjectTypeIndex=(SELECT lngIndex FROM Project_Types WHERE strID = ?))';
		push @values, $params{'project_type_name'};
	} # end if
	if ( $params{'project_type_id'} ) {
		$sql .= ' AND id IN (SELECT lngPaperIndex FROM Paper_Recommendations WHERE lngProjectTypeIndex=?)';
		push @values, $params{'project_type_id'};
	} # end if
	if ( $params{'fsc_code'} ) {
		$sql .= ' AND fsc_code=?';
		push @values, $params{'fsc_code'};
	} # end if
	if ( $params{'type'} ) {
		if ( ref $params{'type'} eq 'ARRAY' ) {
			$sql .= ' AND type IN (' . join(',', map { '?' } @{$params{'type'}} ) . ')';
			push @values, @{$params{'type'}};
		} else {
			$sql .= ' AND type=?';
			push @values, $params{'type'};
		} # end if
	} # end if
	if ( $params{'supplied'} ) {
		if ( ref $params{'supplied'} eq 'ARRAY' ) {
			my @options;
			foreach my $option ( @{$params{'supplied'}} ) {
				if ( (! defined $option ) or ($option eq '' ) ) {
					push @options, 'supplied IS NULL';
				} else {
					push @options, 'supplied=?';
					push @values, $option;
				} # end if
			} # end foreach
			$sql .= ' AND ( ' . join(' OR ', @options ) . ' )';
		} else {
			if ( (! defined $params{'supplied'} ) or ($params{'supplied'} eq '' ) ) {
				$sql .= ' AND supplied IS NULL';
			} else {
				$sql .= ' AND supplied=?';
				push @values, $params{'supplied'} eq 'Y' ? 1 : 0;
			} # end if
		} # end if
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug("Error loading papers SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$openprint::log->debug('No papers loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$openprint::log->debug("Debug loaded papers ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::PaperInventory( $_->{id}, $_ ) } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( q{SELECT * FROM Paper_Inventory WHERE id=?}, {}, $$self{'id'} );
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
} # end sub load

sub save {
	my ( $self, $hash ) = @_;

	if ( $hash ) {
		$self->set( $hash );
	} # end if
	
	my $ac = sql::start_transaction( $openprint::dbh );
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('paperinventory_id_seq')} );

		if ( my $error = sql::insert( undef, undef, 'Paper_Inventory', [map { $_, $$self{$_} } keys %fields ] ) ) {
			$$self{'id'} = undef;
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if

    } else {
        if ( my $error = sql::update( undef, undef, 'Papers', ['id=?',$$self{'id'}], [ map { $_, $$self{$_} } keys %fields ] ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
    } # end if

	sql::end_transaction( $openprint::dbh, $ac );
	$self->load();
	return;
} # end sub save

sub delete {
    my $self = shift;
    my $ac = sql::start_transaction( );
    sql::execute( undef, undef, q{DELETE FROM Paper_Inventory WHERE id=?}, $$self{'id'} );
    sql::end_transaction( undef, $ac );
} # end sub delete

sub add_inventory {
    my ( $self, $skid_id, $quantity, $units, $description ) = @_;
    $quantity =~ s/[^\-\d]//g;
    $quantity = int $quantity;

	my $Skid = new openprint::Skid( $skid_id );
	#Skid{Paper}{paper_id} has already been adjusted

	$units = $self->type() eq 'Roll' ? 'lbs' : 'sheets' if ! $units;
    sql::insert( undef, undef, 'Paper_Inventory',
        'paper_id', $$self{'id'},
        'user_id',  $openprint::session{'user_id'},
        'POIndex',  undef,
        'InStock',  ($skid_id? $$Skid{Paper}{$$self{id}} : $self->in_stock() + $quantity),
        'UpdateTime',   'NOW()',
        'delta',    $quantity,
        'Comment',  $description,
        'skid_id',  $skid_id,
		'units',	$units,
        );
	delete $$self{allocated};
	delete $$self{in_stock};

} # end sub add_inventory

sub allocate {
    my ( $self, $skid_id, $project_id, $quantity, $units ) = @_;
	$units = $self->type() eq 'Roll' ? 'lbs' : 'sheets' if ! $units;

    my $ac = sql::start_transaction();
    sql::insert( undef, undef, 'Paper_Allocations',
        'paper_id',     $$self{'id'},
        'skid_id',      $skid_id,
        'quantity',     $quantity,
		'units',		$units,
        'project_id',   $project_id,
        'operator_id',  $openprint::session{'user_id'},
        );
    openprint::project::insert_into_log( undef, undef, @openprint::session{'company_id','user_id'}, $project_id, qq`Allocated $quantity $units of <a href="/employee/inventory/paper_details.html?paper_id=$$self{'id'}">` . $self->to_string() . qq{</a> on skid <a href="/employee/inventory/skids.html?skid_id=$skid_id">$skid_id</a>} );
    sql::end_transaction( undef, $ac );

} # end sub allocate
sub back_ordered {
    my $self = shift;
	return 0 if ! $$self{'id'};

    ( $_ ) = sql::execute( undef, undef, q{SELECT Quantity FROM Paper_Purchase_Order_Contents WHERE paper_id=? AND PaperPurchaseOrder_id IN ( SELECT id FROM Paper_Purchase_Orders WHERE Status='Sent')}, $$self{'id'} );
    return int $_;
} # end sub back_ordered
sub allocated {
    my ( $self, $project_id ) = @_;
	return 0 if ! $$self{'id'};
	if ( $project_id ) {
    ( $_ ) = sql::execute( undef, undef, q{SELECT SUM(Quantity) FROM Paper_Allocations WHERE paper_id=? and project_id=?}, $$self{'id'}, $project_id );
		return $_;
	} # end if
	if ( ! exists $$self{allocated} ) {
    @$self{allocated} = sql::execute( undef, undef, q{SELECT SUM(Quantity) FROM Paper_Allocations WHERE paper_id=?}, $$self{'id'} );
	} # end if
    return $$self{allocated};
} # end sub allocated
sub in_stock {
    my $self = shift;
	return 0 if ! $$self{'id'};

	if ( ! exists $$self{in_stock} ) {
    @$self{in_stock} = sql::execute( undef, undef, q{SELECT SUM(quantity) FROM Skid_Contents WHERE paper_id=?}, $$self{'id'} );
	} # end if
    return int $$self{in_stock};
} # end sub in_stock

sub Paper {
	return new openprint::Paper( $_[0]{'paper_id'} );
} # end sub Paper
sub Skid {
	return new openprint::Skid( $_[0]{'skid_id'} );
} # end sub Skid
sub User {
	return new openprint::User( $_[0]{'user_id'} );
} # end sub User

1;
__END__
