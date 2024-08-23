#!/usr/bin/perl -w
use utf8;
use lib '/var/www/openprint/perl';
use strict;

use Getopt::Long;
use File::Basename qw(basename);
my $program = basename($0);

my %options;
GetOptions(\%options, 'help', 
  'db_port=s', 'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s', 'debug=s', 'host_id=s',
);

if ($options{help}) {
  usage();
  exit 0;
}

my %defaults = (
	config	=>	'/etc/openprint/remote_apt_update.conf',
	ping_type	=>	'icmp',
);
foreach my $default ( keys %defaults ) {
	$options{$default} = $defaults{$default} if ! $options{$default};
} # end foreach

require configuration;
require sql;
require openprint::Host;
require logger;
require openprint::Email;
require openprint::Log;

use vars qw( $log $dbh %config);
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
$log = logger->new();
$log->{level} = 'debug';
configuration::init( );
configuration::from_file( $options{config} );
configuration::merge( \%options );
print "Loaded config\n";
foreach my $param ('db_name', 'db_user', 'db_pass') {
  die "$program: missing required --$param parameter" if ! $config{$param};
} # end foreach required-param

if ( $config{'site_url'} ) {
	$config{'siteURL'} = $config{'site_url'};
	$config{'ExternalSiteURL'} = $config{'site_url'};
} # end if
$config{'SiteTitle'} = $config{'site_title'};
$config{'SkinPath'} = $config{'skin_path'};

$config{'log_level'} = 'debug' if ! $config{'log_level'};
$log = logger->new( {'file'=>$config{'log_file'}, 'level'=>$config{'log_level'}} );

$dbh = sql::open_sql( $log,
    port => $config{db_port},
		host		=> $config{db_host},
		database	=> $config{db_name},
		driver	=> 'Pg',
		login		=> $config{db_user},
		password	=> $config{db_pass},
		);
die "Error opening db. $!" if !$dbh;
print "Connected to db\n";

require Net::SSH2;
require Net::Ping;
# udp has less network traffic overhead
my $p = Net::Ping->new('icmp', 10);

my @Hosts = $options{host_id} ? openprint::Host->find(id=>$options{host_id}) : openprint::Host->find(monitored=>1, order=>'id');
$log->debug( 'Checking ' . @Hosts . ' hosts.' );
foreach my $Host ( @Hosts ) {
	foreach my $HI ( $Host->Interfaces() ) {
		if (!$HI->ip() ) {
			$log->debug( "Monitored host without ip: " . $Host->to_string() );
			next;
		} # end if
    $log->debug( "Pinging ip: " . $HI->ip() );
    if (!$options{noping}) {
      my @ping = $p->ping($HI->ip());
      my $ping = $ping[0];
      if (!@ping) {
        $log->warn("Problem with ping for " . $Host->hostname() );
        next;
      } # end if
      if (!$ping) {
        $log->warn("Failed ping for ".$Host->hostname());
        next;
      }
    } # end if noping

    print "Connecting to $$Host{hostname} $config{username}\@$$HI{ip}\n";
    my $ssh = Net::SSH2->new(debug=>0);
    $ssh->connect($HI->ip()) or $ssh->die_with_error;
    $ssh->check_hostkey('tofu') or $ssh->die_with_error;
    my $home  = '/home/ipc';
    #print "Using $config{username} $home/.ssh/id_ed25519.pub, $home/.ssh/id_ed25519 \n";
    if (!$ssh->auth_publickey($config{username}, "$home/.ssh/id_ed25519.pub", "$home/.ssh/id_ed25519")) {
      `ssh-copy-id $config{username}\@$$HI{ip}`;
      $ssh->auth_publickey($config{username}, "$home/.ssh/id_ed25519.pub", "$home/.ssh/id_ed25519") or $ssh->die_with_error;
    }
    print "rsync -rav $home/VueIPSkin  $config{username}\@$$HI{ip}...\n";
    `rsync -rav $home/VueIPSkin  $config{username}\@$$HI{ip}:`;
    print $!."\n" if $!;
    foreach my $cmd ( 
      #'cd vueip_install && git pull',
      #'sudo -S cp vueip_install/etc/sudoers.d/upgrades /etc/sudoers.d/',
      'sudo /usr/bin/apt update',
      'sudo /usr/bin/apt -y -f -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade',
      #'cd /usr/share/zoneminder/www/skins/classic/css/VueIP/ && sudo /usr/bin/git pull /home/ipc/VueIPSkin',
      #'mysql -u zmuser --password=zmpass zm -e "UPDATE Config SET Value=\'<img width=\"212\" height=\"63\" src=\"/skins/classic/css/VueIP/graphics/vueiplogo2023_horizontal.png\"/>\' WHERE Name=\'ZM_HOME_CONTENT\'"',
      #'mysql -u zmuser --password=zmpass zm -e "UPDATE Config SET Value=\'https://ipcnv.com/surveillance\' WHERE Name=\'ZM_HOME_URL\'"',

    ) {
      print "Execing $cmd\n";
      #print "Opening channel\n";
      my $chan = $ssh->channel() or $ssh->die_with_error;
      $chan->exec($cmd. ' 2>&1') or $ssh->die_with_error;
      #print "Output:\n";
      my $output = '';
      while (<$chan>) {
        $output .= $_;
        last if !$_;
        print;
      }
      if ($chan->exit_status) {
        print "EXIT CODE: ", $chan->exit_status, "\n";
        die if !confirm('Continue? [Y|n]', 'Y');
      }
    } # end foreach cmd
    last; 
  } # end foreach HI
} # end foreach $Host
$p->close();
$dbh->disconnect() if $dbh;
exit 0;

sub usage {
	print <<EOH;

usage: remote_apt_update [--help] 


Command-line options:

	--help		Displays this message.

EOH
} # end sub usage

sub confirm {
  my $prompt = shift;
  my $default = @_ ? lc shift : 'y';
  print $prompt ? $prompt : "Confirm? (Y|n)";
  if ( $options{y} ) {
    print "Y\n";
    return 1;
  }
  if ( $options{n} ) {
    print "N\n";
    return 0;
  }
  $_=<STDIN>; chomp;
  return 1 if $_ and ( lc($_) eq 'y');
  return 1 if (!$_) and (lc $default eq 'y');
  return 0;
}
1;
__END__
