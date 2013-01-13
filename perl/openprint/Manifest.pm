use strict;
package openprint::Manifest;
our @ISA = qw(openprint::Object);
require openprint::Object;

use openprint ();
use vars qw( $debug $table $serial %find_fields %fields %transforms %defaults );

require sql;
require openprint::Manifest_Content_Type;
require openprint::ManifestContent;
require openprint::PurchaseOrder;
require openprint::Company;

$table = 'manifests';
$serial = 'manifests_id_seq';

$debug = 0;

%fields = (
	id			=>	'id',
	name		=>	'name',
	created_on	=>	'created_on',
	updated_on	=>	'updated_on',
	received_on	=>	'received_on',
	supplier_id	=>	'supplier_id',
);

%find_fields = (
	docket	=>	'(SELECT docket FROM Manifest_Content_Types WHERE manifest_id=manifests.id)',
	po_id	=>	'(SELECT po_id FROM Manifest_Content_Types WHERE manifest_id=manifests.id)',
);

%transforms = (
    name		=>	[ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
	updated_on	=>	[ 's/.*//g' ],
	supplier_id	=>	[ 's/\D//g' ],
);

%defaults = (
	'created_on'	=>	'NOW()',
	'updated_on'	=>	'NOW()',
	'received_on'	=>	'NOW()',
	'supplier_id'	=>	undef,
);

sub delete {
    my $self = shift;
    my $ac = sql::start_transaction( $openprint::dbh );
	foreach my $PO ( openprint::PurchaseOrder->find('manifest_id'=>$$self{'name'}) ) {
		$PO->save({'manifest_id'=>undef});
	} # end foreach $PO
	foreach my $C ( $self->Contents() ) {
		$C->delete();
	} # end foreach Content
	foreach my $T ( $self->Types() ) {
		$T->delete();
	} # end foreach Type
	
    sql::execute( undef, undef, q{DELETE FROM Manifests WHERE id=?}, $$self{'id'} );
    sql::end_transaction( $openprint::dbh, $ac );
	return $openprint::dbh->errstr() if $openprint::dbh->errstr();
	delete $openprint::Object::cache{'openprint::Manifest'}{$$self{'id'}};
	return '';
} # end sub delete

sub Types {
	my ( $self, %params ) = @_;
	if ( %params ) {
		if ( $$self{'id'} ) {
			$params{'manifest_id'} = $$self{'id'};
			return openprint::Manifest_Content_Type->find(%params);
		} # end if
	} # end if
	if ( ! $$self{'Types'} ) {
		if ( $$self{'id'} ) {
			$params{'manifest_id'} = $$self{'id'};
			@{$$self{'Types'}} = openprint::Manifest_Content_Type->find(%params);
		} # end if
	} # end if
	return @{$$self{'Types'}} if $$self{'Types'};
	return;
} # end sub Types

sub Contents {
	my ( $self, %params ) = @_;
	if ( %params ) {
		if ( $$self{'id'} ) {
			return openprint::ManifestContent->find('manifest_id'=>$$self{id}, %params );
		} # end if
	} # end if
	if ( ! $$self{'Contents'} ) {
		if ( $$self{'id'} ) {
			@{$$self{'Contents'}} = openprint::ManifestContent->find('manifest_id'=>$$self{id} );
		} # end if
	} # end if
	return @{$$self{'Contents'}} if $$self{'Contents'};
	return;
} # end sub Contents

sub Vendor {
	return new openprint::Company( $_[0]{'supplier_id'} );
} # end sub Vendor

sub po_ids {
	return sets::union( map { $_->po_id() } $_[0]->Types() );
} # end sub po_ids
sub dockets {
	return sets::union( map { $_->docket() } $_[0]->Types() );
} # end sub dockets
sub link_to {
	return '<a href="/employee/inventory/manifest.html?manifest_id='.$_[0]{'id'}.'">'.$_[0]{'name'}.'</a>';
} # end sub link_to

1;
__END__
