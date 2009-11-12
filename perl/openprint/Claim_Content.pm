package openprint::Claim_Content;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use openprint ();
use vars qw(%variable $log $dbh %config $table $serial %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require sql;
require ssi;
require misc;

my $debug = 0;

$table = 'claim_contents';
$serial = 'claim_contents_id_seq';

%fields = (
	'id'				=>	'id',
	'claim_id'			=>	'claim_id',
	'skid_id'			=>	'skid_id',
	'quantity'			=>	'quantity',
	'reason'			=>	'reason',
	'cost'				=>	'cost',
	'cost_units'		=>	'cost_units',
);

%transforms = (
	'quantity'	=> [ 's/\D//g' ],
	'skid_id'	=> [ 's/\D//g' ],
	'cost'		=> [ 's/[^\d\.]//g' ],
);

%defaults = (
	'quantity'	=> 0,
	'skid_id'	=>	undef,
	'cost'		=>	undef,
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my @values;
	my $sql = 'SELECT * FROM Claim_Contents WHERE 1>0';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( $params{'skid_id'} ) {
		$sql .= ' AND skid_id=?';
		push @values, $params{'skid_id'};
	} # end if
	if ( $params{'claim_id'} ) {
		$sql .= ' AND claim_id=?';
		push @values, $params{'claim_id'};
	} # end if
	if ( $params{'id_like'} ) {
		$sql .= " AND id LIKE '%$params{id_like}%'";
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug("Error loading Claim_Content SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No Claim_Content loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded Claim_Content ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::Claim_Content( $_->{id}, $_ ) } @$data;
} # end sub find

sub Skid {
	return new openprint::Skid( $_[0]{skid_id} );
} # end sub Skid

sub Claim {
	return new openprint::Claim( $_[0]{claim_id} );
} # end sub Manifest

sub description {
	my ( $self ) = @_;
	my $description;
	foreach my $SkidContent ( $self->Skid()->Contents() ) {
		$description .= $SkidContent->Paper()->to_string().'<br/>';
	} # end foreach SkidContent

	return $description;
} # end sub description

sub total {
	my ( $self ) = @_;
	return sprintf('%.2f', $$self{'cost'} * $$self{'quantity'}/100 );
} # end sub total

sub save {
	my ( $self, $hash ) = @_;
	if ( $$self{'id'} ) {
		return $self->SUPER::save( $hash );
	} else {
		my $rc = $self->SUPER::save( $hash );	
		my $Claim = $self->Claim();
		if ( ! sets::isin( $$self{'id'}, [ map { $_->id() } $Claim->Contents() ] ) ) {
			push @{$$Claim{'Contents'}}, $self;
		} # end if
		return $rc;
	} # end if
} # end sub save

1;
__END__
