package openprint::ManifestContent;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use openprint ();
use vars qw(%variable $log $dbh %config $table $serial %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require sql;
require ssi;
require misc;
require openprint::Manifest_Content_Type;

my $debug = 0;

$table = 'manifestcontents';
$serial = 'manifestcontents_id_seq';

%fields = (
	'id'				=>	'id',
	'manifest_id'		=>	'manifest_id',
	'skid_id'			=>	'skid_id',
	'quantity'			=>	'quantity',
	'type_id'			=>	'type_id',
);

%transforms = (
	'quantity'	=> [ 's/\D//g' ],
	'type_id'	=> [ 's/\D//g' ],
);

%defaults = (
	'quantity'	=> 0,
);

# Returns a paper object specified by the parameters
sub Skid {
	return new openprint::Skid( $_[0]{skid_id} );
} # end sub Skid

sub Manifest {
	return new openprint::Manifest( $_[0]{manifest_id} );
} # end sub Manifest

sub Type {
	return new openprint::Manifest_Content_Type( $_[0]{type_id} );
} # end sub Type

sub units {
	my $Type = $_[0]->Type();
	if ( $Type->paper_id() ) {
		return $Type->Paper()->type() eq 'Roll' ? 'lbs' : 'sheets';
	} # end if
} # end sub units


1;
__END__
