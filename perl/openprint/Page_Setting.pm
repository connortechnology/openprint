use strict;
package openprint::Page_Setting;
our @ISA = qw(openprint::Object);

use vars qw( $debug $serial $table %fields %transforms %defaults $cache_field $cached %cache );

$debug = 1;
$cached = 0;
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
$cache_field = 'url';
sub cache_field {
    return $cache_field;
}

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

sub get {
	my ( $page ) = @_;

	if ( ! $cache{$openprint::config{db_name}} ) {
		$openprint::log->debug("loading Page settings for $openprint::config{db_name}") if $debug;
		$cache{$openprint::config{db_name}} = { map { $_->url(), $_ } openprint::Page_Setting->find() };
	} # end if

	my $cache = $cache{$openprint::config{db_name}};

	if ( ! $$cache{$page} ) {
# Need to create one.
		my @chunks = split('/', $page );
		while ( @chunks ) {
			pop @chunks;
			last if ! @chunks;

# Because there is a / at the beginning of the url, the first entry in chunks is '', so we don't need to prepend a /
			my $chunk = join('/', @chunks);
			$chunk = '/' if ! $chunk; # neccessary to deal with the empty string

			$openprint::log->debug("Looking for page setting for $chunk") if $debug;
			if ( $$cache{$chunk} ) {
# Why stuff up the db with entries, just fill the hash with copies.
				$$cache{$page} = $$cache{$chunk};
				last;
			} # end if
		} # end while chunks
		if ( ! $$cache{$page} ) {
			$$cache{$page} = new openprint::Page_Setting();
			#$$cache{$page}->save({url=>$page}) if $openprint::session{user_type} eq 'A';
		} # end if
	} # end if Page Settings not found
	return $$cache{$page};
} # end sub get

1;
__END__
