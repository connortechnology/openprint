use strict;
package openprint::Page_Setting;
our @ISA = qw(openprint::Object);

use vars qw( $debug $serial $table %fields %defaults );

$debug = 1;
$table = 'page_settings';
$serial = 'page_settings_id_seq';
%fields = (
	'id'	=>	'id',
	'url'	=>	'url',
	'user_level'	=>	'user_level',
	'cacheable'	=>	'cacheable',
	'keywords'	=>	'keywords',
	'description'	=>	'description',
);
%defaults = (
	'user_level'	=>	undef,
	'cacheable'		=>	undef,
);

sub can_view {
	if ( $openprint::session{user_type} eq 'A' ) {
		return 1;
	} elsif ( $openprint::session{user_type} eq 'E' ) {
		return 0 if $_[0]{user_level} eq 'A';
		return 1;
	} elsif ( $openprint::session{user_type} eq 'C' ) {
		return 0 if $_[0]{user_level} eq 'A' or $_[0]{user_level} eq 'E';
		return 1;
	} 
	return 0 if $_[0]{user_level};
	return 1; 
} # end sub can_view

1;
__END__
