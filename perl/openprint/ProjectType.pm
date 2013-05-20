use strict;
package openprint::ProjectType;
our @ISA = qw(openprint::Object);

require openprint::Object;
require openprint::Log;
require openprint::ProjectType_Template;
require openprint;

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 0;
$table = 'project_types';
$serial = 'project_types_id_seq';

%fields = (
	'id'			=>	'id',
	'name'			=>	'name',	
	'description'	=>	'description',
	'category_id'	=>	'category_id',
	'url'			=>	'url',
	'sorting'		=>	'sorting',
	'type'			=>	'type',
	'please_call'	=>	'please_call',
);
%transforms = (
	'name'	=>	[ 's/\s//g' ],
);
%defaults = (
	'id'			=>	undef,
	'category_id'	=>	undef,
	'sorting'		=>	undef,
	'please_call'	=>	0,
);

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
			next if ! $servicetype_id;
			sql::insert( undef, undef, 'ProjectType_RequiredServices', ['ProjectType_id', $$self{'id'}, 'ServiceType_id', $servicetype_id ] );
		} # end foreach
	} # end if
	return;	
} # end sub save

sub next {
	my $self = shift;
	if ( $$self{name} ) {
		($_) = sql::execute( undef, undef, q{SELECT id FROM Project_Types WHERE name = (SELECT MIN(name) FROM Project_Types WHERE name>?)}, $$self{name} );
		if ( ! $_ ) {
			( $_ ) = sql::execute( undef, undef, q{SELECT id FROM Project_Types WHERE name = (SELECT MAX(name) FROM Project_Types WHERE name<?)}, $$self{'name'} );
		} # end if
	} # end if
	( $_ ) = sql::execute( undef, undef, q{SELECT MIN(id) FROM Project_Types} ) if ! $_;
	return new openprint::ProjectType( $_ );
} # end sub next
sub prev {
	my $self = shift;
	if ( $$self{name} ) {
		($_) = sql::execute( undef, undef, q{SELECT Id FROM Project_Types WHERE name = (SELECT MAX(name) FROM Project_Types WHERE name<?)}, $$self{'name'} );
		if ( ! $_ ) {
			( $_ ) = sql::execute( undef, undef, q{SELECT Id FROM Project_Types WHERE name = (SELECT MIN(name) FROM Project_Types WHERE name>?)}, $$self{'name'} );
		} # end if
	} # end if name
	( $_ ) = sql::execute( undef, undef, q{SELECT MIN(id) FROM Project_Types} ) if ! $_;
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
	return map { new openprint::ServiceType( $_ ); } $_[0]->required_services();
}

sub delete {
	my $self = shift;

	my $ac = sql::start_transaction( $openprint::dbh );
	sql::execute( undef, undef, q{DELETE FROM projecttype_defaults WHERE projecttype_id=?}, $$self{'id'} );
	sql::execute( undef, undef, q{DELETE FROM ProjectTemplate WHERE projecttype_id=?}, $$self{'id'} );
	sql::execute( undef, undef, q{DELETE FROM Paper_Recommendations WHERE lngProjectTypeIndex=?}, $$self{'id'} );
	sql::execute( undef, undef, q{DELETE FROM ProjectType_RequiredServices WHERE ProjectType_Id=?}, $$self{'id'} );
	sql::update( undef, undef, 'Projects', ['type_id=?',$$self{'id'}], 'type_id', undef );
	sql::execute( undef, undef, q{DELETE FROM Project_Types WHERE Id=?}, $$self{'id'} );
	sql::end_transaction( $openprint::dbh, $ac );
	
	(new openprint::Log())->save({ action=>'Delete Project Type', note=>"Project Type ID: $$self{id} Project Type: $$self{name}"});
	return;
} # end sub delete

sub Templates {
	my ( $self, %params ) = @_;
	$params{'projecttype_id'} = $$self{'id'};
	return openprint::ProjectType_Template->find(%params);
} # end sub Templates

1;
__END__
