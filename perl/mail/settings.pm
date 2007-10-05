package mail::settings;

use Apache::Constants qw(:common REDIRECT); # Offers OK, Error, etc for web server.
use Apache::Request;

require mail::auto_responder;
require mail::EmailAutoResponder_Functions;

use strict;

my $NoLocalUserPage = "/error/error_nouser.html";

sub verify_local_user {
	my ($User) = @_;
	my @tokens; # for splitting the lines in the passwd file
	my $status;

	# Check to see if the supplied user exists in the passwd file.
	
	# Open /etc/passwd
	$status = open(PASSWD, "/etc/passwd");
	if (not defined $status) {
		return "NOTFOUND";
	}
	
	# Iterate line by line to see if the first token is the current User
	while(<PASSWD>) {
		# split on ":"
		@tokens = split(/:/, $_);

		# If found, return true
		if ($tokens[0] eq $User) {
			close(PASSWD);
			return "FOUND";
		}
	}
	close(PASSWD);

	# Return False
	return "NOTFOUND";
}

sub get_mail_settings_page {
	my ($r, $log, $variable, $Username, $Password, $page) = @_;

	# Check to make sure the supplied user is a local mail user
	if (verify_local_user($Username) eq "NOTFOUND") {
		$$variable{'Redirect'} = $NoLocalUserPage;
	}
	else {
		# Now send the page
		mail::EmailAutoResponder_Functions::Init($Username, $Password);
		mail::EmailAutoResponder_Functions::SendHTMLOpening($page);
		mail::EmailAutoResponder_Functions::SendInstructions($page);

		mail::EmailAutoResponder_Functions::ProcessInput($r);

		mail::EmailAutoResponder_Functions::SendMessages($page);
		mail::EmailAutoResponder_Functions::SendForms($page, $r);
		mail::EmailAutoResponder_Functions::SendHTMLClosing($page);
	}
	return OK;
}

1;
