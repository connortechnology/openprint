#!/usr/bin/perl
use strict;
use Date::Calc ();

my $domain = $ARGV[0];
my @users;
my $spool_path = '/var/mail/vhosts/'.$domain.'/';

if ( $ARGV[1] ) {
	@users = ( $ARGV[1] );
} elsif ( opendir DIRHANDLE, $spool_path ) {
	@users = readdir DIRHANDLE;
	closedir DIRHANDLE;
} else {
	print "Cannot open spool dir $spool_path \n";
	die;
} # end if

my ( $year, $month, $day ) = Date::Calc::Today();

my $postfix_uid = getpwnam('postfix');
my $postfix_gid = getgrnam('postfix');

foreach my $user ( @users ) {
	next if $user =~ /^\./;
	foreach my $folder ( '.', '.Sent', '.Sent Messages' ) {

		if ( ! opendir INBOXHANDLE, "$spool_path$user/$folder/cur" ) {
			print "Unable to open inbox $spool_path$user/$folder/cur\n" if $folder eq '.';
			next;
		} # end if

		if ( $folder ne '.' ) {
			if ( -e "$spool_path$user/$folder/.".($year-1) ) {
			#print "Already has a directory for email from " . ($year-1)."\n";
				rename "$spool_path$user/$folder/.".($year-1), "$spool_path$user/$folder.".($year-1);
			} # end if
			if ( -e "$spool_path$user/$folder/.".($year-2) ) {
#print "Already has a directory for email from " . ($year-1)."\n";
				rename "$spool_path$user/$folder/.".($year-2), "$spool_path$user/$folder.".($year-2);
			} # end if
			if ( -e "$spool_path$user/$folder/.".($year-3) ) {
#print "Already has a directory for email from " . ($year-1)."\n";
				rename "$spool_path$user/$folder/.".($year-3), "$spool_path$user/$folder.".($year-3);
			} # end if
		} # end if

		my @inbox = readdir INBOXHANDLE;
		closedir INBOXHANDLE;

		if ( scalar @inbox < 100 ) {
			print "Inbox too small to bother $user/$folder/cur : " . @inbox . " entries\n";
			next;
		} else {
			print "For $user/$folder/cur : " . @inbox . " entries\n";
		} # end if @inbox < 100

		my %move_count;
		foreach my $email ( @inbox ) {
			next if $email =~ /^\./;

			my $mtime = ( stat "$spool_path$user/$folder/cur/$email" )[9];
			if ( ! $mtime ) {
				print "Unable to stat $spool_path$user/$folder/cur/$email\n";
				last;
			} # end if
			my ($y,$m,$d, $hour,$min,$sec, $doy,$dow,$dst) = Date::Calc::Localtime( $mtime );

			if ( $y < $year ) {
				$move_count{$y} += 1;	
				next;
			} # end if
		} # end foreach email

		if ( ! %move_count ) {
			print "No changes made for $user/$folder\n";
			next;
		} # end if

		my $process = 0;
		foreach my $y ( sort keys %move_count ) {
			print "$move_count{$y} emails moved for $user/$folder $y\n";
			if ( ! -e "$spool_path$user/$folder/.".$y ) {
				mkdir "$spool_path$user/$folder/.".$y;
				mkdir "$spool_path$user/$folder/.".$y.'/tmp';
				mkdir "$spool_path$user/$folder/.".$y.'/cur';
				mkdir "$spool_path$user/$folder/.".$y.'/new';
				chown $postfix_uid, $postfix_gid, "$spool_path$user/$folder/.".$y, "$spool_path$user/$folder/.".$y.'/tmp', "$spool_path$user/$folder/.".$y.'/cur', "$spool_path$user/$folder/.".$y.'/new';
				if ( -e "$spool_path$user/courierimapsubscribed" ) {
					if ( $folder eq '.' ) {
						`echo "INBOX.$y" >> $spool_path$user/courierimapsubscribed`;
					} else {
						`echo "INBOX$folder.$y" >> $spool_path$user/courierimapsubscribed`;
					} # end if
				} 
				if ( -e "$spool_path$user/ubscriptions" ) {
					if ( $folder eq '.' ) {
						`echo "$y" >> $spool_path$user/subscriptions`;
					} else {
						`echo "$folder.$y" >> $spool_path$user/subscriptions`;
					} # end if
				} # end if
			} # end if
			if ( -e "$spool_path$user/$folder/.".$y and -e "$spool_path$user/$folder/.$y/cur" ) {
				$process = 1;
			} # end if
		} # end foreach

		next if ! $process;

		foreach my $email ( @inbox ) {
			next if $email =~ /^\./;

			my $mtime = ( stat "$spool_path$user/$folder/cur/$email" )[9];
			if ( ! $mtime ) {
				print "Unable to stat $spool_path$user/$folder/cur/$email\n";
				last;
			} # end if
			my ($y,$m,$d, $hour,$min,$sec, $doy,$dow,$dst) = Date::Calc::Localtime( $mtime );

			if ( $y < $year ) {
				if ( $folder ne '.' ) {
				rename "$spool_path$user/$folder/cur/$email", "$spool_path$user/$folder/.$y/cur/$email" or die "Unable to rename $spool_path$user/$folder/cur/$email to $spool_path$user/$folder/.$y/cur/$email\n";
				} else {
				rename "$spool_path$user/cur/$email", "$spool_path$user/.$y/cur/$email" or die "Unable to rename $spool_path$user/$folder/cur/$email to $spool_path$user/$folder/.$y/cur/$email\n";
				} # end if
			} # end if
		} # end foreach email
	} # end foreach folder
	
} # end foreach $user

1;
__END__
