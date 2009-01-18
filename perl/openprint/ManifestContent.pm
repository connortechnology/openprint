package openprint::ManifestContent;
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

my $debug = 1;

%fields = (
	'id'			=>	'id',
	'manifest_id'	=>	'manifest_id',
	'skid_id'		=>	'skid_id',
	'quantity'		=>	'quantity',
	'docket'		=>	'docket',
);

%transforms = (
	'quantity'	=> [ 's/\D//g' ],
	'docket'	=> [ 's/\D//g' ],
	'cost'		=> [ 's/[^\d\.]//g' ],
);

%defaults = (
	'quantity'	=> 0,
	'cost'		=> undef,
	'docket'	=> undef,
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my @values;
	my $sql = 'SELECT * FROM ManifestContents WHERE 1>0';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( $params{'manifest_id'} ) {
		$sql .= ' AND manifest_id=?';
		push @values, $params{'manifest_id'};
	} # end if
	if ( $params{'skid_id'} ) {
		$sql .= ' AND skid_id=?';
		push @values, $params{'skid_id'};
	} # end if
	if ( $params{'id_like'} ) {
		$sql .= " AND id LIKE '%$params{id_like}%'";
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug("Error loading ManifestContent SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No ManifestContent loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded ManifestContent ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::ManifestContent( $_->{id}, $_ ) } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $dbh->selectrow_hashref( q{SELECT * FROM ManifestContents WHERE id=?}, {}, $$self{'id'} );
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
	if ( ! $$data{'id'} ) {
		delete $openprint::Object::cache{'openprint::ManifestContent'}{$$self{'id'}};
		delete $$self{'id'};
	} # end if
#delete $$self{'id'};
} # end sub load

sub save {
	my ( $self, $hash ) = @_;

	if ( $hash ) {
		$self->set( $hash );
	} # end if

	my $ac = sql::start_transaction( $dbh );

	if ( ! $$self{id} ) {
		@$self{id} = sql::execute( $openprint::log, $openprint::dbh, q{SELECT nextval('ManifestContents_id_seq')} );
		if ( my $error = sql::insert( undef, undef, 'ManifestContents', map { $_, $$self{$_} } keys %fields ) ) {
			$$self{'id'} = undef;
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if
    } else {
		if ( my $error = sql::update( undef, undef, 'ManifestContents', ['id=?', $$self{id}], map { $_, $$self{$_} } keys %fields ) ) {
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
    sql::execute( undef, undef, q{DELETE FROM ManifestContents WHERE id=?}, $$self{'id'} );
    sql::end_transaction( undef, $ac );
	delete $openprint::Object::cache{'openprint::ManifestContent'}{$$self{'id'}};
	return '';
} # end sub delete

sub Skid {
	return new openprint::Skid( $_[0]{skid_id} );
} # end sub Skid


1;
__END__
