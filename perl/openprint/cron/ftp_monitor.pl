#!/usr/bin/perl
use utf8;
use lib '/etc/apache2/lib/perl';
use strict;
use warnings;

require configuration;
require sql;
require ssi;
require misc;
require openprint::Company;
require openprint::User;
require Email::Valid;
require openprint::Email;
require openprint::User_Notification;
require logger;
require openprint::Upload;
require openprint;
require openprint::File;
require openprint::Log;

use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

use File::Basename qw(basename);
use Getopt::Long ();
use Mail::Sendmail ();
use MIME::QuotedPrint qw(encode_qp);
use MIME::Base64 qw(encode_base64);
use Encode ();
use Data::Dumper;

my @banned_files = ( 'ftpchk3.txt' );
my $program = basename($0);

my $opts = {};
Getopt::Long::GetOptions($opts, 'attach-file', 'fifo=s', 'from=s', 'help', 'ignore-users=s',
	'log_file=s', 'log_level=s',
	'recipient=s', 'sleep=s', 'smtp-server=s', 'subject=s',
	'watch-users=s','pid_file=s', 'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s',
	'skin_path=s', 'document_root=s', 'file_path=s','site_title=s', 'site_url=s',
	'scoreboard=s','max_files=s', 'config=s',
);

if ($opts->{help}) {
	usage();
	exit 0;
}

my %defaults = (
    config  =>  '/etc/openprint/ftp_monitor.conf',
);
foreach my $default ( keys %defaults ) {
    $$opts{$default} = $defaults{$default} if ! $$opts{$default};
} # end foreach default

$log = new logger(level=>'debug',program=>$program);
# Get our configuration information
if (my $err = configuration::from_file($$opts{config})) {
    die $err;
}

foreach my $param ( 'db_name','db_user','db_pass','fifo','from','recipient','smtp-server' ) {
	$config{$param} = $$opts{$param} if $$opts{$param};
	if ( ! $config{$param} ) {
		die "$program: missing required --$param parameter";
	}
} # end foreach required-param
foreach my $param ( 'pid_file', 'db_host', 'log_file', 'log_level', 'sleep', 'scoreboard', 'file_path','skin_path','document_root','watch-users','ignore-users','site_title','site_url', 'max_files' ) {
	$config{$param} = $$opts{$param} if exists $$opts{$param};
} # end foreach non-required param

if ( $config{'site_url'} ) {
	$config{'siteURL'} = $config{'site_url'};
	$config{'ExternalSiteURL'} = $config{'site_url'};
} # end if

$config{'SiteTitle'} = $config{'site_title'};
$config{'SkinPath'} = $config{'skin_path'};
$config{'log_level'} = 'debug' if ! $config{'log_level'};
$config{'sleep'} = 1.0 if ! $config{'sleep'};

if ( $config{'pid_file'} ) {
	my $pidh;
	if (open($pidh, '> '.$config{'pid_file'} ) ) {
		print $pidh $$."\n"; 
		close($pidh);
	} else {
		die "Unable to open pid file";
	} # end if
} # end if

$log = logger->new( {'file'=>$config{'log_file'}, 'level'=>$config{'log_level'}} );
$log->info("Opening SQL connection");
$openprint::dbh = sql::open_sql( $log, 
	host		=> $config{db_host},
	database	=> $config{db_name},
	driver		=> 'Pg',
	login		=> $config{db_user},
	password	=> $config{db_pass},
);
die 'Error opening db' if ! $dbh;
configuration::init( \%config );
configuration::from_file($$opts{config});
# Cache of recently completed uploads.  keys are username, value is array of upload hashes.  When the user is no longer logged in or
# older than a certain age, the email notification should go out, and the hash entry cleared.
my %uploads;
my %Users; # Cache of User Objects keyed by user/email address

