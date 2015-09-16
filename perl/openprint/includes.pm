use strict;
package openprint::includes;

use openprint ();
use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

sub _states {
} # end sub _states

sub _provinces {
} # end sub _provinces

sub _opinion_button {
	my $Object_Type = openprint::Object_Type->find_one('name'=>$param{'object_type'});
	if ( ! $Object_Type ) {
		$log->error('Object type not found : ' . $param{'object_type'} );
		$variable{'error'} .= 'Unable to opinion. Please try again later';
		return;
	} # end if
	my $Object = $variable{'Object'} = $Object_Type->Object( $param{'object_id'} );
	$Object->toggle_Opinion( $param{'opinion_type_id'} );
} # end sub opinion_button

sub _opinions {
	my $Object_Type = openprint::Object_Type->find_one('name'=>$param{'object_type'});
	if ( ! $Object_Type ) {
		$log->error('Object type not found : ' . $param{'object_type'} );
		$variable{'error'} .= 'Unable to load opinions. Please try again later';
		return;
	} # end if
	my $Object = $variable{'Object'} = $Object_Type->Object( $param{'object_id'} );
	$Object->toggle_Opinion( $param{'opinion_type_id'} );
} # end sub _opinions

sub _captcha {
} # end sub _captcha

sub _privacy_name {
} # end sub _privacy_name
sub _privacy_users {
	my $Privacy = $variable{'Privacy'} = new openprint::Privacy( $param{'privacy_id'} );
	if ( $param{'action'} eq 'add' ) {
		$Privacy->user_id( [ sets::union( @{$Privacy->user_id()}, $param{'user_id'} ) ] );
		$variable{'error'} .= $Privacy->save();	
	} elsif ( $param{'action'} eq 'set' ) {
		$Privacy->user_id( $param{'user_id'} );
	} else {
		$log->error("Unknown action in _privacy_users");
	} # end if
}

sub _users {
} # end sub _users

sub _comments {
	my $Object = $variable{'Object'} = $param{'object_type'}->new( $param{'object_id'} );
	if ( $param{'text'} ) {
		if ( ! openprint::Comment->find_one(
			'user_id'	=>	$session{'user_id'},
			'text'		=>	$param{'text'},
			'object_id'	=>	$Object->id(),
			'object_type'	=>	$param{'object_type'}
			) ) {

			my $approved = 0;
			if ( $session{'user_type'} eq 'A' or ( $session{'user_id'} == $Object->created_by() ) ) {
				$approved = 1;
			} # endif

			$variable{'error'} .= new openprint::Comment()->save({
					'text'			=>	$param{'text'},
					'object_type'	=>	$param{'object_type'},
					'object_id'		=>	$Object->id(),
					'approved'		=>	$approved,
					});
		} # end if comment already exists
	} elsif ( $param{'action'} eq 'approve' ) {
		if ( $session{'user_type'} eq 'A' or $session{'user_id'} == $$Object->created_by() ) {
			my $Comment = openprint::Comment->find_one('object_id'=>$$Object{'id'}, 'object_type'=>$param{'object_type'}, 'id'=>$param{'comment_id'} );
			if ( $Comment ) {
				$Comment->save({'approved'=>1});
			} else {
				$variable{'error'} .= 'Comment not found.';
			} # end if
		} else {
			$variable{'error'} .= 'You are not authorized to approve this comment.';
		} # end if
	} elsif ( $param{'action'} eq 'delete' ) {
		my $Comment = new openprint::Comment( $param{'comment_id'} );
		if ( $Comment->can_delete() ) {
			$Comment->delete();
		} else {
			$variable{'error'} .= 'You do not have the right to delete that comment.';
		} # end if
	} # end if
} # end sub _comments
sub _user_autocomplete {
} # end sub _user_autocomplete
sub _equipment {
} # end sub _equipment
sub _products_ddm {
} # end sub _products_ddm

sub _address_ddm {
	require openprint::Address;
} # end sub _addres_ddm

sub _company_ddm {
} # end sub _company_ddm

sub _logs_contents {
	my $Object_Type = new openprint::Object_Type( $param{object_type_id} );
	$$variable{Object} = $Object_Type->Object( $param{object_id} );
} # end sub _logs_contents
1;
__END__
