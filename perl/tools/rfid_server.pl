#!/usr/bin/perl -w -T
use lib '/etc/apache2/lib/perl';
use Net::Server::PreFork;

@ISA = qw(Net::Server::PreFork);
use strict;
require openprint::Object;
require openprint::RFIDScanner;
require openprint::RFIDScannerHistory;
require openprint::RFIDTag;
require logger;
require sets;
require sql;
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
		my $timeout = 60; # give the user 30 seconds to type some lines

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
			#$self->log(1, sprintf('%s : %s : %s', $date, $self->{server}->{peeraddr}, $tag ));

			my ( $tag_id, $end ) = $tag =~ /<TAG>\[A0\]\s*(\w*)<\/TAG>(.*)/;
			if ( ! $tag_id ) {
				next;
			} # end if
			$tag = $end;
			#$self->log(1, sprintf('%s : %s : hex %s', $date, $self->{server}->{peeraddr}, $tag_id ));
			$tag_id = substr( $tag_id, length($tag_id)-16, 16 );
			my $type_digit = substr( $tag_id, 0, 1 );
			$tag_id = substr( $tag_id, 2, 15 );

			#$self->log(1, sprintf('%s : %s : short  hex %s', $date, $self->{server}->{peeraddr}, $tag_id ));
			$tag_id = hex($tag_id);
			$tag_id = sprintf('%d%.14d', $type_digit , $tag_id );
			$self->log(1, sprintf('%s : %s : dec %s', $date, $self->{server}->{peeraddr}, $tag_id ));
			if ( ! $tag_id ) {
			$self->log(1, sprintf('%s : %s : No tag', $date, $self->{server}->{peeraddr} ));
			} else {
				my $changed = 0;
				my $Tag = new openprint::RFIDTag( $tag_id );
				if ( ! $Tag->id() ) {
					#$self->log(1, sprintf('%s : going to allocate ', $self->{server}->{peeraddr} ));
					$changed = 1;
				} # end if
					#$self->log(1, sprintf('%s : Type %s', $self->{server}->{peeraddr}, $Tag->type() ));
				if ( ! $Tag->type() ) {
					if ( $type_digit == 1 ) {
					#$self->log(1, sprintf('%s : Location %s', $self->{server}->{peeraddr}, $type_digit ));
						$Tag->type( 'Location' );
					#$self->log(1, sprintf('%s : Type %s', $self->{server}->{peeraddr}, $Tag->type() ));
						$changed = 1;
					} elsif ( $type_digit == 2 ) {
						$Tag->type( 'Skid' );
						$changed = 1;
					} else {
						$self->log(1, sprintf('%s : %s : unknown type %s', $date, $self->{server}->{peeraddr}, $type_digit ));
					} # end if
				} # end if
				if ( $Scanner->type() eq 'Mobile' ) {
					if ( $Tag->type() eq 'Location' ) {
						#$self->log(1, sprintf('%s : %s : getting histyo', $date, $self->{server}->{peeraddr} ));
						my @location_ids = map {$_->location_id()} openprint::RFIDScannerHistory::find('scanner_id'=>$Scanner->id(),'order'=>'updated_on DESC','limit'=>3);
						$self->log(1, sprintf('%s : %s : current: %d new: %d pastlocations %s', $date, $self->{server}->{peeraddr},$Scanner->location_id(), $Tag->location_id(), join(',', @location_ids) ));
						if ( ! sets::isin( $Tag->location_id(), \@location_ids ) ) {
							$Scanner->location_id( $Tag->location_id(), $Tag->id() );
							my $e = $Scanner->save();
							$self->log(1, sprintf('%s : %s : error saving scanner %s', $date, $self->{server}->{peeraddr}, $e )) if $e;
						} # end if
					} elsif ( $Scanner->location_id() != $Tag->location_id() ) {
						$changed = 1;
						$self->log(1, sprintf('%s : %s : updating location of tag %s to $d', $date, $self->{server}->{peeraddr}, $Tag->id(), $Scanner->location_id() ));
						$Tag->location_id( $Scanner->location_id(), $Scanner->id() );
						$self->log(1, sprintf('%s : %s : done updating location of tag %s to $d', $date, $self->{server}->{peeraddr}, $Tag->id(), $Scanner->location_id() ));
					} # end if
				} elsif ( $Scanner->type() eq 'Fixed' ) {
					if ( $Scanner->location_id() != $Tag->location_id() ) {
						$changed = 1;
						$Tag->location_id( $Scanner->location_id(), $Scanner->id() );
					} # End if
				} elsif ( $Scanner->type() eq 'Checkout' ) {
					if ( $Tag->type() eq 'Skid' ) {
						my $Skid = $Tag->Skid();
					} # end if
				} else {
					$self->log(1, sprintf('%s : %s : unknown scanner type %s', $date, $self->{server}->{peeraddr}, $Scanner->type() ));
				} # End if
					#$self->log(1, sprintf('%s : changed %s', $self->{server}->{peeraddr}, $changed ));
				if ( $changed ) {
				#$self->log(1, sprintf('%s : %s : saving', $date, $self->{server}->{peeraddr} ));
					my $error = $Tag->save({'id'=>$tag_id});
					$self->log(1, sprintf('%s : %s : error %s', $date, $self->{server}->{peeraddr}, $error )) if $error;
				} else {
				#$self->log(1, sprintf('%s : %s : not saving', $date, $self->{server}->{peeraddr} ));
				} # end if
			} # end if
			#print LOG $self->{server}->{peeraddr} . ": $data\r\n";
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
