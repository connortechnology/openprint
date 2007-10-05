package mail::auto_responder;

use strict;

my $VacationProgram = "/usr/bin/vacation";

#
# This file controls the behavior of the vacation email auto responder.
# It uses the Net::SSH::Perl package to login to the localhost using
# the specified user to read and write the control files.
#

#
# Purpose: Retrieves the contents of the .vacation.msg file
#
# Params:
# 		$Username: Username for local login
# 		$Password: Password for logging in the local user
#
# Pre:
# 		$User is valid local username
# 		Params are defined
#
# Post: Returns the vacation message OR undef
#
sub RetrieveMessage {
	my ($Username, $Password) = @_;
	
	# Do input variable testing
	if ( (not defined $Username) or (not defined $Password) ) {
		return undef;
	}
	if ($Username eq '') {
		return undef;
	}

	return '';
}

#
# Purpose: Starts the email auto responder
#
# Params:
# 		$Username: Username for local login
# 		$Password: Password for logging in the local user
# 		$VacationMsg: Password for logging in the local user
#
# Pre:
# 		$User is valid local username
# 		Params are defined
#
# Post: Creates a .forward file, and a .vacation.msg file in the users
# 	home directory.
#
sub StartAutoResponder {
	my ($Username, $Password, $VacationMsg) = @_;
}

#
# Purpose: Stops the email auto responder
#
# Params:
# 		$Username: Username for local login
# 		$Password: Password for logging in the local user
#
# Pre: $User is valid local username
#
# Post: Returns the vacation message OR undef
#
sub StopAutoResponder {
	my ($Username, $Password) = @_;
}

1;
