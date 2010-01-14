package openprint::ProjectType;
@ISA = qw(openprint::Object);
use strict;
require openprint::Object;
require openprint::logs;
require openprint::ProjectType_Template;
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
);
%transforms = (
	'name'	=>	[ 's/\s//g' ],
);
%defaults = (
	'id'			=>	undef,
	'category_id'	=>	undef,
	'sorting'		=>	undef,
);

sub find_one {
    my @results = find( @_, 'limit', 1 );
    if ( @results > 1 ) {
        $openprint::log->error('ProjectType::find_one more than 1 result!');
    } elsif ( @results ) {
        return $results[0];
    } # end if
    return;
} # end sub find_one

sub find {
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
		$$self{'required_services'} = $$params{'required_services'} if exists $$params{'required_services'};
		sql::execute( undef, undef, q{DELETE FROM ProjectType_RequiredServices WHERE ProjectType_id=?}, $$self{'id'} );
		if ( $$self{'required_services'} ) {
			# The union gets rid of duplicates
			foreach my $servicetype_id ( sets::union( @{$$self{'required_services'}} ) ) {
				sql::insert( undef, undef, 'ProjectType_RequiredServices', ['ProjectType_id', $$self{'id'}, 'ServiceType_id', $servicetype_id ] );
			} # end foreach
		} # end if
	} # end if
	return;	
} # end sub save

sub next {
	my $self = shift;
	($_) = sql::execute( undef, undef, q{SELECT Id FROM Project_Types WHERE Id = (SELECT MIN(name) FROM Project_Types WHERE name>?)}, $$self{'name'} );
	if ( ! $_ ) {
		( $_ ) = sql::execute( undef, undef, q{SELECT id FROM Project_Types WHERE id = (SELECT MAX(name) FROM Project_Types WHERE name<?)}, $$self{'name'} );
	} # end if
	return new openprint::ProjectType( $_ );
} # end sub next
sub prev {
	my $self = shift;
	($_) = sql::execute( undef, undef, q{SELECT Id FROM Project_Types WHERE Id = (SELECT MAX(name) FROM Project_Types WHERE name<?)}, $$self{'name'} );
	if ( ! $_ ) {
		( $_ ) = sql::execute( undef, undef, q{SELECT Id FROM Project_Types WHERE Id = (SELECT MIN(name) FROM Project_Types WHERE name>?)}, $$self{'name'} );
	} # end if
	return new openprint::ProjectType( $_ );
} # end sub prev

sub required_services {
	my $self = shift;

	if ( @_ > 1 ) {
		@{$$self{'required_services'}} = @_;
	} elsif ( @_ ) {
		$_ = shift;
		if ( ref $_  eq 'ARRAY' ) {
			@{$$self{'required_services'}} = @{$_};
		} elsif ( $_ ) {
			@{$$self{'required_services'}} = ($_);
		} # end if
	} elsif ( ! $$self{'required_services'} ) {
		@{$$self{'required_services'}} = sql::execute( undef, undef, q{SELECT ServiceType_id FROM ProjectType_RequiredServices WHERE ProjectType_id=?}, $$self{'id'} );
	} # end if
	return @{$$self{'required_services'}} if $$self{'required_services'};
} # end sub required_services

sub required_ServiceTypes {
	my $self = shift;
	return map { new openprint::ServiceType( $_ ); } $self->required_services();
}

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

1;
__END__
