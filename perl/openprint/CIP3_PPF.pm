package openprint::CIP3_PPF;
@ISA = qw(openprint::Object);

use strict;

require misc;
require sql;
require openprint::Object;
use openprint ();
use MIME::Base64;
use Text::PDF;
use Text::PDF::Filter;
use Image::Magick;

use vars qw( $log $dbh %config $table $serial %fields %transforms %defaults );

my $debug = 1;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

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
	'deleted'		=>	'deleted',
);
%defaults = (
	'created_on'	=>	'NOW()',
	'deleted'		=>	0,
);
%transforms = (
	'signature'		=> [ 's/\D//g' ],
);
sub find {
	my %params = @_;

	my $sql = 'SELECT ';
	$sql .= 'DISTINCT' if $params{'distinct'};
	$sql .= ' * FROM ' . $table . ' WHERE 1>0';
	my @values;

	if ( exists $params{'docket'} ) {
		$sql .= ' AND docket=?';
		push @values, $params{'docket'};
	} # end if
	if ( exists $params{'signature'} ) {
		$sql .= ' AND signature=?';
		push @values, $params{'signature'};
	} # end if
	if ( exists $params{'side'} ) {
		$sql .= ' AND side=?';
		push @values, $params{'side'};
	} # end if
	if ( $params{'deleted'} ) {
		$sql .= ' AND deleted=?';
		push @values, $params{'deleted'};
	} else {
		$sql .= ' AND deleted=?';
		push @values, 0;
	} # end if

	$sql .= " ORDER BY $params{order}" if $params{'order'};
	$sql .= " LIMIT $params{limit}" if $params{'limit'};
	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$log->debug("openprint::CIP3_PPF::find( $sql) @values reason:" . $dbh->errstr);
		return;
	} # end if

	if ( $debug ) {
		$log->debug("openprint::CIP3_PPF::find($sql) (@values): #of records:" . @$data );
	} # end if
	return map { new openprint::CIP3_PPF( $_->{id}, $_ ); } @$data;
} # end sub find

sub parseSheet {
	my $sheet = shift;
	while ( @_ ) {
		my $line = shift;
		if ( $line =~ /^CIP3AdmWorkStyle \/(\w+) def$/ ) {
			$$sheet{'WorkStyle'} = $1;
		} elsif ( $line =~ /^CIP3AdmPaperExtent \[ ([\d\.]+) ([\d\.]+) \] def$/ ) {
			$$sheet{'StockWidth'} = $1;
			$$sheet{'StockHeight'} = $2;
		} elsif ( $line =~ /^CIP3BeginFront/ ) {
			$$sheet{'Front'} = {};
			@_ = parseSide( $$sheet{'Front'}, @_ );
		} elsif ( $line =~ /^CIP3BeginBack/ ) {
			$$sheet{'Back'} = {};
			@_ = parseSide( $$sheet{'Back'}, @_ );
		} elsif ( $line =~ /^CIP3EndSheet/ ) {
			last;
		} # end if
	} # end while
	return @_;
} # end sub parseSheet

sub parseSide {
	my $front = shift;
	while ( @_ ) {
		my $line = shift;
		if ( $line =~ /^CIP3BeginPreviewImage$/ ) {
			my $preview = {};
			@_ = parsePreviewImage( $preview, @_ );
			push @{$$front{'previews'}}, $preview;
		} elsif ( $line =~ /^CIP3EndFront$/ ) {
			last;
		} elsif ( $line =~ /^CIP3EndBack$/ ) {
			last;
		} # end if
	} # end while
	return @_;
} # end sub parseFront

sub parsePreviewImage {
	my $image = shift;
	while ( @_ ) {
		my $line = shift;
		if ( $line =~ /^\( Separation preview for ink: "(\w+)" \) CIP3Comment/ ) {
			my $separation = {};
			$$separation{'ink'} = $1;
			$line = shift;
			if ( $line =~ /^CIP3BeginSeparation$/ ) {
				@_ = parseSeparation( $separation, @_ );
				push @{$$image{'separations'}}, $separation;
			} # end if
		} elsif ( $line =~ /^CIP3EndPreviewImage/ ) {
			last;
		} # end if
		
	} # end while
	return @_;	
} # end sub parsePreviewImage

sub parseSeparation {
	my $image = shift;
	while ( @_ ) {
		my $line = shift;
		if ( $line =~ /^\/CIP3PreviewImageWidth (\d+) def/ ) {
			$$image{'width'} = $1;
		} elsif ( $line =~ /^\/CIP3PreviewImageHeight (\d+) def/ ) {
			$$image{'height'} = $1;
		} elsif ( $line =~ /^\/CIP3PreviewImageEncoding \/(\w+) def/ ) {
			$$image{'encoding'} = $1;
		} elsif ( $line =~ /^\/CIP3PreviewImageCompression \/(\w+) def/ ) {
			$$image{'compression'} = $1;	
		} elsif ( $line =~ /^CIP3PreviewImage$/ ) {
			$line = shift;
			my @image_data;
			while ( ! ( $line =~ /^CIP3EndSeparation/ ) ) {
				push @image_data, $line;
				$line = shift;
			} # end while
			$$image{'image'} = join("\r\n", @image_data);
			$log->debug("Got image data for $$image{ink} lines: " . @image_data . " length: " . length($$image{'image'}) );
			last;
		} elsif ( $line =~ /^CIP3EndSeparation/ ) {
			last;
		} else {
			$log->warn("UNknown line: $line in parseSeparation");
		} # end if
	} # end while
	return @_;
} # end sub parsePreviewImage

