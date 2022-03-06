#!/usr/bin/perl 
use lib '/var/www/testing/perl';
use strict;
use warnings;
use Digest::MD5;

require sql;
require ssi;
require logger;
require misc;
require configuration;
require openprint::Object;
require openprint::Host;
require openprint::Log;
require openprint::Paper;
use Date::Calc;
use Apache::Session::Postgres;
use File::Basename qw(basename);
use Getopt::Long ();

use openprint ();
use vars qw($log $dbh %config);
*dbh = \$openprint::dbh;
*log = \$openprint::log;
*config = \%openprint::config;

my $program = basename($0);

my $opts = {};
Getopt::Long::GetOptions($opts, 'help',
    'log_file=s', 'log_level=s',
    'db_port=s', 'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s',
    'config=s',
);

if ($opts->{help}) {
    usage();
    exit 0;
}

my %defaults = (
);
foreach my $default ( keys %defaults ) {
    $$opts{$default} = $defaults{$default} if ! $$opts{$default};
} # end foreach default

$log = new logger(level=>'debug', program=>$program);

# Get our configuration information
$$opts{config} = '/etc/openprint/'.$program.'.conf' if !$$opts{config};
if (my $err = configuration::from_file($$opts{config})) {
	$log->error($err);
}
configuration::merge($opts);
foreach my $param ( 'db_name','db_user','db_pass' ) {
	if ( ! $config{$param} ) {
		die "$program: missing required --$param parameter";
	}
} # end foreach required-param

my $r;

$openprint::dbh = sql::open_sql( $log, 
	port		=> $config{db_port},
	host		=> $config{db_host},
	database	=> $config{db_name},
	driver		=> 'Pg',
	login		=> $config{db_user},
	password	=> $config{db_pass},
);
die 'Error opening db' if ! $dbh;

configuration::init( \%config );
configuration::from_file($$opts{config});
configuration::merge($opts);

# Paper maintenance
foreach my $Paper ( openprint::Paper->find( 'project_type_id exists' => 1 ) ) {
  my $clone = $Paper->clone();
	if ( (! $$Paper{basis_mweight} ) and $Paper->basis_mweight() ) {
    $log->debug('Updating basis_weight');
    (new openprint::Log())->save({ Object=>$Paper, action=>'Edit', note=>'Updated basis_weight to '.$Paper->basis_mweight() } );
    $Paper->save();
	}
	
	my $check = $Paper->check();
	if ( $check ) {
		if ( $check =~ /basis/ ) {
			if ( $Paper->weight() =~ /(\d+)lb/ ) {
				$log->debug('Updating based on basis_mweight');
				$$Paper{gsm} = undef;
				$$Paper{wpsi} = undef;
				$$Paper{mweight} = undef;
				$Paper->gsm();
				$Paper->mweight();
				$Paper->basis_mweight( 2*$1 );
				$Paper->save();
        my @changes = $clone->changes($Paper);
        (new openprint::Log())->save({ Object=>$Paper, action=>'Edit', note=>'Updated '.join(',', @changes) } );
			}
      $check = $Paper->check();
		}
		$log->error($Paper->to_string() . ' ' . $check . " id:$$Paper{id}");
    if ( $check =~ /Should probably be 20x26/ ) {
      if ( confirm('fix?') ) {
        $Paper->basis_width(20);
        $Paper->basis_height(26);
        $Paper->save();
        my @changes = $clone->changes($Paper);
        (new openprint::Log())->save({ Object=>$Paper, action=>'Edit', note=>'Updated '.join(',', @changes) } );
      }
    } elsif ( $check =~ /Should probably be 17x22/ ) {
      if ( confirm('fix?') ) {
        $Paper->basis_width(17);
        $Paper->basis_height(22);
        $Paper->save();
        my @changes = $clone->changes($Paper);
        (new openprint::Log())->save({ Object=>$Paper, action=>'Edit', note=>'Updated '.join(',', @changes) } );
      }
    }
    sleep(1);
	}

	my $old_wpsi = $Paper->wpsi();
	$old_wpsi = '' if ! defined $old_wpsi;
	next if ! $Paper->wpsi(undef);
	if ( $old_wpsi ne $Paper->wpsi() ) {
$openprint::log->debug("Updating wpsi (old: $old_wpsi, new: $$Paper{wpsi}) for " . $Paper->to_string() );
		$Paper->save();
		last if $dbh->errstr();
	} # end if
} # end foreach my Paper

$dbh->disconnect();

sub usage {
	print <<EOH;

usage: $program [--help] 

The purpose of this script is to cleanup various things in the database.

Command-line options:

	--help		Displays this message.
EOH
}

sub confirm {
  #if ( !exists($$opts{interactive}) or $$opts{interactive} ) {
    my $input;
    print $_[0];
    $input = <STDIN>;
    chomp $input;
    if ( $input eq 'Y' or $input eq 'y' or $input eq '' ) {
      return 1;
    }
    return 0;
    #} else {
    #return 1;
    #}
  return 0;
}

1;
__END__
