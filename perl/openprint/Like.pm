use strict;
require openprint::Object_Type;
package openprint::Like;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table %fields %find_fields %transforms %defaults @identified_by );

$debug = 1;
$table = 'likes';
%fields = (
	'user_id'		=>	'user_id',
	'object_type_id'	=>	'object_type_id',
	'object_type'	=>	undef,
	'object_id'		=>	'object_id',
	'created_on'	=>	'created_on',
);
%find_fields = (
	'object_type'	=>	'(SELECT name FROM object_types WHERE id=object_type_id)',
);
@identified_by = ( 'user_id', 'object_type_id', 'object_id' );
%defaults = (
	'created_on'	=>	q`'NOW()'`,
);

sub object_type {
	if ( @_ > 1 ) {
		$_[0]{'object_type'} = $_[1];
		my $Type = openprint::Object_Type->find_one('name'=>$_[1]);
		if ( ! $Type ) {
			$Type = new openprint::Object_Type();
			$Type->save({'name'=>$_[1],'human'=>$_[1]});
		} # end if
		$_[0]{'object_type_id'}=$Type->id();
	} # end if
	if ( ! $_[0]{'object_type'} ) {
		$_[0]{'object_type'} = new openprint::Object_Type( $_[0]{'object_type_id'} )->name();
	} # end if
	return $_[0]{'object_type'};
} # end sub object_type

sub Object {
	if ( ! $_[0]{'Object'} ) {
#$openprint::log->debug("Like: new object ".$_[0]->object_type());
		my $type = $_[0]->object_type();
		if ( ! $type ) {
			$openprint::log->warn("No object_type $type");

		} elsif ( $type->can('new') ) {
			$_[0]{'Object'} = $type->new( $_[0]{'object_id'} );
#$openprint::log->debug("lLike: new object type: " . (ref $_[0]{'Object'}) . ' id: ' . $_[0]{'Object'}->id() );
		} else {
			$openprint::log->warn("Unable to create an $_[0]{object_type}");
		} # end if
	} 
	if ( ! $_[0]{'Object'} ) {
		return new openprint::Object();
	} # end if
	return $_[0]{'Object'};
} # end sub Object

sub Object_Type {
	if ( $_[0]{'object_type_id'} ) {
		$_[0]{'Object_Type'} = new openprint::Object_Type( $_[0]{'object_type_id'} );
	} else {
		$_[0]{'Object_Type'} = openprint::Object_Type->find_one('name'=>ref $_[0] );
		$_[0]{'Object_Type'} = new openprint::Object_Type() if ! $_[0]{'Object_Type'};
	} # end if
	return $_[0]{'Object_Type'};
} # end sub Object_Type

1;
__END__
