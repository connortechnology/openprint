package openprint::RFIDScanner;
@ISA = qw(openprint::Object);
require openprint::Object;

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
require openprint::Location;

my $debug = 1;

%fields = (
	'id'		=>	'id',
	'name'		=>	'name',
	'ipaddr'	=>	'ipaddr',
	'type'		=>	'type',
	'location_id'	=>	'location_id',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
	'other'			=>	'other',
);

%transforms = (
	'updated_on'	=>	['s/.*//g'],
);

%defaults = (
	'created_on'	=>	'NOW()',
	'updated_on'	=>	'NOW()',
	'location_id'	=>	undef,
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my @values;
	my $sql = 'SELECT * FROM RFIDScanners WHERE 1>0';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
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
	if ( $params{'name'} ) {
		$sql .= ' AND name=?';
		push @values, $params{'name'};
	} # end if
	if ( exists $params{'ipaddr'} ) {
		if ( ref $params{'ipaddr'} eq 'ARRAY' ) {
			$sql .= ' AND ipaddr IN ('. join(',', map {'?'} @{$params{'ipaddr'}} ) . ')';
			push @values, @{$params{'ipaddr'}};
		} else {
			$sql .= ' AND ipaddr=?';
			push @values, $params{'ipaddr'};
		} # end if
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug("Error loading RFIDScanners SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$openprint::log->debug('No RFIDScanners loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$openprint::log->debug("Debug loaded RFIDScanners ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::RFIDScanner( $_->{id}, $_ ) } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $dbh->selectrow_hashref( q{SELECT * FROM RFIDScanners WHERE id=?}, {}, $$self{'id'} );
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
} # end sub load

sub save {
	my ( $self, $hash ) = @_;

	if ( $hash ) {
		$self->set( $hash );
	} # end if

	my %sql = map { $_, $$self{$_} } keys %fields;
	$sql{'updated_on'} = 'NOW()';
	
	my $ac = sql::start_transaction( $dbh );
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('RFIDScanners_id_seq')} );
		$sql{'id'} = $$self{'id'};

		if ( my $error = sql::insert( undef, undef, 'RFIDScanners', \%sql ) ) {
			$$self{'id'} = undef;
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if

    } else {
		if ( my $error = sql::update( undef, undef, 'RFIDScanners', ['id=?', $$self{id}], \%sql ) ) {
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if
    } # end if

	sql::end_transaction( $dbh, $ac );
	$self->load();
	return;
} # end sub save

sub delete {
    my $self = shift;
    my $ac = sql::start_transaction( );
    sql::execute( undef, undef, q{DELETE FROM RFIDScanners WHERE id=?}, $$self{'id'} );
    sql::end_transaction( undef, $ac );
} # end sub delete

sub Location {
	return new openprint::Location( $_[0]{'location_id'} );
} # end sub Location

sub location_id {
    my ( $self, $new, $rfidtag_id ) = @_;
    if ( $new ) {
        if ( $new != $$self{'location_id'} ) {
            sql::insert( undef, undef, 'RFIDScannerHistory', {'location_id'=>$new, 'scanner_id'=>$$self{id}, 'rfidtag_id'=>$rfidtag_id } );
            $$self{'location_id'} = $new;
        } # end if
    } # end if
    return $$self{'location_id'};
} # end sub location_id

1;
__END__
