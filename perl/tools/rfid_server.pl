#!/usr/bin/perl -T -w
use lib '/var/www/p1/perl';
use Net::Server::PreFork;

@ISA = qw(Net::Server::PreFork);
use strict;
require openprint::Object;
require openprint::RFIDScanner;
require openprint::RFIDScannerHistory;
require openprint::RFIDTag;
require openprint::Skid;
require logger;
require sets;
require sql;
require Date::Format;
require Date::Parse;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'warn' );
$openprint::Object::no_cache = 1;
my %CheckedOutSkids;
my %Scanners;

$sql::timing = 0;
my $debug = 0;

sub Checkout_Skid {
	my ( $Scanner, $Tag, $context, $checkout_tags ) = @_;

	my $date = Date::Format::time2str('%Y-%m-%d %H:%M', time );
	#$context->log(1, sprintf('%s : %s : checkout skid with rfid tag %s', $date, $context->{server}->{peeraddr}, $Tag->id() ));
	my $Skid = $Tag->Skid();
	$Skid->rfidtag_id( $Tag->id() ) if ! $Skid->rfidtag_id();
	my $error = $Skid->save() if ! $Skid->id();
	if ( $error ) {
		$context->log(1, sprintf('%s : %s : error saving skid: %s', $date, $context->{server}->{peeraddr}, $error ));
	} else {
		return if $CheckedOutSkids{$Skid->id()};
		$Skid->checkout( ' by ' . $Scanner->name() );
		$CheckedOutSkids{$Skid->id()} = 1;
		$context->log(1, sprintf('%s : %s : success Skid is in checkout location skidid: %s', $date, $context->{server}->{peeraddr}, $Skid->id() ));

		sql::insert( undef, undef, 'RFIDTagHistory', {'rfidtag_id'=>$Tag->id(),'location_id'=>$Tag->location_id(), 'scanner_id'=>$Scanner->id()} );
	} # end if
} # end sub Checkout_Skid

