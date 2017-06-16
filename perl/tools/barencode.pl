#!/usr/bin/perl
use utf8;
use strict;
use warnings;
use Barcode::Code128 qw(:all);

my $encoder = new Barcode::Code128;
print "Encoding: $ARGV[0] \n";
print $encoder->barcode( $ARGV[0] ) . "\n";

print '    : ' . join( ' ', map { $_ } @{ $encoder->encode( $ARGV[0] ) } ) . "\n";
print 'FNC1: ' . join( ' ', map { $_ } @{ $encoder->encode( FNC1 . $ARGV[0] ) } ) . "\n";
print 'FNC2: ' . join( ' ', map { $_ } @{ $encoder->encode( FNC2 . $ARGV[0] ) } ) . "\n";
print 'FNC3: ' . join( ' ', map { $_ } @{ $encoder->encode( FNC3 . $ARGV[0] ) } ) . "\n";
print 'FNC4: ' . join( ' ', map { $_ } @{ $encoder->encode( FNC4 . $ARGV[0] ) } ) . "\n";


print '    : ' . join( ' ', map { chr ( $_ >= 95 ? $_ + 105 :  $_ + 32 ) } @{ $encoder->encode( $ARGV[0] ) } ) . "\n";
print 'FNC1: ' . join( ' ', map { $_ } @{ $encoder->encode( FNC1 . $ARGV[0] ) } ) . "\n";
print 'FNC2: ' . join( ' ', map { $_ } @{ $encoder->encode( FNC2 . $ARGV[0] ) } ) . "\n";
print 'FNC3: ' . join( ' ', map { $_ } @{ $encoder->encode( FNC3 . $ARGV[0] ) } ) . "\n";
print 'FNC4: ' . join( ' ', map { $_ } @{ $encoder->encode( FNC4 . $ARGV[0] ) } ) . "\n";
