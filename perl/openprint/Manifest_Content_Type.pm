package openprint::Manifest_Content_Type;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use openprint ();
use vars qw(%variable $log $dbh %config $debug $table $serial %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require openprint::Manifest;
require openprint::Paper;
require openprint::PurchaseOrder_Content;

$debug = 1;

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
	'supplier_invoice'	=>	'supplier_invoice',
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
				$log->debug('POC desc: ' . $POC->item());
				next if $POC->type() ne $Paper->type().' Stock';
				my ( $weight ) = $POC->item() =~ /(\d+)lb/i;
				if ( $weight and $Paper->basis_mweight() and ( $Paper->basis_mweight() != $weight*2 ) ) {
					$log->debug("Wrong weight: $weight != " . $Paper->basis_mweight() );
					next;
				} else {
					$log->debug("Right weight: $weight == " . $Paper->basis_mweight() );
				} # end if
				my ( $width ) = $POC->item() =~ /([\.\d]+)in/i;
				if ( $width and $Paper->width() and ( $Paper->width() != $width ) ) {
					$log->debug("Wrong width: $width != " . $Paper->width() );
					next;
				} else {
					$log->debug("Right width: $width == " . $Paper->width() );
				} # end if
				if ( $Paper->fsc_code() and ( $POC->item() !~ /^FSC/ ) ) {
					$log->debug("FSC Mismatch");
					next;
				} elsif ( (!$Paper->fsc_code()) and $POC->item() =~ /^FSC/ ) {
					$log->debug("FSC Mismatch");
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
