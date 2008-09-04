package openprint::PurchaseOrder;
@ISA = qw(openprint::Object);
require openprint::Object;
use MIME::QuotedPrint;

use strict;
use openprint ();
use vars qw(%variable $log $dbh %config %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require sql;
require ssi;
require misc;
require openprint::Company;
require openprint::Currency;
require openprint::User;

my $debug = 1;

%fields = (
	'id'			=>	'id',
	'currency_id'	=>	'currency_id',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
	'created_by'	=>	'created_by',
	'delivered_on'	=>	'delivered_on',
	'total'			=>	'total',
	'deleted'		=>	'deleted',
);

%transforms = (
);

%defaults = (
	'created_on'	=> 'NOW()',
	'updated_on'	=> 'NOW()',
	'deleted'		=>	0,
	'currency_id'	=> $openprint::session{'Currency_id'},
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my @values;
	my $sql = 'SELECT * FROM PurchaseOrders WHERE 1>0';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( $params{'created_on_start'} and $params{'created_on_end'} ) {
		$sql .= ' AND ( created_on BETWEEN ? AND ? )';
		push @values, @params{'created_on_start','created_on_end'}
	} elsif ( $params{'created_on_start'} ) {
		$sql .= ' AND ( created_on >= ?)';
		push @values, $params{'created_on_start'};
	} elsif ( $params{'created_on_end'} ) {
		$sql .= ' AND ( created_on <= ?)';
		push @values, $params{'created_on_end'};
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug("Error loading PurchaseOrders SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$openprint::log->debug('No PurchaseOrders loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$openprint::log->debug("Debug loaded PurchaseOrders ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::PurchaseOrder( $_->{id}, $_ ) } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
#
#$openprint::log->debug("Loading label $$self{id}") if $debug;
		$data = $openprint::dbh->selectrow_hashref( q{SELECT * FROM PurchaseOrders WHERE id=?}, {}, $$self{'id'} );
#$openprint::log->debug("Loading label $$self{id} $$data{data}") if $debug;
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
	delete $$self{'data'};
	%{$$self{'data'}} = sql::execute( undef, undef, 'SELECT name, value FROM label_Data WHERE label_id=?', $$self{'id'} );
} # end sub load

sub save {
	my ( $self, $hash ) = @_;

	if ( $hash ) {
		$self->set( $hash );
	} # end if

	my %sql;
	foreach my $k ( keys %fields ) {
		$sql{$k} = $$self{$k};
	} # end foreach
	delete $sql{'created_on'};

	my $ac = sql::start_transaction( $openprint::dbh );
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('PurchaseOrders_id_seq')} );
		$sql{'id'} = $$self{'id'};

		if ( my $error = sql::insert( undef, undef, 'PurchaseOrders', \%sql ) ) {
			$$self{'id'} = undef;
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if

    } else {
		if ( my $error = sql::update( undef, undef, 'PurchaseOrders', ['id=?', $$self{id}], [map { $_, $$self{$_} } keys %fields ] ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
    } # end if

	sql::end_transaction( $openprint::dbh, $ac );
	$self->load();
	return;
} # end sub save

sub delete {
	my $self = shift;
	return sql::update( undef, undef, 'PurchaseOrders', ['id=?', $$self{id}], 'deleted',1 );
} # end sub delete

sub destroy {
    my $self = shift;
    my $ac = sql::start_transaction( );
    #sql::execute( undef, undef, q{DELETE FROM PurchaseOrder_data WHERE label_id=?}, $$self{'id'} );
    sql::execute( undef, undef, q{DELETE FROM PurchaseOrders WHERE id=?}, $$self{'id'} );
    sql::end_transaction( undef, $ac );
} # end sub delete

sub copy {
	my $self = shift;
	my $new = new openprint::PurchaseOrder();
	@$new{keys %fields} = @$self{keys %fields};
	delete $$new{'id'};
	#foreach my $k ( keys %{$$self{'data'}} ) {
		#$$new{'data'}{$k} = $$self{'data'}{$k};
	#} # end foreach
	return $new;
} # end sub copy

sub Currency {
	my ( $self ) = @_;
	if ( ! $$self{'currency_id'} ) {
		$$self{'currency_id'} = openprint::Currency::get_current()->id();
	} # end if
	return new openprint::Currency( $_[0]{currency_id} );
} # end sub Currency
sub Supplier {
	return new openprint::Company( $_[0]{supplier_id} );
} # end sub Supplier
sub Creator {
	return new openprint::User( $_[0]{created_by} );
} # end sub Creator

1;
__END__
