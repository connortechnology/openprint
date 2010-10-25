package openprint::PurchaseOrder_Content;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use openprint ();
use vars qw(%variable $log $dbh $table $serial %config %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require sql;
require openprint::PurchaseOrder_ContentType;

my $debug = 0;
$table = 'PurchaseOrder_Contents';
$serial = 'PurchaseOrder_Contents_id_seq';

%fields = (
	'id'			=>	'id',
	'po_id'			=>	'po_id',
	'created_on'	=>	'created_on',
	'qty'			=>	'qty',
	'price'			=>	'price',
	'total'			=>	'total',
	'item'			=>	'item',
	'docket'		=>	'docket',
	'description'	=>	'description',
	'type_id'		=>	'type_id',
);

%transforms = (
	'price'			=>	[ 's/[^\-\d\.]//g' ],
	'total'			=>	[ 's/[^\-\d\.]//g' ],
	'qty'			=>	[ 's/[^\-\d\.]//g' ],
);

%defaults = (
	'po_id'			=>	undef,
	'created_on'	=> q`'NOW()'`,
	'price'			=>	undef,
	'total'			=>	undef,
	'qty'			=>	undef,
	'type_id'		=>	undef,
);

sub PurchaseOrder {
	return new openprint::PurchaseOrder( $_[0]{po_id} );
} # end sub Supplier

sub Type {
	return new openprint::PurchaseOrder_ContentType( $_[0]{type_id} );
} # end sub Type

sub units {
	my ( $self ) = @_;
	if ( $self->Type()->name() eq 'Roll Stock' ) {
		return 'lbs';
	} elsif ( $self->Type()->name() eq 'Sheet Stock' ) {
		return 'sheets';
	} # end if
	return;
} # end sub units

1;
__END__
