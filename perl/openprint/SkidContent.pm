package openprint::SkidContent;
@ISA = qw(openprint::Object);

use strict;

require sql;
use vars qw( $log $dbh %fields %transforms %defaults $table $serial );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

my $debug = 1;

%fields = (
	'id'			=>	'id',
	'skid_id'		=>	'skid_id',
	'paper_id'		=>	'paper_id',
	'quantity'		=>	'quantity',
	'purpose_id'	=>	'purpose_id',
	'units'			=>	'units',
);
%defaults = (
);
%transforms = (
);
$table = 'Skid_Contents';
$serial = 'skid_contents_id_seq';

sub find_one {
	my %params = @_;
	$params{'limit'}=1;
	my @Results = find(%params);
	return $Results[0] if @Results;
} # end sub find_one

sub find {
	my %params = @_;

	my $sql = 'SELECT * FROM Skid_Contents WHERE 1>0';
	my @values;
	if ( $params{'skid_id'} ) {
		$sql .= ' AND skid_id=?';
		push @values, $params{'skid_id'};
	} # end if
	if ( $params{'paper_id'} ) {
		$sql .= ' AND paper_id=?';
		push @values, $params{'paper_id'};
	} # end if
	if ( $params{'Paper'} ) {
		$sql .= ' AND paper_id=?';
		push @values, $params{'Paper'}->id();
	} # end if
	if ( exists $params{'quantity_>'} ) {
		$sql .= ' AND quantity > ?';
		push @values, $params{'quantity_>'};
	} # end if

	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$log->debug("openprint::SkidContent::find( $sql)" . $dbh->errstr);
		return;
	} elsif ( $debug ) {
		$log->debug("Loading openprint::SkidContent::find($sql) : @values # of results: " . @$data );
	} # end if
	return map { new openprint::SkidContent( $_->{id}, $_ ); } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;

	if ( (! $data) and $$self{'id'} ) {
		$data = $dbh->selectrow_hashref( 'SELECT * FROM Skid_Contents WHERE skid_id=? AND paper_id=?', {}, @$self{'skid_id','paper_id'} );
		if ( ! $data ) { $log->debug($dbh->errstr ); }
	} # end if
	@$self{keys %$data} = @$data{keys %$data};

} # end sub load

sub delete {
	my $self = shift;

    sql::execute( undef, undef, q{DELETE FROM Skid_Contents WHERE skid_id=? AND paper_id=? AND ( purpose_id=? OR purpose_id IS NULL)}, @$self{'skid_id','paper_id','purpose_id'} );
} # end sub delete

sub purpose {
	my $self = shift;
	return $self->Purpose()->name();
} # end sub purpose

sub Purpose {
	my $self = shift;
	my $Purpose = new openprint::StockPurpose( $$self{'purpose_id'} );
	return $Purpose;
} # end sub Purpose

sub Paper {
	my $self = shift;
	my $Paper = new openprint::Paper( $$self{'paper_id'} );
	return $Paper;
} # end sub Paper

sub Skid {
	return new openprint::Skid( $_[0]{'skid_id'} );
} # end sub Skid

1;

__END__
~       
