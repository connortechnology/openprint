#!/usr/bin/perl

@INC=( '/etc/apache2/lib/perl', @INC );

use strict;

require JMF;
require logger;
require XML::DOM;

my $log = new logger( 'debug' );

my $doc = new XML::DOM::Document;
$doc->setXMLDecl( $doc->createXMLDecl( '1.0' ) );

my $JMF = $doc->appendChild( JMF::JMFNode($doc) );
#$JMF->appendChild( JMF::QueryKnownMessages( $doc ) );
$JMF->appendChild( JMF::QuerySetupPersistentChannel( $doc, 'Status' ) );
print $doc->toString();

$log->debug( JMF::send_query('http://192.168.1.229:8080/elk-printing/jmf', $doc ) );
1;
__END__
