use strict;
package openprint::User;
our @ISA = qw( openprint::Object );
use Text::Unaccent ();
use MIME::QuotedPrint ();
use Carp qw( cluck );

require openprint::Company;
require openprint::logs;
require openprint::UserGroup;
require openprint::User_Notification;
require openprint::Asset;
require openprint::User_Profile;

use openprint ();
use vars qw( $log $dbh %config %variable %param $debug %fields %find_fields %transforms %defaults $table $serial $AUTOLOAD );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*param = \%openprint::param;
*variable = \%openprint::variable;
$table = 'Users';
$serial = 'users_id_seq';

$debug = 1;

%fields = (
	'id'				=>	'id',
	'company_id'		=>	'company_id',
	'salutation'		=>	'salutation',
	'title'				=>	'title',
	'firstname'			=>	'firstname',
	'lastname'			=>	'lastname',
	'email'				=>	'email',
	'phone'				=>	'phone',
	'extension'			=>	'extension',
	'mobile'			=>	'mobile',
	'sms'				=>	'sms',
	'fax'				=>	'fax',
	'mailinglist'		=>	'ysnmailinglist',
	'greeting'			=>	'greeting',
	'created_on'		=>	'created_on',
	'updated_on'		=>	'updated_on',
	'type'				=>	'type',
	'change_password'	=>	'ysnchangepassword',
	'password_changed_on'	=>	'password_changed_on',
	'commission'		=>	'dblcommission',
	'wage'				=>	'wage',
	'administrator'		=>	'ysnadministrator',
	'password',			=>	'password',
	'ftp_active'		=>	'ftp_active',
	'web_active'		=>	'web_active',
	'howdidyouhearaboutus'	=>	'howdidyouhearaboutus',
	'howdidyouhearaboutusother'	=>	'howdidyouhearaboutusother',
	'quote_level'		=>	'quote_level',
	'email_quotes_to_myself'        =>      'email_quotes_to_myself',
	'purchasing_limit'	=>	'purchasing_limit',
	'purchasing_total_limit'	=>	'purchasing_total_limit',
	'notes'				=>	'notes',
	'asset_id'			=>	'asset_id',
	'deleted'			=>	'deleted',
); # end %fields
%find_fields = (
	'name'	=>	q`firstname || ' ' || lastname`,
	'usergroup_id'	=>	'(SELECT usergroup_id FROM users_in_usergroups WHERE user_id=users.id)',
	'usergroup'		=>	'(SELECT name from usergroups WHERE id IN (SELECT usergroup_id FROM users_in_usergroups WHERE user_id=users.id))',
	'last_online'	=>	'(SELECT MAX(date_time) FROM logs WHERE user_id=users.id)',
);

%transforms = (
	'commission'		=>	[ 's/[^\d\.\-]//g' ],
	'wage'				=>	[ 's/[^\d\.]//g' ],
	'email'				=>	[ 'tr/[A-Z]/[a-z]/', 's/^\s+//', 's/\s+$//' ],
	'password'			=>	[ 's/^\s+//', 's/\s+$//' ],
	'purchasing_limit'	=>	[ 's/[^\d\.\-]//g' ],
	'purchasing_total_limit'	=>	[ 's/[^\d\.\-]//g' ],
	'email'				=>	[ 'tr/[A-Z]/[a-z]/' ],
	'created_on'		=>	[ 's/.*//g' ],
	'updated_on'		=>	[ 's/.*//g' ],
);

%defaults = (
	'web_active'	=>	q`'N'`,
	'ftp_active'	=>	0,
	'created_on'	=>	q`'NOW()'`,
	'updated_on'	=>	q`'NOW()'`,
	'type'			=>	q`'C'`,
	'change_password'	=>	q`'N'`,
	'administrator'		=>	q`'N'`,
	'commission'		=>	undef,
	'quote_level'		=> undef,
	'purchasing_limit'	=>	undef,
	'purchasing_total_limit'	=>	undef,
	'wage'				=>	undef,
	'deleted'			=>	0,
	'email_quotes_to_myself'	=>	0,
	'asset_id'			=>	undef,
	'password_changed_on'		=>	undef,
);

