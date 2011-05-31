package openprint::employee_sred;

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

require openprint::SRED_Project;

sub projects {
	if ( $param{'function'} eq 'Save' ) {
		my $Project = new openprint::SRED_Project($param{'project_id'});
		$Project->set({'created_by'=>$session{'user_id'}}) if ! $Project->id();
		$variable{'error'} .= $Project->save( {'name' => $param{'name'}, 'description' => $param{'description'} } );
		%param = ();
	} elsif ( $param{'function'} eq 'Delete' ) {
		my $Project = new openprint::SRED_Project( $param{'project_id'} );
		$variable{'error'} .= $Project->delete();
		%param = ();
	} else {
		ssi::save_params( '/employee/sred/projects.html', ( 
			'created_on_start_year','created_on_start_month','created_on_start_day',
			'created_on_end_year','created_on_end_month','created_on_end_day',
			'user_id',
			) );
	} # end if
} # end sub projects
sub _projects {
	ssi::save_params( '/employee/sred/projects.html', ( 
		'created_on_start_year','created_on_start_month','created_on_start_day',
		'created_on_end_year','created_on_end_month','created_on_end_day',
		'user_id',
		) );
} # end sub _projects

sub history {
	if ( $param{'btnFunction'} eq 'Save' ) {
		$param{'owner_id'} = $session{'company_id'} if ! $param{'owner_id'};
		$param{'starting'} = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', @param{'starting_year','starting_month','starting_day','starting_hour','starting_minute'} );
		$param{'ending'} = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', @param{'ending_year','ending_month','ending_day','ending_hour','ending_minute'} );
		if ( ! $param{'timetrack_id'} ) {
			if ( openprint::Timetrack->find_one('owner_id'=>$param{'owner_id'},'company_id'=>$param{'company_id'},'starting'=>$param{'starting'},'ending'=>$param{'ending'},'service_id'=>$param{'service_id'}) ) {
				$variable{'error'} = 'Not creating duplicate.<br/>';
				return;
			} # end if
		} # end if
		my $Timetrack = new openprint::Timetrack( $param{'timetrack_id'} );
		$variable{'error'} .= $Timetrack->save(\%param);
		if ( $param{'referrer_invoice_id'} ) {
			$_ = $param{'referrer_invoice_id'};
			%param = ();
			$param{'invoice_id'} = $_;
			$variable{'Redirect'} = '/invoice/edit.html';
		} else {
			ssi::save_params( '/timetrack/edit.html', 'ending', 'company_id' );
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Destroy' ) {
		my $Timetrack = new openprint::Timetrack( $param{'timetrack_id'} );
		$variable{'error'} .= $Timetrack->destroy();
	} elsif ( $param{'action'} eq 'reset' ) {
		foreach ( 'starting_start_year','starting_start_month','starting_start_day','starting_end_year','starting_end_month','starting_end_day','invoiced','paid','user_id','company_id', 'service_id', 'lastupdated' ) {
			delete $session{'/timetrack/history.html?'.$_}
		} # end foreach
	} elsif ( ! $param{'btnFunction'} ) {
		ssi::save_params( '/timetrack/history.html', ( 'starting_start_year','starting_start_month','starting_start_day','starting_end_year','starting_end_month','starting_end_day','invoiced','paid','user_id','company_id', 'service_id') );
	} # end if

	if ( ( ! $session{'/timetrack/history.html?lastupdated'} ) or ( time - $session{'/timetrack/history.html?lastupdated'} ) > ( 12*60*60 ) ) {
		ssi::setup_date_select( '/timetrack/history.html', 'starting_start', -31 );
		ssi::setup_date_select( '/timetrack/history.html', 'starting_end', '' );
	} # end if

	$session{'/timetrack/history.html?invoiced'} = '0' if ! $session{'/timetrack/history.html?invoiced'};
	$session{'/timetrack/history.html?paid'} = '0' if ! $session{'/timetrack/history.html?paid'};
	if ( sets::isin( $session{'user_type'}, ['A','E'] ) ) {
		$session{'/timetrack/history.html?user_id'} = $session{'user_id'} if ! exists $session{'/timetrack/history.html?user_id'};
	} # end if
} # end sub history

sub _history {
	if ( ! $param{'btnFunction'} ) {
		ssi::save_params( '/timetrack/history.html', ( 'starting_start_year','starting_start_month','starting_start_day','starting_end_year','starting_end_month','starting_end_day','invoiced','paid','user_id','company_id', 'service_id') );
	} # end if
} # end sub _history

sub project {
	my $Project = $variable{'Project'} = new openprint::SRED_Project( $param{'project_id'} );
	if ( $param{'function'} eq 'Save' ) {
		$Project->set({'created_by'=>$session{'user_id'}}) if ! $Project->id();
		$variable{'error'} .= $Project->save( {'name' => $param{'name'}, 'description' => $param{'description'} } );
		%param = ();
	} elsif ( $param{'function'} eq 'Copy' ) {
		$variable{'Project'} = $Project = $Project->copy();
		$variable{'error'} .= $Project->save();
	} elsif ( $param{'function'} eq 'Upload' ) {
		foreach my $C ( $Project->Contents() ) {
			next if ! $param{'filename-'.$$C{id}};

			my $Asset = new openprint::Asset();
			$variable{'error'} .= $Asset->save( { 'filename' => $param{"filename-$$C{id}"} } );
			if ( ! $variable{'error'} ) {
				$variable{'information'} .= 'Information successfully stored.<br/>';
			} # end if
			my $upload = $r->upload('filename-'.$$C{id});
            if ( ! $upload ) {
                $variable{'error'} .= "There was no upload for $param{'filename-'.$$C{id}}<br/>";
                $Asset->save({'filename'=>''});
				next;
            } elsif ( ! $upload->link( $Asset->on_disk_path() ) ) {
                $variable{'error'} .= "There was an error saving file $param{'filename-'.$$C{id}} to " . $Asset->on_disk_path() . ": $!<br/>";
                $Asset->save({'filename'=>''});
				next;
			} # end if
			$variable{'information'} .= "File $param{'filename-'.$$C{id}} was uploaded successfully.<br/>";
			if ( $Asset->id() ) {
				my $SRED_Asset = new openprint::SRED_Asset();
				$variable{'error'} .= $SRED_Asset->save({'content_id'=>$$C{'id'},'asset_id'=>$$Asset{'id'}});
			} # end if
		} # end foreach
        %param = ();
	} elsif ( $param{'function'} eq 'SaveContent' ) {
		if ( openprint::SRED_Content->find(
					'project_id'	=>	$param{'project_id'},
					'user_id'		=>	$param{'user_id-'.$param{'content_id'}},
					'description'	=>	$param{'description-'.$param{'content_id'}},
					'notes'         =>  $param{'notes-'.$param{'content_id'}},
					'starting'		=>	sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', @param{map { 'starting-'.$param{'content_id'}.'_'.$_ } ( 'year','month','day','hour','minute') } ),
					'ending'		=>	sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', @param{map { 'ending-'.$param{'content_id'}.'_'.$_ } ( 'year','month','day','hour','minute') } ),
					'docket'        =>  $param{'docket-'.$param{'content_id'}},
					) ) {
			$variable{'error'} .= 'Duplicate found.  Not saving.';
		} else {
			my $Content = new openprint::SRED_Content();
			$variable{'error'} .= $Content->save({
					'project_id'	=>	$param{'project_id'},
					'user_id'		=>	$param{'user_id-'.$param{'content_id'}},
					'description'	=>	$param{'description-'.$param{'content_id'}},
					'notes'         =>  $param{'notes-'.$param{'content_id'}},
					'starting'		=>	sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', @param{map { 'starting-'.$param{'content_id'}.'_'.$_ } ( 'year','month','day','hour','minute') } ),
					'ending'		=>	sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', @param{map { 'ending-'.$param{'content_id'}.'_'.$_ } ( 'year','month','day','hour','minute') } ),
					'docket'        =>  $param{'docket-'.$param{'content_id'}},
					});
			if ( $param{'filename'} ) {
				my $Asset = new openprint::Asset();
				$variable{'error'} .= $Asset->save( { 'filename' => $param{'filename'} } );
				if ( ! $variable{'error'} ) {
					$variable{'information'} .= 'Information successfully stored.<br/>';
				} # end if
				my $upload = $r->upload('filename');
				if ( ! $upload ) {
					$variable{'error'} .= "There was no upload for $param{'filename'}<br/>";
					$Asset->save({'filename'=>''});
					next;
				} elsif ( ! $upload->link( $Asset->on_disk_path() ) ) {
					$variable{'error'} .= "There was an error saving file $param{'filename'} to " . $Asset->on_disk_path() . ": $!<br/>";
					$Asset->save({'filename'=>''});
					next;
				} # end if
				$variable{'information'} .= "File $param{'filename'} was uploaded successfully.<br/>";
				if ( $Asset->id() ) {
					my $SRED_Asset = new openprint::SRED_Asset();
					$variable{'error'} .= $SRED_Asset->save({'content_id'=>$$Content{'id'},'asset_id'=>$$Asset{'id'}});
				} # end if
			} # end if filename
		} # end if duplicate found
	} # end if
} # end sub project

sub _contents {
	my $Project = $variable{'Project'} = new openprint::SRED_Project( $param{'project_id'} );
	if ( $param{'function'} eq 'Add' ) {
# AJAX Doesn't do file uploads, so this code is not in effect right now.
		my $Content = new openprint::SRED_Content();
		$variable{'error'} .= $Content->save({
			'user_id'		=>	$param{'user_id'},
			'project_id'	=>	$param{'project_id'},
			'description'	=>	$param{'description-new'},			
			'notes'			=>	$param{'notes'},
			'starting'		=>	sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', @param{'starting_year','starting_month','starting_day','starting_hour','starting_day'} ),
			'ending'		=>	sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', @param{'ending_year','ending_month','ending_day','ending_hour','ending_day'} ),
			'docket'		=>	$param{'docket'},
				});
		if ( $param{'filename'} ) {
			my $Asset = new openprint::Asset();
			$variable{'error'} .= $Asset->save( { 'filename' => $param{'filename'} } );
			if ( ! $variable{'error'} ) {
				$variable{'information'} .= 'Information successfully stored.<br/>';
			} # end if
			my $upload = $r->upload('filename');
            if ( ! $upload ) {
                $variable{'error'} .= "There was no upload for $param{'filename'}<br/>";
                $Asset->save({'filename'=>''});
				next;
            } elsif ( ! $upload->link( $Asset->on_disk_path() ) ) {
                $variable{'error'} .= "There was an error saving file $param{'filename'} to " . $Asset->on_disk_path() . ": $!<br/>";
                $Asset->save({'filename'=>''});
				next;
			} # end if
			$variable{'information'} .= "File $param{'filename'} was uploaded successfully.<br/>";
			if ( $Asset->id() ) {
				my $SRED_Asset = new openprint::SRED_Asset();
				$variable{'error'} .= $SRED_Asset->save({'content_id'=>$$Content{'id'},'asset_id'=>$$Asset{'id'}});
			} # end if
		} # end if filename
	} elsif ( $param{'func'} eq 'delete' ) {
		my $Content = new openprint::SRED_Content( $param{'content_id'} );
		$variable{'error'} .= $Content->delete();
	} # end if
} # end sub _contents

sub _description {
	my $Content = $variable{'Content'} = new openprint::SRED_Content( $param{'id'} );
	if ( $param{'action'} eq 'update' ) {
		$variable{'error'} .= $Content->save({'description'=>$param{'value'}});
	} # end if
} # end sub _description

sub _date_edit {
	my $Object = $variable{'Object'} = ('openprint::'.$param{'object_type'})->new( $param{'object_id'} );
	if ( $param{'action'} eq 'save' ) {
		$Object->save({
			$param{field} => sprintf('%.4d-%.2d-%.2d %.2d:%.2d:%.2d', @param{map { $param{'field'}.'_'.$_ } ( 'year','month','day','hour','minute' ) } ),
			} );
	} # end if
} # end sub _date_edit

sub _content_edit {
	my $C = $variable{'C'} = new openprint::SRED_Content( $param{'content_id'} );
} # end sub _content_edit
sub _content_view {
	my $Content = $variable{'C'} = new openprint::SRED_Content( $param{'content_id'} );
	if ( $param{'function'} eq 'Save' ) {
# AJAX Doesn't do file uploads, so this code is not in effect right now.
		$variable{'error'} .= $Content->save({
			'user_id'		=>	$param{'user_id-'.$param{'content_id'}},
			'project_id'	=>	$param{'project_id'},
			'description'	=>	$param{'description-'.$param{'content_id'}},
			'notes'			=>	$param{'notes'.$param{'content_id'}},
			'starting'		=>	sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', @param{map { 'starting-'.$param{'content_id'}.'_'.$_ } ( 'year','month','day','hour','minute') } ),
			'ending'		=>	sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', @param{map { 'ending-'.$param{'content_id'}.'_'.$_ } ( 'year','month','day','hour','minute') } ),
			'docket'		=>	$param{'docket'},
				});
		if ( $param{'filename'} ) {
			my $Asset = new openprint::Asset();
			$variable{'error'} .= $Asset->save( { 'filename' => $param{'filename'} } );
			if ( ! $variable{'error'} ) {
				$variable{'information'} .= 'Information successfully stored.<br/>';
			} # end if
			my $upload = $r->upload('filename');
            if ( ! $upload ) {
                $variable{'error'} .= "There was no upload for $param{'filename'}<br/>";
                $Asset->save({'filename'=>''});
				next;
            } elsif ( ! $upload->link( $Asset->on_disk_path() ) ) {
                $variable{'error'} .= "There was an error saving file $param{'filename'} to " . $Asset->on_disk_path() . ": $!<br/>";
                $Asset->save({'filename'=>''});
				next;
			} # end if
			$variable{'information'} .= "File $param{'filename'} was uploaded successfully.<br/>";
			if ( $Asset->id() ) {
				my $SRED_Asset = new openprint::SRED_Asset();
				$variable{'error'} .= $SRED_Asset->save({'content_id'=>$$Content{'id'},'asset_id'=>$$Asset{'id'}});
			} # end if
		} # end if filename
	} # end if
} # end sub _content_edit

1;
__END__
