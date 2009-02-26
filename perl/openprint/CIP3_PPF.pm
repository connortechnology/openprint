package openprint::CIP3_PPF;
@ISA = qw(openprint::Object);

use strict;

require misc;
require sql;
require openprint::Object;
use openprint ();
use MIME::Base64;

use vars qw( $log $dbh $table $serial %fields %transforms %defaults );

my $debug = 1;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
$table = 'CIP3_PPF';
$serial = 'CIP3_PPF_id_seq';
%fields = (
	'id'			=>	'id',
	'created_on'	=>	'created_on',
	'data'			=>	'data',
	'data_length'	=>	'data_length',
	'signature'		=>	'signature',
	'side'			=>	'side',
	'docket'		=>	'docket',
);
%defaults = (
	'created_on'	=>	'NOW()',
);
%transforms = (
	'signature'		=> [ 's/\D//g' ],
);
sub find {
	my %params = @_;

	my $sql = 'SELECT * FROM ' . $table . ' WHERE 1>0';
	my @values;

	if ( exists $params{'docket'} ) {
		$sql .= ' AND docket=?';
		push @values, $params{'docket'};
	} # end if

	$sql .= " ORDER BY $params{order}" if $params{'order'};
	$sql .= " LIMIT $params{limit}" if $params{'limit'};
	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$log->debug("openprint::CIP3_PPF::find( $sql)" . $dbh->errstr);
	} else {
		if ( $debug ) {
			$log->debug("openprint::CIP3_PPF::find( $sql) : #of records:" . @$data );
		} # end if
		return map { new openprint::CIP3_PPF( $_->{id}, $_ ); } @$data;
	} # end if
} # end sub find

sub previews {
	my ( $self ) = @_;
	
	my @data = split("\n", base64_decode($$self{'data'}) );
	my @previews;

	my $line;
	for ( $line = 0; $line < @data; $line += 1 ) {	
		if ( $data[$line] =~ /^CIP3BeginPreviewImage/ ) {
			$line += 1;
			my $width;
			my $height;
			my $image;
			my $encoding;
			my $compression;
			while ( ($line < @data) ) {
				last if $data[$line] =~ /^CIP3EndPreviewImage/;
				if ( $data[$line] =~ /^\/CIP3PreviewImageWidth (\d+) def/ ) {
					$width = $1;
				} elsif ( $data[$line] =~ /^\/CIP3PreviewImageHeight (\d+) def/ ) {
					$height = $1;
				} elsif ( $data[$line] =~ /^\/CIP3PreviewImage (.*)/ ) {
					$line += 1;
					while ( ! $data[$line] =~ /^CIP3/ ) {
						$image .= $data[$line];
						$line += 1;
					} # end while
				} elsif ( $data[$line] =~ /^\/CIP3PreviewImageEncoding \/(\w+) def/ ) {
					$encoding = $1;
				} elsif ( $data[$line] =~ /^\/CIP3PreviewImageCompression \/(\w+) def/ ) {
					$compression = $1;	
				} # end if
				$line += 1;
			} # end while
			if ( $compression eq 'RunLengthDecode' ) {
				$image = misc::rle_decode( $image, $width, $height );
			} # end if
			push @previews, $image;
		} # end if found preview image				
	} # end for each line
	return @previews;

} # end sub preview

1;

__END__
~       