# if we have previously loaded info for this customer, and it hasn't changed, that field will not be saved.
# If we have not previously loaded the info, we will just save it whether it has actually changed or not.
# We do this for efficiency's sake.	
sub save {
	my ( $self, $params ) = @_;

	if ( exists $$params{password} and $$params{password} eq '' ) {
		delete $$params{password};
	} # end if

	if ( $params and $$params{type} and $$self{type} and ( $$params{'type'} ne $$self{'type'} ) and ( $$params{'type'} ne 'C' ) ) {
# Notify someone
		my %info;
		$info{'User'} = $self;
		@info{'UserFirstName','UserLastName','UserType'} = @$params{'firstname','lastname','type'};

		$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/usertype_system_notification.html' );
		$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );

		my $email_template = misc::load_file( $log, $config{'SkinPath'}.'/email_template.html' );
		$email_template = ssi::variable_substitution( \$email_template, \%info );

		new openprint::Email()->send(
				FROM    => $openprint::config{'LoginEmail'},
				TO      => $openprint::config{'LoginEmail'},
				SUBJECT => join(' ', @$params{'firstname','lastname'})."'s User Type has changed!",
				ATTACHMENTS => [ '', MIME::QuotedPrint::encode_qp($email_template), 'text/html', 'quoted-printable' ],
				);
	} # end if

	if ( $params and (defined $$params{'web_active'} and defined $$self{'web_active'} ) and ( $$self{'web_active'} ne $$params{'web_active'} ) and ( $$params{'web_active'} eq 'Y' ) ) {
		my %info;
		$info{'User'} = $self;
		$_ = $$params{'web_active'} eq 'Y' ? 'user_account_activated.html' : 'user_account_deactivated.html';
		$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . "/email_content/$_" );
		$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
		my $email_template = misc::load_file( $log, $config{'SkinPath'}.'/email_template.html' );
		$email_template = ssi::variable_substitution( \$email_template, \%info );

		new openprint::Email()->send(
				FROM    => $openprint::config{'AdministratorEmail'},
				TO      => sprintf( '"%s %s" <%s>', @$params{'firstame','lastname','email'} ),
				SUBJECT => 'User account status has changed!',
				ATTACHMENTS => [ '', MIME::QuotedPrint::encode_qp($email_template), 'text/html', 'quoted-printable' ],
				);
	} # end if

	my $error = $self->SUPER::save( $params );
	return $error if $error;

	if ( exists $$params{'assistant_ids'} ) {
		$self->assistant_ids( $$params{'assistant_ids'} );
	} # end if
	if ( exists $$params{'csr_ids'} ) {
		$self->csr_ids( $$params{'csr_ids'} );
	} # end if
	return;
} # end sub save

sub destroy {
	my $self = shift;

	my $ac = sql::start_transaction( $dbh );
	sql::execute( undef, undef, 'DELETE FROM Users_in_Marketing_Categories WHERE User_Id=?', $$self{'id'} );

	foreach my $Quote ( openprint::Quote->find('user_id'=>$$self{'id'}) ) {
		$Quote->delete();
	} # end foreach
	foreach my $Order ( openprint::Order->find('user_id'=>$$self{'id'}) ) {
		$Order->delete();
	} # end foreach
	sql::update( undef, undef, 'order_log', ['user_id=?',$$self{'id'}], 'user_id', undef );
	foreach my $Project ( openprint::Project->find('user_id'=>$$self{'id'}) ) {
		$Project->delete();
	} # end foreach
	sql::execute( $log, $dbh, 'DELETE FROM users_in_usergroups WHERE user_id=?', $$self{'id'} );
	sql::execute( $log, $dbh, 'DELETE FROM Project_Log WHERE user_id=?', $$self{'id'} );
	sql::update( undef, undef, 'barcode_log', ['operator_id=?', $$self{'id'} ], 'operator_id', undef );
	sql::update( undef, undef, 'barcode_log', ['user_id=?',$$self{'id'}], 'user_id', undef );
	sql::update( undef, undef, 'skids', ['created_by_id=?',$$self{'id'}], 'created_by_id', undef );

	sql::execute( $log, $dbh, 'DELETE FROM creditapplications WHERE user_id=?', $$self{'id'} );
	sql::execute( $log, $dbh, 'DELETE FROM helpdesk WHERE user_id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM Assistants WHERE csr_id=? OR assistant_id=?', @$self{'id','id'} );
	sql::execute( undef, undef, 'DELETE FROM EmailCampaign_sent WHERE user_id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM survey_responses WHERE user_id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM uploads WHERE user_id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM user_profiles WHERE user_id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM Message_to WHERE user_id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM Messages WHERE from_id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM User_Relationships WHERE user_id1=? OR user_id2=?', @$self{'id','id'} );

	sql::execute( $log, $dbh, 'DELETE FROM Users WHERE id=?', $$self{'id'} );

	sql::end_transaction( $dbh, $ac );

	(new openprint::Log())->save({'action'=>'Destroy User','note'=>"User ID: " . $$self{'id'}});
} # end sub destroy

