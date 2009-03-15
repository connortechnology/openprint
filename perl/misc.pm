package misc;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( load_file send_email_with_attached_files send_email_with_attachment build_city_prov_country export_csv export get_destination);

use Text::CSV_XS;

use MIME::QuotedPrint;
use Mail::Sendmail;

use strict;
use openprint ();

sub send_email_with_attached_files {
    my ( $r, $log, $mail, @attachments ) = @_; 

	for ( my $index = 0; $index < @attachments; $index += 4 ) {

		open ( F, $attachments[$index+1] ) or $log->error( "Can't open " . $attachments[$index+1] );;
		binmode F; undef $/;
		my $text = '';
		foreach my $curline (<F>) {
			$curline =~ s/\n/\r\n/g;
			$text .= $curline;
		} #end foreach
		close F;
		$attachments[$index+1] =$text;
	} # end for
	send_email_with_attachment( $log, $mail, @attachments );
} # end sub send_email_with_attached_files

sub send_email_with_attachment {
    my ( $log, $mail, @attachments ) = @_; 

    my $message = $$mail{BODY};

    my $boundary = "====" . time() . "====";
	$$mail{'content-type'} = "multipart/mixed;\r\n  boundary=\"$boundary\"\r\n";
	$boundary = '--'.$boundary;

	# start with the current body
	$$mail{'BODY'} .= "This is a multi-part message in MIME format.\n\n";
	if ( $message ) {
		$$mail{'BODY'} .= "$boundary\n";
		$$mail{'BODY'} .= "Content-Type: text/plain;\n\tcharset=\"iso-8859-1\"\n";
		$$mail{'BODY'} .= "Content-Transfer-Encoding: 8-bit\n";
		$$mail{'BODY'} .= "\n$message\n";
	} else {
		my ( $name, $text, $type, $encoding ) = splice @attachments,0,4;
		$$mail{BODY} .= "$boundary\nContent-Type: $type;\n";
		$$mail{BODY} .= "Content-Transfer-Encoding: $encoding\n";
		$$mail{BODY} .= "\n$text\n";
	} # end if

	while ( @attachments ) {
		my $name = shift @attachments;
		my $text = shift @attachments;
		my $type = shift @attachments;
		my $encoding = shift @attachments;
		$$mail{BODY} .= "$boundary\nContent-Type: $type;\n";
		$$mail{BODY} .= "\tname=\"$name\"\n" if $name;
		$$mail{BODY} .= "Content-Transfer-Encoding: $encoding\n";
		$$mail{BODY} .= "Content-Disposition: attachment;\n";
		$$mail{BODY} .= "\tfilename=\"$name\"\n" if $name;
		$$mail{BODY} .= "\n$text\n";
	} # end while

	# Signal end of attachments
	$$mail{BODY} .= "$boundary--\n\n";
	sendmail(%{$mail}) || $log->error( "Error: $Mail::Sendmail::error\n" );
} # end sub send_email_with_attachment

# Loads the specified file and returns it.  Returns undef on failure.
sub load_file {
	my ( $log, $file ) = @_;

	if ( open( TEMPLATE, "< $file" ) ) {
		my $contents = '';
		while ( <TEMPLATE> ) {
			$contents .= $_;
		} # end while
		close( TEMPLATE );
		return $contents;
	} # end if

	$log->warn( "Error opening $file, Reason: $!" );
	return undef;
} # end sub load_file

sub build_city_prov_country {
	my ( $city, $prov, $country ) = @_;
	my $cpc = $city;

	if ( $prov ) {
		$cpc .= ', ' if $cpc;
		$cpc .= $prov;
	} # end if

	if ( $country ) {
		$cpc .= ', ' if $cpc;
		$cpc .= $country;
	} # end if;
	return $cpc;
} # end sub build_city_prov_country

sub data_to_csv {
	my ( $header, $data ) = @_;

	my @data;
	my $csv = Text::CSV_XS->new( {'binary'=>1});

	my $columns = scalar @{$header};
	$csv->combine( @{$header} );    # combine columns into a string
	push @data, $csv->string() . "\n";

	for ( my $index = 0; $index < @{$data}; $index += 1 ) {
		$$data[$index] =~ s/[\n\r]//g; # these really mess up the CSV
	} # end for
	
	while ( @{$data} ) {
		my $status = $csv->combine( splice( @{$data}, 0, $columns ) );    # combine columns into a string
		push @data, $csv->string() . "\n";
	} # end while

	return @data;
} # end sub data_to_csv

sub export_csv {
	my ( $r, $log, $variable, $filename, $header, $data ) = @_;
	my @data = data_to_csv( $header, $data );
	return export( $r, $log, $variable, $filename, \@data );
} # end sub

sub export {
	my ( $r, $log, $variable, $filename, $data ) = @_;
	$r->headers_out->{'Content-Disposition'} = "attachment; filename=\"$filename\"";
	$r->content_type( "application/octet-stream; name=\"$filename\"" );
	#$r->content_encoding( "binary" );
	$$variable{'Download'} = $filename;
	return $$variable{'File_Data'} = $data;
} # end sub export

sub get_destination {
    my ( $r, $log, $uri ) = @_;
    my $dest = $uri ? $uri : $r->uri();
    my @keys = $r->param();
    if ( @keys ) {
        $dest .= '?';
        my @params;
        foreach my $key ( @keys ) {
            push @params, join( '=', ($key, $r->param($key)));
        } # end foreach
        $dest .=  join( '&', @params );
    } # end if
    return $dest;
} # end sub get_destination

