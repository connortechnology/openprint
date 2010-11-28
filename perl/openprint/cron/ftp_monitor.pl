#!/usr/bin/perl -w
use utf8;
use lib '/var/www/p1/perl';
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
use openprint ();

use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

use File::Basename qw(basename);
use Getopt::Long;
use Mail::Sendmail;
use MIME::QuotedPrint;
use MIME::Base64 qw(encode_base64);
use Time::HiRes qw(usleep);
use Encode;

my $program = basename($0);

my @args = @ARGV;

my $opts = {};
GetOptions($opts, 'attach-file', 'fifo=s', 'from=s', 'help', 'ignore-users=s',
	'log_file=s', 'log_level=s',
	'recipient=s', 'sleep=s', 'smtp-server=s', 'subject=s',
	'watch-users=s','pid_file=s', 'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s',
	'skin_path=s', 'document_root=s', 'file_path=s','site_title=s', 'site_url=s',
	'scoreboard=s',
 );

if ($opts->{help}) {
	usage();
	exit 0;
}

$log = new logger('level'=>'debug');
$log->debug("Help");
# Get our configuration information
if (my $err = ReadCfg('/etc/ftp_monitor.conf')) {
    die $err;
} else {
	#$log->debug("Successfully read cfg");
	#foreach my $k ( keys %CFG::Config ) {
		#$log->debug("$k => $CFG::Config{$k}");
	#} # end foreach
}

foreach my $param ( 'db_name','db_user','db_pass','fifo','from','recipient','smtp-server' ) {
	$CFG::Config{$param} = $$opts{$param} if $$opts{$param};
	if ( ! $CFG::Config{$param} ) {
		die "$program: missing required --$param parameter";
	}
} # end foreach required-param
foreach my $param ( 'pid_file', 'db_host', 'log_file', 'log_level', 'sleep', 'scoreboard', 'file_path','skin_path','document_root','watch-users','ignore-users','site_title','site_url' ) {
	$CFG::Config{$param} = $$opts{$param} if $$opts{$param};
} # end foreach non-requiredp aram
if ( $CFG::Config{'site_url'} ) {
	$CFG::Config{'siteURL'} = $CFG::Config{'site_url'};
	$CFG::Config{'ExternalSiteURL'} = $CFG::Config{'site_url'};
} # end if

$CFG::Config{'SiteTitle'} = $CFG::Config{'site_title'};
$CFG::Config{'SkinPath'} = $CFG::Config{'skin_path'};

$CFG::Config{'log_level'} = 'debug' if ! $CFG::Config{'log_level'};
$CFG::Config{'sleep'} = 1.0 if ! $CFG::Config{'sleep'};

if ( $CFG::Config{'pid_file'} ) {
	my $pidh;
	if (open($pidh, '> '.$CFG::Config{'pid_file'} ) ) {
		print $pidh $$."\n"; 
		close($pidh);
	} else {
		die "Unable to open pid file";
	} # end if
} # end if

$log = logger->new( {'file'=>$CFG::Config{'log_file'}, 'level'=>$CFG::Config{'log_level'}} );
$log->info("Opening SQL connection");
$openprint::dbh = sql::open_sql( $log, 
	'host'		=> $CFG::Config{'db_host'},
	'database'	=> $CFG::Config{'db_name'},
	'driver'	=> 'Pg',
	'login'		=> $CFG::Config{'db_user'},
	'password'	=> $CFG::Config{'db_pass'},
);
die 'Error opening db' if ! $dbh;
configuration::init_cache( $log, $dbh, \%CFG::Config );
# Cache of recently completed uploads.  keys are username, value is array of upload hashes.  When the user is no longer logged in or
# older than a certain age, the email notification should go out, and the hash entry cleared.
my %uploads;

my $scoreboard = get_scoreboard( $config{'scoreboard'} );
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

			$log->debug("$line\n");
			$line = undef;
		} else {
			# No input at this time. Sleep for half a second (or less) and check again.
#$log->debug( "No input\n" );
			check_scoreboard();
			usleep($config{'sleep'} * 1000* 1000);
		} # End if $line

		if ( ! $dbh->ping() ) {
			$log->info("Opening SQL connection");
			$openprint::dbh = sql::open_sql( $log, 
					'host'		=> $CFG::Config{'db_host'},
					'database'	=> $CFG::Config{'db_name'},
					'driver'	=> 'Pg',
					'login'		=> $CFG::Config{'db_user'},
					'password'	=> $CFG::Config{'db_pass'},
					);
			die 'Error opening db' if ! $dbh;
			configuration::init_cache( $log, $dbh, \%CFG::Config );
		} # end if
	} # end while <input>

	close($fifoh);
} else {
	die "$program: unable to read FIFO '$config{fifo}': $!\n";
}
if ( $config{'pid_file'} ) {
	unlink $config{'pid_file'};
} # end if

