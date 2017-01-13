#!/usr/bin/perl -w
use lib '/etc/apache2/lib/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Skid;
require openprint::ManifestContent;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'warn' );

$openprint::Object::no_cache = 1;
$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>'database') );

# SKids that has a manufacturers id but no manifest
foreach my $S ( openprint::Skid->find('has manufacturers_id'=>1, has_manifest_id=>0) ) {
	my @Skids = openprint::Skid->find(id=>$$S{id});
	next if @Skids == 1;
	foreach my $Skid ( @Skids ) {
		if ( ! $Skid->Contents() ) {
			$log->warn("Skid $$Skid{id} has no contents");
		}
		if ( ! openprint::ManifestContent->find(skid_id=>$$Skid{id}) ) {
			$log->warn("Skid $$Skid{id} has no manifest");
		} # end if
		#$Skid->destroy();
	} # end foreach
} # end foraech S
my $dup_count = 0;
foreach my $S ( openprint::Skid->find('has manufacturers_id'=>1,deleted=>[0,1,undef]) ) {
	if ( (my @dups = openprint::Skid->find(manufacturers_id=>$$S{manufacturers_id},deleted=>[0,1,undef]) ) > 1 ) {
		$dup_count += 1;
		my $change = 0;
		foreach my $D ( @dups ) {
			$log->warn("Duplicate for $$D{manufacturers_id}: $$D{id}");
			if ( $D->deleted() ) {
				$D->destroy();
				$change = 1;
				next;
			} # end if
			if ( ! ( openprint::ManifestContent->find_one(skid_id=>$$D{id}) or openprint::SkidContent->find_one(skid_id=>$$D{id}) ) ) {
				$change = 1;
				$D->destroy();
			} 
		} # end foreach
		next if $change;
		if ( @dups == 2 ) {
			if ( $dups[0]->location() eq 'Metro' ) {
				my $ManifestContent = openprint::ManifestContent->find_one(skid_id=>$dups[0]{id});
				if ( ! $ManifestContent ) {
					$log->error("Unable to find ManifestContent for $dups[0]{id}");
					$dups[0]->destroy();
					next;
				} else {
					$ManifestContent->save({ skid_id=>$dups[1]{id} });
					$dups[0]->destroy();
				}
				next;
			} # en dif

			if ( $dups[1]->location() eq 'Metro' ) {
				my $ManifestContent = openprint::ManifestContent->find_one(skid_id=>$dups[1]{id});
				if ( ! $ManifestContent ) {
					$log->error("Unable to find ManifestContent for $dups[1]{id}");
					$dups[1]->destroy();
					next;
				} else {
					$ManifestContent->save({ skid_id=>$dups[0]{id} });
					$dups[1]->destroy();
				}
				next;
			} # en dif
			$log->warn("Unknown location for $dups[0]{id}: " . $dups[0]->location()  . " $dups[1]{id}: " . $dups[1]->location() );
		} # en dif
	} # end if
} # end foreach S
$log->warn("Dups: $dup_count");

$dbh->disconnect();
1;
__END__
