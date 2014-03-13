use strict;
package openprint::Manifest_Content_Type;
our @ISA = qw(openprint::Object);
require openprint::Object;

use openprint ();
use vars qw( $debug $table $serial %fields %find_fields %transforms %defaults );

require openprint::Manifest;
require Math::Round;

$debug = 0;

$table = 'manifest_content_types';
$serial = 'manifest_content_types_id_seq';

%fields = (
	'id'			=>	'id',
	'cost'			=>	'cost',
	'cost_units'	=>	'cost_units',
	'docket'		=>	'docket',
	'po_id'			=>	'po_id',
	'po_content_id'	=>	'po_content_id',
	'manifest_id'	=>	'manifest_id',
	'paper_id'		=>	'paper_id',
	supplier_invoice	=>	'supplier_invoice',
	item_count			=>	'item_count',
	type			=>	'type',
	manufacturers_name	=>	'manufacturers_name',
	condition_id	=>	'condition_id',
);
%find_fields = (
	total_quantity	=>	'(SELECT SUM(quantity) FROM manifestcontents WHERE manifestcontents.manifest_id=manifest_content_types.manifest_id and type_id=manifest_content_types.id)',
	skid_id			=>	'(SELECT skid_id FROM manifestcontents WHERE manifestcontents.manifest_id=manifest_content_types.manifest_id and type_id=manifest_content_types.id)',
);

%transforms = (
	paper_id		=> [ 's/\D//g' ],
	po_id			=> [ 's/\D//g' ],
	po_content_id	=> [ 's/\D//g' ],
	item_count		=> [ 's/\D//g' ],
	docket			=> [ 's/\D//g' ],
	cost			=> [ 's/[^\d\.]//g' ],
    type			=> [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);

%defaults = (
	cost			=>	undef,
	docket			=>	undef,
	po_id			=>	undef,
	po_content_id	=>	undef,
	paper_id		=>	undef,
	type			=>	undef,
	item_count		=>	undef,
	manufacturers_name	=>	undef,
	condition_id	=>	undef,
);

sub Paper {
require openprint::Paper;
	return new openprint::Paper( $_[0]{'paper_id'} );
} # end sub Paper

sub Manifest {
	return new openprint::Manifest( $_[0]{'manifest_id'} );
} # end sub Manifest

sub PurchaseOrder {
	return new openprint::PurchaseOrder( $_[0]{'po_id'} );
} # end sub PurchaseOrder

sub PurchaseOrder_Content {
	if ( ! exists $_[0]{'PurchaseOrder_Content'} ) {
require openprint::PurchaseOrder_Content;
		if ( ! $_[0]{'po_content_id'} ) {
			my $PO = new openprint::PurchaseOrder( $_[0]{'po_id'} );
			my $Paper = $_[0]->Paper();
			foreach my $POC ( $PO->Contents() ) {
				$openprint::log->debug('POC desc: ' . $POC->item()) if $debug;
				next if $POC->type() ne $Paper->type().' Stock';
				my ( $weight ) = $POC->item() =~ /(\d+)lb/i;
				if ( $weight and $Paper->basis_mweight() ) {
					$weight = Math::Round::nearest(1,$weight*2);
					my $basis_weight = Math::Round::nearest(1,$Paper->basis_mweight());
					if ( $weight != $basis_weight ) {
						$openprint::log->debug("Wrong weight: 2*$weight != " . $basis_weight ) if $debug;
						next;
					} else {
						$openprint::log->debug("Right weight: $weight == " . $basis_weight ) if $debug;
					} 
				} else {
					$openprint::log->debug("Indeterminate weight: $weight == " . $Paper->basis_mweight() ) if $debug;
				} # end if
				my ( $width ) = $POC->item() =~ /([\.\d]+)in/i;
				if ( $width and $Paper->width() and ( $Paper->width() != $width ) ) {
					$openprint::log->debug("Wrong width: $width != " . $Paper->width() ) if $debug;
					next;
				} else {
					$openprint::log->debug("Right width: $width == " . $Paper->width() ) if $debug;
				} # end if
				if ( $Paper->fsc_code() and ( $POC->item() !~ /^FSC/ ) ) {
					$openprint::log->debug("FSC Mismatch") if $debug;
					next;
				} elsif ( (!$Paper->fsc_code()) and $POC->item() =~ /^FSC/ ) {
					$openprint::log->debug("FSC Mismatch") if $debug;
					next;
				} # end if
				$_[0]{'PurchaseOrder_Content'} = $POC;
				last;
			} # end foreach POC
			$_[0]{'PurchaseOrder_Content'} = new openprint::PurchaseOrder_Content() if ! $_[0]{'PurchaseOrder_Content'};
		} else {
			$_[0]{'PurchaseOrder_Content'} = new openprint::PurchaseOrder_Content($_[0]{'po_content_id'});
		} # end if
	} # end if
	return $_[0]{'PurchaseOrder_Content'}; 
} # end sub PurchaseOrder_Content

sub type {
	if ( @_ > 1 ) {
		$_[0]{type} = $_[1];
	} # end if
	if ( ! $_[0]{type} ) {
		if ( $_[0]{paper_id} ) {
			$_[0]{type} = $_[0]->Paper()->type();
		} # end if
	} # end if
	return $_[0]{type};
} # end sub type

sub Contents {
	my ( $self, %params ) = @_;
	if ( %params ) {
		if ( $$self{id} ) {
			return openprint::ManifestContent->find( manifest_id=>$$self{manifest_id}, type_id=>$$self{id}, %params );
		} # end if
	} # end if
	if ( ! $$self{Contents} ) {
		if ( $$self{id} ) {
			@{$$self{Contents}} = openprint::ManifestContent->find( manifest_id=>$$self{manifest_id}, type_id=>$$self{id} );
		} # end if
	} # end if
	return @{$$self{Contents}} if $$self{Contents};
	return;
} # end sub Contents

sub condition_id {
	if ( @_ > 1 ) {
		$_[0]{condition_id} = $_[1];
	} # en dif
	if ( ! $_[0]{condition_id} ) {
		require openprint::InventoryCondition;
		my $New = openprint::InventoryCondition->find_one(name=>'new');
		$_[0]{condition_id} = $New->id() if $New;
	} # end if
	return $_[0]{condition_id};
} # end sub condition_id

sub Condition {
	require openprint::InventoryCondition;
	return new openprint::InventoryCondition($_[0]{condition_id});
} # end sub Condition

1;
__END__