sub next {
	my $self = shift;
	my %params = @_;

	my $sql = 'SELECT MIN(firstname) FROM users WHERE firstname > ?';
	my @values = ( $$self{firstname} );
	if ( $params{'company_id'} ) {
		$sql .= ' AND company_id=?';
		push @values, $params{'company_id'};
	} # end if
	if ( $params{'type'} ) {
		$sql .= ' AND type=?';
		push @values, $params{'type'};
	} # end if

	$sql = qq{SELECT id FROM users WHERE firstname = ($sql)};
	( $_ ) = sql::execute( $log, $dbh, $sql, @values );
	return $_;
}
sub Next {
	my $self = shift;
	return new openprint::User( $self->next( @_ ) );
} # end sub Nex

sub prev {
	my $self = shift;
	my %params = @_;

	my $sql = 'SELECT MAX(FirstName) FROM Users WHERE FirstName < ?';
	my @values = ( $$self{firstname} );
	if ( $params{'company_id'} ) {
		$sql .= ' AND company_id=?';
		push @values, $params{'company_id'};
	} # end if
	if ( $params{'type'} ) {
		$sql .= ' AND type=?';
		push @values, $params{'type'};
	} # end if

	$sql = qq{SELECT id FROM Users WHERE FirstName = ($sql)};
	( $_ ) = sql::execute( $log, $dbh, $sql, @values );
	return $_;
}
sub Prev {
	return new openprint::User( $_[0]->prev(@_) );
} # end sub Nex

sub Company {
	return new openprint::Company( $_[0]{'company_id'} );
} # end sub Company

sub name {
	my $self = $_[0];
if ( (!$self) or ( ref $self ne 'openprint::User' ) ) {
$log->error("FUcked up $self");
Carp::cluck( 'No object is name' );
return;
}
	my $Company = $_[0]->Company();
	#if ( $_[0]{'company_id'} == $openprint::session{'company_id'} ) {
		#return $_[0]{'firstname'};
	#} elsif ( $_[0]->Company()->name() ne ($_[0]{'firstname'} . ' ' . $_[0]{'lastname'}) ) {
	if ( $Company->name() ne ($_[0]{'firstname'} . ' ' . $_[0]{'lastname'}) ) {
		return $Company->name() . ' (' . $_[0]{'firstname'} . ')';
	} else {
		if ( $_[0]{'firstname'} and $_[0]{'lastname'} ) {
			return join(' ', @$self{'firstname','lastname'} );
		} elsif ( $_[0]{'firstname'} ) {
			return $_[0]{'firstname'};
		} elsif ( $_[0]{'lastname'} ) {
			return $_[0]{'lastname'};
		} # end if
	} # end if
} # end sub name

sub assistant_ids {
	my $self = shift;
	if ( @_ ) {
		my $ac = sql::start_transaction( $dbh );
		sql::execute( undef, undef, 'DELETE FROM Assistants WHERE csr_id=?', $$self{id} );
		foreach ( ( @_ == 1 and ref $_[0] eq 'ARRAY' ) ? @{$_[0]} : @_ ) {
			sql::insert( undef, undef, 'Assistants', ['csr_id', $$self{id}, 'assistant_id', $_] ) if $_;
		} # end foreach
		sql::end_transaction( $dbh, $ac );
		return @_;
	} # end if
	return sql::execute( undef, undef, 'SELECT assistant_id FROM Assistants WHERE csr_id=?', $$self{id} );
} # end sub

sub csr_ids {
	my $self = shift;
	if ( @_ ) {
		my $ac = sql::start_transaction( $dbh );
		sql::execute( undef, undef, 'DELETE FROM Assistants WHERE assistant_id=?', $$self{id} );
		foreach ( ( @_ == 1 and ref $_[0] eq 'ARRAY' ) ? @{$_[0]} : @_ ) {
			sql::insert( undef, undef, 'Assistants', ['assistant_id', $$self{id}, 'csr_id', $_] ) if $_;
		} # end foreach
		sql::end_transaction( $dbh, $ac );
		return @_;
	} # end if
	return sql::execute( undef, undef, 'SELECT csr_id FROM Assistants WHERE assistant_id=?', $$self{id} );
} # end sub

