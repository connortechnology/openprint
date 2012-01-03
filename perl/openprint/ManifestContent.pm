use strict;
package openprint::ManifestContent;
our @ISA = qw(openprint::Object);
require openprint::Object;

use Math::Round qw( nearest );
use openprint ();
use vars qw(%variable $log $dbh %config $debug $table $serial %fields %find_fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require openprint::Manifest_Content_Type;
require openprint::Manifest;
require openprint::Skid;

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
%find_fields = (
	'paper_id'	=>	'(SELECT paper_id FROM Manifest_Content_Types WHERE manifest_content_types.manifest_id = manifestcontents.manifest_id)',
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
	if ( @_ > 1 ) {
		$_[0]{'value'} = $_[1];
	} # end if
	if ( ! defined $_[0]{'value'} ) {
		my $Type = $_[0]->Type();
		if ( $Type->cost() ) {
			$_[0]{'value'} = Math::Round::nearest( .01, $Type->cost() * $_[0]{'quantity'}/100 );
		} elsif ( my $POC = $Type->PurchaseOrder_Content() ) {
			$_[0]{'value'} = Math::Round::nearest( .01, $POC->price() * $_[0]{'quantity'}/100 );
		} else {
			$_[0]{'value'} = 0;
		} # end if	
	} # end if	
	return $_[0]{'value'};
} # end sub value

sub delete {
	foreach my $S ( openprint::SkidContent->find('manifestcontent_id'=>$_[0]{'id'}) ) {
		if ( $S->manifestcontent_id() != $_[0]->id() ) {
			$log->error("BLAH!");
			next;
		} # end if
		$S->save({'manifestcontent_id'=>undef});
	} # end foreach
	$_[0]->SUPER::delete();
} # end sub delete

1;
__END__
