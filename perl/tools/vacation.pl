#!/usr/bin/perl -w
#
# Virtual Vacation 3.1
# by Mischa Peters <mischa at high5 dot net>
# Copyright (c) 2002 - 2005 High5!
# License Info: http://www.postfixadmin.com/?file=LICENSE.TXT
#
# Additions:
# 2004/07/13  David Osborn <ossdev at daocon.com>
#             strict, processes domain level aliases, more
#             subroutines, send reply from original to address
#
# 2004/11/09  David Osborn <ossdev at daocon.com>
#             Added syslog support          
#             Slightly better logging which includes messageid
#             Avoid infinite loops with domain aliases
#
use DBI;
use strict;

my $db_type = 'Pg';
my @db_host = ( 'database' );
my $db_user = 'postfix';
my $db_pass = 'postfix';
my $db_name = 'mail';
my $sendmail = "/usr/sbin/sendmail";
my $logfile = "/tmp/vacation.log";    # specify a file name here for example: vacation.log
my $debugfile = "/tmp/vacation.dbg";  # sepcify a file name here for example: vacation.debug
my $syslog = 1;   # 1 if log entries should be sent to syslog
my $vacation_for_aliases = 0;

my $dbh;
foreach my $db_host ( @db_host ) {
	$dbh = DBI->connect("DBI:$db_type:dbname=$db_name;host=$db_host", "$db_user", "$db_pass", { RaiseError => 1 });
	last if $dbh;
} # end foreach db_host
die "Couldnt connect to db!" if ! $dbh;

# used to detect infinite address lookup loops
my $loopcount=0;

sub do_query {
   my ($query, @params ) = @_;
   my $sth = $dbh->prepare($query) or die "Can't prepare $query: $dbh->errstr\n";
   $sth->execute(@params) or die "Can't execute the query: $sth->errstr @params";
   return $sth;
}

sub do_debug {
   my ($in1, $in2, $in3, $in4, $in5, $in6) = @_;
   if ( $debugfile ) {
   my $date;
   open (DEBUG, ">> $debugfile") or die ("Unable to open debug file");
   chop ($date = `date "+%Y/%m/%d %H:%M:%S"`);
   print DEBUG "====== $date ======\n";
      printf DEBUG "%s | %s | %s | %s | %s | %s\n", $in1, $in2, $in3, $in4, $in5, $in6;
   close (DEBUG);
   }
}

sub do_cache {
   my ($to, $from) = @_;

   my $sth = do_query ( qq{SELECT * FROM vacation_cache WHERE to_email=? AND from_email=?}, $to, $from );
   if ($sth->rows == 0) {
      $sth = do_query( qq{INSERT INTO vacation_cache VALUES (?,?)}, $to, $from );
	  return 0;
   } # end if
   return $sth->rows;
} # end sub do_cache

sub do_log {
   my ($messageid, $to, $from, $subject) = @_;
   my $date;
   if ( $syslog ) {
       open (SYSLOG, "|/usr/bin/logger -p mail.info -t Vacation") or die ("Unable to open logger"); 
       printf SYSLOG "Orig-To: %s From: %s MessageID: %s Subject: %s", $to, $from, $messageid, $subject;
       close (SYSLOG); 
   }
   if ( $logfile ) {
   open (LOG, ">> $logfile") or die ("Unable to open log file");
   chop ($date = `date "+%Y/%m/%d %H:%M:%S"`);
       print LOG "$date: To: $to From: $from Subject: $subject MessageID: $messageid \n";
   close (LOG);
   }
}

sub do_mail {
   my ($from, $to, $subject, $body) = @_;
   $from =~ s/[\<\>]//g;
   open (MAIL, "| $sendmail -t -f $from") or die ("Unable to open sendmail");
   print MAIL "From: $from\n";
   print MAIL "To: $to\n";
   print MAIL "Subject: $subject\n";
   print MAIL "X-Loop: Postfix Admin Virtual Vacation\n\n";
   print MAIL "$body";
   close (MAIL);
}

