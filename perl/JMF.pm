package JMF;

use Apache2::Request;    # instead of CGI, it's MUCH faster, and does nice things.
use Apache2::RequestRec ();
use Apache2::Const -compile => qw(OK);# Offers OK, Error,etc for web server.
use Apache2::Log;
use Apache2::ServerUtil ();
use Apache2::RequestIO ();

use HTTP::Request;
use HTTP::Response;
use HTTP::Headers;
use LWP::UserAgent;
use strict;
require XML::DOM;
require sql;
require Date::Format;
require configuration;
require sql;

require openprint::JMF_Message;

use openprint;
use vars qw( %config $log $dbh );
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

sub handler {
	# this module just generates barcodes
	my $request = shift;
	my $r = Apache2::Request->new( $request );
	$log = $r->log;

	$log->debug("Got JMF Request");
	my $h = $r->headers_in();
	my $body;
    $r->read( $body, $$h{'Content-Length'} );

	my $p = XML::DOM::Parser->new;
	my $doc = $p->parse( $body );

	# Valid XML Doc, so now go to the trouble of setting up all the openprint vars
	
	$dbh = sql::open_sql( $log,
			'database'  => $r->dir_config('database'),
			'driver'    => $r->dir_config('db_driver'),
			'host'      => $r->dir_config('db_host'),
			'login'     => $r->dir_config('db_user'),
			'password'  => $r->dir_config('db_password'),
			);

	%config = configuration::init( $log, $dbh, $r->dir_config() );

	handle_JMF_Message( $doc );

	$log->debug( $doc->toString() );

	return Apache2::Const::OK;
} # end sub handler

sub handle_JMF_Message {
	my $doc = shift;

	my $JMF = $doc->getDocumentElement();
	my $SenderID = $JMF->getAttribute('SenderID');
	my $TimeStamp = $JMF->getAttribute('TimeStamp');

	my @Equipment = openprint::Equipment->find( 'strid'=>$SenderID );
	if ( ! @Equipment ) {
		# Error
$openprint::log->debug("Equipment $SenderID not found");
	}
	my $Equipment = shift @Equipment;
				my $message = new openprint::JMF_Message();
				$message->Equipment( $Equipment );
				$message->comment( $JMF->toString() );
				$message->created_on( 'NOW()');
				$message->save();

	foreach my $Signal ( $JMF->getElementsByTagName('Signal') ) {
	my $SignalID = $Signal->getAttribute('ID');
	
$openprint::log->debug("SIgnal: $SignalID");
		# Store the general message
		#foreach my $Notification ( $Signal->getElementsByTagName('Notification') ) {
			#foreach my $Comment ( $Notification->getElementsByTagName('Comment') ) {
				
			#} # end foreach
		#} # end foreach Notification
		foreach my $DeviceInfo ( $Signal->getElementsByTagName('DeviceInfo') ) {
# Mostly useless, just provides info on the press, which should rarely change
		} # end foreach DeviceInfo

		foreach my $JobPhase ( $Signal->getElementsByTagName('DeviceInfo') ) {
			my $Amount = $JobPhase->getAttribute('Amount');
			my $JobID = $JobPhase->getAttribute('JobID'); # DOcket
			my $JobPartID = $JobPhase->getAttribute('JobPartID'); #Project #, maybe plus Sig #
			my $PercentCompleted = $JobPhase->getAttribute('PercentCompleted');
			my $RestTime = $JobPhase->getAttribute('RestTime'); # Remaining time
			my $StartTime = $JobPhase->getAttribute('StartTime'); # Remaining time
			my $Status = $JobPhase->getAttribute('Status'); # 
			my $StatusDetails = $JobPhase->getAttribute('StatusDetails'); # 
		} # end foreach JobPhase

	} # end foreach Signal

} # end sub handle_JMF_Message( $doc )

sub send_query {
	my ( $host, $doc ) = @_;
	my $headers = HTTP::Headers->new;
	$headers->header('Content-Type'=>'application/vnd.cip4-jmf+xml');

	my $request = HTTP::Request->new( 'POST', $host, $headers, $doc->toString() );
	my $ua = LWP::UserAgent->new;
	my $response = $ua->request( $request );
	return $response->as_string();
} # end sub query

sub JMFNode {
	my $doc = shift;
	my $params = shift;
	$params = {} if ! $params;
    my $JMF = $doc->createElement('JMF');
	my @gmtime = gmtime(time);
	$JMF->setAttribute('TimeStamp', sprintf('%.4d-%.2d-%.2dT%.2d:%.2d:%.2dZ', $gmtime[5]+1900, $gmtime[4]+1, $gmtime[3]+1,$gmtime[2],$gmtime[1],$gmtime[0] ) );
	$JMF->setAttribute('SenderID', 'IQServer' );
	$JMF->setAttribute('Version', $$params{'Version'} ? $$params{'Version'} : '1.3' );
	$JMF->setAttribute('xmlns', 'http://www.CIP4.org/JDFSchema_1_1' );
	return $JMF;
} # end sub JMFNode

sub QueryKnownMessages {
	my $doc = shift;
	my $params = @_ ? shift : {};

	my $Query = $doc->createElement('Query');
	$Query->setAttribute('ID', 'Q'.time );
	#$Query->setAttribute('Type','Status');
	$Query->setAttribute('Type','KnownMessages');
	
	my $KnownMsgQuParams = $Query->appendChild($doc->createElement('KnownMsgQuParams'));
	$KnownMsgQuParams->setAttribute('ListCommands','true');
	$KnownMsgQuParams->setAttribute('ListQueries','true');
	$KnownMsgQuParams->setAttribute('ListSignals','true');
	#my $StatusQuParams = $JMF->appendChild($doc->createElement('StatusQuParams'));
	#$StatusQuParams->setAttribute('','');
	return $Query;
} # end sub QueryKnownMessages


# Returns an XML fragment representing a query to setup a persistent channel
sub QuerySetupPersistentChannel {
	my $doc = shift;
	my $type = shift;
	my $params = @_ ? shift : {};
	my $Query = $doc->createElement('Query');
	$Query->setAttribute('ID', 'Q'.$type.($$params{'ID'} ? $$params{'ID'} : time ) );
	$Query->setAttribute('Type',$type);
	
	my $Subscription = $Query->appendChild($doc->createElement('Subscription'));
	$Subscription->setAttribute('URL','http://www3.internal.point-one.com/JMF.htm');
	my $ObservationTarget = $Subscription->appendChild($doc->createElement('ObservationTarget'));
	$ObservationTarget->setAttribute('ObservationPath','//*/@*');

	if ( $type eq 'Status' ) {
		my $StatusQuParams = $Query->appendChild($doc->createElement($type.'QuParams'));
		$StatusQuParams->setAttribute('JobDetails','Full'); # Full, Brief, None
		$StatusQuParams->setAttribute('EmployeeInfo','true'); # true/false
	} # end if
	return $Query;
} # end sub QuerySetupPersistentChannel( $doc )

1;

__END__
