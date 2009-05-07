#!/usr/bin/perl
use lib qw( /etc/apache2/lib/perl );
use Linux::Inotify2;
use Fcntl qw(:flock);


use strict;

require sets;
require sql;
require logger;
require configuration;
require openprint::CIP3_PPF;
require openprint::Project;
require openprint::service;
use openprint ();
use MIME::Base64;
use Getopt::Long;
use Compress::Zlib;

use vars qw( $log $dbh %config $use_compression );

*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
$use_compression = 1;

$log = logger->new();
$log->{level} = 'warn';

my $program = 'PPF_Monitor.pl';
my $opts = {};
GetOptions($opts, 'help', 'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s','equipment_name=s','skin_path=s');

if ($opts->{help}) {
	usage();
	exit 0;
}

unless ($opts->{db_host}) {
	print STDERR "$program: missing required --db_name parameter\n";
	exit 1;
}
unless ($opts->{db_name}) {
	print STDERR "$program: missing required --db_name parameter\n";
	exit 1;
}
$opts->{db_user} = $opts->{db_name} if ! $opts->{db_user};
$opts->{db_pass} = $opts->{db_name} if ! $opts->{db_pass};

$dbh = sql::open_sql( $log,
		'host'      => $opts->{db_host},
		'database'  => $opts->{db_name},
		'driver'    => 'Pg',
		'login'     => $opts->{db_user},
		'password'  => $opts->{db_pass},
		);
die 'Error opening db' if ! $dbh;

configuration::init_cache( $log, $dbh, {'SkinPath'=> $opts->{skin_path}});

my @Equipment = openprint::Equipment::find('cip3_monitor'=>1,'strid'=>$opts->{equipment_name});
if ( ! @Equipment ) {
	die "No equipment found.\n";
} # end if
foreach my $Equipment ( @Equipment ) {
	my @filenames;
	if ( ! open(S, "> $$Equipment{cip3_in}/.lock.lck") ) {
		$log->error("Unable to open semaphore\n");
		next;
	} # end if
	if ( ! flock(S, LOCK_EX) ) {
		$log->error("Unable to lock semaphore\n");
		next;
	} # end if
	if ( opendir DIRHANDLE, $Equipment->cip3_in() ) {
		@filenames = readdir DIRHANDLE;
		closedir DIRHANDLE;
	} else {
		print "Cannot open input hotfolder for $$Equipment{name} at $$Equipment{cip3_in}\n";
		next;
	} # end if

	if ( $$Equipment{'cip3_merge'} ) {
		# First have to look for Back's, so that we don't process fronts before backs.
		foreach my $file ( @filenames ) {
			# Will ignore ., .., any hidden file
			next if $file =~ /^\./; 
			my ( $file_base, $side, $extension ) = $file =~ /^(.*)([AB])\.(ppf)$/i;
#$log->debug("Parsed to $file_base, $side, $extension from $file");
			next if $side ne 'B';

			my $out_base = $file_base;
			$out_base =~ s/\./_/g;

			my ( $docket, $ppo, $name, $sig ) = $file_base =~ /^(\d\d\d\d\d)(\w\w)?_?(.*?)S?g?(\d+)/i;
	#print "File: $file Docket $docket, Operattor: $ppo, Name: $name, Sig: $sig, $side\n";
			$sig = 0 if ! $sig;
			my $data;
			$side = 'M';
			if ( ! sets::isin( $file_base.'A.'.$extension, @filenames ) ) {
				print "A file not found " . $$Equipment{'cip3_in'}.'/'.$file_base."A.$extension ignoring B\n" ;
				next;
			} # end if
			@filenames = sets::exclude( [$file_base.'A.'.$extension,$file_base.'B.'.$extension], \@filenames );	

			if ( ! open ( FH, '< ' . $$Equipment{'cip3_in'}.'/'.$file_base.'B.'.$extension ) ) {
				print "Error opening " . $$Equipment{'cip3_in'}.'/'.$file_base."B.$extension\n" ;
				next;
			} # end if

			my @Back;
			my $back_flag = 0;	
			while ( <FH> ) {
				$back_flag = 1 if ( $_ =~ /CIP3BeginBack/ );
				push @Back, $_ if ( $back_flag );
				last if $_ =~ /CIPEndBack/;
			} # end while
			close( FH );
			if ( ! @Back ) {
				print "No Back found in B file!\n";
				rename $$Equipment{'cip3_in'}.'/'.$file_base.'B.'.$extension, $$Equipment{'cip3_in'}.'/'.$file_base.'E.'.$extension;
				next;
			} # end if

			my $A;
			if ( ! open( $A, '< '.$$Equipment{'cip3_in'}.'/'.$file_base.'A.'.$extension ) ) {
				print "Error opening " . $$Equipment{'cip3_in'}.'/'.$file_base."A.$extension\n" ;
				next;
			} # end if
			my $fileA = $file_base.'A';
			my $fileM = $file_base.'M';

			while ( <$A> ) {
				my $line = $_;
				next if $line =~ /^CIP3EndSheet/;
				$line =~ s/$fileA/$fileM/g;
				if ( $line =~ /^\/CIP3AdmSheetName \(Sheet (\d*)\) def/ ) {
					$line = sprintf("/CIP3AdmSheetName (Sig#%dSheet#%d) def\r\n", 1*$sig, $1 );
				} # end if

				if ( $line =~ /CIP3EndOfFile/ ) {
					foreach ( @Back ) {
						$data .= $_;
					} # end foreach
				} # end if
				$data .= $line;
			} # end while
			close $A;

			
			my $PPF = store_PPF( $docket, $sig, $side, $data );
			$PPF->send_ppf( $Equipment ) if ! $$Equipment{'cip3_hold'};
			unlink $$Equipment{'cip3_in'}.'/'.$file_base.'A.'.$extension;
			unlink $$Equipment{'cip3_in'}.'/'.$file_base.'B.'.$extension;
		} # end foreach file in input hotfolder
	} # end if cip3_merge

	foreach my $file ( @filenames ) {
		# Will ignore ., .., any hidden file
		next if $file =~ /^\./; 
		my ( $file_base, $side, $extension ) = $file =~ /^(.*)([AB])\.(ppf)$/i;
#$log->debug("Parsed to $file_base, $side, $extension from $file");
		my $out_base = $file_base;
		$out_base =~ s/\./_/g;
		my $data;

		my ( $docket, $ppo, $name, $sig ) = $file_base =~ /^(\d\d\d\d\d)(\w\w)?_?(.*?)S?g?(\d+)/i;
		if ( ! $docket ) {
			$log->error("Docket $docket not found for ($file_base) ($file)");
			next;
		} # end if docket

		if ( ! open ( IN, '< ' . $$Equipment{'cip3_in'}.'/'.$file ) ) {
			print "Error opening for read:" . $$Equipment{'cip3_in'}.'/'.$file."\n" ;
			next;
		} # end if
		while ( <IN> ) {
			my $line = $_;
			if ( $line =~ /^\/CIP3AdmSheetName \(Sheet (\d*)\) def/ ) {
				$line = sprintf("/CIP3AdmSheetName (Sig#%dSheet#%d) def\r\n", 1*$sig, $1 );
			} # end if
			$data .= $line;
		} # end while
		close IN;
		my $PPF = store_PPF( $docket, $sig, $side, $data );
		$PPF->send_ppf( $Equipment ) if ! $$Equipment{'cip3_hold'};
		unlink $$Equipment{'cip3_in'}.'/'.$file;
	} # end foreach file in input hotfolder
	close S;

} # end foreach Equipment
$dbh->disconnect() if $dbh;