sub find_real_address {
   my ($email) = @_;

   my $sth = do_query('SELECT email FROM vacation WHERE email=? and active=true', $email );

   # Recipient has vacation
   if ($sth->rows == 1) {
	   $sth->finish();
	   return ( 1, $email );
   } elsif ( $vacation_for_aliases ) {
	  $sth->finish();
      $sth = do_query( 'SELECT goto FROM alias WHERE address=?', $email );
      # Recipient is an alias, check if mailbox has vacation
      if ($sth->rows == 1) { 
         my @row = $sth->fetchrow_array;
         my $alias = $row[0];
         $sth = do_query('SELECT email FROM vacation WHERE email=? and active=true', $alias );

         # Alias has vacation
         if ($sth->rows == 1) {
			$sth->finish();
            return ( 1, $alias );
         } # end if
      } # end if
	  $sth->finish();
   } # end if
} # end sub

sub send_vacation_email {
	my ($email, $orig_subject, $orig_from, $orig_to, $orig_messageid) = @_;

	if (do_cache($email, $orig_from)) { return; }

	my $sth = do_query( qq{SELECT subject,body FROM vacation WHERE email=?}, $email );
	if ($sth->rows == 1) {
		my @row = $sth->fetchrow_array;
		if ( $row[0] or $row[1] ) {
			do_debug ("[SEND RESPONSE] for $orig_messageid:\n", "FROM: $email (orig_to: $orig_to)\n", "TO: $orig_from\n", "SUBJECT: $orig_subject\n", "VACATION SUBJECT: $row[0]\n", "VACATION BODY: $row[1]\n");
			do_mail ($email, $orig_from, $row[0], $row[1]);
			do_log ($orig_messageid, $orig_to, $orig_from, $orig_subject); 
		} else {
			do_mail ($orig_from, $orig_from, 'Vacation set with empty body and subject! Please either turn off your vacation auto-responder or enter a message to be sent to people while you are away.', '' );
		} # end if
	} # end if
	$sth->finish();

} # end sub send_vacation_email

########################### main #################################

my ($from, $to, $cc, $subject, $messageid);

# Take headers apart
while (<STDIN>) {
   last if (/^$/);
   if (/^from:\s+(.*)\n$/i) { $from = $1; }
   if (/^to:\s+(.*)\n$/i) { $to = $1; }
   if (/^cc:\s+(.*)\n$/i) { $cc = $1; }
   if (/^subject:\s+(.*)\n$/i) { $subject = $1; }
   if (/^message-id:\s+(.*)\n$/i) { $messageid = $1; }
   if (/^precedence:\s+(bulk|list|junk)/i) { exit (0); }
   if (/^x-loop:\s+postfix\ admin\ virtual\ vacation/i) { exit (0); }
}

# If either From: or To: are not set, exit
if (!$from || !$to) { exit (0); }

$from = lc ($from);

# Check if it's an obvious sender, exit
if ($from =~ /([\w\-.%]+\@[\w.-]+)/) { $from = $1; }
if ($from eq "" || $from =~ /^owner-|-(request|owner)\@|^(mailer-daemon|postmaster)\@/i) { exit (0); }

# Strip To: and Cc: and push them in array
my @strip_cc_array; 
my @strip_to_array = split(/, */, lc ($to) );
if (defined $cc) { @strip_cc_array = split(/, */, lc ($cc) ); }
push (@strip_to_array, @strip_cc_array);

my @search_array;

# Strip email address from headers
for (@strip_to_array) {
   if ($_ =~ /([\w\-.%]+\@[\w.-]+)/) { 
	push (@search_array, $1); 
  	do_debug ("[STRIP RECIPIENTS]: ", $messageid, $1, "-", "-", "-");
   }
}

# Search for email address which has vacation
for (@search_array) {
	my ($rv, $email) = find_real_address ($_);
	if ($rv == 1) {
		do_debug ("[FOUND VACATION]: ", $messageid, $from, $to, $email, $subject);
		send_vacation_email( $email, $subject, $from, $to, $messageid);
	} else {
		do_debug ("[DID NOT FIND VACATION]: ", $messageid, $from, $to, $email, $subject);
	} # end if
}
$dbh->disconnect();

0;
__END__
