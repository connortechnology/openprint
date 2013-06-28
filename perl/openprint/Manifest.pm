package openprint::Manifest;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use openprint ();
use vars qw( $debug $table $serial %variable $log $dbh %config %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require sql;
require ssi;
require misc;

require openprint::Manifest_Content_Type;
require openprint::ManifestContent;
require openprint::PurchaseOrder;
require openprint::Company;

$table = 'manifests';
$serial = 'manifests_id_seq';

$debug = 1;

%fields = (
	'id'			=>	'id',
	'name'			=>	'name',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
	'received_on'	=>	'received_on',
	'supplier_id'	=>	'supplier_id',
	deleted			=>	'deleted',
);

%transforms = (
	'updated_on'	=> [ 's/.*//g' ],
	'supplier_id'	=>	[ 's/\D//g' ],
);

%defaults = (
	'created_on'	=>	'NOW()',
	'updated_on'	=>	'NOW()',
	'received_on'	=>	'NOW()',
	'supplier_id'	=>	undef,
	deleted	=>	0,
);

# Returns a paper object specified by the parameters
sub find {
	shift @_ if $_[0] eq 'openprint::Manifest';
	shift @_ if ref $_[0] eq 'openprint::Manifest';

	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my @values;
	my $sql = 'SELECT * FROM Manifests WHERE 1>0';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( $params{'id_like'} ) {
		$sql .= " AND id LIKE '%$params{id_like}%'";
	} # end if
	if ( exists $params{'name'} ) {
		if ( ref $params{'name'} eq 'ARRAY' ) {
			$sql .= ' AND name IN ('. join(',', map {'?'} @{$params{'name'}} ) . ')';
			push @values, @{$params{'name'}};
		} else {
			$sql .= ' AND name=?';
			push @values, $params{'name'};
		} # end if
	} # end if
	if ( $params{'name_like'} ) {
		$sql .= " AND name LIKE '%$params{name_like}%'";
	} # end if
	if ( $params{'name like'} ) {
		$sql .= ' AND name LIKE ?';
		push @values, $params{'name like'};
	} # end if
	if ( exists $params{'po_id'} ) {
		$sql .= ' AND ? IN (SELECT po_id FROM Manifest_Content_Types WHERE manifest_id=manifests.id)';
		push @values, $params{'po_id'};
	} # end if
	if ( exists $params{'supplier_id'} ) {
		if ( ref $params{'supplier_id'} eq 'ARRAY' ) {
			if ( @{$params{'supplier_id'}} ) {
				$sql .= ' AND supplier_id IN ('. join(',', map {'?'} @{$params{'supplier_id'}} ) . ')';
				push @values, @{$params{'supplier_id'}};
			} else {
				return ();
			} # end if
		} else {
			$sql .= ' AND supplier_id=?';
			push @values, $params{'supplier_id'};
		} # end if
	} # end if
	if ( exists $params{'docket'} ) {
			$sql .= ' AND ? IN (SELECT docket FROM Manifest_Content_Types WHERE manifest_id=manifests.id)';
			push @values, $params{'docket'};
	} # end if
	if ( exists $params{skid_id} ) {
		$sql  .= ' AND ? IN (SELECT skid_id FROM manifestcontents WHERE manifest_id=manifests.id)';
		push @values, $params{skid_id};
	} # end if
	if ( exists $params{rfidtag_id} ) {
		$sql  .= ' AND ? IN (SELECT rfidtag_id FROM manifestcontents WHERE manifest_id=manifests.id)';
		push @values, $params{rfidtag_id};
	} # end if
	if ( exists $params{manufacturers_id} ) {
		$sql  .= ' AND ? IN (SELECT manufacturers_id FROM manifestcontents WHERE manifest_id=manifests.id)';
		push @values, $params{manufacturers_id};
	} # end if

	if ( $params{'received_on_start'} and $params{'received_on_end'} ) {
		$sql .= ' AND ( received_on BETWEEN ? AND ? )';
		push @values, @params{'received_on_start','received_on_end'};
	} elsif ( $params{'received_on_start'} ) {
		$sql .= ' AND received_on >= ?';
		push @values, $params{'received_on_start'};
	} elsif ( $params{'received_on_end'} ) {
		$sql .= ' AND received_on <= ?';
		push @values, $params{'received_on_end'};
	} # end if

	if ( $params{'created_on_start'} and $params{'created_on_end'} ) {
		$sql .= ' AND ( created_on BETWEEN ? AND ? )';
		push @values, @params{'created_on_start','created_on_end'};
	} elsif ( $params{'created_on_start'} ) {
		$sql .= ' AND created_on >= ?';
		push @values, $params{'created_on_start'};
	} elsif ( $params{'created_on_end'} ) {
		$sql .= ' AND created_on <= ?';
		push @values, $params{'created_on_end'};
	} # end if
	if ( $params{'updated_on_start'} and $params{'updated_on_end'} ) {
		$sql .= ' AND ( updated_on BETWEEN ? AND ? )';
		push @values, @params{'updated_on_start','updated_on_end'};
	} elsif ( $params{'updated_on_start'} ) {
		$sql .= ' AND updated_on >= ?';
		push @values, $params{'updated_on_start'};
	} elsif ( $params{'updated_on_end'} ) {
		$sql .= ' AND updated_on <= ?';
		push @values, $params{'updated_on_end'};
	} # end if
   if ( exists $params{'deleted'} ) {
        if ( ref $params{'deleted'} eq 'ARRAY' ) {
            $sql .= ' AND (deleted IS NULL OR deleted IN (' . join(',', map {'?'} @{$params{'deleted'}}) . '))';
            push @values, @{$params{'deleted'}};
        } else {
            $sql .= ' AND deleted=?';
            push @values, $params{'deleted'};
        } # end if
    } else {
        $sql .= ' AND (deleted=? OR deleted IS NULL)';
        push @values, 0;
    } # end if

	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug("Error loading Manifest SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No Manifest loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded Manifest ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::Manifest( $_->{id}, $_ ) } @$data;
} # end sub find

sub destroy {
    my $self = shift;
	return if ! $$self{id};
    my $ac = sql::start_transaction( );
	foreach my $PO ( openprint::PurchaseOrder->find('manifest_id'=>$$self{id}) ) {
		$PO->save({'manifest_id'=>undef});
	} # end foreach $PO
	foreach my $C ( $self->Contents() ) {
		$C->delete();
	} # end foreach Content
	foreach my $T ( $self->Types() ) {
		$T->delete();
	} # end foreach Type
	
    sql::execute( undef, undef, q{DELETE FROM Manifests WHERE id=?}, $$self{'id'} );
    sql::end_transaction( undef, $ac );
	return $dbh->errstr() if $dbh->errstr();
	delete $openprint::Object::cache{'openprint::Manifest'}{$$self{'id'}};
	return '';
} # end sub destroy

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
			$params{manifest_id} = $$self{'id'};
			@{$$self{'Types'}} = openprint::Manifest_Content_Type->find(%params);
		} # end if
	} # end if
	return @{$$self{'Types'}} if $$self{'Types'};
	return;
} # end sub Types

