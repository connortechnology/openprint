package openprint::RFIDScannerHistory;
@ISA = qw(openprint::Object);
require openprint::Object;
use MIME::QuotedPrint;

use strict;
use openprint ();
use vars qw(%variable $log $dbh %config %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require sql;
require ssi;
require misc;

my $debug = 1;

%fields = (
	'id'				=>	'id',
	'rfidtag_id'		=>	'rfidtag_id',
	'scanner_id'		=>	'scanner_id',
	'location_id'		=>	'location_id',
	'updated_on'		=>	'updated_on',
);

%transforms = (
);

%defaults = (
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my @values;
	my $sql = 'SELECT * FROM RFIDScannerHistory WHERE 1>0';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( exists $params{'rfidtag_id'} ) {
		if ( ref $params{'rfidtag_id'} eq 'ARRAY' ) {
			$sql .= ' AND rfidtag_id IN ('. join(',', map {'?'} @{$params{'rfidtag_id'}} ) . ')';
			push @values, @{$params{'rfidtag_id'}};
		} else {
			$sql .= ' AND rfidtag_id=?';
			push @values, $params{'rfidtag_id'};
		} # end if
	} # end if
	if ( exists $params{'scanner_id'} ) {
		if ( ref $params{'scanner_id'} eq 'ARRAY' ) {
			$sql .= ' AND scanner_id IN ('. join(',', map {'?'} @{$params{'scanner_id'}} ) . ')';
			push @values, @{$params{'scanner_id'}};
		} else {
			$sql .= ' AND scanner_id=?';
			push @values, $params{'scanner_id'};
		} # end if
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
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " LIMIT $params{'limit'}" if $params{'limit'};

	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug("Error loading RFIDScannerHistory SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$openprint::log->debug('No RFIDScannerHistory loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$openprint::log->debug("Debug loaded RFIDScannerHistory ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::RFIDScannerHistory( $_->{id}, $_ ) } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( q{SELECT * FROM RFIDScannerHistory WHERE id=?}, {}, $$self{'id'} );
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
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('RFIDScannerHistory_id_seq')} );

		if ( my $error = sql::insert( undef, undef, 'RFIDScannerHistory', [map { $_, $$self{$_} } keys %fields ] ) ) {
			$$self{'id'} = undef;
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if

    } else {
		if ( my $error = sql::update( undef, undef, 'RFIDScannerHistory', ['id=?', $$self{id}], [map { $_, $$self{$_} } keys %fields ] ) ) {
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
    sql::execute( undef, undef, q{DELETE FROM RFIDScannerHistory WHERE id=?}, $$self{'id'} );
    sql::end_transaction( undef, $ac );
} # end sub delete

sub Location {
	my ( $self ) = @_;
	return new openprint::Location( $$self{'location_id'} );
} # end sub Location

sub Scanner {
	my ( $self ) = @_;
	return new openprint::RFIDScanner( $$self{'scanner_id'} );
} # end sub Scanner
	

1;
__END__
