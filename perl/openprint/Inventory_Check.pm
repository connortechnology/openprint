use strict;
package openprint::Inventory_Check;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 0;
$table = 'inventory_checks';
$serial= 'inventory_checks_id_seq';
%fields = (
	id		=>	'id',
	name	=>	'name',
	created_on	=>	'created_on',
	started_on	=>	'started_on',
	contains	=>	'contains', # 'sheets','rolls', etc'
	ended_on	=>	'ended_on',
	scanner_id	=>	'scanner_id',
	deleted		=>	'deleted',
);
%transforms = (
	name	=> [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%defaults = (
	created_on	=>	q`'NOW()'`,
	started_on	=>	q`'NOW()'`,
	scanner_id	=>	undef,
	deleted		=>	'0',
);

sub name {
	if ( @_ > 1 ) {
		$_[0]{name} = $_[1];
	}
	if ( ! $_[0]{name} ) {
		return $_[0]{id};
	}
	return $_[0]{name};
}

sub link_to {
	return sprintf(
		'<a href="/employee/inventory/check.html?check_id=%d">%s</a>'
		, $_[0]{id},
		( $_[0]{name} ? $_{name} : $_[0]{id} . ' started on ' . $_[0]{started_on} )
	 );
} # end sub link_to

sub Entries {
	if ( ! $_[0]{Entries} ) {
		$_[0]{Entries} = [ openprint::Inventory_Check_Entry->find( ic_id => $_[0]{id} ) ];
	}
	return @{$_[0]{Entries}};
} # end sub Entries

1;
__END__
