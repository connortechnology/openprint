package openprint::Invoice_Interest;
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
use vars qw( $table $serial %fields %defaults %transforms );

$table = 'invoice_interests';
$serial = 'invoice_interests_id_seq';

require sql;

%fields = (
	'id'				=>	'id',
	'amount'			=>	'amount',
	'created_on'		=>	'created_on',
	'updated_on'		=>	'updated_on',
	'description'		=>	'description',
	'compounded_on'		=>	'compounded_on',
	'invoice_id'		=>	'invoice_id',
);

%transforms = (
);
%defaults = (
	'invoice_id'	=>	undef,
	'created_on'	=> 'NOW()',
	'updated_on'	=> 'NOW()',
	'amount'		=>	0,
);

sub find {
	my %params = @_;

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

	if ( $params{'compounded_on_start'} and $params{'compounded_on_end'} ) {
		$sql .= ' AND ( compounded_on BETWEEN ? AND ? )';
		push @values, @params{'compounded_on_start','compounded_on_end'};
	} elsif ( $params{'compounded_on_start'} ) {
		$sql .= ' AND compounded_on >= ?';
		push @values, $params{'compounded_on_start'};
	} elsif ( $params{'compounded_on_end'} ) {
		$sql .= ' AND compounded_on <= ?';
		push @values, $params{'compounded_on_end'};
	} elsif ( $params{'compounded_on'} ) {
		$sql .= ' AND compounded_on = ?';
		push @values, $params{'compounded_on'};
	} # end if

	if ( $params{'order'} ) {
		$sql .= " ORDER BY $params{'order'}";
	} # end if

	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$log->warn("Error loading Invoice_Interests: ($sql) (@values)" . $dbh->errstr );
		return;
	} elsif ($debug ) {
		$log->debug("openprint::Invoice_Interest::find($sql) (@values)");
	} # end if
	return map { new openprint::Invoice_Interest( $_->{id}, $_ ); } @$data;
} # end sub find

sub delete {
	my $self = shift;
    return sql::execute( undef, undef, q{DELETE FROM Invoice_Interests WHERE id=?}, $$self{'id'} );
} # end sub delete

sub destroy {
	my $self = shift;
    return sql::execute( undef, undef, q{DELETE FROM Invoice_Interests WHERE id=?}, $$self{'id'} );
} # end sub destroy

sub Invoice {
	return new openprint::Invoice( $_[0]{invoice_id} );
} # end sub Order

1;

__END__
~       
