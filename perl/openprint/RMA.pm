use strict;
package openprint::RMA;
our @ISA = qw(openprint::Object);

require openprint::RMA_Type;
require openprint::RMA_Status;

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 1;
$table = 'rma';
$serial = 'rma_id_seq';
%fields = (
	id			=>	'id',
	company_id	=>	'company_id',
	user_id		=>	'user_id',
	project_id	=>	'project_id',
	order_id	=>	'order_id',
	type_id		=>	'type_id',
	type		=>	undef,
	created_on	=>	'created_on',
	updated_on	=>	'updated_on',
	description	=>	'description',
	comments	=>	'comments',
	rmanumber	=>	'rmanumber',
	approved	=>	'approved',
	status_id	=>	'status_id',
	status		=>	undef,
	priority	=>	'priority',
	po_id		=>	'po_id',
	received_on	=>	'received_on',
	warranty	=>	'warranty',
	estimate_required	=>	'estimate_required',
	product_id	=>	'product_id',
	serialnumber		=>	'serialnumber',
	accessories			=>	'accessories',
);

%transforms = (
	id				=>	[ 's/\D//g' ],
	description		=>	[ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
	comments		=>	[ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
	rmanumber		=>	[ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
	serialnumber	=>	[ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
	accessories		=>	[ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);

%defaults = (
	company_id	=>	undef,
	user_id		=>	undef,
	project_id	=>	undef,
	order_id	=>	undef,
	type_id		=>	undef,
	status_id	=>	undef,
	created_on	=>	q`'NOW()'`,
	received_on	=>	q`'NOW()'`,
	approved	=>	0,
	status		=>	undef,
	priority	=>	undef,
	po_id		=>	undef,
	estimate_required	=>	undef,
	warranty	=>	undef,
);

sub Type {
	return new openprint::RMA_Type( $_[0]{'type_id'} );
} # end sub Type

sub type {
	if ( @_ > 1 ) {
		my $type = openprint::RMA_Type->transform( 'name', $_[0] );
		my $Type = openprint::RMA_Type->find_one( 'name lc' => lc $type );
		if ( ! $Type ) {
			$Type = new openprint::RMA_Type();
			$Type->set(name=>$type);
		} # end if

		@{$_[0]}{'type_id','type'} = @$Type{'id','name'};
	} elsif ( $_[0]{type_id} and ! $_[0]{'type'} ) {
		$_[0]{type} = new openprint::RMA_Type( $_[0]{type_id} )->name();
	} # end if
	return $_[0]{type};
} # end sub type

sub status {
	if ( @_ > 1 ) {
		my $status = openprint::RMA_Status->transform( 'name', $_[0] );
		my $Status = openprint::RMA_Status->find_one( 'name lc' => lc $status );
		if ( ! $Status ) {
			$Status = new openprint::RMA_Status();
			$Status->set(name=>$status);
		} # end if

		@{$_[0]}{'status_id','status'} = @$Status{'id','name'};
	} elsif ( $_[0]{status_id} and ! $_[0]{status} ) {
		$_[0]{status} = new openprint::RMA_Status( $_[0]{status_id} )->name();
	} # end if
	return $_[0]{status};
} # end sub type
1;
__END__