sub parse {
	my ( $self ) = @_;

	$$self{'parsed'} = 1;
	
	my @data = split("\r\n", decode_base64($$self{'data'}) );
	while ( @data ) {
		my $line = shift @data;
		if ( $line =~ /^CIP3BeginSheet$/ ) {
			my $sheet = {};	
			@data = parseSheet( $sheet, @data );
			push @{$$self{'sheets'}}, $sheet;
		} # end if
	} # end while
} # end sub parse;


sub previews {
	my ( $self, $side ) = @_;
	
	if ( ! $$self{'parsed'} ) {
		$self->parse();
	} # end if
	my @previews;

	if ( $$self{'sheets'} ) {
		foreach my $sheet ( @{$$self{'sheets'}} ) {
			if ( $$sheet{'Front'} and ( (!$side) or ($side eq 'Front') ) ) {
#$openprint::log->debug("Adding front previews");
				push @previews, @{$$sheet{'Front'}{'previews'}} if $$sheet{'Front'}{'previews'};
			} # end if
			if ( $$sheet{'Back'} and ( (!$side) or ($side eq 'Back') ) ) {
#$openprint::log->debug("Adding back previews");
				push @previews, @{$$sheet{'Back'}{'previews'}} if $$sheet{'Back'}{'previews'};
			} # end if

			#if ( $$image{'compression'} eq 'RunLengthDecode' ) {
#$openprint::log->debug("Compression was RunLengthDecode" . (length $$image{'image'} ) .','.$$image{'width'}.'x'.$$image{'height'} );
				#my $f = Text::PDF::RunLengthDecode->new();
				#$$image{'image'} = $f->outfilt($$image{'image'}, 1);
#$openprint::log->debug("Compression was RunLengthDecode" . (length $$image{'image'} ) .','.$$image{'width'}.'x'.$$image{'height'} );
			#} # end if
		} # end foreach sheet
	} # end if sheets
#$openprint::log->debug("Previews: " . @previews );
	return @previews;
} # end sub previews

sub generate_previews {
	my ( $self, $path ) = @_;

	$path = $config{'SkinPath'} . '/images/previews/' if ! $path;
	my $part_path = '';
	foreach my $e ( split ('/', $path ) ) {
		$part_path .= $e . '/';
		mkdir $part_path unless -d $path;
	} # end foreach

	if ( ! $$self{'parsed'} ) {
		$self->parse();
	} # end if

	foreach my $side ( 'Front', 'Back' ) {
		foreach my $preview ( $self->previews($side) ) {
			next if ! $$preview{'separations'};

			foreach my $image ( @{$$preview{'separations'}} ) {

				my $Image;
				if ( $$image{'compression'} eq 'RunLengthDecode' ) {
					my $data = misc::rle_decode($$image{'image'});
					$data = $data x 9;
	$log->debug("Compression was RunLengthDecode" . (length $$image{'image'} ) .','.$$image{'width'}.'x'.$$image{'height'} .$$image{'width'}*$$image{'height'}.'=>' . length ($data) );

					$Image = Image::Magick->new(magick=>'cmyk',depth=>1,size=>$$image{'width'}.'x'.$$image{'height'},'colorspace'=>'CMYK','debug'=>'Blob');
					#$Image = Image::Magick->new(magick=>'rle',depth=>1,size=>$$image{'width'}.'x'.$$image{'height'},'colorspace'=>'CMYK','debug'=>'Blob');
					$_ = $Image->BlobToImage($data);
					$log->error( $_ ) if $_;
				} elsif ( $$image{'compression'} eq 'DCTDecode' ) {
					$Image = Image::Magick->new(magick=>'jpg');
					$_ = $Image->BlobToImage($$image{'image'});
					$log->error( $_ ) if $_;
				} elsif ( $$image{'compression'} eq 'None' ) {
					$Image = Image::Magick->new(magick=>'cmyk',depth=>8,size=>$$image{'width'}.'x'.$$image{'height'},'colorspace'=>'CMYK','debug'=>'Blob');
					$_ = $Image->BlobToImage($$image{'image'});
					$log->error( $_ ) if $_;
				} else {
					$log->error("Unknown compression $$image{'compression'}");
					$Image = Image::Magick->new(magick=>'cmyk',depth=>1,size=>$$image{'width'}.'x'.$$image{'height'},'colorspace'=>'CMYK','type'=>'ColorSeparation','debug'=>'Blob');
					$_ = $Image->BlobToImage($$image{'image'});
					$log->error( $_ ) if $_;
				} # end if

				$_ = $Image->Write( sprintf('%s%dsg%dsd%s-%s.jpg', $path, $self->get('docket','signature'), $side, $$image{'ink'} ) );
				$log->error( $_ ) if $_;
			} # end foreach separation
		} # end foreach preview
	} # end foreach side
} # end sub generate_previews
1;

__END__
~       
