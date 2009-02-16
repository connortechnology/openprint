package openprint::ServiceType;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use vars qw( $log $dbh $table $serial %fields %transforms %defaults );

*log = \$openprint::log;
*dbh = \$openprint::dbh;
$table = 'Service_Types';
$serial = 'ServiceTypeIndex';

%fields = (
	'name'				=> 'name',
	'description'		=> 'description',
	'url'				=> 'strdetailedurl',
	'type'				=> 'type',
	'category'			=> 'category',
	'sorting'			=> 'sorting',
	'create_visible'	=> 'create_visible',
	'view_visible'		=> 'view_visible',
);
%transforms = (
);
%defaults = (
	'sorting'	=>	undef,
);

my $debug = 0;

my %cache;

sub init_cache {
	%cache = map { $_->name(), $_->id() } find();
} # end sub init_cache

sub find {
	my %params = @_;
	my @values;
	my $sql = q{SELECT * FROM Service_Types WHERE 1>0};

	if ( exists $params{'name'} ) {
		if ( ref $params{'name'} eq 'ARRAY' ) {
            $sql .= q{ AND name IN (}.join(',', map {'?'} @{$params{'name'}} ).')';
            push @values, @{$params{'name'}};
		} else {
			# cache optimisation, if we are looking up just by name, then we can do a quick idnex lookup
			if ( ( keys %params ) == 1 ) {
				if ( %cache ) {
					if ( exists $cache{$params{'name'}} ) {
						return ( new openprint::ServiceType( $cache{$params{'name'}} ) );
					} else {
						return;
					} # end if
				} # end if
			} # end if
			$sql .= ' AND name=?';
			push @values, $params{'name'};
		} # end if
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
	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$log->error("Error loading ServiceTypes: ($sql) (@values)");
		return;
	} elsif ( $debug ) {
		$log->debug("Loading ServiceTypes: ($sql) (@values) (".@$data.')');
	} # end if
	return map { new openprint::ServiceType( $_->{id}, $_ ); } @$data;
} # end sub find


sub next {
	my $self = shift;
	($_) = sql::execute( $log, $dbh, q{SELECT id FROM Service_Types WHERE name = (SELECT MIN(name) FROM Service_Types WHERE name>?)}, $$self{'name'} );
	if ( ! $_ ) {
		( $_ ) = sql::execute( $log, $dbh, q{SELECT id FROM Service_Types WHERE name = (SELECT MAX(name) FROM Service_Types WHERE name<?)}, $$self{'name'} );
	} # end if
	return $_;
} # end sub next
sub Next {
	my $self = shift;
	return new openprint::ServiceType( $self->next() );
}
sub prev {
	my $self = shift;
	($_) = sql::execute( $log, $dbh, q{SELECT id FROM Service_Types WHERE name = (SELECT MAX(name) FROM Service_Types WHERE name<?)}, $$self{'name'} );
	if ( ! $_ ) {
		( $_ ) = sql::execute( $log, $dbh, q{SELECT id FROM Service_Types WHERE name = (SELECT MIN(name) FROM Service_Types WHERE name>?)}, $$self{'name'} );
	} # end if
	return $_;
} # end sub prev

sub Prev {
	my $self = shift;
	return new openprint::ServiceType( $self->prev() );
}

sub delete {
	my $self = shift;

	my $ac = sql::start_transaction( $dbh );
	sql::execute( $log, $dbh, q{DELETE FROM tbl_service_defaults WHERE lngServiceTypeIndex=?}, $$self{'id'} );
	sql::execute( $log, $dbh, q{DELETE FROM Service_Types WHERE id=?}, $$self{'id'} );
	sql::end_transaction( $dbh, $ac );
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
