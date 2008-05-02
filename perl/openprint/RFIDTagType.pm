package openprint::RFIDTagType;
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
	'id'		=>	'id',
	'name'		=>	'name',
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
	my $sql = 'SELECT * FROM RFIDTagTypes WHERE 1>0';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( $params{'name'} ) {
		$sql .= ' AND name=?';
		push @values, $params{'name'};
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug("Error loading RFIDTag Types SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$openprint::log->debug('No RFIDTag Types loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$openprint::log->debug("Debug loaded RFIDTag Types ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::RFIDTagType( $_->{id}, $_ ) } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( q{SELECT * FROM RFIDTagTypes WHERE id=?}, {}, $$self{'id'} );
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
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('rfidtagtypes_id_seq')} );

		if ( my $error = sql::insert( undef, undef, 'RFIDTagTypes', [map { $_, $$self{$_} } keys %fields ] ) ) {
			$$self{'id'} = undef;
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if

    } else {
		if ( my $error = sql::update( undef, undef, 'RFIDTagTypes', ['id=?', $$self{id}], [map { $_, $$self{$_} } keys %fields ] ) ) {
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
    sql::execute( undef, undef, q{DELETE FROM RFIDTagTypes WHERE id=?}, $$self{'id'} );
    sql::end_transaction( undef, $ac );
} # end sub delete

1;
__END__
