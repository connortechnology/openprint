#!/usr/bin/perl -w
use utf8;
use lib '/etc/apache2/lib/perl';
use strict;

require configuration;
require sql;
require ssi;
require misc;
require openprint::Company;
require openprint::User;
require Email::Valid;
require logger;
require openprint::Upload;

use vars qw( $log $dbh %config);
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
$log = logger->new();
$log->{level} = "warn";

use File::Basename qw(basename);
use Getopt::Long;
use Mail::Sendmail;
use MIME::QuotedPrint;
use MIME::Base64 qw(encode_base64);
use Time::HiRes qw(usleep);
use Encode;

my $program = basename($0);

my $opts = {};
GetOptions($opts, 'attach-file', 'fifo=s', 'from=s', 'help', 'ignore-users=s',
	'log=s', 'recipient=s@', 'sleep=s', 'smtp-server=s', 'subject=s',
	'watch-users=s','pid_file=s', 'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s',
	'skin_path=s', 'document_root=s', 'file_path=s','site_title=s', 'site_url=s',
 );

if ($opts->{help}) {
	usage();
	exit 0;
}

unless ($opts->{db_name}) {
	print STDERR "$program: missing required --db_name parameter\n";
	exit 1;
}
unless ($opts->{db_user}) {
	print STDERR "$program: missing required --db_user parameter\n";
	exit 1;
}
unless ($opts->{db_pass}) {
	print STDERR "$program: missing required --db_pass parameter\n";
	exit 1;
}
unless ($opts->{fifo}) {
	print STDERR "$program: missing required --fifo parameter\n";
	exit 1;
}
my $fifo = $opts->{fifo};

unless ($opts->{from}) {
	print STDERR "$program: missing required --from parameter\n";
	exit 1;
}
my $from = $opts->{from};

unless ($opts->{recipient}) {
	print STDERR "$program: missing required --recipient parameter\n";
	exit 1;
}
my $recipients = $opts->{recipient};

unless ($opts->{'smtp-server'}) {
	print STDERR "$program: missing required --smtp-server parameter\n";
	exit 1;
}
my $smtp_server = $opts->{'smtp-server'};

#print "file path: " .  $opts->{file_path} . "\n";

my $delay = 0.5;
if ($opts->{sleep}) {
	$delay = $opts->{sleep};
}

if ( $opts->{'pid_file'} ) {
	my $pidh;
	if (open($pidh, '> '.$opts->{'pid_file'} ) ) {
		print $pidh $$."\n"; 
		close($pidh);
	} else {
		die "Unable to open pid file";
	} # end if
} # end if

$openprint::log->info("Opening SQL connection");
$openprint::dbh = sql::open_sql( $log, 
	'host'		=> $opts->{'db_host'},
	'database'	=> $opts->{'db_name'},
	'driver'	=> 'Pg',
	'login'		=> $opts->{'db_user'},
	'password'	=> $opts->{'db_pass'},
);
die 'Error opening db' if ! $dbh;
%openprint::config = ();
configuration::init_cache( $log, $dbh, {} );
if ( $opts->{'site_url'} ) {
	$config{'siteURL'} = $opts->{'site_url'};
	$config{'ExternalSiteURL'} = $opts->{'site_url'};
} # end if
if ( $opts->{'site_title'} ) {
	$config{'SiteTitle'} = $opts->{'site_title'};
} # end if
if ( $opts->{'skin_path'} ) {
	$config{'SkinPath'} = $opts->{'skin_path'};
} # end if