sub check_scoreboard {
	my $scoreboard = get_scoreboard( $config{'scoreboard'} );
	my @users = map { $$_{'sce_user'} } @$scoreboard;
	#$log->debug( "Users: @users in scoreboard\n" );

	foreach my $user ( keys %uploads ) {
		if ( ! sets::isin( $user, \@users ) ) {
			$log->debug( "Sending mail for $user\n" );
# No longer logged in, so we can process and send emails.
			send_email( @{$uploads{$user}} );
			delete $uploads{$user};
		} else {
			$log->debug( "Holding mail for $user\n" );
		} # end if
	} # end foreach $user
} # end sub check_scoreboard

sub send_email {
	my @uploads = @_;

	foreach my $upload ( @uploads ) {
		my $file = $upload->{file};
# File should be the full path, relative to filesystem root.
# Problem is, spaces have been replaced by underscores
		my $file_str = basename($file);
		$$upload{'file_str'} = $file_str;
		my $regexp = $config{'file_path'}.'(.*)'.$file_str;
		my ( $company_name ) = $file =~ /^$regexp$/;
		if ( $company_name ) {
			$company_name =~ s/^\/*//g;
		   my @parts = split('/', $company_name);
		   $$upload{'company_name'} = shift @parts;
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

	my $Company;
	my $User;

	if ( $$upload{'company_name'} ) {
# Try to figure out the company
		if ( my @Companies = openprint::Company->find('name'=>$$upload{'company_name'},'limit'=>1) ) {
$log->debug("Found company $$upload{'company_name'}");
			$Company = $Companies[0];
		} else {
$log->debug("Didn't Found company $$upload{'company_name'}");
		} # end if
	} # end if
	if ( $Company ) {
		# If we hae the company, then narrow the user search
		if ( $User = openprint::User->find_one('company_id'=>$Company->id(), 'email'=>lc $upload->{user}) ) {
$log->debug("Found user $$upload{user} with company");
		} # end if
	} # end if
	if ( ! $User ) {
		if ( $User = openprint::User->find_one('email'=>lc $upload->{user},'limit'=>1) ) {
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

		my $to;
		if ( $User->email() =~ /^iconnor/ ) {
			$to = '"Isaac Connor" <iconnor@penultima.org>';
		} elsif ( $Company->salesrep_id() ) {
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
			$variable{'Uploads'} = \@uploads;

			if (-e $config{'skin_path'} . '/email_content/ftp_csr_notification.html') {
				$variable{'ReplacementText'} = misc::load_file( $log, $config{'skin_path'} . '/email_content/ftp_csr_notification.html' );
			} else {
				$variable{'ReplacementText'} = misc::load_file( $log, $config{'document_root'} . '/email_content/ftp_csr_notification.html' );
			} # end if
			$variable{'ReplacementText'} = ssi::variable_substitution( \$variable{'ReplacementText'}, \%variable );
			my $email_template = misc::load_file( $log, $config{'skin_path'} . '/email_template.html' );
			my $body = ssi::variable_substitution( \$email_template, \%variable );
			my %mail = (
							SMTP    => $config{'Mail Server'},
							FROM    => $from,
							TO      => $to,
							#BCC		=>	'iconnor@penultima.org',
							SUBJECT => $subject,
					   );
			misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp(Encode::encode('utf-8',$body)), 'text/html', 'quoted-printable' ) );
		} # end if to
	
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
#  pid_t sce_pid;
#  uid_t sce_uid;
#  gid_t sce_gid;
#  char sce_user[32];
#  int sce_server_port;
#  char sce_server_addr[80], sce_server_label[32];
#  char sce_client_addr[INET_ADDRSTRLEN];
#  char sce_client_name[PR_TUNABLE_SCOREBOARD_BUFFER_SIZE];
#  char sce_class[32];
#  char sce_cwd[PR_TUNABLE_SCOREBOARD_BUFFER_SIZE];
#  char sce_cmd[5];
#  char sce_cmd_arg[PR_TUNABLE_SCOREBOARD_BUFFER_SIZE];
#  time_t sce_begin_idle, sce_begin_session;
#  off_t sce_xfer_size, sce_xfer_done, sce_xfer_len;
#  unsigned long sce_xfer_elapsed;
#0000000 beef dead 0000 0000 0002 0104 0000 0000
#0000010 2c20 0000 0000 0000 3d87 4c78 0000 0000
#0000020 307c 0000 0021 0000 0021 0000 6369 6e6f

	my $header = "L L l L L L L L";
	my $template = "L L L A32 L A80 A32 A16 A80 A32 A80 A5 A79 L L L L L L";
	my $recordsize = length(pack($template,(  )));
	open(SCORE,$score_file) or die "Unable' to open $score_file:$!\n";
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
	return \@scoreboard;
} # end sub get_scoreboard

# Read a configuration file
#   The arg can be a relative or full path, or
#   it can be a file located somewhere in @INC.
sub ReadCfg {
    my $file = $_[0];

    our $err;

    {   # Put config data into a separate namespace
        package CFG;
		use vars qw( %Config );

        # Process the contents of the config file
        my $rc = do($file);

        # Check for errors
        if ($@) {
            $::err = "ERROR: Failure compiling '$file' - $@";
        } elsif (! defined($rc)) {
            $::err = "ERROR: Failure reading '$file' - $!";
        } elsif (! $rc) {
            $::err = "ERROR: Failure processing '$file'";
        }
    }

    return ($err);
}

1;
__END__
