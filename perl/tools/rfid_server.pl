#!/usr/bin/perl 
use lib '/etc/apache2/lib/perl';
use Net::Server::PreFork;

@ISA = qw(Net::Server::PreFork);
use strict;
require openprint::Object;
require openprint::RFIDScanner;
require openprint::RFIDTag;
require logger;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'warn' );

sub process_request {
	my $self = shift;

	$dbh = sql::open_sql( $log, ('database'=>'point-one', 'driver'=>'Pg','login'=>'point-one', 'password'=>'point-one','host'=>'www2') );

	eval {
		local $SIG{'ALRM'} = sub { die "Timed Out!\n" };
		my $timeout = 30; # give the user 30 seconds to type some lines

		my $previous_alarm = alarm($timeout);
		$self->get_client_info();
		
		my $Scanner;
		my @Scanners = openprint::RFIDScanner::find('ipaddr'=>$self->{server}->{peeraddr});
		if ( ! @Scanners ) {
			# Have a new one, add it
			$Scanner = new openprint::RFIDScanner();
			$Scanner->save( {'ipaddr'=>$self->{server}->{peeraddr}} );
		} else {
			$Scanner = $Scanners[0];
		} # end if
			open( LOG, ">>/tmp/rfid.log" );

		# Each tag is 40 chars long
		my $data;
		while ( read(STDIN, $data, 44) ) {

			my ( $tag_id ) = $data =~ /^<TAG>\[A0\] (\w*)<\/TAG>$/;
			$self->log(1, sprintf('%s : %s', $self->{server}->{peeraddr}, $tag_id ));
			if ( ! $tag_id ) {
			} else {
				my $changed = 0;
				my $Tag = new openprint::RFIDTag( $tag_id );
				if ( ! $Tag->id() ) {
					$self->log(1, sprintf('%s : No tag found for %s', $self->{server}->{peeraddr}, $tag_id ));
					$changed = 1;
				} else {
					$self->log(1, sprintf('%s : found for %s', $self->{server}->{peeraddr}, $tag_id ));
				} # end if

				if ( $Scanner->location_id() != $Tag->location_id() ) {
					$changed = 1;
					$Tag->location_id( $Scanner->location_id() );
				} # End if
				$Tag->save({'id'=>$tag_id}) if $changed;
			} # end if
			print LOG $self->{server}->{peeraddr} . ": $data\r\n";
#print "$_\r\n";
			alarm($timeout);
		} # end while
		close(LOG);
		alarm($previous_alarm);
	};

	if ($@ =~ /timed out/i) {
		print STDOUT "Timed Out.\r\n";
		return;
	}
} # end sub process_request

__PACKAGE__->run();
1;
__END__
