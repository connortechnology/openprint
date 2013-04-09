use strict;
package openprint::Manifest_Content_Type;
our @ISA = qw(openprint::Object);
require openprint::Object;

use openprint ();
use vars qw( $debug $table $serial %fields %find_fields %transforms %defaults );

require openprint::Manifest;
require openprint::Paper;
require openprint::PurchaseOrder_Content;
require Math::Round;

$debug = 0;

$table = 'manifest_content_types';
$serial = 'manifest_content_types_id_seq';

%fields = (
	'id'			=>	'id',
	'cost'			=>	'cost',
	'docket'		=>	'docket',
	'po_id'			=>	'po_id',
	'po_content_id'	=>	'po_content_id',
	'manifest_id'	=>	'manifest_id',
	'paper_id'		=>	'paper_id',
	supplier_invoice	=>	'supplier_invoice',
);
%find_fields = (
	total_quantity	=>	'(SELECT SUM(quantity) FROM manifestcontents WHERE manifestcontents.manifest_id=manifest_content_types.manifest_id and type_id=manifest_content_types.id)',
	skid_id			=>	'(SELECT skid_id FROM manifestcontents WHERE manifestcontents.manifest_id=manifest_content_types.manifest_id and type_id=manifest_content_types.id)',
);

%transforms = (
	'paper_id'		=> [ 's/\D//g' ],
	'po_id'			=> [ 's/\D//g' ],
	'po_content_id'	=> [ 's/\D//g' ],
	'docket'	=> [ 's/\D//g' ],
	'cost'		=> [ 's/[^\d\.]//g' ],
);

%defaults = (
	'cost'			=>	undef,
	'docket'		=>	undef,
	'po_id'			=>	undef,
	'po_content_id'	=>	undef,
	'paper_id'		=>	undef,
);

sub Paper {
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
		if ( ! $_[0]{'po_content_id'} ) {
			my $PO = new openprint::PurchaseOrder( $_[0]{'po_id'} );
			my $Paper = $_[0]->Paper();
			foreach my $POC ( $PO->Contents() ) {
				$openprint::log->debug('POC desc: ' . $POC->item());
				next if $POC->type() ne $Paper->type().' Stock';
				my ( $weight ) = $POC->item() =~ /(\d+)lb/i;
				if ( $weight and $Paper->basis_mweight() ) {
					$weight = Math::Round::nearest(1,$weight*2);
					my $basis_weight = Math::Round::nearest(1,$Paper->basis_mweight());
					if ( $weight != $basis_weight ) {
						$openprint::log->debug("Wrong weight: 2*$weight != " . $basis_weight );
						next;
					} else {
						$openprint::log->debug("Right weight: $weight == " . $basis_weight );
					} 
				} else {
					$openprint::log->debug("Indeterminate weight: $weight == " . $Paper->basis_mweight() );
				} # end if
				my ( $width ) = $POC->item() =~ /([\.\d]+)in/i;
				if ( $width and $Paper->width() and ( $Paper->width() != $width ) ) {
					$openprint::log->debug("Wrong width: $width != " . $Paper->width() );
					next;
				} else {
					$openprint::log->debug("Right width: $width == " . $Paper->width() );
				} # end if
				if ( $Paper->fsc_code() and ( $POC->item() !~ /^FSC/ ) ) {
					$openprint::log->debug("FSC Mismatch");
					next;
				} elsif ( (!$Paper->fsc_code()) and $POC->item() =~ /^FSC/ ) {
					$openprint::log->debug("FSC Mismatch");
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

1;
__END__