sub Contents {
	my ( $self, %params ) = @_;
	if ( ( @_ == 2 ) and ( ref $_[1] eq 'ARRAY' ) ) {
		$$self{Contents} = $_[1];
	} elsif ( %params ) {
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

sub check {
	my ( $Manifest ) = @_;
	my @Contents = $Manifest->Contents();
	my %skid_ids;
	foreach ( @Contents ) {
		push @{$skid_ids{$$_{skid_id}}}, $_ if $$_{skid_id};
	} # end foreach
	my %manufacturer_ids;
	foreach ( @Contents ) {
		push @{$manufacturer_ids{$$_{manufacturers_id}}}, $_ if $$_{manufacturers_id};
	} # end foreach
	my $error;
	if ( keys %skid_ids != @Contents ) {
		foreach my $id ( keys %skid_ids ) {
			if ( @{$skid_ids{$id}} > 1 ) {
				$error .= "Skid $id is listed " . @{$skid_ids{$id}} . ' times<br/>';
			} # end if
		} # end foreach skid
	} # end if skid_ids duplicated
	my @mfg_ids = keys %manufacturer_ids;

	if ( @mfg_ids != @Contents ) {
		foreach my $id ( @mfg_ids ) {
			if ( @{$manufacturer_ids{$id}} > 1 ) {
				$error .= "Manufacturers $id is listed " . @{$manufacturer_ids{$id}} . ' times<br/>';
			} # end if
		} # end foreach manufacturer
	} # end if skid_ids duplicated
	foreach my $C ( @Contents ) {
		$error .= $C->check();
	} # end foreach C
	return $error;
} # end sub check

sub can_edit {
	return 1 if ! $_[0]{id};
	return 1 if $openprint::session{user_type} eq 'A';
	return 1 if $openprint::session{user_id} == $_[0]{created_by};
	return 1 if openprint::usergroup::is_user_in( ['Inventory','InventoryManager'], $openprint::session{user_id} );
	return 0;
} # end sub can_edit

sub can_see_pricing {
	return 1 if $openprint::session{user_type} eq 'A';
	return 1 if openprint::usergroup::is_user_in( ['Accounting','InventoryManager'], $openprint::session{user_id} );
	return 0;
} # end sub can_see_pricing

1;
__END__