sub Groups {
	if ( $_[0]{'id'} ) {
		return openprint::UserGroup->find('user_id any'=>$_[0]{id} );
	} # end if
	return ();
} # end sub Groups

sub notifications {
	my ( $self, $notifications_hash ) = @_;
	
	if ( $notifications_hash ) {
		my %types = sql::execute( undef, undef, 'SELECT id, name FROM User_Notification_types' );
		my $ac = sql::start_transaction( $dbh );
		sql::execute( undef, undef, 'DELETE FROM User_Notifications WHERE user_id=?', $$self{'id'} );
		foreach my $k ( keys %types ) {
			sql::insert( undef, undef, 'User_Notifications', { 'user_id'=>$$self{'id'},'type_id'=>$k, 'value'=>$$notifications_hash{$types{$k}} } ) if $$notifications_hash{$types{$k}};
		} # end foreach k
		sql::end_transaction( $dbh, $ac );
		$$self{'notifications'} = $notifications_hash;
	} elsif ( ! exists $$self{'notifications'} ) {
		%{$$self{'notifications'}} = sql::execute( undef, undef, 'SELECT (SELECT name FROM User_Notification_Types WHERE id=type_id),value FROM User_Notifications WHERE user_id=?', $$self{'id'} );
	} # end if
	
	return $$self{'notifications'};
} # end sub notifications

sub notification {
	my ( $self, $name ) = @_;

	$self->notifications() if ( ! exists $$self{'notifications'} );
	return $$self{'notifications'}{$name} if $$self{'notifications'} and $$self{'notifications'}{$name};
	return '';
} # end sub notification

sub purchasing_total {
	require openprint::PurchaseOrder;
	my $total = 0;
	foreach my $PO ( openprint::PurchaseOrder->find('authorized'=>'N') ) {
		$total += $PO->total();
	} # end foreach $PO
} # end sub purchasing_total

sub po_limit {
	my ( $self, $type_id, $new_value ) = @_;

	if ( ! exists $$self{'po_limits'} ) {
		%{$$self{'po_limits'}} = sql::execute( undef, undef, 'SELECT type_id, po_limit FROM User_PurchaseOrder_limits WHERE user_id=?', $$self{'id'} );
	} # end if

	if ( defined $new_value ) {
		if ( exists $$self{'po_limits'}{$type_id} ) {
			sql::update( undef, undef, 'user_purchaseorder_limits', ['user_id=? AND type_id=?', $$self{'id'},$type_id], 'po_limit', 1*$new_value );
		} else {
			sql::insert( undef, undef, 'user_purchaseorder_limits', ['user_id',$$self{'id'},'type_id', $type_id, 'po_limit', 1*$new_value ] );
		} # end if
		$$self{'po_limits'}{$type_id} = 1*$new_value;
	} # end if

	return $$self{'po_limits'}{$type_id};
} # end sub po_limit

sub Asset {
	if ( ! $_[0]{'Asset'} ) {
		if ( $_[0]{'asset_id'} ) {
			$_[0]{'Asset'} = new openprint::Asset( $_[0]{'asset_id'} );
		} else {
			if ( $_[0]->Profile()->Gender() ) {
				#$openprint::log->debug("Loading by gender");
				$_[0]{'Asset'} = openprint::Asset->find_one('name'=>'Default Profile ' . $_[0]->Profile()->Gender() );
			} # end if
			if ( ! $_[0]{'Asset'} ) {
				#$openprint::log->debug("Loading by default");
				$_[0]{'Asset'} = openprint::Asset->find_one('name'=>'Default Profile' );
			} # end if
			my @Albums = openprint::Photo_Album->find('user_id'=>$_[0]{'id'});
			foreach my $Album ( @Albums ) {
				my @Photos = $Album->Photos();
				if ( @Photos ) {
					$_[0]{'Asset'} = $Photos[0]->Asset();
				} # end if
			} # end foreach Album
			if ( ! $_[0]{'Asset'} ) {
				$_[0]{'Asset'} = new openprint::Asset( );
			} # end if
		} # end if
	} # end if
	return $_[0]{'Asset'};
} # end sub Asset

sub Profile {
	if ( ! exists $_[0]{'Profile'} ) {
		$_[0]{'Profile'} = new openprint::User_Profile( $_[0]{'id'} );
	} # end if
	return $_[0]{'Profile'};
} # end sub Profile

