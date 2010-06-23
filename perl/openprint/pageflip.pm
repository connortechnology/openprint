package openprint::pageflip;
use strict;
use openprint ();

use vars qw( $log $dbh %param %config %variable );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*param = \%openprint::param;
*config = \%openprint::config;
*variable = \%openprint::variable;

require openprint::PageFlip;

sub view {
	$variable{'PageFlip'} = new openprint::PageFlip();

	if ( $param{'docket'} ) {
		my $PageFlip = openprint::PageFlip->find_one('docket'=>$param{'docket'});
		if ( ! $PageFlip ) {
			my $Project = openprint::Project->find_one('docket'=>$param{'docket'});
			if ( ! $Project ) {
				$variable{'error'} .= "Invalid docket $param{'docket'}";
				return;
			} # end if

# Go looking for files.
			my @filenames;
			if ( opendir DIRHANDLE, $config{'PageFlipDir'}.'/LR' ) {
				@filenames = readdir DIRHANDLE;
				closedir DIRHANDLE;
			} else {
				$log->error( "Cannot open $config{'PageFlipDir'}" );
			} # end if
			$log->debug("# of files read " . @filenames );
			my @pages;
			foreach my $file ( @filenames ) {
			   if ( $file =~ /^$param{'docket'}/ ) {
				   push @pages, $file;
			   } # end if
			} # end foreach
			$log->debug("Pages found: " . @pages );
			$PageFlip = new openprint::PageFlip();
			$variable{'error'} .= $PageFlip->save({
					'docket'=>$param{'docket'},
					'page_files'=>[ sort @pages],
					'company_id'=>$Project->company_id()
					});
		} # end if
		$variable{'PageFlip'} = $PageFlip; 
	} # end if
} # end sub view
 1;
__END__