my $fifoh;
if (open($fifoh, "< $fifo")) {
	while (1) {
		my $line = <$fifoh>;
		if ($line) {
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

				my $xfer_type = $6;
				my $action_flag = $7;
				my $xfer_direction = $8;
				my $access_mode = $9;
				my $user_name = $10;
				my $completion_status = $11;

				my $send_email = 0;

				if ($xfer_direction eq 'i') {
					$send_email = 1;
				}

				if ($send_email) {

					# First, check for any specific --watch-users filter.	If configured,
					# and if the user name does NOT match the --watch-users filter, then
					# don't send email.	Otherwise, check for an --ignore-users filter,
					# and see if the user matches that ignore filter.

					if ($opts->{'watch-users'}) {
						if ($user_name !~ /$opts->{'watch-users'}/) {
							$send_email = 0;
						}

					} elsif ($opts->{'ignore-users'}) {
						if ($user_name =~ /$opts->{'ignore-users'}/) {
							$send_email = 0;
						}
					}
				}

				if ($send_email) {
					send_email({
						timestamp => $curr_time,
						duration => $xfer_nsecs,
						client => $client,
						size => $nbytes,
						file => $path,
						transfer_type => $xfer_type,
						auth_mode => $access_mode,
						user => $user_name,
						status => $completion_status,
					});
				} # end if send email
			}

			if ($opts->{log}) {
				# Note: since this opens, writes, then closes the log file for every
				# write, it will interact with log rotation scripts MUCH better than
				# proftpd by itself.	Just one of the small benefits.

				my $log_file = $opts->{log};
				my $logfh;

				if (open($logfh, ">> $log_file")) {
					print $logfh "$line\n";

					unless (close($logfh)) {
						print STDERR "$program: error writing to log file '$log_file': $!\n";
					}

				} else {
					print STDERR "$program: error opening log file '$log_file': $!\n";
				}
			} # end if log file
		} else {
			# No input at this time. Sleep for half a second (or less) and check again.
			usleep($delay * 1000000);
		} # End if $line
	} # end while <input>

	close($fifoh);
	print "Fifo closed.\n";
} else {
	die "$program: unable to read FIFO '$fifo': $!\n";
}
if ( $opts->{'pid_file'} ) {
	unlink $opts->{'pid_file'};
} # end if

