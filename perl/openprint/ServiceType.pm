package openprint::ServiceType;
@ISA = qw(openprint::Object);
require openprint::Object;
require openprint::ServiceType_Category;
require openprint::ServiceType_Default;

use strict;
use vars qw( $log $dbh $debug $table $serial %find_fields %fields %transforms %defaults );

*log = \$openprint::log;
*dbh = \$openprint::dbh;
$debug = 1;
$table = 'service_types';
$serial = 'service_types_id_seq';

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
%find_fields = (
	'category'	=>	'(SELECT name FROM ServiceType_Categories WHERE id=category_id)',
);
%transforms = (
);
%defaults = (
	'sorting'	=>	undef,
);

sub cache_field {
	return 'name';
}

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
		my $ServiceType_Category = openprint::ServiceType_Category->find_one('name'=>$_[1]);
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

sub Defaults {
	return openprint::ServiceType_Default->find('servicetype_id'=>$_[0]{'id'});
} # end sub Defaults

1;
__END__
