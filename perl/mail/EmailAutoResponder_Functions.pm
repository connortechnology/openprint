package mail::EmailAutoResponder_Functions;

use Apache::Request;

use strict;

require mail::EmailAutoResponder_Impl;

# Variables that come from the CGI
my $VacationMessage;
my $UserName;
my $Password;
my $Command;

my $Error;
my $ConnectError;

my $StartCmd;
my $StopCmd;
my $RetrieveCmd;

my $AutoResponderState; 

# Default variables
my $DefaultVacationMessage = "";

sub Init {
	$StartCmd = "Start Auto-Respond Service";
	$StopCmd = "Stop Auto-Respond Service";
	$RetrieveCmd = "Retrieve Auto-Respond Message";

	undef $UserName;
	undef $Password;
	undef $Command;
	undef $Error;
	undef $ConnectError;

	undef $VacationMessage;
	undef $AutoResponderState; 

	($UserName, $Password) = @_;

}

sub SendHTMLOpening {
	my ($page) = @_;
	$$page .= "<HTML>\n";
	$$page .= "<HEAD>\n";
	$$page .= "<TITLE>";
	$$page .= '<!--#include virtual="/includes/site_specific/title.html" -->';
	$$page .= " Email Auto-Responder Settings";

	$$page .= "</TITLE>\n";


	$$page .= '<script language="javascript" src="/javascripts/detect.js"></script>';
	$$page .= '<script language="javascript">var userType = "<?user_type?>";</script>';
	$$page .= '<script language="javascript" src="/javascripts/menu.js"></script>';
	$$page .= '<script language="javascript" src="/javascripts/main_content.js"></script>';
	$$page .= '<script language="javascript" src="/javascripts/other.js"></script>';
	$$page .= '<script language="javascript">document.write(styleSheet);</script>';
	$$page .= '<link href="/styles/colors.css" rel="stylesheet" type="text/css"> <link href="/styles/main.css" rel="stylesheet" type="text/css">';
	$$page .= '<!--#include virtual="/includes/meta.html" -->';
	$$page .= '<script language="javascript" src="/javascripts/filter_ddm.js"></script>';


	$$page .= "</HEAD>\n";
	$$page .= '<BODY alink="#000000" marginwidth="0" marginheight="0">\n';
	$$page .= '<!--#include virtual="/includes/main/account.html" -->';
	$$page .= '<!--#include virtual="/includes/main/marks/mark2.html" -->';
	$$page .= '<!--#include virtual="/includes/main/bann.html" -->';

	$$page .= '<div id="title" class="titleCSS"><img src="/images/main/titles/account_welcome.gif"></div>';

	$$page .= '<div id="content" class="contentCSS">';

	$DefaultVacationMessage = "";

}

sub SendHTMLClosing {
	my ($page) = @_;

	$$page .= "</div>";
	$$page .= "</BODY>\n";
	$$page .= "</HTML>\n";
}

sub MessagesToSend() {
	# We only need to check for error conditions if a Command
	# is specified. On the first invokation, Command will be undefined.
	if (defined $Command) {
		if ((not defined $UserName) or (not defined $Password) or
			(not defined $VacationMessage) or 
			(not defined $ConnectError) ) {
			$Error = 1;
			return 1;
		}
		else {
			return 0;
		}
	}
}

sub SendMessages {
	my ($page) = @_;

	if (MessagesToSend()) {
		$$page .= "<H3> The following errors occured while tring to process your request: </H3>";

		$$page .= "<OL STYLE=list-style-type:decimal>";
		$$page .= '<FONT COLOR="#ff0000">';

		if (not defined $UserName) {
			$$page .= "<LI>You must supply a Username.<BR>";
		}

		if (not defined $Password) {
			$$page .= "<LI>You must supply a Password.<BR>";
		}

		if (not defined $VacationMessage) {
			$$page .= "<LI>You must supply a Auto-Reply Message.<BR>";
		}

		if (not defined $Command) {
			$$page .= "There was an error processing your request.";
			$$page .= " Please contact your System Administrator.<BR>";
		}

		if (not defined $ConnectError) {
			$$page .= "<LI> There was an logging in with your ";
			$$page .= "Username and Password. If this problem ";
			$$page .= "presists, contact your System Administrator";
		}

		$$page .= "</FONT>";
		$$page .= "</OL>";
		$$page .= "<HR>";
	}
	
	# Tell the user the state of the Auto-Responder
	$AutoResponderState = mail::EmailAutoResponder_Impl::GetAutoResponderState($UserName, $Password);
	$$page .= "<H3> The Auto Responder is ";
	if ( (defined $AutoResponderState) and ($AutoResponderState eq "1") ) {
		$$page .= "ON";
	}
	else {
		$$page .= "OFF";
	}
	$$page .= "</H3>";
}

sub SendInstructions {
	my ($page) = @_;

	$$page .= "<H3> Changing your Auto-Respond E-mail setttings </H3>";
	$$page .= " The Auto-Repond Email option allows you to set a custom";
	$$page .= " message that others will receive when you are away for";
	$$page .= " an extended period of time. They will receive an ";
	$$page .= " automatic reply to messages sent to you, at most, once";
	$$page .= " per week.";
	$$page .= "<BR>";
	$$page .= "";

	$$page .= "<HR>";
}

