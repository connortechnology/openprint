#!/usr/bin/perl -w
use lib '/var/www/testing/perl';
use sets;
use strict;
use Date::Calc ();
use File::Find;           

use constant DAYS_TO_KEEP_JUNK => 60*60*24*7;
use constant DAYS_TO_KEEP_TRASH => 60*60*24*365*1;
use constant DEBUG => 0;

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
my $DAYS_TO_KEEP_JUNK = 60*60*24*7 if ! $ARGV[2];

my ( $year, $month, $day ) = Date::Calc::Today();

my $postfix_uid = getpwnam('postfix');
my $postfix_gid = getgrnam('postfix');

foreach my $user ( @users ) {
	next if $user =~ /^\./;

	my @subscriptions;
	next if ! -e $spool_path.$user.'/subscriptions';

if ( open my $handle, '<', $spool_path.$user.'/subscriptions' ) {
	chomp( @subscriptions = <$handle>);
	close $handle;
} else {
	print "Error opening ".$spool_path.$user.'/subscriptions' . "\n";
	next;
}

	#print "Subscriptions: @subscriptions\n";
	my %subscriptions = map { '.'.$_, $_ } @subscriptions;

	opendir DIRHANDLE, $spool_path.$user;
    my @dirs = map { ( $_ eq 'cur' or $_ eq 'new' or $_ eq 'tmp' or $_ eq '.' or $_ eq '..' or ! $_ =~ /^./ ) ? () : $_ } ( map { -d $spool_path.$user.'/'.$_ ? $_ : () } readdir DIRHANDLE );
    closedir DIRHANDLE;

	#print "Dirs: @dirs\n";
	foreach my $dir ( @dirs ) {
		if ( ! $subscriptions{$dir} ) {
			my $size = 0;             
			find(sub { $size += -s if -f $_ }, $spool_path.$user.'/'.$dir );
			print 	$spool_path.$user.'/'.$dir . ' has size ' . $size . "\n";
		} # end if
	} # end foreach dir

} # end foreach $user

1;
__END__