sub send_email {
	my $upload_info = shift;

	my $file = $upload_info->{file};
	my $file_str = basename($file);
	my $regexp = $opts->{'file_path'}.'(.*)'.$file_str;
	my ( $company_name ) = $file =~ /^$regexp$/;
	if ( $company_name ) {
		$company_name =~ s/^\/*//g;
		my @parts = split('/', $company_name);
		$company_name = shift @parts;
	} # end if
	my $proper_file_path = '/'.$company_name.'/'.$file_str;

	my $subject;
	if ($opts->{subject}) {
		$subject = $opts->{subject};
	} else {
		$subject = "User '$upload_info->{user}' uploaded file '$proper_file_path' via FTP";
	}

	my $bytes_str = "bytes";
	if ($upload_info->{size} == 1) {
		$bytes_str = "byte";
	}

	my $status = "Completed";
	if ($upload_info->{status} eq 'i') {
		$status = "Incomplete";
	}

	my $secs_str = "secs";
	if ($upload_info->{duration} == 1) {
		$secs_str = "sec";
	}

	my $type_str = "Binary";
	if ($upload_info->{transfer_type} eq 'a') {
		$type_str = "ASCII";
	}

	my $attached = "";
	if ($opts->{'attach-file'} and -e $file) {
		$attached = "(attached)";
	}

	my $text = <<EOT;
File just uploaded via FTP:

	User: $upload_info->{user}
		Client: $upload_info->{client}

	File: $file $attached
		Size: $upload_info->{size} $bytes_str
		At: $upload_info->{timestamp}
		Duration: $upload_info->{duration} $secs_str
		Status: $status
		Transfer type: $type_str

Cheers,
	--$program

EOT


	my $Company;
	my $User;

	if ( $company_name ) {
# Try to figure out the company
		if ( my @Companies = openprint::Company->find('name'=>$company_name,'limit'=>1) ) {
			$Company = $Companies[0];
		} # end if
	} # end if
	if ( $Company ) {
		if ( my @Users = openprint::User->find('company_id'=>$Company->id(), 'email'=>lc $upload_info->{user},'limit'=>1) ) {
			$User = $Users[0];
		} # end if
	} else {
		if ( my @Users = openprint::User->find('email'=>lc $upload_info->{user},'limit'=>1) ) {
			$User = $Users[0];
			$Company = $User->Company();
		} # end if
	} # end if

	my $Upload = new openprint::Upload();
	my $error = $Upload->save({
		('company_id'	=>	$Company ? $Company->id() : undef),
		('user_id'		=>	$User ? $User->id() : undef ),
		'company'		=>	$company_name,
		'size'			=>	$upload_info->{size},
		'total'			=>	$upload_info->{size},
		'finished'		=>	$upload_info->{timestamp},
		'file_path'		=>	$proper_file_path,
		'type'			=>	'FTP',
	});
	if ( $error ) {
		print STDERR $error 
	} else {
		my $File = new openprint::File();
		$error = $File->save({
			'size'		=>	$upload_info->{size},
			'filename'	=>	$proper_file_path,
			'upload_id'	=>	$Upload->id(),
		});
		print STDERR $error if $error;
	} # end if

	if ( $Company and $User ) {
		my $from;
		if ( ! Email::Valid->address( $User->email() ) ) {
			$from = $config{'OrderingEmail'};
		} else {
			$from = sprintf('"%s" <%s>', $User->name(), $User->email() );
		} # end if

		my $to;
		if ( $Company->salesrep_id() ) {
			if ( $Company->CSR()->notification('Client File Uploads') ne 'No' ) {
				$to = sprintf('"%s %s" <%s>', $Company->CSR()->get('firstname','lastname','email') ),
			} # end if
		} else {
			$to = $config{'OrderingEmail'};
		} # end if
		if ( $to ) {
			my %variable;
			$variable{'Company'} = $Company;
			$variable{'User'} = $User;
			$variable{'filename'} = $proper_file_path;
			$variable{'size'} = $upload_info->{size};

			if (-e $opts->{'skin_path'} . '/email_content/uploadfiles_csr_notification.html') {
				$variable{'ReplacementText'} = misc::load_file( $log, $opts->{'skin_path'} . '/email_content/ftp_csr_notification.html' );
			} else {
				$variable{'ReplacementText'} = misc::load_file( $log, $opts->{'document_root'} . '/email_content/ftp_csr_notification.html' );
			} # end if
			$variable{'ReplacementText'} = ssi::variable_substitution( \$variable{'ReplacementText'}, \%variable );
			my $email_template = misc::load_file( $log, $opts->{'skin_path'} . '/email_template.html' );
			my $body = ssi::variable_substitution( \$email_template, \%variable );
			my %mail = (
							SMTP    => $config{'Mail Server'},
							FROM    => $from,
							TO      => $to,
							BCC		=>	'iconnor@penultima.org',
							SUBJECT => $subject,
					   );
			misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp(Encode::encode('utf-8',$body)), 'text/html', 'quoted-printable' ) );
		} # end if
	
	} elsif ( 1 ) {
		my $email_info = {
			smtp => $smtp_server,
			From => $from,
			To => join(', ', @$recipients),
			BCC	=>	'iconnor@point-one.com',
			Subject => $subject,
		};

		if ($opts->{'attach-file'}) {
			if (-e $file) {
				$email_info->{'MIME-Version'} = '1.0';

				my $boundary = '====' . time() . '====';
				$email_info->{'Content-Type'} = "multipart/mixed; boundary=\"$boundary\"";
				$boundary = '--' . $boundary;

				$email_info->{Body} .= "$boundary\n";
				$email_info->{Body} .= "Content-Type: text/plain; charset=\"iso-8859-1\"\n";
				$email_info->{Body} .= "Content-Transfer-Encoding: quoted-printable\n\n";
				$email_info->{Body} .= "$text\n";

				if (open(my $fh, "< $file")) {
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

					$email_info->{Body} .= "Content-Disposition: attachment; filename=\"$file\"\n";
					if ($upload_info->{transfer_type} eq 'a') {
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
					print STDERR "$program: $timestamp: error reading file '$file' for attaching: $!\n";
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

			print STDERR "$program: $timestamp: error sending email: $Mail::Sendmail::error\n";
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
