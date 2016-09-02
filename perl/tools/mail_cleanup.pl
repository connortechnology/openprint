#!/usr/bin/perl -w
use lib '/var/www/testing/perl';
use sets;
use strict;
use Date::Calc ();

use constant DAYS_TO_KEEP_TRASH => 60*60*24*90*1;
use constant DEBUG => 0;

my $amavis_home = '/usr/lib/amavis';


my $domain = $ARGV[0] ? $ARGV[0] : '';
my @users;
my $spool_path = '/var/mail/';
$spool_path .= $domain.'/' if $domain;

if ( $ARGV[1] ) {
	@users = ( $ARGV[1] );
} elsif ( opendir DIRHANDLE, $spool_path ) {
	@users = readdir DIRHANDLE;
	closedir DIRHANDLE;
} else {
	print "Cannot open spool dir $spool_path \n";
	die;
} # end if
my $DAYS_TO_KEEP_JUNK = $ARGV[2] ? $ARGV[2] : 7;
my $SECONDS_TO_KEEP_JUNK = $DAYS_TO_KEEP_JUNK*60*60*24;

my ( $year, $month, $day ) = Date::Calc::Today();

my $postfix_uid = getpwnam('postfix');
my $postfix_gid = getgrnam('postfix');

foreach my $user ( @users ) {
	next if $user =~ /^\./;

	my $update_spamassassin = 0;
	foreach my $folder ( '.Junk', '.SpamKiller', '.Junk E-mail' ) {
		if ( ! -e "$spool_path$user/$folder" ) {
			next;
		} 
		print "Spam dir $folder exists for $spool_path$user.\n" if DEBUG;

        if ( ! opendir CUR, "$spool_path$user/$folder/cur" ) {
            print "Unable to open $spool_path$user/$folder/cur\n";
            next;
        } # end if

        my @messages = readdir CUR;
        closedir CUR;
		@messages = sets::exclude( [ '.', '..' ], \@messages );
		next if ! @messages;

		print "sa-learn for " . @messages . " messages.\n" if DEBUG; 
		foreach my $message ( @messages ) {
			my $mtime = ( stat "$spool_path$user/$folder/cur/$message" )[9];
            if ( ! $mtime ) {
                print "Unable to stat $spool_path$user/$folder/cur/$message\n";
                last;
            } # end if
			if ( time - $mtime > $SECONDS_TO_KEEP_JUNK ) {
				print "/usr/bin/sa-learn --spam \"$spool_path$user/$folder/cur/$message\"\n";
				`/usr/bin/sa-learn --dbpath $amavis_home/.spamassassin -u amavis --spam "$spool_path$user/$folder/cur/$message"`;
				unlink "$spool_path$user/$folder/cur/$message";
				$update_spamassassin = 1;
			} # end if
		} # end foreach

	} # end foreach folder
	`/bin/kill -HUP \`/bin/cat /var/run/spamassassin.pid\`` if $update_spamassassin;
	foreach my $folder ( '.Trash', '.Deleted Messages' ) {
		next if $user eq 'matt';
		if ( ! -e "$spool_path$user/$folder" ) {
			next;
		}
		print "Trash dir $folder exists for $spool_path$user.\n" if DEBUG;

		if ( ! opendir CUR, "$spool_path$user/$folder/cur" ) {
			print "Unable to open $spool_path$user/$folder/cur\n";
			next;
		} # end if

		my @messages = readdir CUR;
		closedir CUR;
		@messages = sets::exclude( [ '.', '..' ], \@messages );
		next if ! @messages;

		print "rm for " . @messages . " messages.\n" if DEBUG;
		foreach my $message ( @messages ) {
			my $mtime = ( stat "$spool_path$user/$folder/cur/$message" )[9];
			if ( ! $mtime ) {
				print "Unable to stat $spool_path$user/$folder/cur/$message\n";
				last;
			} # end if
			if ( time - $mtime > DAYS_TO_KEEP_TRASH ) {
				unlink "$spool_path$user/$folder/cur/$message";
			} # end if
		} # end foreach

	} # end foreach folder

} # end foreach $user

1;
__END__