sub SendForms {
	my ($page, $r) = @_;

	# Open the '/mail/default.eml' file and read it for the
	# default auto-response email message
	my $status = open(DEFAULT_EML, "< " . $ENV{'DOCUMENT_ROOT'} . "/mail/default.eml");
	if (defined $status) {
		$DefaultVacationMessage = "";
		while(<DEFAULT_EML>) {
			$DefaultVacationMessage .= $_;
		}
	}
	else {
		$r->log->error("Unable to open Default Email Message");
		$DefaultVacationMessage = "No default message available";
	}
	close(DEFAULT_EML);

	# Set the Vacation Message if it has not already been set
	if (not defined $r->param('VacationMsg')) {
		# Get the current users message, if it does not exists,
		# use the default message.
		my $msg = mail::EmailAutoResponder_Impl::RetrieveMessage($UserName, $Password);
		if (not defined $msg) {
			$VacationMessage = $DefaultVacationMessage;
		}
		elsif ($msg eq "") {
			$VacationMessage = $DefaultVacationMessage;
		}
		else {
			$VacationMessage = $msg;
		}
			
	}
	else {
		$VacationMessage = $r->param('VacationMsg');
	}

	$$page .= '<FORM NAME="Vacation" METHOD="POST">';
	$$page .= "\n";

	# Pass on the CGI variables to the next page, unless they are
	# generated from this script
	#
	# NB! Do NOT store txtEmail or txtPassword. This will allow
	# page backs to auto-relogin. This is NOT desirable at all
	#foreach my $key ($r->param() ) {
		#if (($key ne "VacationMsg") and ($key ne "Command") and
		    #($key ne "Username") and ($key ne "Password") ) {
			#$$page .= "<INPUT TYPE=HIDDEN ";
			#$$page .= "NAME = " . $key . " ";
			#$$page .= "VALUE = " . $r->param($key);
			#$$page .= ">";
		#}
	#}


	#$$page .= '<INPUT TYPE=HIDDEN NAME ="Username" VALUE = ';
	#$$page .= $UserName . ">";

	# Password Text Box
	#$$page .= '<INPUT TYPE=HIDDEN NAME="Password" ';
	#if ($Password) {
		#$$page .= 'VALUE="';
		#$$page .= $Password;
		#$$page .= '"';
	#}
	#$$page .= '>';
	$$page .= "\n";

	# Vacation Message Text Box
	$$page .= "<B>You may edit your Auto-Respond Message</B>";

	$$page .= '<TEXTAREA ROWS="10" COLS="60" NAME="VacationMsg">';
	if (defined $VacationMessage) {
		$$page .= $VacationMessage;
	}
	$$page .= '</TEXTAREA>';
	$$page .= "\n";

	$$page .= '<BR><BR>';


	if ( (defined $AutoResponderState)  and ($AutoResponderState == 1) ) {
		# Stop Vacation Message Button
		$$page .= '<A HREF="#" onClick="btnOff('. "'StopCommand'";
		$$page .= ');'."Vacation.Command.value='Stop'".'; Vacation.submit(); return false;" ';
		$$page .= 'onmouseover="btnOn(' . "'StopCommand'" . ');" ';
		$$page .= 'onmouseout="btnOff(' . "'StopCommand'" . ');"> ';
		$$page .= '<IMG SRC="/images/buttons/off/stop.gif" ALT="Stop" ';
		$$page .= 'BORDER="0" NAME="StopCommand"> </A>';
		$$page .= "\n";
	}
	else {
		# Start Vacation Message Button
		$$page .= '<A HREF="#" onClick="btnOff('. "'StartCommand'";
		$$page .= ');'."Vacation.Command.value='Start'".'; Vacation.submit(); return false;" ';
		$$page .= 'onmouseover="btnOn(' . "'StartCommand'" . ');" ';
		$$page .= 'onmouseout="btnOff(' . "'StartCommand'" . ');"> ';
		$$page .= '<IMG SRC="/images/buttons/off/start.gif" ALT="Start" ';
		$$page .= 'BORDER="0" NAME="StartCommand"> </A>';
		$$page .= "\n";
	}


	$$page .= '<INPUT TYPE="HIDDEN" NAME="Command" />';

	$$page .= '</FORM>';
	$$page .= "\n";

}

sub ProcessInput {
	# (UserName, Password, Command={Retrieve, Start, Stop})

	my ($r) = @_;

	# Check for valid input
	if (defined $r->param('Command')) {
		$Command = $r->param('Command');
	}
		
	if (defined $r->param('VacationMsg')) {
		$VacationMessage = $r->param('VacationMsg');
	}
	else {
		if (defined $Command) {
			undef $VacationMessage;
		}
	}

	# Now do what we were supposed to do
	if (not defined $Command) {
		return;
	}

	# Command = Start Auto-Respond Service 
	if ($Command eq "Start") {
		$ConnectError = mail::EmailAutoResponder_Impl::StartAutoResponder($UserName, $Password, $VacationMessage);
	}

	# Command = Stop Auto-Respond Service 
	if ($Command eq "Stop") {
		$ConnectError = mail::EmailAutoResponder_Impl::StopAutoResponder($UserName, $Password);
	}

}

1;