sub get_url {
	my ( $uri, $params, $options ) = @_;
	my @keys = keys %$params;
	if ( $options and $$options{'exclude'} ) {
		@keys = sets::exclude( $$options{'exclude'}, \@keys );
	} # end if	
	@keys = sets::exclude( [ 'password', 'btnFunction', 'email','select_currency_id','ddmCompany' ], \@keys );
	my %encoded;
	foreach my $k ( @keys ) {
		$encoded{$k} = $$params{$k};
		$encoded{$k} =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;	
	} # end foreach
	if ( $options and $$options{'include'} ) {
		foreach my $k ( keys %{$$options{'include'}} ) {
			$encoded{$k} = $$options{'include'}{$k};
		} # end foreach
	} # end if	
	
	return join( '?', $uri, join('&amp;', map { $_.'='.$encoded{$_} } keys %encoded ) );
} # end sub get_url

sub sum {
	my $sum = 0;
	foreach $_ ( @_ ) {
		$sum += $_;
	} # end foreach
	return $sum;
} # end sub sum

sub error {
    my ( $log, $dbh, $variable, $error, $details ) = @_;
    
    $log->debug("Error: $error");
    $log->debug("Details: $details");

    $$variable{'error'} = $error;
    $$variable{'details'} = $details;
    $$variable{'Redirect'} = $openprint::config{'errorpage'};
} # end sub error

sub trim {
	my @results;
	foreach my $thing ( @_ ) {
		$thing =~ s/^\s*(.*)\s*$/$1/;
		push @results, $thing;
	}
	return @results;
}

sub moneyfilter {
	$_ = shift;
	if (/.*?(?:\$\s*)?(\-?[0-9]+(\.[0-9]{1,2})?).*?/) {
		if ( $1 > 10000000 ) {
			return 10000000;
		}
		return $1;
	} else {
		return undef;
	}
} # end sub moneyfilter

sub seconds_to_interval {
    $_[0] = int $_[0];
    my $h = int ($_[0]/3600);
    my $m = $_[0] - ($h*3600);
    return ( $h, int($m/60), $m%60 );
}

sub seconds_to_JDF_interval {
    $_[0] = int $_[0];
	my $d = int ($_[0]/86400);
	$_[0] -= $d*86400;
    my $h = int ($_[0]/3600);
    my $m = $_[0] - ($h*3600);
	my $return;
	$return .= $d.'D' if $d;
	$return .= $h.'H' if $h;
	$return .= int($m/60).'M' if int($m/60);
	$return .= ($m%60).'S' if $m%60;

    return $return;
}

sub interval_to_seconds {
    my $interval = shift;
    my ( $h, $m, $s ) = split ':', $interval;
    return ($h*3600) + ($m*60) + $s;
} # end sub interval_to_seconds

sub seconds_to_pretty_interval {
    my ( $seconds ) = @_;
    my $string;
    my $years = int($seconds / ( 60 * 60 * 24 * 365 ));
    my $remainder = $seconds % ( 60*60*24*365 );
    $string .= sprintf('%dy', $years) if $years;
    return $string if ! $remainder;

    my $days = int ( $remainder / ( 60* 60 * 24 ) );
    $remainder = $remainder % ( 60 * 60 * 24 );
    if ( sets::isin( $days, [ 28,29,30,31 ] ) ) {
        $string .= '1 month';
    } elsif ( $days ) {
        $string .= sprintf('%dd', $days );
    } # end if
    return $string if ! $remainder;

    my $hours = int( $remainder / (60*60) );
    $remainder = $remainder % ( 60*60 );
    my $minutes = int ( $remainder / 60 );
    $remainder = $remainder % 60;

    if ( $remainder ) {
        $string .= sprintf('%d:%.2d:%.2d', $hours, $minutes, $remainder );
    } else {
        $string .= sprintf('%d:%.2d', $hours, $minutes );
    } # end if
    return $string;

} # end sub seconds_to_pretty_interval


sub rle_decode {
	my ( $source, $width, $height ) = @_;
	my $result = '';
	my $position = 0;
$openprint::log->warn("RLE::DECODE:: source: " . length $source );
    while ($source ne "") {
        my $l = unpack("C", $source);
        if ($l == 128) {
			if ( length $source > 1 ) {
				$openprint::log->debug("End while still data at position $position " . unpack("H",$source) . ' ' . substr($source,0,1) . ' length of result: ' . length($result));
			} # end if
            return $result;
        } elsif ($l > 128) {
        #if ($l > 128) {
            if (length($source) < 2) {
                $openprint::log->warn("Premature end to data in RunLengthEncoded data");
                return $result;
            } # end if
            $result .= substr($source, 1, 1) x (257 - $l);
            substr($source, 0, 2) = "";
			$position += 2;
        } else {
            if (length($source) < $l + 1) {
                $openprint::log->warn("Premature end to data in RunLengthEncoded data");
                return $result;
            }
            $result .= substr($source, 1, $l);
            substr($source, 0, $l + 1) = "";
			$position += $l+1;
        }
    }
$openprint::log->warn("RLE::DECODE:: results: " . length $result );
	return $result;
} # end sub rle_decode

1;

__END__
