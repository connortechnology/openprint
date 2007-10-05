package mail::EmailAutoResponder_Impl;

use strict;

require Net::SSH;

my $Vacation = "/usr/bin/vacation";

#
# Returns a string containing the .vacation.msg file.
# undef if a login error occurs
# "" if the .vacation.msg file does not exists
#
sub RetrieveMessage {
	my $host = shift;
	my $Username = shift;
	
	my $out; my $err; my $exit;

	# Make sure the Perl Module knows what our Home Directory is.
	# This is a bit of a hack, since running under mod_perl isn't
	# quite like running using the command line
	#$ENV{HOME} = "/home/$Username";
	#
	# Odd behavior. On this system/verion of Net::SSH::Perl, the .ssh
	# files written are in the current Users directory, not the one
	# specified in "login". Since 127.0.0.1 was added to
	# /etc/ssh/ssh_known_hosts, write ability is not required to
	# the ssh directory. This alleviates file permission issues.

	$ENV{HOME} = '/srv';

	eval { $out = Net::SSH::ssh_cmd ( "$Username\@$host", "cat .vacation.msg" ) };
	if ($@) {
		return $!;
	}

	# We know we have logged in, so return an empty string
	# since evidently the .vacation.msg file is not present.
	#
	# Alternately, we could re-read the default email...
	if (not defined $out) {
		$out = "";
	}

	return $out;
}

sub SetMessage {
	my $host = shift;
	my $Username = shift;
	my $message = shift;

	my $out; my $err; my $exit;

	$ENV{HOME} = '/srv';

	eval { Net::SSH::ssh_cmd ( "$Username\@$host", "echo '$message' > .vacation.msg" ) };
	if ($@) {
		return $!;
	}
	return undef;

}
				
#
# Returns:
# 		1: if the auto-responder is ON
# 		0: if the auto-responder is OFF
# 		an error msg: if a login error occurs
#
sub RetrieveState {
	my $host = shift;
	my $Username = shift;

	my $Forward = "\\".$Username.', "'."|$Vacation $Username".'"';

	my $out; my $err; my $exit;

	# Make sure the Perl Module knows what our Home Directory is.
	# This is a bit of a hack, since running under mod_perl isn't
	# quite like running using the command line
	$ENV{HOME} = "/srv";

	# Read the .forward file
	eval { $out = Net::SSH::ssh_cmd ( "$Username\@$host", "cat .forward" ) };
	if ($@) {
		return (0, 'Error logging in.'. $! );
	}

	# Check to make sure the forward file is what it should be
	if (not defined $out) {
		# file does not exist
		return ( 0, 'File does not exist' );
	} elsif ($out eq "") {
		# File is empty
		return ( 0, 'File is empty' );
	} else {
		# If the forward command is not identical, we assume
		# the auto-responder is OFF
		chomp($out);
		if ($out ne $Forward) {
			return ( 0, 'Forward file not in the correct format.' );
		}
	}

	return ( 1, 'All is good' );
}

sub Start {
	my $host = shift;
	my $Username = shift;

	# Make sure the Perl Module knows what our Home Directory is.
	# This is a bit of a hack, since running under mod_perl isn't
	# quite like running using the command line
	#$ENV{HOME} = "/home/$Username";
	#
	# Odd behavior. On this system/verion of Net::SSH::Perl, the .ssh
	# files written are in the current Users directory, not the one
	# specified in "login". Since 127.0.0.1 was added to
	# /etc/ssh/ssh_known_hosts, write ability is not required to
	# the ssh directory. This alleviates file permission issues.
	$ENV{HOME} = "/srv";


	my $ForwardCmd = "\\".$Username.', "'."|$Vacation $Username".'"';

	eval { Net::SSH::ssh_cmd ( "$Username\@$host", "echo '$ForwardCmd' > .forward" ) };
	if ($@) {
        	return undef;
	}

	return 1;
}

sub Stop {
	my $host = shift;
	my $Username = shift;

	# Make sure the Perl Module knows what our Home Directory is.
	# This is a bit of a hack, since running under mod_perl isn't
	# quite like running using the command line
	#$ENV{HOME} = "/home/$Username";
	#
	# Odd behavior. On this system/verion of Net::SSH::Perl, the .ssh
	# files written are in the current Users directory, not the one
	# specified in "login". Since 127.0.0.1 was added to
	# /etc/ssh/ssh_known_hosts, write ability is not required to
	# the ssh directory. This alleviates file permission issues.
	$ENV{HOME} = "/srv";

	eval { Net::SSH::ssh_cmd ( "$Username\@$host", "rm .forward" ) };
	if ($@) {
        	return undef;
	}

	return 1;
}

1;
