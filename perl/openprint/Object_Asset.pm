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
sub object_type {
    if ( @_ > 1 ) {
        my $Type = openprint::Object_Type->find_one('name lc'=> lc (openprint::Object_Type->transform( 'name', $_[1] ) ) );
        if ( ! $Type ) {
            $Type = new openprint::Object_Type();
            $Type->save({'name'=>$_[1], 'human'=>$_[1]});
        } # end if
        $_[0]{'object_type'} = $Type->name();
        $_[0]{'object_type_id'} = $Type->id();
    } # end if
    if ( ! $_[0]{'object_type'} ) {
        $_[0]{'object_type'} = new openprint::Object_Type( $_[0]{'object_type_id'} )->name();
    } # end if
    return $_[0]{'object_type'};
} # end sub object_type


1;
__END__
