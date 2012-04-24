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

1;
__END__