sub icon {
	if ( ! $_[0]{'icon'} ) {
		$_[0]{'icon'} = sprintf('<a href="/account/view.html?user_id=%1$d" class="thumbnail"><img src="%2$s" alt="%3$s" title="%3$s" /></a>',
			$_[0]{'id'}, $_[0]->Asset()->thumbnail_url(), $_[0]->name() );
	} # end if
	return $_[0]{'icon'};
} # end sub icon

sub html {
	if ( ! $_[0]{'id'} ) {
		$log->error("called html on user without id".$_[0]->to_string() );
		return '';
	} # end if
	my $User = $_[0];
	my $Profile = $_[1] ? $_[1] : $_[0]->Profile();

	my $age = 0;
	my $birthday = $Profile->date_of_birth();
	if ( $birthday and $birthday ne '--' ) {
		my @Birthday = split('-', $birthday );
		$age = Date::Calc::check_date( @Birthday ) ? int(Date::Calc::Delta_Days( @Birthday, Date::Calc::Today() )/365) : 0;
	} # end if

	my $Asset = $User->Asset();
	my $thumbnail_url = $Asset->thumbnail_url();

	return sprintf(q`
				<div class="User">
					<a class="thumbnail" href="/account/view.html?user_id=%1$d"><img src="%3$s" alt="%4$s" /></a>
					<a href="/account/view.html?user_id=%1$d">
					<div class="Name">%2$s</div>
					<div class="Details">%5$s %6$s</div>
					<div class="Tagline">%7$s</div>
					</a>
				</div>`,
				$User->id(), $User->name(),
				( $thumbnail_url ? $thumbnail_url : '/images/no_image.gif' ), '',
				$age ? $age.' year old' : '',
				$Profile->Gender() ? $Profile->Gender() : '',
				$Profile->Tagline(),
			);
	return sprintf(q`
				<div class="User">
					<a href="/account/view.html?user_id=%1$d"><img class="thumbnail" src="%3$s" alt="%4$s" /></a>
					<div class="Name"><label>Name:</label>%2$s</div>
					<div class="Age"><label>Age:</label>%5$s</div>
					<div class="Gender"><label>Gender:</label>%6$s</div>
					<div class="Joined"><label>Joined:</label>%7$s</div>
				</div>`,
				$User->id(), $User->name(),
				( $_ = $User->Asset()->thumbnail_filename() ? $_ : 'no_image.gif' ), '',
				$age ? $age : 'old!',
				$Profile->Gender() ? $Profile->Gender() : 'indeterminate',
				Date::Format::time2str( $openprint::config{'DateFormat'}, Date::Parse::str2time( $User->created_on() ) ),
			);
} # end sub html

sub last_logged_in {
	if ( ! $_[0]{'last_logged_on'} ) {
		# Almost any entry means we were logged in.  
		my @Logs = openprint::Log->find('limit'=>1, 'user_id'=>$_[0]{'id'},'order'=>'date_time DESC');
		if ( @Logs == 1 ) {
			$_[0]{'last_logged_on'} = $Logs[0]{'date_time'};
		} else {
			$openprint::log->debug("@ of logs returned " . @Logs );
		} # end if
	}
	return $_[0]{'last_logged_on'};
} # end sub last_logged_in

sub AUTOLOAD {
	my $name = $AUTOLOAD;
	$name =~ s/.*://;
	if ( $fields{$name} ) {
		if ( @_ > 1 ) {
#$openprint::log->debug("Autoload $type $name $_[0]");
			return $_[0]{$name} = $_[1];
		} else {
			return $_[0]{$name};
		} # end if
	} elsif ( ! sets::isin( $name, [ 'DESTROY' ] ) ) {
		my $Profile = $_[0]->Profile();
		if ( exists $$Profile{'fields'}{$name} ) {
			if ( @_ > 1 ) {
				$$Profile{'fields'}{$name} = $_[1];
			} # end if
			return $$Profile{'fields'}{$name};
		#} else {
			#$openprint::log->warn("Unknown field in User::AUTOLOAD $name");
		} # end if
	} # end if
} # end sub AUTOLOAD

sub can_edit {
	return 1 if $openprint::session{'user_id'} == $_[0]{id};
	return 1 if $openprint::session{'user_type'} eq 'A';
	return 1 if ( new openprint::User( $openprint::session{'user_id'} )->administrator() eq 'Y' ) and ( $_[0]{'company_id'} == $openprint::session{'company_id'} );
	return 1 if new openprint::Company( $_[0]{'company_id'} )->salesrep_id() == $openprint::session{'user_id'};
	return 0;
} # end sub can_edit

1;
__END__
