#!/usr/bin/perl
use Net::Server::PreFork;

@ISA = qw(Net::Server::PreFork);

sub process_request {
	my $self = shift;
	eval {
$self->log(1, "My Message with %s in it");

		local $SIG{'ALRM'} = sub { die "Timed Out!\n" };
		my $timeout = 30; # give the user 30 seconds to type some lines

		my $previous_alarm = alarm($timeout);
		# Each tag is 40 chars long
		my $data;
		while ( read(STDIN, $data, 40) ) {
		open( LOG, ">>/tmp/rfid.log" );
			print LOG "$data\r\n";
		close(LOG);
			#print "$_\r\n";
			alarm($timeout);
		} # end while
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
