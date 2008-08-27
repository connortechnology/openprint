package openprint::Manifest;
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

require openprint::ManifestContent;


my $debug = 1;

%fields = (
	'id'			=>	'id',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
	'received_on'	=>	'received_on',
);

%transforms = (
	'updated_on'	=> [ 's/.*//g' ],
);

%defaults = (
	'created_on'	=>	'NOW()',
	'updated_on'	=>	'NOW()',
	'received_on'	=>	'NOW()',
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my @values;
	my $sql = 'SELECT * FROM Manifests WHERE 1>0';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( $params{'id_like'} ) {
		$sql .= " AND id LIKE '%$params{id_like}%'";
	} # end if

	if ( $params{'received_on_start'} and $params{'received_on_end'} ) {
		$sql .= ' AND ( received_on BETWEEN ? AND ? )';
		push @values, @params{'received_on_start','received_on_end'};
	} elsif ( $params{'received_on_start'} ) {
		$sql .= ' AND received_on >= ?';
		push @values, $params{'received_on_start'};
	} elsif ( $params{'received_on_end'} ) {
		$sql .= ' AND received_on <= ?';
		push @values, $params{'received_on_end'};
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
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug("Error loading Manifest SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No Manifest loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded Manifest ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::Manifest( $_->{id}, $_ ) } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $dbh->selectrow_hashref( q{SELECT * FROM Manifests WHERE id=?}, {}, $$self{'id'} );
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
	if ( ! $$data{'id'} ) {
		delete $openprint::Object::cache{'openprint::Manifest'}{$$self{'id'}};
		delete $$self{'id'};
	} # end if
#delete $$self{'id'};
} # end sub load

sub save {
	my ( $self, $hash ) = @_;

	$self->set( $hash );

	if ( ! $$self{'id'} ) {
		return 'Manifest must have an id';
	} # end if
	
	my $ac = sql::start_transaction( $dbh );

$openprint::log->debug("Updated: $$self{updated_on}");
	if ( ! sql::execute( undef, undef, 'SELECT * FROM Manifests WHERE id=?', $$self{'id'} ) ) {
		if ( my $error = sql::insert( undef, undef, 'Manifests', map { $_, $$self{$_} } keys %fields ) ) {
			$$self{'id'} = undef;
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if
    } else {
		if ( my $error = sql::update( undef, undef, 'Manifests', ['id=?', $$self{id}], map { $_, $$self{$_} } keys %fields ) ) {
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
    sql::execute( undef, undef, q{DELETE FROM ManifestContents WHERE manifest_id=?}, $$self{'id'} );
    sql::execute( undef, undef, q{DELETE FROM Manifests WHERE id=?}, $$self{'id'} );
    sql::end_transaction( undef, $ac );
	delete $openprint::Object::cache{'openprint::Manifest'}{$$self{'id'}};
	return '';
} # end sub delete

sub Contents {
	return openprint::ManifestContent::find('manifest_id'=>$_[0]{id});
} # end sub Contents

1;
__END__
