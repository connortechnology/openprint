package openprint::Invoiced_Product;
@ISA = qw(openprint::Object);

use vars qw( %config $log $dbh %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
use MIME::QuotedPrint;
use MIME::Base64;

my $debug = 0;

use strict;
use vars qw( $table $serial %fields %defaults %transforms %find_cache );

$table = 'invoiced_products';
$serial = 'invoiced_products_id_seq';

require sql;

%fields = (
	'id'				=>	'id',
	'price'				=>	'price',
	'quantity'			=>	'quantity',
	'invoice_id'		=>	'invoice_id',
	'product_id'		=>	'product_id',
	'description'		=>	'description',
);

%transforms = (
);
%defaults = (
	'invoice_id'	=>	undef,
	'product_id'	=>	undef,
	'price'			=>	0,
	'quantity'		=>	undef,
);

sub find {
	my %params = @_;
	my $hash_key = join(';',map { $_, ref $params{$_} eq 'HASH' ? join(';',%{$params{$_}}) : $params{$_} } sort keys %params );
	return map { new openprint::Invoiced_Product( $_ ) } @{$find_cache{$hash_key}} if $find_cache{$hash_key};

	my $sql = 'SELECT * FROM ' . $table . ' WHERE 1>0';
	my @values;
	if ( $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= q{ AND id IN (}.join(',', map {'?'} @{$params{'id'}} ).')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= q{ AND id=?};
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( $params{'invoice_id'} ) {
		if ( ref $params{'invoice_id'} eq 'ARRAY' ) {
			$sql .= q{ AND invoice_id IN (}.join(',', map {'?'} @{$params{'invoice_id'}} ).')';
			push @values, @{$params{'invoice_id'}};
		} else {
			$sql .= q{ AND invoice_id=?};
			push @values, $params{'invoice_id'};
		} # end if
	} # end if

	if ( $params{'order'} ) {
		$sql .= " ORDER BY $params{'order'}";
	} # end if

	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$log->warn("Error loading Invoiced_Products: ($sql) (@values)" . $dbh->errstr );
		return;
	} elsif ($debug ) {
		$log->debug("openprint::Invoiced_Product::find($sql) (@values)");
	} # end if
	@{$find_cache{$hash_key}} = map { $_->{id} } @$data;
	return map { new openprint::Invoiced_Product( $_->{id}, $_ ); } @$data;
} # end sub find

sub Invoice {
	return new openprint::Invoice( $_[0]{invoice_id} );
} # end sub Invoice

sub Product {
	return new openprint::Product( $_[0]{product_id} );
} # end sub Product

sub name {
	return $_[0]->Product()->name();
} # end sub name

sub total {
	my ( $self ) = @_;
	return $$self{'quantity'} * $$self{'price'};
} # end sub total

sub description {
	my ( $self ) = @_;
	if ( ( ! $$self{'description'} ) and $$self{'product_id'} ) {
		$$self{'description'} = $self->Product()->name();
	} # end if
	return $$self{'description'};
} # end if

1;

__END__
~       
