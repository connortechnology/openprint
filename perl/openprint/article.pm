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
	if ( $param{'func'} eq 'Save' ) {
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
					# Turn relative links into absolute
					$content =~ s/src="\//src="http:\/\/www.epicurious.com\//g;
					$content =~ s/href="\//href="http:\/\/www.epicurious.com\//g;
					my ( $title ) = $content =~ /<h1 class="fn">(.+?)<\/h1>/;
					my ( $summary ) = $content =~ /<span id="truncatedText" class="summary">(.+?)<\/span>/;
					my ( $thumb ) = $content =~ /<div id="recipe_thumb">(.+?)<\/div>/;
					
					$param{'source_content'} = qq`<div class="Epicurious"><h1>$title</h1><div class="thumb">$thumb</div><div class="summary">$summary</div></div>`;
				} else {
					$log->error("Bad status" . $res->status_line );
					$variable{'information'} .= 'Unable to grab content from source.: ' . $res->status_line . '<br/>';
				} # end if
			 } elsif ( $param{'source'} =~ /glittermuff.tumblr.com/ ) {
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
# Turn relative links into absolute
					 $content =~ s/src="\//src="http:\/\/glittermuff.tumblr.com\//g;
					 $content =~ s/href="\//href="http:\/\/glittermuff.tumblr.com\//g;

					 my ( $source_content ) = $content =~ /(<div class="photo">.+)<!\-\- end single post \-\->/m;
					 $source_content =~ s/<script.*?<\/script>//g;
					 $source_content =~ s/<noscript.*?<\/noscript>//g;
					 $source_content =~ s/<a href="http:\/\/disqus.com" class="dsq-brlink".*<\/a>//g;
					 $source_content =~ s/<div id="disqus_thread"><\/div>//;
					 $source_content =~ s/<div class="notecontainer">.*?<\/ol><\/div>//g;	
					 $source_content =~ s/(\s)\s+/$1/g;
					 $source_content =~ s/<div id="post-id">.*?<\/div>//g;
					 $source_content =~ s/<span class="arrow">.*?<\/span>//g;
					 $source_content =~ s/<span class="reblog">.*?<\/span>//g;
					 $source_content =~ s/<span class="tags">.*?<\/span>//g;
					 $source_content =~ s/<span class="notes">.*?<\/span>//g;
					 $source_content =~ s/<img src="http:\/\/static.tumblr.com\/xequfu2\/eXXkpzidm\/post_bottom.png" style="margin-bottom:-68px; margin-left:-10px;">//g;
					 $source_content =~ s/<div style="text-align:right;">\s+<span class="when">Date:<\/span> (\d\d)\.(\d\d)\.(\d\d)\s+<span class="when">Time:<\/span>\s+(\d\d):(\d\d) (\w\w)\s+<\/div>//mg;
					 $param{'published_on'} = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', 2000+$3, $1, $2, $4 + ( $6 eq 'PM' ? 12 : 0 ), $5 );
					 $param{'source_content'} = qq`<div class="Muffy">$source_content</div>`;
				 } else {
					 $log->error("Bad status" . $res->status_line );
					 $variable{'information'} .= 'Unable to grab content from source.: ' . $res->status_line . '<br/>';
				 } # end if
			} # end if
		} # end if source
		my $body = '';
		my $remainder = $param{'body'};
		my $pre;
my $a;
		while ( $remainder ) {
			( $pre, $a, $remainder ) =~ /(.*)<a (.*)><\/a>(.*)/im;
			$body .= $pre;
			# Do stuff to a
			$body .= $a;
		} # end while
		$param{'body'} = $body;
		$variable{'error'} .= $Article->save(\%param);
	} elsif ( $param{'func'} eq 'Destroy' ) {
		my $Article = new openprint::Article( $param{'article_id'} );
		$variable{'error'} .= $Article->destroy();
	} elsif ( ! $param{'func'} ) {
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
	if ( ! $param{'func'} ) {
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
	if ( $param{'func'} eq 'Save' ) {
		$variable{'error'} .= $variable{'Article'}->save(\%param);
		$variable{'Redirect'} = '/article/history.html';
	} elsif ( $param{'func'} eq 'Copy' ) {
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
        if ( $param{'filename'} ) {
            my $upload = $r->upload('filename');
            if ( ! $upload ) {
                $variable{'error'} .= "There was no upload for $param{'filename'}<br/>";
            } else {
				my $path = '/images/article_categories/' . $Category->id() . '_' . $param{'filename'};
                if ( ! $upload->link( $config{'SkinPath'} . $path ) ) {
                    $variable{'error'} .= "There was an error saving file $param{'filename'} to $config{SkinPath}$path : $!<br/>";
#$Asset->save({'filename'=>''});
                } else {
                    $variable{'error'} .= $Category->save({'image_filename'=>$path});
                    $variable{'information'} .= "File $param{'filename'} was uploaded successfully.<br/>";
                } # end if
            } # end if
		} else {
			$log->debug("No image uploaded");
        } # end if

	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		$variable{'error'} .= $Category->delete();
	} elsif ( $param{'btnFunction'} eq 'Destroy' ) {
		$variable{'error'} .= $Category->destroy();
	} # end if
} # end sub category

sub view {
	my $Article = $variable{'Article'} = new openprint::Article( $param{'article_id'} );
	$Article->set( \%param );
} # end sub view

sub _comments {
	my $Article = $variable{'Article'} = new openprint::Article( $param{'article_id'} );
	if ( $param{'text'} ) {
		if ( ! openprint::Comment->find_one(
			'user_id'	=>	$session{'user_id'},
			'text'		=>	$param{'text'},
			'object_id'	=>	$Article->id(),
			'object_type'	=>	'openprint::Article',
			) ) {

			my $approved = 0;
			if ( $session{'user_type'} eq 'A' or $session{'user_id'} == $Article->created_by() ) {
				$approved = 1;
			} # endif

			$variable{'error'} .= new openprint::Comment()->save({
					'text'			=>	$param{'text'},
					'object_type'	=>	'openprint::Article',
					'object_id'		=>	$Article->id(),
					'approved'		=>	$approved,
					});
		} # end if comment already exists
	} elsif ( $param{'action'} eq 'approve' ) {
		if ( $session{'user_type'} eq 'A' or $session{'user_id'} == $$Article{'user_id'} ) {
			my $Comment = openprint::Comment->find_one('object_id'=>$$Article{'id'}, 'object_type'=>'openprint::Article', 'id'=>$param{'comment_id'} );
			if ( $Comment ) {
				$Comment->save({'approved'=>1});
			} else {
				$variable{'error'} .= 'Comment not found.';
			} # end if
		} else {
			$variable{'error'} .= 'You are not authorized to approve this comment.';
		} # end if
	} # end if
} # end sub _comments

1;
__END__
