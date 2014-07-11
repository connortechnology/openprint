use strict;
require openprint::Keyword;
require openprint::Object;
require openprint::Object_Type;

package openprint::Object_Keyword;
our @ISA = qw(openprint::Object);
use vars qw( $debug %fields %find_fields %transforms %defaults $table @identified_by );
$debug = 0;
$table = 'object_keywords';
@identified_by = ( 'object_id','object_type_id','keyword_id' );
%fields = (
	object_id			=>	'object_id',
	object_type_id		=>	'object_type_id',
	object_type			=>	undef,
	keyword_id			=>	'keyword_id',
);
%find_fields = (
	object_type	=>	'(SELECT name FROM object_types WHERE id=object_type_id)',
);


sub Keyword {
	return new openprint::Keyword( $_[0]{'keyword_id'} );
} # end sub Keyword

sub Object {
	$_ =	$_[0]->object_type()->new( $_[0]{'object_id'} );
$openprint::log->debug( "Returning object of type " . ref $_ );
	return $_;
} # end sub Object

1;
__END__
