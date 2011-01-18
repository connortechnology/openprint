package openprint::article;

use strict;
use LWP::UserAgent;
use openprint;
use vars qw( $r %variable %session %param %config $log $dbh );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*r = \$openprint::r;

require openprint::Article;
require openprint::Article_Category;

sub history {
	if ( $param{'btnFunction'} eq 'Save' ) {
		$param{'company_id'} = $session{'company_id'} if ! $param{'company_id'};
		$param{'published_on'} = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', @param{'published_on_year','published_on_month','published_on_day','published_on_hour','published_on_minute'} );
		my $Article = new openprint::Article( $param{'article_id'} );
		if ( $param{'category_id'} ) {
			delete $param{'category'};
		} else {
			delete $param{'category_id'};
		} # end if
		if ( $param{'source'} ) {
			if ( $param{'source'} =~ /epicurious\.com/ ) {
				my $ua = LWP::UserAgent->new;
				$ua->agent("MyApp/0.1 ");
# Create a request
				my $req = HTTP::Request->new(GET => $param{'source'} );
# Pass request to the user agent and get a response back
				my $res = $ua->request($req);
# Check the outcome of the response
				if ($res->is_success) {
					$log->debug("Content: " . $res->content );
					my $content = $res->content;
					#my ( $title, $summary ) = $res->content =~ /<h1 class="fn">(.+)<\/h1>.*<span id="truncatedText" class="summary">(.*)<\/span>/m;
					$content =~ s/\n\r//g;
					$content =~ s/\n//g;
					my ( $title ) = $content =~ /<h1 class="fn">(.+?)<\/h1>/;
					my ( $summary ) = $content =~ /<span id="truncatedText" class="summary">(.+?)<\/span>/;
					my ( $thumb ) = $content =~ /<div id="recipe_thumb">(.+?)<\/div>/;
					
					$param{'source_content'} = qq`<div class="Epicurious"><h1>$title</h1><div class="thumb">$thumb</div><div class="summary">$summary</div></div>`;
				} else {
					$log->error("Bad status" . $res->status_line );
					$variable{'information'} .= 'Unable to grab content from source.: ' . $res->status_line . '<br/>';
				} # end if
			} # end if
		} # end if
		$variable{'error'} .= $Article->save(\%param);
	} elsif ( $param{'btnFunction'} eq 'Destroy' ) {
		my $Article = new openprint::Article( $param{'article_id'} );
		$variable{'error'} .= $Article->destroy();
	} elsif ( ! $param{'btnFunction'} ) {
	} # end if

	if ( ( ! $session{'/article/history.html?lastupdated'} ) or ( time - $session{'/article/history.html?lastupdated'} ) > ( 12*60*60 ) ) {
		ssi::setup_date_select( '/article/history.html', 'published_on_start', -31 );
		ssi::setup_date_select( '/article/history.html', 'published_on_end', '' );
		ssi::setup_date_select( '/article/history.html', 'created_on_start', -31 );
		ssi::setup_date_select( '/article/history.html', 'created_on_end', '' );
	} # end if
	ssi::save_params( '/article/history.html', ( 
				'created_on_start_year','created_on_start_month','created_on_start_day',
				'created_on_end_year','created_on_end_month','created_on_end_day',
				'published_on_start_year','published_on_start_month','published_on_start_day',
				'published_on_end_year','published_on_end_month','published_on_end_day',
				'published','employee_id','company_id', 'category_id' ) );

	$session{'/article/history.html?published'} = '0' if ! $session{'/article/history.html?published'};
} # end sub history

sub _history {
	if ( ! $param{'btnFunction'} ) {
		ssi::save_params( '/article/history.html', ( 
				'created_on_start_year','created_on_start_month','created_on_start_day',
				'created_on_end_year','created_on_end_month','created_on_end_day',
				'published_on_start_year','published_on_start_month','published_on_start_day',
				'published_on_end_year','published_on_end_month','published_on_end_day',
				'published','employee_id','company_id', 'category_id' ) );
	} # end if
} # end sub _history

sub edit {
	$variable{'Article'} = new openprint::Article( $param{'article_id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
		$variable{'error'} .= $variable{'Article'}->save(\%param);
		$variable{'Redirect'} = '/article/history.html';
	} elsif ( $param{'btnFunction'} eq 'Copy' ) {
		$variable{'Article'} = $variable{'Article'}->copy();
		$variable{'error'} .= $variable{'Article'}->save();
	} # end if
	if ( time - $session{'/article/edit.html?lastupdated'} < ( 12*60*60 ) ) {
		$variable{'Article'}->company_id( $session{'/article/edit.html?company_id'} ) if ! $variable{'Article'}->company_id();
		$variable{'Article'}->published_on( $session{'/article/edit.html?ending'} ) if ! $variable{'Article'}->published_on();
	} # end if
} # end sub edit

sub list {
} # end sub list

sub category {
	my $Category = $variable{'Category'} = new openprint::Article_Category( $param{'category_id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
		$variable{'error'} .= $Category->save(\%param);
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		$variable{'error'} .= $Category->delete();
	} # end if
} # end sub category

sub _view {
	my $Article = $variable{'Article'} = new openprint::Article( $param{'article_id'} );
	$Article->set( \%param );
} # end sub _view

1;
__END__