sub store_PPF {
	my ( $docket, $sig, $side, $data ) = @_;

	foreach my $PPF (openprint::CIP3_PPF::find('docket'=>$docket,'signature'=>$sig,'side'=>$side)) {
		$PPF->delete();
	} # end foreach

	my $compressed_data;
	if ( $use_compression ) {
		$compressed_data = Compress::Zlib::compress($data);
		$log->debug("Compressed PPF from " . length $data . " to " . length $compressed_data );
	} # end if
	my $PPF = new openprint::CIP3_PPF();
	$_ = $PPF->save({
			'docket'    	=>  $docket,
			'signature' 	=>  $sig,
			'side'      	=>  $side,
			'data'      	=>  encode_base64($compressed_data ? $compressed_data : $data),
			'compressed'		=>	$compressed_data ? 1 : 0,
			});
	$log->error($_) if $_;
	$PPF->generate_previews(undef,1);

	foreach my $Project ( openprint::Project::find('docket'=>$docket) ) {
		my $services = $Project->services();

		my $found = 0;
		foreach my $ss_id ( $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
			if ( $$services{'AdditionalSignature'} ) {
				if ( $sig == $$sig_specs{'SignatureIndex'} ) {
					$found = 1;
					last;
				} # end if
			} elsif ( $sig == $$sig_specs{'SignatureIndex'}+1 ) {
				$found = 1;
				last;
			} # end if
		} # end foreach sig
		if ( ! $found ) {
			print "Adding new signature for $docket $sig $side\n";
			my $ac = sql::start_transaction( $dbh );
			$dbh->do( 'LOCK TABLE tbl_Service_Specifications IN SHARE ROW EXCLUSIVE MODE' ) or $log->error( $dbh->errstr() );
			my ($print_service_index) = openprint::print_project::insert_service( $log, $dbh, $Project->id(), 'AdditionalSignature' );
			openprint::service::status( $Project->id(), $print_service_index, 'Ordered' );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $print_service_index, 'txtPrice'.$Project->ordered_quantity_index(), 0 );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $print_service_index, 'txtSignatureType', 'Interior Spreads' );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $print_service_index, 'txtServiceDescription', 'Interior Spreads' );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $print_service_index, 'SignatureIndex', $sig );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $print_service_index, 'ddmRunStyleUsed', $PPF->runstyle() );
			sql::end_transaction( $dbh, $ac );
			$Project->add_to_log( undef, undef, "CIP3 Adding new form $sig $side." );
		} # end if
	} # end foreach Project
	return $PPF;
} # end sub store_PPF

sub usage {
	print <<EOH;

usage: $program [--help] [--db_name \$db_name] [--db_host \$db_host] [--db_user \$db_user] [--db_pass \$db_pass]

The purpose of this script is to monitor the hotfolders configured for each
press for PPF files and perform conversions for Heidelberg JDF, Merge front 
and backs for presses that require it, and to import the PPF previews and 
other data into the IntelligentQuote system.

Command-line options:

	--help		Displays this message.

	--db_host	The hostname of the machine on which the database resides.

	--db_name	The name of the database.
	
	--db_user	The name of the user to use when connecting to the database.

	--db_pass	The password to use when connecting to the database.

EOH
}
1;
__END__


