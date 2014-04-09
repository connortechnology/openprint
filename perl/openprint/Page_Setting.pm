use strict;
package openprint::Page_Setting;
our @ISA = qw(openprint::Object);

use vars qw( $debug $serial $table %fields %transforms %defaults );

$debug = 1;
$table = 'page_settings';
$serial = 'page_settings_id_seq';
%fields = (
	id	=>	'id',
	url	=>	'url',
	user_level	=>	'user_level',
	cacheable	=>	'cacheable',
	keywords	=>	'keywords',
	description	=>	'description',
	user_ids	=>	'user_ids',
);
%transforms = (
	url	=>	[ 's/\/+$//g' ],
);
%defaults = (
	user_level	=>	undef,
	cacheable	=>	undef,
	user_ids	=>	'[]',
);

sub can_view {
	return 1 if $_[0]{user_ids} and sets::isin( $openprint::session{user_id}, $_[0]{user_ids} );
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

sub Users {
	if ( ! exists $_[0]{Users} ) {
	require openprint::User;
		$_[0]{Users} = [ openprint::User->find( id=>$_[0]{user_ids}, order=>'lower(firstname),lower(lastname)' ) ] if $_[0]{user_ids} and @{$_[0]{user_ids}};
	} 
	return @{$_[0]{Users}} if $_[0]{Users};
	return ();
} 

1;
__END__
