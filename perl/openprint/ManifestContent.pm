package openprint::ManifestContent;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use Math::Round qw( nearest );
use openprint ();
use vars qw(%variable $log $dbh %config $debug $table $serial %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require openprint::Manifest_Content_Type;

$debug = 0;

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

sub value {
	my $Type = $_[0]->Type();
	my $cost = $Type->cost() ? $Type->cost() : $Type->cost_from_po();
	return Math::Round::nearest( .01, $cost * $_[0]{'quantity'}/100 );
} # end sub value

1;
__END__
