package openprint::Payment;
@ISA = qw(openprint::Object);

use vars qw( %config $log $dbh %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
use MIME::QuotedPrint;
use MIME::Base64;

my $debug = 1;

use strict;
use vars qw( %fields %defaults %transforms );

require sql;

%fields = (
	'id'				=>	'id',
	'order_id'			=>	'order_id',
	'recipient_id'		=>	'owner_id',
	'payor_id'		=>	'payor_id',
	'amount'			=>	'amount',
	'created_on'		=>	'created_on',
	'method'			=>	'method',
	'currency_id'		=>	'currency_id',
	'transaction_id'	=>	'transaction_id',
	'description'		=>	'description',
	'completed'			=>	'completed',
	
);

%transforms = (
);
%defaults = (
	'order_id'		=>	undef,
	'created_on'	=> 'NOW()',
	'updated_on'	=> 'NOW()',
	'completed'		=>	0,
);

sub find {
	my %params = @_;

	my $sql = q{SELECT * FROM Payments WHERE 1>0};
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
	if ( $params{'payor_id'} ) {
		if ( ref $params{'payor_id'} eq 'ARRAY' ) {
			$sql .= q{ AND payor_id IN (}.join(',', map {'?'} @{$params{'payor_id'}} ).')';
			push @values, @{$params{'payor_id'}};
		} else {
			$sql .= q{ AND payor_id=?};
			push @values, $params{'payor_id'};
		} # end if
	} # end if
	if ( $params{'recipient_id'} ) {
		if ( ref $params{'recipient_id'} eq 'ARRAY' ) {
			$sql .= q{ AND owner_id IN (}.join(',', map {'?'} @{$params{'recipient_id'}} ).')';
			push @values, @{$params{'recipient_id'}};
		} else {
			$sql .= q{ AND owner_id=?};
			push @values, $params{'recipient_id'};
		} # end if
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

	if ( $params{'deleted'} ) {
		$sql .= ' AND deleted=?';
		push @values, $params{'deleted'};
	} else {
		$sql .= ' AND deleted=?';
		push @values, 0;
	} # end if
	if ( $params{'completed'} ) {
		$sql .= ' AND completed=?';
		push @values, $params{'completed'};
	} # end if
	if ( $params{'order_id'} ) {
		$sql .= ' AND order_id=?';
		push @values, $params{'order_id'};
	} # end if

	if ( $params{'order'} ) {
		$sql .= " ORDER BY $params{'order'}";
	} # end if

	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->warn("Error loading Payments: ($sql) (@values)" . $openprint::dbh->errstr );
		return;
	} elsif ($debug ) {
		$openprint::log->debug("openprint::Payment::find($sql) (@values)");
	} # end if
	return map { new openprint::Payment( $_->{id}, $_ ); } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;

	if ( (! $data) and $$self{'id'} ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Payments WHERE id=?', {}, $$self{'id'} );
		if ( ! $data ) { $openprint::log->debug($openprint::dbh->errstr ); }
	} # end if
	@$self{keys %fields} = @$data{keys %fields};
} # end sub load

sub delete {
	my $self = shift;
	return sql::update( undef, undef, 'Payments', ['id=?', $$self{'id'} ], 'deleted', 1 );
} # end sub delete

sub destroy {
	my $self = shift;
    return sql::execute( undef, undef, q{DELETE FROM Payments WHERE id=?}, $$self{'id'} );
} # end sub destroy

sub save {
	my ( $self, $param ) = @_;
	
	$self->set( $param ) if $param;

	my %sql;
	foreach my $k ( keys %fields ) {
		$sql{$k} = $$self{$k};
	} # end foreach

	my $ac = sql::start_transaction( $openprint::dbh );
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('payments_id_seq')});
		$sql{'id'} = $$self{id};
		if ( my $error = sql::insert( undef, undef, 'Payments', \%sql ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
	} else {
		if ( my $error = sql::update( undef, undef, 'Payments', ['id=?', $$self{'id'}], \%sql ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
	} # end if
	sql::end_transaction( $openprint::dbh, $ac );
	$self->load();
	return '';
} # end sub save

sub copy {
	my $self = shift;
	my $new = new openprint::Payment();
	@$new{keys %$self} = @$self{keys %$self};
	$$new{'id'} = undef;
	return $new;
} # end sub

sub Payor {
	return new openprint::Company( $_[0]{payor_id} );
} # end sub Payor

sub Recipient {
	return new openprint::Company( $_[0]{owner_id} );
} # end sub Recipient

sub Currency {
	return new openprint::Currency( $_[0]{currency_id} );
} # end sub Currency
sub Order {
	return new openprint::Order( $_[0]{order_id} );
} # end sub Order

1;

__END__
~       
