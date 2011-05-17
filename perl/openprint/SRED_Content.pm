use strict;
package openprint::SRED_Content;
our @ISA = qw(openprint::Object);
require openprint::Object;
require openprint::SRED_Asset;

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 1;
$table = 'sred_contents';
$serial = 'sred_contents_id_seq';

%fields = (
	'id'	=>	'id',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
    'starting'          =>  'starting',
    'ending'            =>  'ending',
    'project_id'        =>  'project_id',
    'description'       =>  'description',
    'time_associated'   =>  'time_associated',
    'user_id'           =>  'user_id',
    'deleted'           => 'deleted',

);

%transforms = (
	'created_on'	=>	'NOW()',
	'updated_on'	=>	'NOW()',
	'name' => [ 's/^\s+//', 's/\s+$//' ],
);

%defaults = (
    'created_on'    => 'NOW()',
    'updated_on'    => 'NOW()',
    'deleted'       => 0,
    'project_id'    =>  undef,
    'user_id'       =>  undef,
	'time_associated'	=>	undef,
);

sub elapsed {
	my ( $self ) = @_;

	if ( $$self{'time_associated'} ) {
		return Date::Parse::str2time( $$self{'ending'} ) - Date::Parse::str2time( $$self{'starting'} );
	} else {
		my ($start) = $$self{'starting'} =~ /(\d\d\d\d-\d\d-\d\d)/;
		my ($end) = $$self{'ending'} =~ /(\d\d\d\d-\d\d-\d\d)/;
		return Date::Parse::str2time( $end ) - Date::Parse::str2time( $start );
	} # end if
} # end sub elapsed

sub Assets {
	my $self = shift;
	my %params = @_;
	$params{'content_id'} = $$self{'id'};
	return openprint::SRED_Asset->find(%params);
} # end sub Assets

1;
__END__
