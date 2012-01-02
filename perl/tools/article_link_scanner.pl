#!/usr/bin/perl
use lib '/var/www/testing/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Article;

use openprint ();
use HTML::LinkExtractor;
use Data::Dumper;

use vars qw( $log $dbh %session );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;
@session{'company_id','user_id'} = ( 6, 1085 );

$log = new logger( 'debug' );

$openprint::Object::no_cache = 1;
$ARGV[1] = $ARGV[0] if ! $ARGV[1];
$ARGV[2] = $ARGV[1] if ! $ARGV[2];
$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>$ARGV[3]) );
die if ! $dbh;

my $LX = new HTML::LinkExtractor();

foreach my $Article ( openprint::Article->find() ) {
	my $body = $Article->body();
	$LX->parse( \$body );
	foreach my $link ( @{$LX->links} ) {	
		next if $$link{'tag'} ne 'a';
		if ( ! $$link{'target'} ) {
			print Dumper($link);
			my ( $contents, $text ) = $$link{'_TEXT'} =~ /<a ([^>]+)>([^<]+)<\/a>/;
			my $search_text = $$link{'_TEXT'};
			$search_text =~ s/\//\\\//g;
			$search_text =~ s/\./\\\./g;
			$search_text =~ s/\-/\\\-/g;
			$search_text =~ s/\?/\\\?/g;
			$search_text =~ s/\(/\\\(/g;
			$search_text =~ s/\)/\\\)/g;
print "Search: $search_text\n";
print 'before: ' . $body ."\n";
			while ( $body =~ /$search_text/m ) {
			$body =~ s/$search_text/<a $contents target="_blank">$text<\/>/;
print 'aftere: ' . $body ."\n";
			} # end while
		}
	} # end foreach
	$Article->save({'body'=>$body}) if $body ne $Article->body();
} # end foreach Article

$dbh->disconnect();
1;
__END__
