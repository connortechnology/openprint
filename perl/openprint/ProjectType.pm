package openprint::ProjectType;
@ISA = qw(openprint::Object);
use strict;
require openprint::Object;
require openprint::logs;
require openprint::ProjectType_Template;
require openprint::ProjectTypeCategory;
use openprint ();

use vars qw( $log $dbh $table $serial %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
$table = 'Project_Types';
$serial = 'project_types_id_seq';

%fields = (
	'id'			=>	'id',
	'name'			=>	'name',	
	'description'	=>	'description',
	'category_id'	=>	'category_id',
	'url'			=>	'url',
	'sorting'		=>	'sorting',
	'please_call'	=>	'please_call',
);
%transforms = (
	id			=>	[ 's/\D//g', '<2147483647' ],
	'name'	=>	[ 's/\s//g' ],
);
%defaults = (
	'id'			=>	undef,
	'category_id'	=>	undef,
	'sorting'		=>	undef,
	'please_call'	=>	0,
);

sub find_one {
	shift @_ if $_[0] eq 'openprint::ProjectType';
	shift @_ if ref $_[0] eq 'openprint::ProjectType';
    my @results = find( @_, 'limit', 1 );
    if ( @results > 1 ) {
        $openprint::log->error('ProjectType::find_one more than 1 result!');
    } elsif ( @results ) {
        return $results[0];
    } # end if
    return;
} # end sub find_one

sub find {
	shift @_ if $_[0] eq 'openprint::ProjectType';
	shift @_ if ref $_[0] eq 'openprint::ProjectType';
	my %params = @_;
	my @values;
	my $sql = q{SELECT * FROM Project_Types WHERE 1>0};
	if ( exists $params{'description'} ) {
		$sql .= ' AND description=?';
		push @values, $params{'description'};
	} # end if
	if ( exists $params{'name'} ) {
		if ( ref $params{'name'} eq 'ARRAY' ) {
			$sql .= q{ AND name IN (}.join(',', map {'?'} @{$params{'name'}} ).')';
			push @values, @{$params{'name'}};
		} else {
			$sql .= ' AND name=?';
			push @values, $params{'name'};
		} # end if
	} # end if
	if ( $params{'category_id'} ) {
		$sql .= ' AND category_id=?';
		push @values, $params{'category_id'};
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->error("Error loading ProjectTypes: ($sql) (@values) Reason: " . $openprint::dbh->errstr() );
		return;
	} # end if
	return map { new openprint::ProjectType( $_->{id}, $_ ); } @$data;
} # end sub find

sub save {
	my ( $self, $params ) = @_;
	if ( ( my $error = $self->SUPER::save( $params ) ) ) {
		return $error;
	} else {
		# self->equired_services is guaranteed to populate $$self{'erquired_services'}
		$self->required_services( $$params{required_services} );
		sql::execute( undef, undef, q{DELETE FROM ProjectType_RequiredServices WHERE ProjectType_id=?}, $$self{'id'} );
		# The union gets rid of duplicates
		foreach my $servicetype_id ( sets::union( @{$$self{'required_services'}} ) ) {
			sql::insert( undef, undef, 'ProjectType_RequiredServices', ['ProjectType_id', $$self{'id'}, 'ServiceType_id', $servicetype_id ] );
		} # end foreach
		# self->equired_services is guaranteed to populate $$self{'erquired_services'}
		$self->blocked_services( $$params{blocked_services} );
		sql::execute( undef, undef, q{DELETE FROM ProjectType_BlockedServices WHERE projecttype_id=?}, $$self{'id'} );
		# The union gets rid of duplicates
		foreach my $servicetype_id ( sets::union( @{$$self{'blocked_services'}} ) ) {
			sql::insert( undef, undef, 'ProjectType_BlockedServices', ['projecttype_id', $$self{'id'}, 'servicetype_id', $servicetype_id ] );
		} # end foreach
	} # end if
	return;	
} # end sub save

sub next {
	my $self = shift;
	($_) = sql::execute( undef, undef, q{SELECT Id FROM Project_Types WHERE name = (SELECT MIN(name) FROM Project_Types WHERE name>?)}, $$self{'name'} );
	if ( ! $_ ) {
		( $_ ) = sql::execute( undef, undef, q{SELECT id FROM Project_Types WHERE name = (SELECT MAX(name) FROM Project_Types WHERE name<?)}, $$self{'name'} );
	} # end if
	return new openprint::ProjectType( $_ );
} # end sub next
sub prev {
	my $self = shift;
	($_) = sql::execute( undef, undef, q{SELECT Id FROM Project_Types WHERE name = (SELECT MAX(name) FROM Project_Types WHERE name<?)}, $$self{'name'} );
	if ( ! $_ ) {
		( $_ ) = sql::execute( undef, undef, q{SELECT Id FROM Project_Types WHERE name = (SELECT MIN(name) FROM Project_Types WHERE name>?)}, $$self{'name'} );
	} # end if
	return new openprint::ProjectType( $_ );
} # end sub prev

sub required_services {
	my $self = shift;
	if ( @_ > 1 ) {
		@{$$self{'required_services'}} = @_;
	} elsif ( @_ ) {
		if ( ref $_[0] eq 'ARRAY' ) {
			$$self{'required_services'} = $_[0];
		} elsif ( $_[0] ) {
			$$self{'required_services'} = [$_[0]];
		} # end if
	} # end if
	if ( ! $$self{'required_services'} ) {
		if ( $$self{'id'} ) {
			@{$$self{'required_services'}} = sql::execute( undef, undef, q{SELECT ServiceType_id FROM ProjectType_RequiredServices WHERE ProjectType_id=?}, $$self{'id'} );
		} else {
			@{$$self{'required_services'}} = ();
		} # end if
	} # end if
	return @{$$self{'required_services'}};
} # end sub required_services

sub required_ServiceTypes {
	my @servicetype_ids = $_[0]->required_services();
	return openprint::ServiceType->find( id=> \@servicetype_ids ) if @servicetype_ids;
	return ();
} # end sub require_ServiceTypes

sub blocked_services {
	my $self = shift;
	if ( @_ > 1 ) {
		@{$$self{'blocked_services'}} = @_;
	} elsif ( @_ ) {
		if ( ref $_[0] eq 'ARRAY' ) {
			$$self{'blocked_services'} = $_[0];
		} elsif ( $_[0] ) {
			$$self{'blocked_services'} = [$_[0]];
		} # end if
	} # end if
	if ( ! $$self{'blocked_services'} ) {
		if ( $$self{'id'} ) {
			@{$$self{'blocked_services'}} = sql::execute( undef, undef, q{SELECT ServiceType_id FROM ProjectType_BlockedServices WHERE ProjectType_id=?}, $$self{'id'} );
		} else {
			@{$$self{'blocked_services'}} = ();
		} # end if
	} # end if
	return @{$$self{'blocked_services'}};
} # end sub blocked_services

sub blocked_ServiceTypes {
	return openprint::ServiceType->find( id=>[ $_[0]->blocked_services() ] );
} # end sub blocked_ServiceTypes

sub delete {
	my $self = shift;

	my $ac = sql::start_transaction( $dbh );
	sql::execute( undef, undef, q{DELETE FROM tbl_projecttype_defaults WHERE lngProjectTypeIndex=?}, $$self{'id'} );
	sql::execute( undef, undef, q{DELETE FROM ProjectTemplate WHERE ProjectType_Id=?}, $$self{'id'} );
	sql::execute( undef, undef, q{DELETE FROM Paper_Recommendations WHERE lngProjectTypeIndex=?}, $$self{'id'} );
	sql::execute( undef, undef, q{DELETE FROM ProjectType_RequiredServices WHERE ProjectType_Id=?}, $$self{'id'} );
	sql::update( undef, undef, 'Projects', ['type_id=?',$$self{'id'}], 'type_id', undef );
	sql::execute( undef, undef, q{DELETE FROM Project_Types WHERE Id=?}, $$self{'id'} );
	sql::end_transaction( $dbh, $ac );
	
	# Add record to audit log - action "Delete Project Type".
	openprint::logs::insertLogRecord('19', "Project Type ID: " . $$self{'id'} . " Project Type: " . $$self{'name'},);
} # end sub delete

sub Templates {
	my ( $self, %params ) = @_;
	$params{'projecttype_id'} = $$self{'id'};
	return openprint::ProjectType_Template::find(%params);
} # end sub Templates

sub category {
	return new openprint::ProjectTypeCategory( $_[0]{category_id} )->name();
} # end sub category

1;
__END__
