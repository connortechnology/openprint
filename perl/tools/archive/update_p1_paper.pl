#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use Date::Calc;
use strict;
require sql;
require configuration;
require logger;
require openprint::Object;
require openprint::Paper;

use openprint ();
use vars qw( $log $dbh %config);
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

$log = new logger( 'warn' );
my %sql_server;
$sql_server{'database'} = $ARGV[0];
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = $ARGV[1];
$sql_server{'password'} = $ARGV[2];

$dbh = sql::open_sql( $log, %sql_server );
configuration::init( $log, $dbh );

$dbh->do( q{alter table paper_prices drop constraint "tbl_paper_prices_lngpaperindex_fkey";});
#$dbh->do( q{alter table paper_purchase_order_contents drop constraint "$2";});
$dbh->do( q{DELETE FROM paper_recommendations where lngpaperindex NOT IN (SELECT lngIndex FROM tbl_Paper)});
# Update paper db now
my %types = sql::execute( undef, undef, q{SELECT name, id FROM Project_Types} );
my $data = $dbh->selectall_arrayref( 'SELECT * FROM tbl_Paper', {'Slice'=>{}} );
foreach my $paper ( @$data ) {
	next if  $$paper{'strname'} eq 'Customer Supplied';
	$log->warn("Considering paper: $$paper{'strname'} $$paper{'strfinish'} $$paper{'strcolour'} $$paper{'strweight'} $$paper{'dblwidth'}x$$paper{'dblheight'}");
	my @papers = openprint::Paper->find(
			'brand'	=>	$$paper{'strname'},
			'finish'=>	$$paper{'strfinish'},
			'colour'=>	$$paper{'strcolour'},
			'weight'=>	$$paper{'strweight'},
			'width'	=>	$$paper{'dblwidth'},
			'height'=>	$$paper{'dblheight'},
			);
	if ( ! @papers ) {
		$log->warn("Adding paper: $$paper{'strname'} $$paper{'strfinish'} $$paper{'strcolour'} $$paper{'strweight'} $$paper{'dblwidth'}x$$paper{'dblheight'}");
		my $Paper = new openprint::Paper();
		$Paper->brand($$paper{'strname'});
		$Paper->finish($$paper{'strfinish'});
		$Paper->colour($$paper{'strcolour'});
		$Paper->weight($$paper{'strweight'});
		$Paper->width($$paper{'dblwidth'});
		$Paper->height($$paper{'dblheight'});
		$Paper->mweight($$paper{'strmweight'});
		$Paper->calliper($$paper{'strcalliper'});
		$Paper->multipart( 0 );
		$Paper->cuttable( $$paper{'ysncutpaper'} eq 'Y' ? 1 : 0 );
		$Paper->doublesided( $$paper{'ysndoublesided'} eq 'Y' ? 1 : 0 );
		$Paper->perfecting( $$paper{'ysnperfecting'} eq 'Y' ? 1 : 0 );
		$Paper->taxexempt1( $$paper{'ysntaxexempt1'} eq 'Y' ? 1 : 0 );
		$Paper->taxexempt2( $$paper{'ysntaxexempt2'} eq 'Y' ? 1 : 0 );
		$Paper->score_required( $$paper{'strcalliper'} > 0.008 ? 1 : 0 );
		$Paper->manufacturer( 'unknown');
    $Paper->quality('new');
		$Paper->owner_id( $config{owner_id} );
    #$Paper->created_on('2007-01-01 00:00:00');
		@{$$Paper{'recommendations'}} = sql::execute( undef, undef, q{SELECT lngProjectTypeIndex FROM paper_recommendations WHERE lngPaperIndex=?}, $$paper{lngindex} );
	$log->warn("Recommended for: @{$$Paper{'recommendations'}}");
		@{$$Paper{'Prices'}} = openprint::PaperPrice->find(paper_id=> $$paper{'lngindex'} );
		$_ = $Paper->save();
		if ( $_ ) {
      die $_;
		} # end if
    #sql::execute( undef, undef, q{UPDATE paper_purchase_order_contents set paper_id=? WHERE paper_id=?}, $Paper->id(), $$paper{lngindex} );
	} else {
		foreach my $Paper ( @papers ) {
			$Paper->mweight($$paper{'strmweight'});
			$Paper->calliper($$paper{'strcalliper'});
			$Paper->multipart( 0 );
			$Paper->cuttable( $$paper{'ysncutpaper'} eq 'Y' ? 1 : 0 );
			$Paper->doublesided( $$paper{'ysndoublesided'} eq 'Y' ? 1 : 0 );
			$Paper->score_required( $$paper{'strcalliper'} > 0.008 ? 1 : 0 );
			$Paper->perfecting( $$paper{'ysnperfecting'} eq 'Y' ? 1 : 0 );
			$Paper->taxexempt1( $$paper{'ysntaxexempt1'} eq 'Y' ? 1 : 0 );
			$Paper->taxexempt2( $$paper{'ysntaxexempt2'} eq 'Y' ? 1 : 0 );

			@{$$Paper{'recommendations'}} = sql::execute( undef, undef, q{SELECT lngProjectTypeIndex FROM paper_recommendations WHERE lngPaperIndex=?}, $$paper{lngindex} );
			@{$$Paper{'Prices'}} = openprint::PaperPrice->find( 'paper_id' => $$paper{'lngindex'} );
			$Paper->manufacturer( 'unknown') if ! $Paper->manufacturer();
			$_ = $Paper->save();
		} # end foreach
	} # end if
} # end foreach paper
$log->warn("Cleaning Up");
$openprint::dbh->do( q{DELETE FROM paper_purchase_order_contents WHERE Paper_Id IN (SELECT lngindex from tbl_Paper)} ) or die $openprint::dbh->errstr();
$openprint::dbh->do( q{DELETE FROM paper_purchase_order_contents WHERE Paper_Id NOT IN (SELECT id from Papers)} ) or die $openprint::dbh->errstr();
$openprint::dbh->do( q{DELETE FROM paper_recommendations WHERE lngPaperIndex IN (SELECT lngindex from tbl_Paper)} ) or die $openprint::dbh->errstr();
$openprint::dbh->do( q{DELETE FROM paper_prices WHERE lngPaperIndex IN (SELECT lngindex from tbl_Paper)} ) or die $openprint::dbh->errstr();
$openprint::dbh->do( q{DELETE FROM tbl_Paper} ) or die $openprint::dbh->errstr();
$dbh->do( q{alter table paper_purchase_order_contents add foreign key (paper_id) references papers (id);}) or die $openprint::dbh->errstr();
$dbh->do( q{alter table paper_prices add foreign key (lngpaperindex) references papers(id)}) or die $openprint::dbh->errstr();
$dbh->do( q{update papers set type='Sheet' where width>0 and height>0}) or die $openprint::dbh->errstr();
$dbh->do( q{update papers set grade=1 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%Gloss%')}) or die $openprint::dbh->errstr();
$dbh->do( q{update papers set grade=1 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%GLOSS%')}) or die $openprint::dbh->errstr();
$dbh->do( q{update papers set grade=1 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%C1S%')}) or die $openprint::dbh->errstr();
$dbh->do( q{update papers set grade=1 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%C2S%')}) or die $openprint::dbh->errstr();
$dbh->do( q{update papers set grade=1 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE 'Coated%')}) or die $openprint::dbh->errstr();
$dbh->do( q{update papers set grade=2 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%Matte%')}) or die $openprint::dbh->errstr();
$dbh->do( q{update papers set grade=2 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%Silk%')}) or die $openprint::dbh->errstr();
$dbh->do( q{update papers set grade=2 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%Dull%')}) or die $openprint::dbh->errstr();
$dbh->do( q{update papers set grade=2 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%Satin%')}) or die $openprint::dbh->errstr();
$dbh->do( q{update papers set grade=4 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%Offset%')}) or die $openprint::dbh->errstr();
$dbh->do( q{update papers set grade=4 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%offset%')}) or die $openprint::dbh->errstr();
$dbh->do( q{update papers set grade=4 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%UnCoated%')}) or die $openprint::dbh->errstr();
$dbh->do( q{update papers set grade=4 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%Smooth%')}) or die $openprint::dbh->errstr();
$dbh->do( q{update papers set grade=4 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%Opaque%')}) or die $openprint::dbh->errstr();
$dbh->do( q{update papers set grade=4 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%Vellum%')}) or die $openprint::dbh->errstr();
$dbh->do( q{update papers set type='Roll' where type IS NULL and height IS NULL}) or die $openprint::dbh->errstr();
