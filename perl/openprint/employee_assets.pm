package openprint::employee_assets;
use strict;
require sql;
require misc;

require openprint::Asset;

use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

sub history {
	if ( $param{'btnFunction'} eq 'Delete' ) {
		foreach my $asset_id ( ref $param{'asset_id'} eq 'ARRAY' ? @{$param{'asset_id'}} : split(',',$param{'asset_id'}) ) {
			my $Asset = new openprint::Asset( $asset_id );
			$variable{'error'} .= $Asset->delete();

		} # end foreach asset_id
		%param = ();
	} # end if
	ssi::save_params( '/employee/asset/history.html', ( 'created_on_start_year','created_on_start_month','created_on_start_day','created_on_end_year','created_on_end_month','created_on_end_day','type_id', 'created_by' ) );
} # end sub history

sub _history {
	ssi::save_params( '/employee/asset/history.html', ( 'created_on_start_year','created_on_start_month','created_on_start_day','created_on_end_year','created_on_end_month','created_on_end_day','type_id', 'created_by' ) );
} # end sub _assets

sub view {
	$param{'asset_id'} =~ s/\s//g;
	my $Asset = new openprint::Asset( $param{'asset_id'} );
	if ( $param{'btnFunction'} eq 'Delete' ) {
		$variable{'error'} .= $Asset->delete();
		if ( ! $variable{'error'} ) {
			$variable{'Redirect'} = '/employee/asset/history.html';
			%param = ();
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Undelete' ) {
		$variable{'error'} .= $Asset->undelete();
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		$variable{'error'} .= $Asset->save( \%param );
		if ( ! $variable{'error'} ) {
			$variable{'information'} .= 'Information successfully stored.<br/>';
		} # end if
		if ( $param{'filename'} ) {
			my $upload = $r->upload('filename');
			if ( ! $upload ) {
				$Asset->save({'filename'=>''});
				$variable{'error'} .= "There was no upload for $param{'filename'}<br/>";
			} elsif ( ! $upload->link( $Asset->on_disk_path() ) ) {
				$variable{'error'} .= "There was an error saving file $param{'filename'} to " . $Asset->on_disk_path() . ": $!<br/>";
				$Asset->save({'filename'=>''});
			} else {
				$variable{'information'} .= "File $param{'filename'} was uploaded successfully.<br/>";
			} # end if
		} # end if
		%param = ();
	} elsif ( $param{'btnFunction'} eq 'Send' ) {
		$variable{'information'} .= $Asset->send();
	} # end if btnfunction
	$variable{'Asset'} = $Asset;
} # end sub view

sub edit {
	$variable{'Asset'} = new openprint::Asset($param{'asset_id'});
	if ( $param{'btnFunction'} eq 'Save' ) {
		my $Asset = $variable{'Asset'};
		$Asset->id( $param{'asset_id'} ) if ! $Asset->id();
		$variable{'error'} .= $Asset->save( \%param );
	} # end if
} # end sub edit

1;
__END__
