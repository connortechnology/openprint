#!/usr/bin/perl -w
use lib '/etc/apache2/lib/perl';
use strict;

require sql;
require logger;
require misc;
require openprint::Object;
require openprint::CIP3_PPF;
use MIME::Base64;
use Image::Magick;
use Text::PDF;
use Text::PDF::Filter;
use Compress::Zlib;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'debug' );

$dbh = sql::open_sql( $log, ('database'=>'point-one', 'driver'=>'Pg','login'=>'point-one', 'password'=>'point-one', 'host'=>'www4') );
my %params = (
	'docket'	=> $ARGV[0],
);
$params{'signature'} = $ARGV[1] if $ARGV[1];
$params{'side'} = $ARGV[2] if $ARGV[2];
$params{'order'} = 'created_on DESC';
foreach my $PPF ( openprint::CIP3_PPF->find(%params) ) {
	my $docket = $PPF->docket();
	my $filename = sprintf('%dsg%dsd%s', $PPF->get('docket','signature','side') );
$log->warn("Compressed?" . $PPF->compressed() );
	$PPF->parse();
	
	open F, ">$filename.ppf";
	print F $PPF->compressed()?Compress::Zlib::uncompress(decode_base64($PPF->data())):decode_base64($PPF->data());
	close(F);

	#$PPF->generate_previews( './' );
} # end foreach PPF

$dbh->disconnect();
1;
__END__
