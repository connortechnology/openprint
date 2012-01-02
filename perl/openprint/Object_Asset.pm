use strict;
require openprint::Asset;
require openprint::Object;
require openprint::Object_Type;

package openprint::Object_Asset;
our @ISA = qw(openprint::Object);
use vars qw( $debug %fields %find_fields %transforms %defaults $table @identified_by );
$debug = 1;
$table = 'object_assets';
@identified_by = ( 'object_id','object_type_id','asset_id' );
%fields = (
	'object_id'			=>	'object_id',
    'object_type_id'    =>  'object_type_id',
    'object_type'       =>  undef,
	'asset_id'			=>	'asset_id',
);
%find_fields = (
    'object_type'   =>  '(SELECT name FROM object_types WHERE id=object_type_id)',
);


sub Asset {
	return new openprint::Asset( $_[0]{'asset_id'} );
} # end sub Asset

sub Object {
    $_ =  $_[0]->object_type()->new( $_[0]{'object_id'} );
$openprint::log->debug( "Returning object of type " . ref $_ );
    return $_;
} # end sub Object

1;
__END__
