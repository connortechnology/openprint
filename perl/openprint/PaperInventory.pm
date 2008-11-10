package openprint::PaperInventory;
@ISA = qw(openprint::Object);
require openprint::Object;
use MIME::QuotedPrint;

use strict;
use openprint ();
use vars qw(%variable %fields %defaults);
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

%defaults = (
	'updated_on'	=>	'NOW()',
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
	if ( exists $params{'skid_id'} ) {
		$sql .= ' AND skid_id=?';
		push @values, $params{'skid_id'};
	} # end if
	if ( exists $params{'comment_like'} ) {
		$sql .= ' AND comment LIKE ?';
		push @values, $params{'comment_like'};
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
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug("Error loading paper inventory SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$openprint::log->debug('No paper inventory loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$openprint::log->debug("Debug loaded paper inventory ($sql) (@values) records:" . @$data );
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
        if ( my $error = sql::update( undef, undef, 'Paper_Inventory', ['id=?',$$self{'id'}], [ map { $_, $$self{$_} } keys %fields ] ) ) {
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