#my $scoreboard = get_scoreboard( $config{'scoreboard'} );
my $fifoh;
if (open($fifoh, "< $config{fifo}")) {
	while (1) {
		my $line;
		eval {
			local $SIG{ALRM} = sub { die "alarm\n" };
			alarm 10;
			$line = <$fifoh>;
			alarm 0;
		}; # end eval
		if ( $@ ) {
			die unless $@ eq "alarm\n";
			check_scoreboard();
			# Update DB scoreboard
			next;
		} elsif ($line) {
			chomp($line);

			if ($line =~ /^(\S+\s+\S+\s+\d+\s+\d+:\d+:\d+\s+\d+)\s+(\d+)\s+(.*?)\s+(\d+)\s+(.*?)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.*?)\s+.*?(\S+)$/o) {
				my $curr_time = $1;
				my $xfer_nsecs = $2;
				my $client = $3;
				my $nbytes = $4;

				# Note that any spaces or control characters will be replaced in this
				# path with underscores.	This can make finding the actual file, as for
				# attachments, rather difficult; we have to test to find the difference
				# between a real underscore in the name, and a substituted underscore.
				my $path = $5;
				my $xfer_type = $6;
				my $action_flag = $7;
				my $xfer_direction = $8;
				my $access_mode = $9;
				my $user_name = $10;
				my $completion_status = $11;

				unless (-e $path) {
					# Perform a quick-and-dirty check, on the assumption that all of the
					# underscores in the given path are actually spaces.	If a
					# combination of underscores and spaces appears in the real file,
					# we won't detect that here.

					my $alt_path = $path;
					$alt_path =~ s/_/ /g;

					if (-e $alt_path) {
						$path = $alt_path;
					}
				}

				my $bad = 0;
				foreach my $banned_re ( @banned_files ) {
					if ( $path =~ /$banned_re/ ) {
						# Detected bad file
						$bad = 1;	
						last;
					} # end if
				} # end foreach banned_re
				if ( $bad ) {
					# Take evasive action
					take_evasive_action($user_name, $client);
					next;
				} # end if


				my $send_email = $xfer_direction eq 'i' ? 1 : 0;

				if ($send_email) {

					# First, check for any specific --watch-users filter.	If configured,
					# and if the user name does NOT match the --watch-users filter, then
					# don't send email.	Otherwise, check for an --ignore-users filter,
					# and see if the user matches that ignore filter.

					if ($config{'watch-users'}) {
						if ($user_name !~ /$config{'watch-users'}/) {
							$send_email = 0;
						}
					} elsif ($config{'ignore-users'}) {
						if ($user_name =~ /$config{'ignore-users'}/) {
							$send_email = 0;
						}
					}
				} # end if send email

				if ($send_email) {
					push @{$uploads{$user_name}}, {
						timestamp => $curr_time,
						duration => $xfer_nsecs,
						client => $client,
						size => $nbytes,
						file => $path,
						transfer_type => $xfer_type,
						auth_mode => $access_mode,
						user => $user_name,
						status => $completion_status,
					};
				} # end if send email
			} else {
				$log->error("Unparsed line $line");
			} # end if

			#$log->debug("$line\n");
			$line = undef;
		} else {
			# No input at this time. Sleep for half a second (or less) and check again.
#$log->debug( "No input\n" );
			check_scoreboard();
			sleep($config{'sleep'}?$config{'sleep'}:10);
		} # End if $line

		if ( ! $dbh->ping() ) {
			$log->warn("REOpening SQL connection");
			$openprint::dbh = sql::open_sql( $log, 
					host		=> $config{db_host},
					database	=> $config{db_name},
					driver		=> 'Pg',
					login		=> $config{db_user},
					password	=> $config{db_pass},
					);
			die 'Error opening db' if ! $dbh;
			configuration::init( \%config );
			configuration::from_file($$opts{config});
		} # end if
	} # end while <input>

	close($fifoh);
	$dbh->disconnect() if $dbh and $dbh->ping();
} else {
	die "$program: unable to read FIFO '$config{fifo}': $!\n";
}
if ( $config{'pid_file'} ) {
	unlink $config{'pid_file'};
} # end if

sub check_scoreboard {
	my $scoreboard = get_scoreboard( $config{scoreboard} );
	my @users = map { $$_{'user'} } @$scoreboard;
	#$log->debug( "Users: @users in scoreboard\n" );

	foreach my $username ( keys %uploads ) {
		if ( ! exists $Users{$username} ) {
			my $User = openprint::User->find_one('email lc'=>lc $username);
			if ( $User ) {
				$Users{$username}= $User;
				(new openprint::Log())->save({action=>'Login', note=>'Successful FTP Login' } );
			} # end if
		} # end if

		if ( ( ! sets::isin( $username, \@users ) ) or ( $config{'max_files'} and ( @{$uploads{$username}} > $config{'max_files'} ) ) ) {
			$log->debug( "Sending mail for $username\n" );
# No longer logged in, so we can process and send emails.
			send_email( @{$uploads{$username}} );
			delete $uploads{$username};
		} else {
			$log->debug( "Holding mail for $username\n" );
		} # end if
	} # end foreach $user
} # end sub check_scoreboard

