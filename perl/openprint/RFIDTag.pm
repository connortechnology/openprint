package openprint::RFIDTag;
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

require openprint::RFIDTagType;
require openprint::Location;

my $debug = 1;

%fields = (
	'id'			=>	'id',
	'location_id'	=>	'location_id',
	'type_id'		=>	'type_id',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
);

%transforms = (
);

%defaults = (
	'created_on'	=>	'NOW()',
	'updated_on'	=>	'NOW()',
	'location_id'	=>	undef,
	'type_id'	=>	undef,
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my @values;
	my $sql = 'SELECT * FROM RFIDTags WHERE 1>0';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( $params{'type_id'} ) {
		$sql .= ' AND type_id=?';
		push @values, $params{'type_id'};
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug("Error loading RFIDTag SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No RFIDTag loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded RFIDTag ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::RFIDTag( $_->{id}, $_ ) } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $dbh->selectrow_hashref( q{SELECT * FROM RFIDTags WHERE id=?}, {}, $$self{'id'} );
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
	if ( ! $$data{'id'} ) {
<<<<<<< HEAD:perl/openprint/RFIDTag.pm
$log->debug("Not found");
=======
>>>>>>> 70e5444db140c0825b196f6444bdfa1ece83291d:perl/openprint/RFIDTag.pm
		delete $openprint::Object::cache{'openprint::RFIDTag'}{$$self{'id'}};
		delete $$self{'id'};
<<<<<<< HEAD:perl/openprint/RFIDTag.pm
	} else {
		$log->debug("Loaded $$self{'id'} ");
=======
>>>>>>> 70e5444db140c0825b196f6444bdfa1ece83291d:perl/openprint/RFIDTag.pm
	} # end if
#delete $$self{'id'};
} # end sub load

sub save {
	my ( $self, $hash ) = @_;

	if ( $hash ) {
		$self->set( $hash );
	} # end if

	if ( ! $$self{'id'} ) {
		return 'RFID Tag must have an id';
	} # end if

	if ( ! $$self{'type_id'} ) {
		my $type;
		if ( $$hash{'type'} ) {
			$type = $$hash{'type'};
		} elsif ( $$self{'type'} ) {
			$type = $$self{'type'};
		} # end if
		if ( $type ) {
			my ( $type_id ) = sql::execute( undef, undef, 'SELECT id FROM RFIDTagTypes WHERE lower(name)=lower(?)', $type );
			if ( ! $type_id ) {
				my $Type = new openprint::RFIDTagType();
				$Type->save( {'name'=>$type } );
				$$self{'type_id'} = $Type->id();
			} else {
				$$self{'type_id'} = $type_id;
			} # end if
		} # end if
	} # end if

	delete $$self{'type'};
	
	my $ac = sql::start_transaction( $dbh );

	if ( ! sql::execute( undef, undef, 'SELECT * FROM RFIDTags WHERE id=?', $$self{'id'} ) ) {
		if ( my $error = sql::insert( undef, undef, 'RFIDTags', map { $_, $$self{$_} } keys %fields ) ) {
			$$self{'id'} = undef;
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if
    } else {
		if ( my $error = sql::update( undef, undef, 'RFIDTags', ['id=?', $$self{id}], map { $_, $$self{$_} } keys %fields ) ) {
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
    sql::execute( undef, undef, q{DELETE FROM RFIDTags WHERE id=?}, $$self{'id'} );
    sql::end_transaction( undef, $ac );
	delete $openprint::Object::cache{'openprint::RFIDTag'}{$$self{'id'}}
} # end sub delete

sub Type {
	return new openprint::RFIDTagType( $_[0]->type_id() );
} # end sub Type

sub type {
	my ( $self ) = @_;
	if ( $$self{'type_id'} and ! $$self{'type'} ) {
		$$self{'type'} = $self->Type()->name();
	} # end if
	return $$self{'type'};
} # end sub type

sub Location {
	return new openprint::Location( $_[0]->location_id() );
} # end sub Location

1;
__END__
