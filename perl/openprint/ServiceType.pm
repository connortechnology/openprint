package openprint::ServiceType;
@ISA = qw(openprint::Object);
require openprint::Object;
require openprint::ServiceType_Category;

use strict;
use vars qw( $log $dbh $table $serial %fields %transforms %defaults );

*log = \$openprint::log;
*dbh = \$openprint::dbh;
$table = 'Service_Types';
$serial = 'ServiceTypeIndex';

%fields = (
	'id'				=>	'id',
	'name'				=> 'name',
	'description'		=> 'description',
	'url'				=> 'strdetailedurl',
	'type'				=> 'type',
	'category_id'		=> 'category_id',
	'sorting'			=> 'sorting',
	'create_visible'	=> 'create_visible',
	'view_visible'		=> 'view_visible',
	'category'			=>	undef,
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

sub find_one {
    my %params = @_;
    $params{'limit'} = 1;
    my @Results = find(%params);
    return $Results[0] if @Results;
} # end sub find_one

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
		$sql .= ' AND category_id=(SELECT id FROM ServiceType_Categories WHERE name=?)';
		push @values, $params{'category'};
	} # end if
	if ( $params{'category_id'} ) {
		$sql .= ' AND category_id=?';
		push @values, $params{'category_id'};
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

sub category {
	my ( $self ) = @_;
	if ( @_ == 2 ) {
		my $ServiceType_Category = openprint::ServiceType_Category::find_one('name'=>$_[1]);
		if ( $ServiceType_Category ) {
			$$self{'category_id'} = $ServiceType_Category->id();
		} else {
			$ServiceType_Category = new openprint::ServiceType_Category();
			$ServiceType_Category->save({'name'=>$_[1]});
		} # end if
		$$self{'category_id'} = $ServiceType_Category->id();
	} # end if
	return new openprint::ServiceType_Category( $$self{'category_id'} )->name();
} # end sub category

1;
__END__
