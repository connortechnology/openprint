package openprint::article;

use strict;
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
		$variable{'error'} .= $Article->save(\%param);
	} elsif ( $param{'btnFunction'} eq 'Destroy' ) {
		my $Article = new openprint::Article( $param{'article_id'} );
		$variable{'error'} .= $Article->destroy();
	} elsif ( ! $param{'btnFunction'} ) {
	} # end if

	if ( ( ! $session{'/article/history.html?lastupdated'} ) or ( time - $session{'/article/history.html?lastupdated'} ) > ( 12*60*60 ) ) {
		ssi::setup_date_select( '/article/history.html', 'published_on', -31 );
	} # end if
	ssi::save_params( '/article/history.html', ( 'published_on_start_year','published_on_start_month','published_on_start_day','published_on_end_year','published_on_end_month','published_on_end_day','published','employee_id','company_id', 'category_id' ) );

	$session{'/article/history.html?published'} = '0' if ! $session{'/article/history.html?published'};
} # end sub history

sub _history {
	if ( ! $param{'btnFunction'} ) {
		ssi::save_params( '/article/history.html', ( 'published_on_start_year','published_on_start_month','published_on_start_day','published_on_end_year','published_on_end_month','published_on_end_day','published','employee_id','company_id', 'category_id' ) );
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

1;
__END__