sub process_request {
	my $self = shift;

	$dbh = sql::open_sql( $log, ('database'=>'point-one', 'driver'=>'Pg','login'=>'point-one', 'password'=>'point-one','host'=>'www4') );

	# Have to reload scanner here

	my $date = Date::Format::time2str('%Y-%m-%d %H:%M', time );

	my @checkout_tags = openprint::RFIDTag::find('type'=>'Checkout');

	$self->get_client_info();
	%Scanners = map { $_->ipaddr(), $_ } openprint::RFIDScanner::find();
	my $Scanner = $Scanners{$self->{server}->{peeraddr}};
	if ( ! $Scanner ) {
		my @Scanners = openprint::RFIDScanner::find('ipaddr'=>$self->{server}->{peeraddr});
		if ( ! @Scanners ) {
			# Have a new one, add it
			$Scanner = new openprint::RFIDScanner();
			$Scanner->save( {'ipaddr'=>$self->{server}->{peeraddr}} );
		} else {
			$Scanner = $Scanners[0];
		} # end if
		$Scanners{$self->{server}->{peeraddr}} = $Scanner;
	} # end if
	$self->log(1, sprintf('%s : %s : %s',$date, $self->{server}->{peeraddr}, 'connect ' . $Scanner->name() )) if $debug;

	my @last_seen;

	my @Users = openprint::User::find('email'=>'rfid');
	if ( @Users ) {
		$openprint::session{'user_id'} = $Users[0]->id();
	} # end nif

	eval {
		local $SIG{'ALRM'} = sub { die "Timed Out!\n" };
		my $timeout = 120;

		my $previous_alarm = alarm($timeout);
		# Each tag is 40 chars long
		my $data;
		my $tag = '';
		while ( read(STDIN, $data, 1) ) {
			$tag .= $data;
			my ( $antenna, $tag_id, $end ) = $tag =~ /<TAG>\[A(\d)\]\s*(\w*)<\/TAG>(.*)/;
			if ( ! $tag_id ) {
				#$self->log(1, "No tag id in $tag\n");
				next;
			} # end if
			$tag = $end;

			$date = Date::Format::time2str('%Y-%m-%d %H:%M', time );
			if ( (time - Date::Parse::str2time($Scanner->lastseen_on())) > 60 ) {
				if ( my $error = $Scanner->save({'lastseen_on'=>'NOW()'}) ) {
					$self->log(1, sprintf('%s : %s : error saving scanner: %s', $date, $self->{server}->{peeraddr}, $error ));
				} # end if
			} # end if

			#$self->log(1, sprintf('%s : %s : hex %s', $date, $self->{server}->{peeraddr}, $tag_id ));
			$tag_id = substr( $tag_id, length($tag_id)-16, 16 );
			my $type_digit = substr( $tag_id, 0, 1 );
			if ( $type_digit =~ /\D/ ) {
				#$self->log(1, sprintf('%s : %s : invlaid type digit', $date, $self->{server}->{peeraddr} ));
				next;
			} # end if
		
			# This is due to a fuck up, where the tags printed only used 15 digits, whereas the rfid is 16
			$tag_id = hex( substr( $tag_id, 2, 15 ) );
			if ( $tag_id =~ /\D/ ) {
				$self->log(1, sprintf('%s : %s : invalid tag (%s)', $date, $self->{server}->{peeraddr}, $tag_id ));
				next;
			} # end if

			if ( ( $type_digit == 2 ) and ( $tag_id < 2100 ) ) {
				# Ignore the test tags
				$self->log(1, sprintf('%s : %s : old skid tag %s', $date, $self->{server}->{peeraddr}, $tag_id ));
				next;
			} # end if

			$tag_id = sprintf('%d%.14d', $type_digit, $tag_id );
			#$self->log(1, sprintf('%s : %s : dec %s', $date, $self->{server}->{peeraddr}, $tag_id ));
			if ( ! $tag_id ) {
				$self->log(1, sprintf('%s : %s : No tag', $date, $self->{server}->{peeraddr} ));
				next;
			} # end if

			my $changed = 0;
			my $Tag = new openprint::RFIDTag( $tag_id );
			if ( ! $Tag->id() ) {
				#$self->log(1, sprintf('%s : going to allocate ', $self->{server}->{peeraddr} ));
				$Tag->save( {'id'=>$tag_id} );
			} # end if

			if ( $Scanner->type() eq 'Mobile' ) {
				if ( sets::isin( $Tag->type(), ['Location','Checkout'] ) ) {
					@last_seen = map {$_->location_id()} openprint::RFIDScannerHistory::find('scanner_id'=>$Scanner->id(),'order'=>'updated_on DESC','limit'=>8) if ! @last_seen;
					#$self->log(1, sprintf('%s : %s : current: %d new: %d pastlocations %s', $date, $self->{server}->{peeraddr},$Scanner->location_id(), $Tag->location_id(), join(',', @location_ids) ));
					if ( ( ! @last_seen ) or ! sets::isin( $Tag->location_id(), \@last_seen ) ) {
						$Scanner->location_id( $Tag->location_id(), $Tag->id() );
						shift @last_seen if @last_seen > 7;
						push @last_seen, $Tag->location_id();
						$self->log(1, sprintf('%s : %s : updating location of scanner %s to %s', $date, $self->{server}->{peeraddr}, $Scanner->name(), $Scanner->location_id() ));
						my $e = $Scanner->save();
						$self->log(1, sprintf('%s : %s : error saving scanner %s', $date, $self->{server}->{peeraddr}, $e )) if $e;
					} # end if
				} elsif ( $Scanner->location_id() != $Tag->location_id() ) {
					$changed = 1;
					$self->log(1, sprintf('%s : %s : updating location of tag %s to %d', $date, $self->{server}->{peeraddr}, $Tag->id(), $Scanner->location_id() ));
					$Tag->location_id( $Scanner->location_id(), $Scanner->id() );
					#$self->log(1, sprintf('%s : %s : done updating location of tag %s to %d', $date, $self->{server}->{peeraddr}, $Tag->id(), $Scanner->location_id() ));
					#if ( $Tag->type() eq 'Skid' ) {
						#Checkout_Skid( $Scanner, $Tag, $self, \@checkout_tags );
					#} # end if Skid
				} # end if
			} elsif ( $Scanner->type() eq 'Fixed' ) {
				if ( $Scanner->location_id() != $Tag->location_id() ) {
					$changed = 1;
					$Tag->location_id( $Scanner->location_id(), $Scanner->id() );
				} # End if
				$Scanner->save();
			} elsif ( $Scanner->type() eq 'Checkout' ) {
				if ( $Tag->type() eq 'Skid' ) {
					if ( ! sets::isin( $Tag->location_id(), map { $_->location_id() } @checkout_tags ) ) {
						$Tag->location_id( $Scanner->location_id(), $Scanner->id() );
						$Tag->save();
					} # end if
					Checkout_Skid( $Scanner, $Tag, $self, \@checkout_tags );
				} # end if
			} elsif ( $Scanner->type() eq 'Truck Location' ) {
				if ( sets::isin( $Tag->type(), ['Location','Checkout'] ) ) {
#$self->log(1, sprintf('%s : %s : getting histyo', $date, $self->{server}->{peeraddr} ));
					@last_seen = map {$_->location_id()} openprint::RFIDScannerHistory::find('scanner_id'=>$Scanner->id(),'order'=>'updated_on DESC','limit'=>8) if ! @last_seen;
					if ( ! sets::isin( $Tag->location_id(), @last_seen ) ) {
						$self->log(1, sprintf('%s : %s : truck moving to %s : %s', $date, $self->{server}->{peeraddr}, $Tag->id(), $Tag->Location()->name() ));
						$Scanner->location_id( $Tag->location_id(), $Tag->id() );
						shift @last_seen if @last_seen > 7;
						push @last_seen, $Tag->location_id();
						my $e = $Scanner->save();
						$self->log(1, sprintf('%s : %s : error saving scanner %s', $date, $self->{server}->{peeraddr}, $e )) if $e;
						if ( $Scanner->other() ) {
							my $Scanner2 = new openprint::RFIDScanner( $Scanner->other() );
							$Scanner2->location_id( $Tag->location_id(), $Tag->id() );
							my $e = $Scanner2->save();
							$self->log(1, sprintf('%s : %s : error saving scanner2 %s', $date, $self->{server}->{peeraddr}, $e )) if $e;
						} # end if
					} # end if
				} else {
					$self->log(1, "unknown tag type: " . $Tag->type() );
				} # end if

			} elsif ( $Scanner->type() eq 'Truck Inventory' ) {
				if ( ( $Tag->type() eq 'Skid' ) and ( $Scanner->location_id() != $Tag->location_id() ) ) {
					my $Skid = $Tag->Skid();
					$Skid = new openprint::Skid() if ! $Skid;
					$Skid->rfidtag_id( $Tag->id() ) if ! $Skid->rfidtag_id();
					my $error = $Skid->save() if ! $Skid->id();
					$self->log(1, sprintf('%s : %s : error saving skid: %s', $date, $self->{server}->{peeraddr}, $error )) if $error;
					$changed = 1;
					$self->log(1, sprintf('%s : %s : updating location of tag %s to %s', $date, $self->{server}->{peeraddr}, $Tag->id(), $Scanner->Location()->name() ));
					$Tag->location_id( $Scanner->location_id(), $Scanner->id() );
					$self->log(1, sprintf('%s : %s : done updating location of tag %s to %s', $date, $self->{server}->{peeraddr}, $Tag->id(), $Scanner->Location()->name() ));
				} # end if
			} else {
				$self->log(1, sprintf('%s : %s : unknown scanner type %s', $date, $self->{server}->{peeraddr}, $Scanner->type() ));
			} # end if
			if ( $changed ) {
				my $error = $Tag->save({'id'=>$tag_id});
				$self->log(1, sprintf('%s : %s : error %s', $date, $self->{server}->{peeraddr}, $error )) if $error;
			} # end if

			alarm($timeout);
		} # end while
		alarm($previous_alarm);
		$self->log(1, sprintf('%s : %s : done while, tag: %s', $date, $self->{server}->{peeraddr}, $tag ));
	}; # end eval

	$dbh->disconnect();
	$self->log(1, sprintf('%s : %s : %s',$date, $self->{server}->{peeraddr}, 'disconnect ' )) if $debug;

	if ($@ =~ /timed out/i) {
		$self->log(1, sprintf('%s : %s : timeout: %s', $date, $self->{server}->{peeraddr}, $@ )) if $debug;
	} elsif ($@) {
		$self->log(1, sprintf('%s : %s : other (%s)', $date, $self->{server}->{peeraddr}, $@ ));
	} # end if
} # end sub process_request

__PACKAGE__->run();
1;
__END__
