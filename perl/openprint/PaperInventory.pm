package openprint::PaperInventory;
@ISA = qw(openprint::Object);
require openprint::Object;
use MIME::QuotedPrint;

use strict;
use openprint ();
use vars qw($log $dbh %variable %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
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
	'docket'		=>	'docket',
);
%transforms = (
	'paper_id'	=>	[ 's/\D//g' ],
	'skid_id'	=>	[ 's/\D//g' ],
	'user_id'	=>	[ 's/\D//g' ],
	'instock'	=>	[ 's/\D//g' ],
	'docket'	=>	[ 's/\D//g' ],
	'delta'		=>	[ 's/[^\d\-]//g' ],
);
%defaults = (
	'updated_on'	=>	'NOW()',
	'docket'		=>	undef,
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
	if ( exists $params{'paper_id'} ) {
		if ( defined $params{'paper_id'} ) {
		$sql .= ' AND paper_id=?';
		push @values, $params{'paper_id'};
		} else {
		$sql .= ' AND paper_id IS NULL';
		} # end if
	} # end if
	if ( exists $params{'docket'} ) {
		if ( defined $params{'docket'} ) {
			$sql .= ' AND docket=?';
			push @values, $params{'docket'};
		} else {
			$sql .= ' AND docket IS NULL';
		} # end if
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
	$sql .= " LIMIT $params{'limit'}" if $params{'limit'};

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

sub docket {
	my $self = shift;
	if ( @_ ) {
		$$self{'docket'} = shift;
		$$self{'docket'} =~ s/\D//g;
	} # end if
	if ( ! $$self{'docket'} ) {
		if ( $$self{'comment'} =~ /docket (\d+)/ ) {
			$$self{'docket'} = $1;
		} # end if
	} # end if
	return $$self{'docket'};
} # end sub docket

sub Project {
	my $self = $_[0];
	return new openprint::Project() if ! $$self{'docket'};
	my @Projects = openprint::Project::find('docket'=>$$self{'docket'});
	if ( @Projects ) {
		return $Projects[0];
	} # end if
	return new openprint::Project();
} # end sub Project

sub comment_html {
	my ( $self ) = @_;

	if ( $$self{'comment'} =~ /^Checked out for docket (\d+) by (.*)$/ ) {
		return qq`Checked out for docket <a href="/employee/project/view.html?docket=$1">$1</a> by $2`;
	} elsif ( $$self{'comment'} =~ /^Inventory adjusted from manifest (.+)\.$/ ) { 
		return qq`Inventory adjusted from manifest <a href="/employee/inventory/manifests.html?manifest_name=$1">$1</a>`;
	} # end if
	return $$self{'comment'};
} # end comment_html

sub instock {
	my $self = shift;
	if ( @_ ) {
		$$self{'instock'} = shift;
	} # end if
	if ( ! defined $$self{'instock'} ) {
$log->warn("Loading instock");
		@$self{'instock'} = sql::execute( undef, undef, 'SELECT SUM(delta) FROM Paper_Inventory WHERE paper_id=? AND id <= ?', @$self{'paper_id', 'id'} );
$log->warn("Loading instock $$self{instock}");
	} # end if
	return $$self{'instock'};
} # end sub instock

sub units {
	if ( ! $_[0]{'units'} ) {
		$_[0]{'units'} = $_[0]->Paper()->units();
	} 
	return $_[0]{'units'};
} # end sub units

1;
__END__