sub send_email {
	my @uploads = @_;
	if ( ! @uploads ) {
		$log->error("No uploads!");
		return;
	} # end if

	foreach my $upload ( @uploads ) {
		my $file = $upload->{file};
# File should be the full path, relative to filesystem root.
# Problem is, spaces have been replaced by underscores
		my $file_str = basename($file);
		$$upload{'file_str'} = $file_str;
		my $regexp = $config{'file_path'}.'(.*)'.$file_str;
		my ( $company_name ) = $file =~ /^$regexp$/;
$log->debug("Trying to match ( $regexp in $file, got $company_name");
		if ( $company_name ) {
			$company_name =~ s/^\/*//g;
		   my @parts = split('/', $company_name);
		   $$upload{'company_name'} = shift @parts if @parts;
		} # end if
	   $$upload{'proper_file_path'} = '/'.$$upload{'company_name'}.'/'.$file_str;
	} # end foreach upload

	my $upload = $uploads[0];
	my $subject;
	if ($config{subject}) {
		$subject = $config{subject};
	} elsif ( scalar @uploads == 1 ) {
		$subject = "User '$upload->{user}' uploaded file '$$upload{proper_file_path}' via FTP";
	} else {
		$subject = "User '$upload->{user}' has uploaded files via FTP";
	} # end if

	my $dbh_count = 1;
	while ( ! ( $openprint::dbh and $openprint::dbh->ping() ) ) {
		$openprint::dbh = sql::open_sql( $log, 
			host		=> $config{'db_host'},
			database	=> $config{'db_name'},
			driver		=> 'Pg',
			login		=> $config{'db_user'},
			password	=> $config{'db_pass'},
		);
		$log->error("Unable to connect to database, try $dbh_count. sleeping.");
		$dbh_count += 1;
		sleep(1);
	} # end while no db connection

	my $Company;
	my $User;

	if ( $$upload{company_name} ) {
# Try to figure out the company
		if ( ! ( $Company = openprint::Company->find_one( name=>$$upload{company_name} ) ) ) {
$log->debug("Didn't Found company $$upload{company_name}");
		} else {
$log->debug("Found company $$upload{'company_name'}");
		} # end if
	} # end if
	if ( $Company ) {
		# If we hae the company, then narrow the user search
		if ( $User = openprint::User->find_one( company_id=>$Company->id(), email=>lc $upload->{user}) ) {
$log->debug("Found user $$upload{user} with company");
		} # end if
	} # end if
	if ( ! $User ) {
		if ( $User = openprint::User->find_one('email'=>lc $upload->{user}) ) {
			$Company = $User->Company();
			foreach my $upload ( @uploads ) {
				$$upload{'company_name'} = $Company->name();
				$$upload{'proper_file_path'} = '/'.$$upload{'company_name'}.'/'.$$upload{'file_str'};
			} # end foreach upload
$log->debug("Found user $$upload{user} with out company.  Company is $$Company{name}");
		} # end if
	} # end if

	foreach my $upload ( @uploads ) {
		my $Upload = new openprint::Upload();
		my $error = $Upload->save({
			('company_id'	=>	$Company ? $Company->id() : undef),
			('user_id'		=>	$User ? $User->id() : undef ),
			'company'		=>	$$upload{'company_name'},
			'size'			=>	$upload->{size},
			'total'			=>	$upload->{size},
			'finished'		=>	$upload->{timestamp},
			'start'			=>	$upload->{timestamp},
			'file_path'		=>	$$upload{proper_file_path},
			'type'			=>	'FTP',
		});
		if ( $error ) {
			$log->error( $error );
		} else {
			my $File = new openprint::File();
			$error = $File->save({
				'size'		=>	$upload->{size},
				'filename'	=>	$$upload{proper_file_path},
				'upload_id'	=>	$Upload->id(),
			});
			$log->error( $error ) if $error;
		} # end if
	} # end foreach upload

	if ( $Company and $User ) {
		my $from;
		if ( ! Email::Valid->address( $User->email() ) ) {
			$from = $config{'OrderingEmail'};
		} else {
			$from = sprintf('"%s" <%s>', $User->name(), $User->email() );
		} # end if

		my @to;
		if ( $User->email() =~ /^iconnor/ ) {
			@to = ( $User );
		} else {
			if ( $Company->salesrep_id() ) {
				if ( $Company->CSR()->notification('CSR Client File Uploads') ne 'No' ) {
					@to = ( $Company->CSR() );
				} # end if
			} # end if
			push @to, map { $_->User() } openprint::User_Notification->find('type'=>'Client File Uploads','value'=>'Yes', company_id=>[ $config{Owner}, $Company->id() ] );
		} # end if
		
		if ( ! @to ) {
			@to = ( $config{'OrderingEmail'} );
		} # end if
		if ( @to ) {
			my %variable;
			$variable{'Company'} = $Company;
			$variable{'User'} = $User;
			$variable{'Uploads'} = \@uploads;

			$variable{'ReplacementText'} = ssi::include( '/email_content/ftp_csr_notification.html', \%variable );
			my $body = ssi::include( '/email_template.html', \%variable );
			my $Mail = new openprint::Email();
			$Mail->send(
					FROM    => ( $config{AdministratorEmail} ? $config{AdministratorEmail} : $from ),
					'Reply-To'	=>	$from,
					TO      => \@to,
#BCC		=>	'iconnor@penultima.org',
					SUBJECT => $subject,
					ATTACHMENTS => [ '', MIME::QuotedPrint::encode_qp(Encode::encode('utf-8',$body)), 'text/html', 'quoted-printable' ]
				);
		} # end if
		#$openprint::dbh->disconnect();
	
	} elsif ( 1 ) {
	my $bytes_str = $upload->{size} == 1 ? 'byte' : 'bytes';
	my $status = $upload->{status} eq 'i' ? 'Incomplete' : 'Completed';
	my $secs_str = $upload->{duration} == 1 ? 'sec' : 'secs';
	my $type_str = $upload->{transfer_type} eq 'a' ? 'ASCII' : 'Binary';
	my $attached = ($config{'attach-file'} and -e $$upload{file}) ? '(attached)' : '';
	my $text = <<EOT;
File just uploaded via FTP:

	User: $upload->{user}
		Client: $upload->{client}

	File: $$upload{proper_file_path} $attached
		Size: $upload->{size} $bytes_str
		At: $upload->{timestamp}
		Duration: $upload->{duration} $secs_str
		Status: $status
		Transfer type: $type_str

Cheers,
	--$program

EOT
		my $email_info = {
			smtp => $config{'smtp_server'},
			From => $config{'from'},
			To => $config{'recipient'},
			BCC	=>	'iconnor@point-one.com',
			Subject => $subject,
		};

		if ($config{'attach-file'}) {
			if (-e $$upload{file}) {
				$email_info->{'MIME-Version'} = '1.0';

				my $boundary = '====' . time() . '====';
				$email_info->{'Content-Type'} = "multipart/mixed; boundary=\"$boundary\"";
				$boundary = '--' . $boundary;

				$email_info->{Body} .= "$boundary\n";
				$email_info->{Body} .= "Content-Type: text/plain; charset=\"iso-8859-1\"\n";
				$email_info->{Body} .= "Content-Transfer-Encoding: quoted-printable\n\n";
				$email_info->{Body} .= "$text\n";

				if (open(my $fh, "< $$upload{file}")) {
					binmode($fh);

	# Note: this reads the entire file into memory, and can fail if
	# the file is too big.

					local $/;
					my $attach;
					while (my $data = <$fh>) {
						$attach .= $data;
					}
					close($fh);

					$email_info->{Body} .= "$boundary\n";

					$email_info->{Body} .= "Content-Disposition: attachment; filename=\"$$upload{file}\"\n";
					if ($upload->{transfer_type} eq 'a') {
						$email_info->{Body} .= "Content-Type: text/plain; charset=\"iso-8859-1\"\n\n";
						$email_info->{Body} .= $attach;

					} else {
						$email_info->{Body} .= "Content-Type: application/octet-stream\n";
						$email_info->{Body} .= "Content-Transfer-Encoding: base64\n\n";
						$email_info->{Body} .= MIME::Base64::encode_base64(Encode::encode('utf-8',$attach));
					}

					$email_info->{Body} .= "\n";

				} else {
					my $timestamp = scalar(localtime());
					$log->error( "$program: $timestamp: error reading file '$$upload{file}' for attaching: $!" );
				}

			} else {
	# Couldn't find/access the uploaded file on the filesystem.	This usually
	# indicates either a permissions problem, or a munged filename.
	#
	# XXX Need to handle this better.
			}

		} else {
			$email_info->{Body} = $text;
		}

		my $res = Mail::Sendmail::sendmail(%$email_info);
		unless ($res) {
			my $timestamp = scalar(localtime());

			$log->error( "$program: $timestamp: error sending email: $Mail::Sendmail::error" );
		}
	} # end if can figure out company name or not
} # end sub send_email

sub usage {
	print <<EOH;

usage: $program [--help] [--fifo \$path] [--from \$addr] [--log \$path] [--pid_file \$pid]
	[--recipient \$addr] [--subject \$string] [--smtp-server \$addr]
	[--attach-file] [--ignore-users \$regex | --watch-users \$regex]

The purpose of this script is to monitor the TransferLog written by proftpd
for uploaded files.	Whenever a file is uploaded by a user, an email will be
sent to the specified recipients.	In the email there will be the timestamp,
the name of the user who uploaded the file, the path to the uploaded file, the
size of the uploaded file, and the time it took to upload.

Command-line options:

	--attach-file		If used, this will cause a copy of the uploaded file
			to be included, as an attachment, in the generated
			email.

	--fifo \$path		Indicates the path to the FIFO to which proftpd is
			writing its TransferLog.	That is, this is the path
			that you used for the TransferLog directive in your
			proftpd.conf.	This parameter is REQUIRED.

	--from \$addr		Specifies the email address to use in the From header.
			This parameter is REQUIRED.

	--help		Displays this message.

	--ignore-users \$regex
			Specifies a Perl regular expression.	If the uploading
			user name matches this regular expression, then NO
			email notification is sent; otherwise, an email is
			sent.

	--log \$path		Since this script reads the TransferLog using FIFOs,
			the actual TransferLog file is not written by default.
			Use this option to write the normal TransferLog file,
			in addition to watching for uploads.

	--pid_file \$pid			Specifies a file to put the pid in

	--recipient \$addr	Specifies an email address to which to send an email
			notification of the upload.	This option can be
			used multiple times to specify multiple recipients.
			AT LEAST ONE recipient is REQUIRED.

	--smtp-server \$addr	Specifies the SMTP server to which to send the email.
												This parameter is REQUIRED.

	--subject \$string	Specify a custom Subject header for the email sent.
			The default Subject is:

				User '\$user' uploaded file '\$file' via FTP

	--watch-users \$regex	Specifies a Perl regular expression.	If the uploading
			user name matches this regular expression, then an
			email notification is sent; otherwise, no email is
			sent.

EOH
}

sub time_stamp {
	my @w = reverse ( (localtime($_[0])) [0..5] );
	$w[0]+=1900; $w[1]++;
	return sprintf "%d-%02d-%02d %02d:%02d:%02d", @w;
}

sub get_scoreboard {
	my ( $score_file ) = @_;
	my ($server_uptime, $record);
	my @scoreboard;
#  pid_t pid;
#  uid_t uid;
#  gid_t gid;
#  char user[32];
#  int server_port;
#  char server_addr[80], server_label[32];
#  char client_addr[INET_ADDRSTRLEN];
#  char client_name[PR_TUNABLE_SCOREBOARD_BUFFER_SIZE];
#  char class[32];
#  char cwd[PR_TUNABLE_SCOREBOARD_BUFFER_SIZE];
#  char cmd[5];
#  char cmd_arg[PR_TUNABLE_SCOREBOARD_BUFFER_SIZE];
#  time_t begin_idle, begin_session;
#  off_t xfer_size, xfer_done, xfer_len;
#  unsigned long xfer_elapsed;
#0000000 beef dead 0000 0000 0002 0104 0000 0000
#0000010 2c20 0000 0000 0000 3d87 4c78 0000 0000
#0000020 307c 0000 0021 0000 0021 0000 6369 6e6f

	my $header = "L L l L L L L L";
	my $template = "L L L A32 L A80 A32 A16 A80 A32 A80 A5 A79 L L L L L L";
	my $recordsize = length(pack($template,(  )));
	if ( open(SCORE,$score_file) ) {
		my $headersize = length(pack($header));
		read(SCORE, $record, $headersize );
		while (read(SCORE,$record,$recordsize)) {
			my %score;
			@score{'sce_pid','sce_uid','sce_gid','sce_user','sce_server_port','sce_server_addr',
				'sce_server_label','sce_client_addr','sce_client_name','sce_class','sce_cwd','sce_cmd','sce_cmd_arg','sce_begin_idle','sce_begin_session',
				'sce_xfer_size','sce_xfer_done','sce_xfer_len','sce_xfer_elapsed'} = unpack($template,$record);
			if ($score{'sce_pid'} != 0) {
				push @scoreboard, \%score;
			} # end if
		} # end while
		close(SCORE);
	} else {
		$log->warn("Unable to open scoreboard at $score_file: reason $!");
		sleep 1;
	} # end if
	return \@scoreboard;
} # end sub get_scoreboard

sub take_evasive_action {
	my ( $username, $client ) = @_;

	my $dbh_count = 1;
	while ( ! ( $openprint::dbh and $openprint::dbh->ping() ) ) {
		$openprint::dbh = sql::open_sql( $log, 
			host		=> $config{db_host},
			database	=> $config{db_name},
			driver	=> 'Pg',
			login		=> $config{db_user},
			password	=> $config{db_pass},
		);
		$log->error("Unable to connect to database, try $dbh_count. sleeping.");
		$dbh_count += 1;
		sleep(1);
	} # enw hwhile no db connection

	my $User = openprint::User->find_one('email lc'=>lc $username, ftp_active=>'Y' );
	if ( ! $User ) {
		$log->warn("unable to load insecure user account for $username");
		return;
	} # end if

	my $Company = $User->Company();
	my @To = ( $config{TechSupportEmail} );

	if ( $Company->salesrep_id() ) {
		push @To, $Company->CSR();
	} # end if
		
	my %variable;
	$variable{Company} = $Company;
	$variable{User} = $User;

	$variable{ReplacementText} = ssi::include( '/email_content/ftp_account_compromised.html', \%variable );
	if ( $variable{ReplacementText} ) {
		my $email_template = misc::load_file( $log, $config{'skin_path'} . '/email_template.html' );
		my $body = ssi::variable_substitution( undef, $log, $dbh, \$email_template, \%variable );
		my $Mail = new openprint::Email();
		$Mail->send(
				FROM    =>	$config{TechSupportEmail},
				TO      =>	\@To,
				SUBJECT =>	'FTP Account compromised',
				ATTACHMENTS => [ '', encode_qp(Encode::encode('utf-8',$body)), 'text/html', 'quoted-printable' ]
			);
		$_ = $User->save({ ftp_active=>'N', change_password=>'Y' });
		$log->error($_) if $_;
	} else {
		$log->error("No email content for 'ftp_account_compromised.html'");
	} # end if
	if ( $client ) {
		$log->debug("Blacklisting client $client");
		my $ip;
		if ( $client =~ /[^\d\.]/ ) {
			$_ = gethostbyname($client);
			if ( defined $_ ) {
				$ip = Socket::inet_ntoa($_);
				$log->debug( "Got $ip for $client\n");
			} # end if
		} else {
			$ip = $client;
		} # end if
		if ( $ip ) {
			my @Interfaces = openprint::Host_Interfaces->find(ip=>$ip);
			if ( @Interfaces ) {
				foreach my $Interface ( @Interfaces ) {
					my $Host = $Interface->Host();	
					if ( ! ( $Host->blacklist() or $Host->whitelist() ) ) {
						$_ = $Host->save({blacklist=>1});
						$log->error($_) if $_;
					} # end if
					(new openprint::Log())->save({
							action	=> 'Intrusion', 
							note		=> "FTP violation. User account $username",
							host_id		=> $$Host{id},
							user_id		=> $$User{id},
							company_id	=> $$User{company_id},
							} );
				} # end foreach  Interface
			} else {
				my $Host = new openprint::Host();
				$Host->save({} );
				my $Interface = new openprint::Host_Interface();
				$Interface->save({ ip=>$ip, host_id=>$$Host{id} });
			} # end if
		} # end if
	} else {
		$log->warn("No client to blacklist.");
	} # end if
} # end sub take_evasive_action

1;
__END__
