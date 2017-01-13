#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use Date::Calc;
use strict;
require sql;
require logger;
require openprint::Object;
require openprint::Paper;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'warn' );
my %sql_server;
$sql_server{'database'} = $ARGV[0];
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = 'point-one';
$sql_server{'password'} = 'point-1';

$dbh = sql::open_sql( $log, %sql_server );
$dbh->do( q{alter table paper_prices drop constraint "tbl_paper_prices_lngpaperindex_fkey";});
$dbh->do( q{alter table paper_purchase_order_contents drop constraint "$2";});
$dbh->do( q{DELETE FROM paper_recommendations where lngpaperindex NOT IN (SELECT lngIndex FROM tbl_Paper)});
# Update paper db now
my %types = sql::execute( undef, undef, q{SELECT strName, lngIndex FROM Project_Types} );
my $data = $dbh->selectall_arrayref( 'SELECT * FROM tbl_Paper', {'Slice'=>{}} );
foreach my $paper ( @$data ) {
	next if  $$paper{'strname'} eq 'Customer Supplied';
	$log->warn("Considering paper: $$paper{'strname'} $$paper{'strfinish'} $$paper{'strcolour'} $$paper{'strweight'} $$paper{'dblwidth'}x$$paper{'dblheight'}");
	my @papers = openprint::Paper->find(
			'name'	=>	$$paper{'strname'},
			'finish'=>	$$paper{'strfinish'},
			'colour'=>	$$paper{'strcolour'},
			'weight'=>	$$paper{'strweight'},
			'width'	=>	$$paper{'dblwidth'},
			'height'=>	$$paper{'dblheight'},
			);
	if ( ! @papers ) {
		$log->warn("Adding paper: $$paper{'strname'} $$paper{'strfinish'} $$paper{'strcolour'} $$paper{'strweight'} $$paper{'dblwidth'}x$$paper{'dblheight'}");
		my $Paper = new openprint::Paper();
		$Paper->name($$paper{'strname'});
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
		$Paper->owner_id( 6 );
		$Paper->created_on('2007-01-01 00:00:00');
		@{$$Paper{'recommendations'}} = sql::execute( undef, undef, q{SELECT strID FROM Project_Types WHERE lngIndex IN ( SELECT lngProjectTypeIndex FROM paper_recommendations WHERE lngPaperIndex=?)}, $$paper{lngindex} );
	$log->warn("Recommended for: @{$$Paper{'recommendations'}}");
		@{$$Paper{'Prices'}} = openprint::PaperPrice->find( 'paper_id' => $$paper{'lngindex'} );
		$_ = $Paper->save();
		if ( $_ ) {
			$log->error($_);
			next;
		} # end if
		sql::execute( undef, undef, q{UPDATE paper_purchase_order_contents set paper_id=? WHERE paper_id=?}, $Paper->id(), $$paper{lngindex} );
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

			@{$$Paper{'recommendations'}} = sql::execute( undef, undef, q{SELECT strName FROM Project_Types WHERE lngIndex IN ( SELECT lngProjectTypeIndex FROM paper_recommendations WHERE lngPaperIndex=?)}, $$paper{lngindex} );
			@{$$Paper{'Prices'}} = openprint::PaperPrice->find( 'paper_id' => $$paper{'lngindex'} );
			$Paper->manufacturer( 'unknown') if ! $Paper->manufacturer();
			$_ = $Paper->save();
		} # end foreach
	} # end if
} # end foreach paper
$log->warn("Cleaning Up");
$openprint::dbh->do( q{DELETE FROM paper_purchase_order_contents WHERE Paper_Id IN (SELECT lngindex from tbl_Paper)} );
$openprint::dbh->do( q{DELETE FROM paper_purchase_order_contents WHERE Paper_Id NOT IN (SELECT id from Papers)} );
$openprint::dbh->do( q{DELETE FROM paper_recommendations WHERE lngPaperIndex IN (SELECT lngindex from tbl_Paper)} );
$openprint::dbh->do( q{DELETE FROM paper_prices WHERE lngPaperIndex IN (SELECT lngindex from tbl_Paper)} );
$openprint::dbh->do( q{DELETE FROM tbl_Paper} );
$dbh->do( q{alter table paper_purchase_order_contents add foreign key (paper_id) references papers (id);});
$dbh->do( q{alter table paper_prices add foreign key (lngpaperindex) references papers(id)});
$dbh->do( q{update papers set type='Sheet' where width>0 and height>0});
$dbh->do( q{update papers set grade=1 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%Gloss%')});
$dbh->do( q{update papers set grade=1 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%GLOSS%')});
$dbh->do( q{update papers set grade=1 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%C1S%')});
$dbh->do( q{update papers set grade=1 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%C2S%')});
$dbh->do( q{update papers set grade=1 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE 'Coated%')});
$dbh->do( q{update papers set grade=2 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%Matte%')});
$dbh->do( q{update papers set grade=2 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%Silk%')});
$dbh->do( q{update papers set grade=2 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%Dull%')});
$dbh->do( q{update papers set grade=2 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%Satin%')});
$dbh->do( q{update papers set grade=4 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%Offset%')});
$dbh->do( q{update papers set grade=4 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%offset%')});
$dbh->do( q{update papers set grade=4 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%UnCoated%')});
$dbh->do( q{update papers set grade=4 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%Smooth%')});
$dbh->do( q{update papers set grade=4 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%Opaque%')});
$dbh->do( q{update papers set grade=4 where finish_id IN (SELECT id FROM paperfinishes where shortname LIKE '%Vellum%')});
$dbh->do( q{update papers set type='Roll' where type IS NULL and height IS NULL});
