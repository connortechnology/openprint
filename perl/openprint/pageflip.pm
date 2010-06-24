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
require openprint::PageFlip_Page;

sub view {
	$variable{'PageFlip'} = new openprint::PageFlip($param{'id'});

	if ( $param{'docket'} ) {
		my $PageFlip = openprint::PageFlip->find_one('docket'=>$param{'docket'});
		if ( ! $PageFlip ) {
			my $Project = openprint::Project->find_one('docket'=>$param{'docket'});
			if ( ! $Project ) {
				$variable{'error'} .= "Invalid docket $param{'docket'}";
				return;
			} # end if

			$PageFlip = new openprint::PageFlip();
			$variable{'error'} .= $PageFlip->save({
					'docket'		=>	$param{'docket'},
					'company_id'	=>	$Project->company_id()
					});
		} # end if
		$variable{'PageFlip'} = $PageFlip; 
	} # end if docket
	if ( ! $variable{'PageFlip'}->Pages() ) {
		$variable{'error'} .= get_files( $variable{'PageFlip'} );
	} # end if
	if ( $param{'command'} eq 'Save' ) {
		
	} # end if
} # end sub view

sub get_files {
	my ( $PageFlip ) = @_;
	my $error;

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
	@pages = sort @pages;
	foreach my $file ( @pages ) {
		my ( $docket, $page ) = $file =~ /^(\d+).+p(\d+).+$/;
		if ( ! $page ) {
			$error .= "Unable to parse filename $file<br/>";
			next;
		} # end id
		my $Page = new openprint::PageFlip_Page();
		$error .= $Page->save({
			'pageflip_id'	=>	$PageFlip->id(),
			'filename'	=>	$file,
			'page'		=>	$page,
		});
		delete $$PageFlip{'Pages'};
	} # end foreach file
	return $error;
} # end sub get_files

sub edit {
	$variable{'PageFlip'} = new openprint::PageFlip($param{'id'});
	foreach my $Page ( $variable{'PageFlip'}->Pages() ) {
		if ( ! ( $Page->width() and $Page->height() ) ) {
			my $Image = $Page->getImage();
			$Page->save({'width'=>$Image->Get('width'), 'height'=>$Image->Get('height') }) if $Image;
		} # end if
	} # end foreach Page
} # end sub edit

1;
__END__
