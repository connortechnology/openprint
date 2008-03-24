package openprint::ServiceType;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;

my %fields = (
	'name'				=> 'name',
	'description'		=> 'description',
	'url'				=> 'strdetailedurl',
	'type'				=> 'type',
	'category'			=> 'category',
	'sorting'			=> 'sorting',
	'create_visible'	=> 'create_visible',
	'view_visible'		=> 'view_visible',
);

my $debug = 1;

sub find {
	my %params = @_;
	my @values;
	my $sql = q{SELECT * FROM Service_Types WHERE 1>0};
	if ( $params{'name'} ) {
		$sql .= ' AND name=?';
		push @values, $params{'name'};
	} # end if
	if ( $params{'category'} ) {
		$sql .= ' AND category=?';
		push @values, $params{'category'};
	} # end if
	if ( $params{'create_visible'} ) {
		$sql .= ' AND create_visible=?';
		push @values, $params{'create_visible'};
	} # end if
	if ( $params{'view_visible'} ) {
		$sql .= ' AND view_visible=?';
		push @values, $params{'view_visible'};
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->error("Error loading ServiceTypes: ($sql) (@values)");
		return;
	} elsif ( $debug ) {
		$openprint::log->debug("Loading ServiceTypes: ($sql) (@values) (".@$data.')');
	} # end if
	return map { new openprint::ServiceType( $_->{id}, $_ ); } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Service_Types WHERE id=?', {}, $$self{id} );
	} # end if
	@$self{keys %fields} = @$data{@fields{keys %fields}};
} # end sub load

sub save {
	my ( $self, $params ) = @_;

	my %sql;
	foreach my $k ( keys %fields ) {
		if ( exists $$params{$k} ) {
			$sql{$fields{$k}} = $$params{$k};
		} else {
			$sql{$fields{$k}} = $$self{$k};
		} # end if
	} # end foreach
	$sql{'sorting'} = undef if $sql{'sorting'} eq '';

	my $ac = sql::start_transaction( $openprint::dbh );
	if ( ! $$self{'id'} ) {
		if ( ! ( @$self{'id'} = sql::execute( $openprint::log, $openprint::dbh, q{SELECT nextval('ServiceTypeIndex')} ) ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return 'Error allocating new Service Type<br/>';
		} # end if
		$sql{'id'} = $$self{'id'};
		if ( $_ = sql::insert( $openprint::log, $openprint::dbh, 'Service_Types', \%sql ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return "Error inserting Service Type $$self{'name'} : $_<br>";
		} # end if
	} else {
		if ( $_ = sql::update( $openprint::log, $openprint::dbh, 'Service_Types', ['id=?', $$self{'id'}], \%sql ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return "Error updating Service Type $$self{'name'} : $_<br>";
		} # end if
	} # end if
	sql::end_transaction( $openprint::dbh, $ac );
	$self->load();
} # end sub save

sub next {
	my $self = shift;
	($_) = sql::execute( $openprint::log, $openprint::dbh, q{SELECT id FROM Service_Types WHERE name = (SELECT MIN(name) FROM Service_Types WHERE name>?)}, $$self{'name'} );
	if ( ! $_ ) {
		( $_ ) = sql::execute( $openprint::log, $openprint::dbh, q{SELECT id FROM Service_Types WHERE name = (SELECT MAX(name) FROM Service_Types WHERE name<?)}, $$self{'name'} );
	} # end if
	return $_;
} # end sub next
sub Next {
	my $self = shift;
	return new openprint::ServiceType( $self->next() );
}
sub prev {
	my $self = shift;
	($_) = sql::execute( $openprint::log, $openprint::dbh, q{SELECT id FROM Service_Types WHERE name = (SELECT MAX(name) FROM Service_Types WHERE name<?)}, $$self{'name'} );
	if ( ! $_ ) {
		( $_ ) = sql::execute( $openprint::log, $openprint::dbh, q{SELECT id FROM Service_Types WHERE name = (SELECT MIN(name) FROM Service_Types WHERE name>?)}, $$self{'name'} );
	} # end if
	return $_;
} # end sub prev

sub Prev {
	my $self = shift;
	return new openprint::ServiceType( $self->prev() );
}

sub delete {
	my $self = shift;

	my $ac = sql::start_transaction( $openprint::dbh );
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM tbl_service_defaults WHERE lngServiceTypeIndex=?}, $$self{'id'} );
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM Service_Types WHERE id=?}, $$self{'id'} );
	sql::end_transaction( $openprint::dbh, $ac );
} # end sub delete

# Returns a copy of the Material object.
sub copy {
	my $self = shift;
	my $new = new openprint::ServiceType();
	@$new{keys %fields} = @$self{keys %fields};
	delete $$new{id};
	$$new{'name'} = 'Copy of ' . $$new{'name'};

	return $new;
} # end sub copy
1;
__END__
