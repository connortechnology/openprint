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

$debug = 1;

$table = 'manifest_content_types';
$serial = 'manifest_content_types_id_seq';

%fields = (
	'id'			=>	'id',
	'cost'			=>	'cost',
	'docket'		=>	'docket',
	'po_id'			=>	'po_id',
	'manifest_id'	=>	'manifest_id',
	'paper_id'		=>	'paper_id',
	'supplier_invoice'	=>	'supplier_invoice',
);

%transforms = (
	'paper_id'		=> [ 's/\D//g' ],
	'po_id'		=> [ 's/\D//g' ],
	'docket'	=> [ 's/\D//g' ],
	'cost'		=> [ 's/[^\d\.]//g' ],
);

%defaults = (
	'cost'		=>	undef,
	'docket'	=>	undef,
	'po_id'		=>	undef,
	'paper_id'	=>	undef,
);

sub Paper {
	return new openprint::Paper( $_[0]{'paper_id'} );
} # end sub Paper

sub Manifest {
	return new openprint::Manifest( $_[0]{'manifest_id'} );
} # end sub Manifest

sub cost_from_po {
	my $Type = $_[0];
	my $PO = new openprint::PurchaseOrder( $Type->po_id() );
	my $PO_Stock;
	my $Paper = $Type->Paper();
	foreach my $POC ( $PO->Contents() ) {
		$log->debug($POC->description());
		next if $POC->type() ne $Paper->type().' Stock';
		my ( $weight ) = $POC->description() =~ /(\d+)lb/i;
		if ( $weight and $Paper->basis_weight() and ( $Paper->basis_weight() != $weight*2 ) ) {
			$log->debug("Wrong weight: $weight != " . $Paper->basis_weight() );
			next;
		} # end if
		my ( $width ) = $POC->description() =~ /([\.\d]+)in/i;
		if ( $width and $Paper->width() and ( $Paper->width() != $width ) ) {
			$log->debug("Wrong width: $width != " . $Paper->width() );
			next;
		} # end if
		$PO_Stock = $POC;
		last;
	} # end foreach POC
	return if ! $PO_Stock;
	return $PO_Stock->price();
} # end if

1;
__END__
