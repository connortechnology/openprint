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
		} elsif ( $line =~ /^CIP3PreviewImage/ ) {
			$line = shift;
			my @image_data;
			while ( ! ( $line =~ /^CIP3EndSeparation/ ) ) {
				push @image_data, $line;
				$line = shift;
			} # end while
			$$image{'image'} = join("\r\n", @image_data);
			$openprint::log->debug("Got image data for $$image{ink} lines: " . @image_data . " length: " . length($$image{'image'}) );
			last;
		} elsif ( $line =~ /^CIP3EndSeparation/ ) {
			last;
		} # end if
	} # end while
	return @_;
} # end sub parsePreviewImage

sub parse {
	my ( $self ) = @_;
	
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
	my ( $self ) = @_;
	
	my @previews;

	if ( $$self{'sheets'} ) {
		foreach my $sheet ( @{$$self{'sheets'}} ) {
			if ( $$sheet{'Front'} ) {
$openprint::log->debug("Adding front previews");
				push @previews, @{$$sheet{'Front'}{'previews'}} if $$sheet{'Front'}{'previews'};
			} # end if
			if ( $$sheet{'Back'} ) {
$openprint::log->debug("Adding back previews");
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
$openprint::log->debug("Previews: " . @previews );
	return @previews;
} # end sub previews


1;

__END__
~       
