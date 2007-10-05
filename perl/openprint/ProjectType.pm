package openprint::ProjectType;
@ISA = qw(openprint::Object);
require openprint::Object;
require openprint::logs;

use strict;

sub find {
	my %params = @_;
	my @values;
	my $sql = q{SELECT * FROM Project_Types WHERE 1>0};
	if ( $params{'name'} ) {
		$sql .= ' AND strName=?';
		push @values, $params{'name'};
	} # end if
	if ( exists $params{'strid'} ) {
		$sql .= ' AND strID=?';
		push @values, $params{'strid'};
	} # end if
	if ( $params{'category_id'} ) {
		$sql .= ' AND category_id=?';
		push @values, $params{'category_id'};
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->error("Error loading ProjectTypes: ($sql) (@values)");
		return;
	} # end if
	return map { new openprint::ProjectType( $_->{lngindex}, $_ ); } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Project_Types WHERE lngIndex=?', {}, $$self{'id'} );
	} # end if
	@$self{qw/strid name url category_id sort/} = @$data{qw/strid strname strdetailedurl category_id lngsort/};
} # end sub load

sub save {
	my $self = shift;

	my $ac = sql::start_transaction( $openprint::dbh );
	my @sql = (
			'strID',            $$self{'strid'},
			'strName',          $$self{'name'},
			'strDetailedURL',   $$self{'url'},
			'category_id',		$$self{'category_id'} ? $$self{'category_id'} : undef,
			'lngSort',          $$self{'sort'} ? $$self{'sort'} : undef,
			);
	if ( ! $$self{'id'} ) {
		if ( ! ( @$self{'id'} = sql::execute( $openprint::log, $openprint::dbh, q{SELECT nextval('ProjectTypeIndex')} ) ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return 'Error allocating new Project Type<br/>';
		} # end if
		push @sql, ( 'lngIndex',			$$self{'id'} );
		if ( $_ = sql::insert( $openprint::log, $openprint::dbh, 'Project_Types', \@sql ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return "Error inserting Project Type $$self{'strid'} : $_<br>";
		} # end if
		# Add record to audit log - action "New Project Type".
		openprint::logs::insertLogRecord('47', "Project Type ID: " . $$self{'id'} . " Project Type: " . $$self{'name'},);
	} else {
		if ( $_ = sql::update( $openprint::log, $openprint::dbh, 'Project_Types', ['lngIndex=?', $$self{'id'}], \@sql ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return "Error updating Project Type $$self{'strid'} : $_<br>";
		} # end if
		# Add record to audit log - action "Update Project Type".
		openprint::logs::insertLogRecord('48', "Project Type ID: " . $$self{'id'} . " Project Type: " . $$self{'name'},);
	} # end if
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM ProjectType_RequiredServices WHERE ProjectType_id=?}, $$self{'id'} );
	if ( $$self{'required_services'} ) {
		# The union gets rid of duplicates
		foreach my $servicetype_id ( sets::union( @{$$self{'required_services'}} ) ) {
			sql::insert( $openprint::log, $openprint::dbh, 'ProjectType_RequiredServices', ['ProjectType_id', $$self{'id'}, 'ServiceType_id', $servicetype_id ] );
		} # end foreach
	} # end if
	sql::end_transaction( $openprint::dbh, $ac );
	$self->load();
} # end sub save

sub next {
	my $self = shift;
	($_) = sql::execute( $openprint::log, $openprint::dbh, q{SELECT lngIndex FROM Project_Types WHERE lngIndex = (SELECT MIN(strID) FROM Project_Types WHERE strID>?)}, $$self{'strid'} );
	if ( ! $_ ) {
		( $_ ) = sql::execute( $openprint::log, $openprint::dbh, q{SELECT lngIndex FROM Project_Types WHERE lngIndex = (SELECT MAX(strID) FROM Project_Types WHERE strID<?)}, $$self{'strid'} );
	} # end if
	return new openprint::ProjectType( $_ );
} # end sub next
sub prev {
	my $self = shift;
	($_) = sql::execute( $openprint::log, $openprint::dbh, q{SELECT lngIndex FROM Project_Types WHERE lngIndex = (SELECT MAX(strID) FROM Project_Types WHERE strID<?)}, $$self{'strid'} );
	if ( ! $_ ) {
		( $_ ) = sql::execute( $openprint::log, $openprint::dbh, q{SELECT lngIndex FROM Project_Types WHERE lngIndex = (SELECT MIN(strID) FROM Project_Types WHERE strID>?)}, $$self{'strid'} );
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
		@{$$self{'required_services'}} = sql::execute( $openprint::log, $openprint::dbh, q{SELECT ServiceType_id FROM ProjectType_RequiredServices WHERE ProjectType_id=?}, $$self{'id'} );
	} # end if
	return @{$$self{'required_services'}} if $$self{'required_services'};
} # end sub required_services

sub required_ServiceTypes {
	my $self = shift;
	return map { new openprint::ServiceType( $_ ); } $self->required_services();
}

sub delete {
	my $self = shift;

	my $ac = sql::start_transaction( $openprint::dbh );
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM tbl_projecttype_defaults WHERE lngProjectTypeIndex=?}, $$self{'id'} );
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM ProjectTemplate WHERE ProjectType_Id=?}, $$self{'id'} );
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM Paper_Recommendations WHERE lngProjectTypeIndex=?}, $$self{'id'} );
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM ProjectType_RequiredServices WHERE ProjectType_Id=?}, $$self{'id'} );
	sql::update( $openprint::log, $openprint::dbh, 'tbl_Projects', "type_id=$$self{'id'}", 'type_id', undef );
#sql::execute( $log, $dbh, q{DELETE FROM tbl_Projects WHERE Type_Id=?}, $id );
	sql::execute( $openprint::log, $openprint::dbh, q{DELETE FROM Project_Types WHERE lngIndex=?}, $$self{'id'} );
	sql::end_transaction( $openprint::dbh, $ac );
	
	# Add record to audit log - action "Delete Project Type".
	openprint::logs::insertLogRecord('19', "Project Type ID: " . $$self{'id'} . " Project Type: " . $$self{'strName'},);
} # end sub delete

1;
__END__
