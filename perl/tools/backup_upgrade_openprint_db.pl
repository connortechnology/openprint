#!/usr/bin/perl
use lib '/var/www/testing/perl';
use strict;
require sql;

use Getopt::Long;
use File::Basename qw(basename);

my %opts;
GetOptions(\%opts, 'help',
  'config=s',
  'src_db=s',
  'dst_db=s',
  'src_host=s',
  'date=s',
  'backup_path=s',
  'log_level=s',
  'log_file=s',
);

if ($opts{help}) {
  usage();
  exit 0;
}

my $program = basename($0);

foreach my $param ( 'src_db','dst_db','src_host' ) {
  if ( ! $opts{$param} ) {
    die "$program: missing required --$param parameter";
  } # end if
} # end foreach required-param

#`systemctl stop openprint-ftp_monitor\@$opts{dst_db}.service`;
#`/etc/init.d/apache2 reload`;
if ( !$opts{date} ) {
  use Date::Calc;
  $opts{date} = join('-', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -1 ));
}

chdir "/var/www/openprint/perl/tools";
if ( $opts{backup_path} ) {
  my $path = "/tmp/$opts{src_db}-$opts{date}.sql";
	if ( ! -e $path ) {
		print "Getting db backup $path using scp $opts{src_host}:$opts{backup_path}/$opts{src_db}/$opts{date}.sql $path\n";
		`scp $opts{src_host}:$opts{backup_path}/$opts{src_db}/$opts{date}.sql "$path"`;
	} # end if
	if ( ! -e $path ) {
		die "No db dump";
	}
	print "Dropping db...";
	`su postgres -c "dropdb $opts{dst_db}"`;
	print "done\n";
	print "Create db...";
	`su postgres -c "createdb -E UTF8 $opts{dst_db}"`;
	print "done\n";
	print "Loading db...";
	`su postgres -c "cat $path | pg_restore -Fc -d $opts{dst_db} --no-owner --role=sherwood"`;
	print "done\n";
} else {
#grab directly
	print "Dropping db...";
	`su postgres -c "dropdb $opts{dst_db}"`;
	print "done\n";
	print "Create db...";
	`su postgres -c "createdb -E UTF8 $opts{dst_db}"`;
	print "done\n";
	print "Loading db...";
	`su postgres -c "ssh $opts{src_host} pg_dump $opts{src_db} | psql $opts{dst_db}"`;
	print "done\n";
} # end if

print "upgrading db ...";
`/var/www/openprint/perl/tools/db_change_owner.sh $opts{dst_db} sherwood`;
`/var/www/openprint/perl/tools/db_update.pl $opts{dst_db} sherwood sherwood` or die $!;
`/var/www/openprint/perl/tools/db_update.pl $opts{dst_db} sherwood sherwood` or die $!;
`/var/www/openprint/perl/tools/dump_password.pl  sherwood localhost sherwood sherwood`;
print "done\n";

my ( $version, $updated_on, $backup ) = sql::execute( undef, undef, q{SELECT version,updated_on,backup FROM database_info ORDER BY updated_on DESC LIMIT 1} );
sql::insert(undef, undef, 'database_info', 'version', $version, 'updated_on', 'NOW()', 'backup', 0 ) if $backup;

#`systemctl start openprint-ftp_monitor\@$opts{dst_db}.service`;
print "done\n";
1;
__END__
