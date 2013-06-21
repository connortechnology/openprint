use strict;
package openprint::ManifestContent;
our @ISA = qw(openprint::Object);
require openprint::Object;

use Math::Round qw( nearest );
use openprint ();
use vars qw( $debug $table $serial %fields %find_fields %transforms %defaults );

require openprint::Manifest_Content_Type;
require openprint::Manifest;
require openprint::Skid;
require openprint::RFIDTag;
require openprint::SkidContent;

$debug = 1;

$table = 'manifestcontents';
$serial = 'manifestcontents_id_seq';

%fields = (
	id				=>	'id',
	manifest_id		=>	'manifest_id',
	skid_id			=>	'skid_id',
	Skid			=>	undef,
	quantity		=>	'quantity',
	type_id			=>	'type_id',
	rfidtag_id			=>	'rfidtag_id',
	RFIDTag				=>	undef,
	manufacturers_id	=>	'manufacturers_id',
	location_id			=>	'location_id',
);
%find_fields = (
	paper_id	=>	'(SELECT paper_id FROM Manifest_Content_Types WHERE manifest_content_types.manifest_id = manifestcontents.manifest_id)',
);

%transforms = (
	quantity	=> [ 's/\D//g' ],
	type_id		=> [ 's/\D//g' ],
	manufacturers_id	=>	[ 'tr/[a-z]/[A-Z]/' ],
);

%defaults = (
	quantity			=> 0,
	manufacturers_id	=>	undef,
	skid_id				=>	undef,
	rfidtag_id			=>	undef,
	location_id			=>	undef,
);

sub skid_id {
	if ( @_ > 1 ) {
		$_[0]{skid_id} = $_[1];
		$_[0]{skid_id} = undef if ! $_[0]{skid_id};
		delete $_[0]{Skid};
	} # end if
	if ( ( ! $_[0]{skid_id} ) and $_[0]{rfidtag_id} ) {
		my $Tag = $_[0]->RFIDTag();
		$_[0]{skid_id} = $Tag->skid_id() if $Tag->skid_id();
	} # end if
	return $_[0]{skid_id};
} # end sub skid_id

sub Skid {
	if ( @_ > 1 ) {
		$_[0]{Skid} = $_[1];
		$_[0]{skid_id} = ref $_[0]{Skid} eq 'openprint::Skid' ? $_[0]{Skid}{id} : undef;
		$_[0]{skid_id} = undef if ! $_[0]{skid_id};
	} # end if
	if ( ! $_[0]{Skid} ) {
		$_[0]{Skid} = new openprint::Skid( $_[0]->skid_id() );
	} # end if
	return $_[0]{Skid};
} # end sub Skid

sub RFIDTag {
	if ( @_ > 1 ) {
		$_[0]{RFIDTag} = $_[1];
		$_[0]{rfidtag_id} = ref $_[0]{RFIDTag} eq 'openprint::RFIDTag' ? $_[0]{RFIDTag}{id} : undef;
	} # end if
	if ( ! $_[0]{RFIDTag} ) {
		if ( $_[0]{rfidtag_id} ) {
			$_[0]{RFIDTag} = new openprint::RFIDTag( $_[0]{rfidtag_id} );
			if ( ! $_[0]{RFIDTag}->id() ) {
				$_[0]{RFIDTag} = new openprint::RFIDTag();
				$_[0]{RFIDTag}->id( $_[0]{rfidtag_id} );
			} # end if
		} else {
			$_[0]{RFIDTag} = $_[0]->Skid()->RFIDTag();
		} # end if
	} # end if
	return $_[0]{RFIDTag};
} # end sub RFIDTag

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
	if ( ! $_[0]{'id'} ) {
		$openprint::log->error("Called delete on ManifestContent with no id.");
		return;
	} # end if
	$_[0]->SUPER::delete();
} # end sub delete

sub manufacturers_id {
	if ( @_ > 1 ) {
		$_[0]{manufacturers_id} = $_[1];
	} # end if
	if ( ( ! $_[0]{manufacturers_id} ) and $_[0]{skid_id} ) {
		my $Skid = new openprint::Skid( $_[0]{skid_id} );
		$_[0]{manufacturers_id} = $Skid->manufacturers_id();
	} # end if
	return $_[0]{manufacturers_id};
} # end sub manufacturers_id

sub location_id {
	if ( @_ > 1 ) {
		$_[0]{location_id} = $_[1];
	} # end if
	if ( ( ! $_[0]{location_id} ) ) {
		if ( $_[0]{skid_id} ) {
			return $_[0]->Skid()->location_id();
		} elsif ( $_[0]{rfidtag_id} ) {
			return $_[0]->RFIDTag()->location_id();
		} # endif
	} # end if
	return $_[0]{location_id};
} # end sub location_id

sub fix {
	my ( $MC ) = @_;
	my $Type = $_[0]->Type();
	my $Manifest = $_[0]->Manifest();

	my $error;
	my @SkidContents = openprint::SkidContent->find( skid_id=>$$MC{skid_id} );
	my %SkidContents = map { $$_{paper_id}, $_ } @SkidContents;

foreach my $k ( keys %SkidContents ) {
$openprint::log->debug( "$k => " . $SkidContents{$k}->to_string() );
}
	if ( $SkidContents{$$Type{paper_id}} ) {
# Have the right paper., remove the ones that don't match.
$openprint::log->debug("desired paper exists");
		foreach my $paper_id ( keys %SkidContents ) {
			next if $$MC{paper_id} == $paper_id;
			my $SC = $SkidContents{$paper_id};
			my $Paper = $SC->Paper();

			my $PI = new openprint::PaperInventory();
			$error .= $PI->save({ user_id=>$openprint::session{user_id}, skid_id=>$$SC{skid_id}, paper_id=>$paper_id, quantity=>-1*$SC->quantity(),
					comment=>qq`Removed stock by manifest <a href="/employee/inventory/manifest.html?manifest_id=$$Manifest{id}">$$Manifest{name}</a>.`
					});
			$error .= $SC->delete();
			$error .= $Paper->save();
		} # end foreach paper_id
	} else {
$openprint::log->debug("desired paper does not exists");
# Change the stock
		foreach my $paper_id ( keys %SkidContents ) {
			my $SC = $SkidContents{$paper_id};
			my $Paper = $SC->Paper();

			my $PI = new openprint::PaperInventory();
			$error .= $PI->save({ user_id=>$openprint::session{user_id}, skid_id=>$$SC{skid_id}, paper_id=>$SC->paper_id(), quantity=>-1*$SC->quantity(),
					comment=>'Changed stock from ' . $Paper->to_string() . ' to ' . $Type->Paper()->to_string()});
# Change the type to the new type
			foreach my $PA ( openprint::PaperAllocation->find( skid_id=>$SC->skid_id(), paper_id=>$SC->paper_id() ) ) {
				$error .= $PA->save({paper_id=>$Type->Paper()->id()});
			} # end foreach PA
			my $PI = new openprint::PaperInventory();
			$error .= $PI->save({user_id=>$openprint::session{user_id},skid_id=>$$SC{skid_id}, paper_id=>$Type->paper_id(), quantity =>$SC->quantity(),
					comment=>'Changed stock from ' . $Paper->to_string() . ' to ' . $Type->Paper()->to_string()});
			$error .= $SC->save({paper_id=>$Type->Paper()->id()});
			$error .= $Paper->save();
		} # end foreach paper_id
	} # end if
	$error .= $Type->Paper()->save();
	return $error;
} # end sub fix
1;
__END__
