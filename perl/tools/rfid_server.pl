#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use Net::Server::PreFork;

@ISA = qw(Net::Server::PreFork);
use strict;
require openprint::Object;
require openprint::RFIDScanner;
require openprint::RFIDTag;
require logger;
require Date::Format;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'warn' );
$openprint::Object::no_cache = 1;

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

		my $date = Date::Format::time2str('%Y-%m-%d %H:%M', time );
		$self->log(1, sprintf('%s : %s : %s',$date, $self->{server}->{peeraddr}, 'connect' ));
		# Each tag is 40 chars long
		my $data;
		my $tag;
		while ( read(STDIN, $data, 1) ) {
			$tag .= $data;
			$date = Date::Format::time2str('%Y-%m-%d %H:%M', time );
			$self->log(1, sprintf('%s : %s : %s', $date, $self->{server}->{peeraddr}, $tag ));

			my ( $tag_id, $end ) = $tag =~ /<TAG>\[A0\]\s*(\w*)<\/TAG>(.*)/;
			if ( ! $tag_id ) {
				next;
			} # end if
			$tag = $end;
			$self->log(1, sprintf('%s : %s : hex %s', $date, $self->{server}->{peeraddr}, $tag_id ));
			$tag_id = substr( $tag_id, length($tag_id)-16, 16 );
			my $type_digit = substr( $tag_id, 0, 1 );
			$tag_id = substr( $tag_id, 1, 15 );

			$self->log(1, sprintf('%s : %s : short  hex %s', $date, $self->{server}->{peeraddr}, $tag_id ));
			$tag_id = hex($tag_id);
			$tag_id = sprintf('%d%.15d', $type_digit , $tag_id );
			$self->log(1, sprintf('%s : %s : dec %s', $date, $self->{server}->{peeraddr}, $tag_id ));
			if ( ! $tag_id ) {
			} else {
				my $changed = 0;
				my $Tag = new openprint::RFIDTag( $tag_id );
				if ( ! $Tag->id() ) {
					#$self->log(1, sprintf('%s : going to allocate ', $self->{server}->{peeraddr} ));
					$changed = 1;
				} # end if
				if ( ! $Tag->type() ) {
					if ( $type_digit == 1 ) {
					#$self->log(1, sprintf('%s : nineth %s', $self->{server}->{peeraddr}, $ninth ));
						$Tag->type( 'Location' );
						$changed = 1;
					} elsif ( $type_digit == 2 ) {
						$Tag->type( 'Skid' );
						$changed = 1;
					} # end if
				} # end if
				if ( $Scanner->type() eq 'Mobile' ) {
					if ( $Tag->type() eq 'Location' ) {
						$Scanner->location_id() = $Tag->location_id();
						$Scanner->save();
					} elsif ( $Scanner->location_id() != $Tag->location_id() ) {
						$changed = 1;
						$Tag->location_id( $Scanner->location_id() );
					} # end if
				} elsif ( $Scanner->type() eq 'Fixed' ) {
					if ( $Scanner->location_id() != $Tag->location_id() ) {
						$changed = 1;
						$Tag->location_id( $Scanner->location_id() );
					} # End if
				} # End if
				if ( $changed ) {
				$self->log(1, sprintf('%s : %s : saving', $date, $self->{server}->{peeraddr} ));
				my $error = $Tag->save({'id'=>$tag_id});
				$self->log(1, sprintf('%s : %s : error %s', $date, $self->{server}->{peeraddr}, $error )) if $error;
				} else {
				$self->log(1, sprintf('%s : %s : not saving', $date, $self->{server}->{peeraddr} ));
				} # end if
			} # end if
			print LOG $self->{server}->{peeraddr} . ": $data\r\n";
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
