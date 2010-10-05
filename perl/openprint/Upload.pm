package openprint::Upload;
@ISA = qw( openprint::Object );
use strict;

require openprint::Company;
require openprint::File;
use openprint ();
use vars qw( $log $dbh $table $serial %fields %transforms %defaults );

*log = \$openprint::log;
*dbh = \$openprint::dbh;

$table = 'uploads';
$serial = 'upload_id_seq';
%fields = (
	'start'	=>	'start',
	'size'	=>	'size',
	'total'	=>	'total',
	'id'	=>	'id',
	'finished'	=>	'finished',
	'company_id'	=>	'company_id',
	'user_id'		=>	'user_id',
	'company'		=>	'company',	
	'type'			=>	'type',
);

my $debug = 1;

sub find {
	my %params = @_;
	my $sql = q{SELECT * FROM Uploads WHERE 1>0};
	my @values;
	if ( $params{'company_id'} ) {
		$sql .= q{ AND company_id=?};
		push @values, $params{'company_id'};
	} # end if
	if ( $params{'started_on_start'} and $params{'started_on_end'} ) {
		$sql .= q{ AND (start BETWEEN ? AND ?)};
		push @values, $params{'started_on_start'},$params{'started_on_end'};
	} elsif ( $params{'started_on_start'} ) {
		$sql .= q{ AND started_on >= ?};
		push @values, $params{'started_on_start'};
	} elsif ( $params{'started_on_end'} ) {
		$sql .= q{ AND started_on <= ?};
		push @values, $params{'started_on_end'};
	} # end if

	$sql .= " ORDER BY $params{'order'}" if ( $params{'order'} );
	$sql .= " LIMIT $params{'limit'}" if ( $params{'limit'} );
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->error("Error loading Upload: ($sql) (@values)");
		return;
	} elsif ( $debug ) {
		$openprint::log->debug("Loading Upload: ($sql) (@values) (".@$data.')');
	} # end if
	return map { new openprint::Upload( $_->{id}, $_ ); } @$data;
} # end sub find

sub Company {
	my $self = shift;
	return new openprint::Company($$self{company_id});
} # end sub Company

sub User {
	my $self = shift;
	return new openprint::User($$self{user_id});
} # end sub User

sub Files {
	my $self = shift;
	return openprint::File::find('upload_id'=>$$self{id});
} # end sub

sub total_text {
	my ( $self ) = @_;
	return misc::format_bytes( $$self{'total'} );
} #end sub total_text
sub size_text {
	my ( $self ) = @_;
	return misc::format_bytes( $$self{'size'} );
} #end sub size_text
1;
__END__

