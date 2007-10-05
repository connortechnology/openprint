package jsrs;
use URI::Escape;

use strict;

require sets;

my $debug = 1;

sub Dispatch {
	my ( $r, $log, $dbh, $variable, $database ) = @_;

    my $func = BuildFunctionCall($r, $log, $variable );
    if ( $func ) {
        my $retval = eval($func);
		if ( $@ ) {
			ReturnError( $r, $log, $variable, $@ );
		} else {
			Return( $r, $log, $variable, $retval );
		} # end if
	} else {
        ReturnError( $r, $log, $variable, "function builds as empty string");
    } # end if
} # end sub Dispatch

sub Return {
	my ( $r, $log, $variable, $payload ) = @_;
	if ( $debug ) {
	foreach my $pair ( sort split('\|', $payload) ) {
		$log->debug( "Payload: $pair" ); 
	}
	}

	$$variable{'C'} = $r->param('C');
	$$variable{'payload'} = escape($payload);
} # end sub Return;

sub escape {
	$_[0] =~ s/&/&amp;/g;
	$_[0] =~ s/\//\\\//g;
	return $_[0];
} # end sub escape

sub ReturnError {
	my ( $r, $log, $variable, $error ) = @_;
$log->debug( $error );
	my $clean = $error;
	$clean =~ s/'/\\'/g;
	$clean =~ s/\\"/\\\\\\"/g;
    $clean = "jsrsError: $clean";
	$$variable{'payload'} = $error; 
		#"<html><head></head><body ".
		#"onload=\"p=document.layers?parentlayer:window.parent;p.jsrsError(\'" . $r->param('C') .
		#"','" . uri_unescape($error) . "\');\">" . $clean . "</body></html>";
} # end sub ReturnError

sub BuildFunctionCall {
	my ( $r, $log, $variable ) = @_;

    my $func = "";
    if ( $r->param('F') ne '' ) {
        $func = $r->param('F');
		my @parts = split( '::', $func );
		if ( @parts > 1 ) {
			pop @parts;
			eval 'require '.join('::', @parts );
			$openprint::log->error('require '.join('::', @parts ). ':' . $@) if $@;
		} # end if
		$func .= '( $r, $log, $dbh, $variable';
		for ( my $index = 0; $index < $r->param(); $index += 1 ) {
			last if ! defined $r->param("P$index");
			$_ = $r->param("P$index");
			$_ = substr( $_, 1, length($_) - 2 );
			$_ =~ s/\\/\\\\/g;
			$_ =~ s/\'/\\\'/g;
			$func .= ", '$_'";
		} # end for
		$func .= ')';
	} # end if
	return $func;
} # end sub BuildFunctionCall

sub EvalEscape {
	$_[0] =~ s/\n/\\n/g;
	$_[0] =~ s/\+"/\\"/g;
	return $_[0];
} # end sub jsrsEvalEscape

sub encode_pairs {
    my @results;
	my %hash = @_;

    foreach my $key ( sort keys %hash ) {
        push @results, ( $key ) . '~' .  ( $hash{$key} );
    } # end while
    return join('|', @results );
} # end sub encode_pairs

sub encode_array {
	my $name = shift;
    my @results;
    while ( @_ ) {
        push @results, $name . '~' . ( shift @_ ) . '~' .  (shift @_ );
    } # end while
    return join('|', @results );
} # end sub encode_pairs

sub object_encode {
    my $log = shift;
    my $object = shift;
    my @keys = keys %{$object};
    $log->debug("Keys @keys");

    my @pairs = map { $_ . '~' . $$object{$_} } @keys;
    $log->debug("Pairs: @pairs");
    $_ =  join('|', @pairs );
    $log->debug("$_");
    return $_;
} # end sub object_encode


sub execute {
    my ( $r, $log, $dbh, $variable, %specs ) = @_;
    my $rc = eval $specs{'code'};
    $log->error( "jsrs::execute error: $@" ) if $@;
    return $rc;
} # end sub execute


1;
__END__
