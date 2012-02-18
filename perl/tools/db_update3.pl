#!/usr/bin/perl
use lib '/var/www/testing/perl';
use strict;

require sql;
require misc;
require logger;
require configuration;
require openprint::Object;
require openprint::Log;
require openprint::Log_Action;
require openprint::ServiceType;

use openprint ();
use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

$openprint::Object::no_cache = 1;

$log = new logger( 'debug' );

$ARGV[1] = $ARGV[0] if ! $ARGV[1];
$ARGV[2] = $ARGV[0] if ! $ARGV[2];

$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>$ARGV[3]) );
configuration::init_cache( $log, $dbh );

my @tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
my @sequences = sql::execute( undef, undef, q`SELECT sequence_name FROM information_schema.sequences where sequence_schema='public'`);

my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='articles'", 'column_name');
if ( ! exists $$data{'source'} ) {
		$dbh->do('ALTER TABLE articles ADD source TEXT');
} # end if
if ( ! exists $$data{'summary'} ) {
		$dbh->do('ALTER TABLE articles ADD summary TEXT');
} # end if
if ( ! exists $$data{'source_content'} ) {
		$dbh->do('ALTER TABLE articles ADD source_content TEXT');
} # end if
if ( ! exists $$data{'category_id'} ) {
		$dbh->do('ALTER TABLE articles ADD category_id INTEGER');
} # end if
if ( ! exists $$data{'user_type'} ) {
	$dbh->do('ALTER TABLE articles ADD user_type CHAR(1)');
	$dbh->do('ALTER TABLE articles ADD FOREIGN KEY (user_type) REFERENCES user_types (identifier)');
} # end if
if ( sets::isin( 'article_categories', \@tables ) ) {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='article_categories'", 'column_name');
	if ( exists $$data{'image_filename'} ) {
		$dbh->do('ALTER TABLE article_categories DROP image_filename');
	} # end if
	if ( ! exists $$data{'album_id'} ) {
		$dbh->do('ALTER TABLE article_categories ADD album_id INTEGER');
		$dbh->do('ALTER TABLE article_categories ADD FOREIGN KEY (album_id) REFERENCES Photo_Albums (id)');
	} # end if
	if ( ! exists $$data{'description'} ) {
		$dbh->do('ALTER TABLE article_categories ADD description TEXT');
	} # end if
	if ( ! exists $$data{'summary'} ) {
		$dbh->do('ALTER TABLE article_categories ADD summary TEXT');
	} # end if
	if ( ! exists $$data{'deleted'} ) {
		$dbh->do('ALTER TABLE article_categories ADD deleted BOOLEAN NOT NULL default false');
	} # end if
} else {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Article_Categories.sql' ) );
}
my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='users'", 'column_name');
if ( ! exists $$data{'asset_id'} ) {
	$dbh->do('ALTER TABLE users add asset_id INTEGER');
} # end if
if ( ! sets::isin( 'assets', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Assets.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='assets'", 'column_name');
	if ( ! exists $$data{'md5'} ) {
		$dbh->do('ALTER TABLE Assets ADD md5 char(32)');
	} # end if
	if ( ! exists $$data{'deleted'} ) {
		$dbh->do('ALTER TABLE Assets ADD deleted BOOLEAN NOT NULL DEFAULT FALSE');
	} # end if
	if ( ! exists $$data{'license'} ) {
		$dbh->do('ALTER TABLE Assets ADD license TEXT');
	} # end if
	if ( ! exists $$data{'attribution'} ) {
		$dbh->do('ALTER TABLE Assets ADD attribution TEXT');
	} # end if
} # end if

if ( ! sets::isin( 'expense_accounts', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Expense_Accounts.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
}
if ( ! sets::isin( 'expenses', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Expenses.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
}

my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='expenses'", 'column_name');
if ( ! exists $$data{'amount_locked'} ) {
	$dbh->do('ALTER TABLE expenses add amount_locked BOOLEAN NOT NULL default false');
}
if ( ! exists $$data{'total_locked'} ) {
	$dbh->do('ALTER TABLE expenses add total_locked BOOLEAN NOT NULL default false');
}
if ( ! exists $$data{'business_use_amount'} ) {
	$dbh->do('ALTER TABLE expenses add business_use_amount float');
}
if ( ! exists $$data{'account_id'} ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Expense_Accounts.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
	$dbh->do('ALTER TABLE expenses add account_id INTEGER');
	$dbh->do('ALTER TABLE expenses add FOREIGN KEY (account_id) REFERENCES Expense_Accounts (id)');
}

if ( ! sets::isin( 'host_types', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Host_Types.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
}

my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='hosts'", 'column_name');
if ( ! exists $$data{'count'} ) {
	$dbh->do('ALTER TABLE hosts add count integer');
	$dbh->do('UPDATE hosts set count=(SELECT count FROM blacklist WHERE blacklist.ip=hosts.ip)');
}
if ( ! exists $$data{'blacklist'} ) {
	$dbh->do('ALTER TABLE hosts add blacklist BOOLEAN NOT NULL default false');
} # end if
if ( ! exists $$data{'whitelist'} ) {
	$dbh->do('ALTER TABLE hosts add whitelist BOOLEAN NOT NULL default false');
} # end if
if ( ! exists $$data{'created_on'} ) {
	$dbh->do('ALTER TABLE hosts add created_on TIMESTAMP WITH TIME ZONE NOT NULL default NOW()');
} # end if
if ( ! exists $$data{'updated_on'} ) {
	$dbh->do('ALTER TABLE hosts add updated_on TIMESTAMP WITH TIME ZONE NOT NULL default NOW()');
} # end if
if ( ! exists $$data{'deleted'} ) {
	$dbh->do('ALTER TABLE hosts add deleted BOOLEAN NOT NULL DEFAULT FALSE');
} # end if
if ( ! exists $$data{'online'} ) {
	$dbh->do('ALTER TABLE hosts add online BOOLEAN');
} # end if
if ( ! exists $$data{'type_id'} ) {
	$dbh->do('ALTER TABLE hosts add type_id INTEGER');
	$dbh->do('ALTER TABLE hosts add FOREIGN KEY (type_id) REFERENCES Host_types (id)');
} # end if
if ( exists $$data{'type'} ) {
	$dbh->do('ALTER TABLE hosts drop type');
}
if ( exists $$data{'monitor'} ) {
	if ( ! exists $$data{'monitored'} ) {
		$dbh->do('ALTER TABLE hosts RENAME COLUMN monitor to monitored');
	} else {
		$dbh->do('ALTER TABLE hosts DROP COLUMN monitor');
	} # end if
} elsif ( ! exists $$data{'monitored'} ) {
	$dbh->do('ALTER TABLE hosts add monitored BOOLEAN NOT NULL DEFAULT FALSE');
} # end if

my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='paper_prices'", 'column_name');
if ( ! exists $$data{'equipment_id'} ) {
	$dbh->do('ALTER TABLE paper_prices add equipment_id INTEGER');
	$dbh->do('ALTER TABLE paper_prices add FOREIGN KEY(equipment_id) REFERENCES tbl_Equipment (id)');
} # end if
if ( ! exists $$data{'service'} ) {
	$dbh->do('ALTER TABLE paper_prices ADD service TEXT');
	$dbh->do("UPDATE paper_prices set service='Material'" );
} # end if

if ( ! sets::isin( 'user_profile_fields', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/User_Profile_Fields.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='user_profile_fields'", 'column_name');
	if ( ! $$data{'deleted'} ) {
		$dbh->do('ALTER TABLE user_profile_fields add deleted BOOLEAN not null default false');
	} # end if
	if ( ! $$data{'searchable'} ) {
		$dbh->do('ALTER TABLE user_profile_fields add searchable BOOLEAN not null default false');
	} # end if
} # end if
if ( ! sets::isin( 'user_profiles', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/User_Profiles.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'company_profile_fields', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Company_Profile_Fields.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='company_profile_fields'", 'column_name');
	if ( ! $$data{'deleted'} ) {
		$dbh->do('ALTER TABLE company_profile_fields add deleted BOOLEAN not null default false');
	} # end if
	if ( ! $$data{'searchable'} ) {
		$dbh->do('ALTER TABLE company_profile_fields add searchable BOOLEAN not null default false');
	} # end if
} # end if
if ( ! sets::isin( 'company_profiles', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Company_Profiles.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
} # end if
my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='shifts'", 'column_name');
if ( ! exists $$data{'updated_on'} ) {
	$dbh->do('ALTER TABLE shifts add updated_on TIMESTAMP WITH TIME ZONE NOT NULL default nOW()');
} # end if
if ( ! exists $$data{'created_on'} ) {
	$dbh->do('ALTER TABLE shifts add created_on TIMESTAMP WITH TIME ZONE NOT NULL default nOW()');
} # end if
my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='tbl_equipment'", 'column_name');
if ( ! exists $$data{'sorting'} ) {
	$dbh->do('ALTER TABLE tbl_equipment ADD sorting integer');
} # end if
if ( ! exists $$data{'message'} ) {
	$dbh->do('ALTER TABLE tbl_equipment ADD message text');
} # end if
if ( ! exists $$data{'servicetype_id'} ) {
	$dbh->do('ALTER TABLE tbl_equipment ADD servicetype_id INTEGER[]');
} # end if
my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='equipment_shifts'", 'column_name');
if ( ! exists $$data{'operator_id'} ) {
	$dbh->do('ALTER TABLE equipment_shifts ADD operator_id INTEGER');
	$dbh->do('ALTER TABLE equipment_shifts ADD FOREIGN KEY (operator_id) REFERENCES Users (id)');
} # end if
if ( ! sets::isin( 'par', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/PAR.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'car', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/CAR.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'event_categories', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Event_Categories.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'photo_albums', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Photo_Albums.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='photos_in_albums'", 'column_name');
	if ( ! exists $$data{'id'} ) {
		$dbh->do( 'ALTER TABLE photos_in_albums ADD id SERIAL' );
		$dbh->do( 'ALTER TABLE photos_in_albums DROP CONSTRAINT photos_in_albums_pkey');
		$dbh->do( 'ALTER TABLE photos_in_albums ADD PRIMARY KEY (id)' );
	} # end if
} # end if
if ( ! sets::isin( 'video_albums', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Video_Albums.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'locations', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Locations.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='locations'", 'column_name');
	if ( ! exists $$data{'type_id'} ) {
if ( ! sets::isin( 'location_types', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Location_Types.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
}
	$dbh->do('ALTER TABLE Locations add type_id INTEGER');
	$dbh->do('ALTER TABLE Locations add FOREIGN KEY(type_id) REFERENCES Location_types (id)');
	} # end if
	if ( ! exists $$data{'short'} ) {
	$dbh->do('ALTER TABLE Locations add short text');
	} # end if
	if ( ! exists $$data{'description'} ) {
	$dbh->do('ALTER TABLE Locations add description text');
	} # end if
	if ( ! exists $$data{'parent_id'} ) {
	$dbh->do('ALTER TABLE Locations add parent_id integer');
	$dbh->do('ALTER TABLE Locations add FOREIGN KEY(parent_id) REFERENCES Locations (id)');
	} # end if
	if ( ! exists $$data{'created_on'} ) {
	$dbh->do('ALTER TABLE Locations add created_on TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()');
	} # end if
	if ( ! exists $$data{'created_by'} ) {
	$dbh->do('ALTER TABLE Locations add created_by INTEGER');
	$dbh->do('ALTER TABLE Locations add FOREIGN KEY (created_by) REFERENCES Users (id)');
	} # end if
	if ( ! exists $$data{'postalcode'} ) {
	$dbh->do('ALTER TABLE Locations add postalcode text');
	} # end if
	if ( ! exists $$data{'address'} ) {
	$dbh->do('ALTER TABLE Locations add address text');
	} # end if
	if ( ! exists $$data{'url'} ) {
	$dbh->do('ALTER TABLE Locations add url text');
	} # end if
	if ( ! exists $$data{'latitude'} ) {
	$dbh->do('ALTER TABLE Locations add latitude float');
	} # end if
	if ( ! exists $$data{'longitude'} ) {
	$dbh->do('ALTER TABLE Locations add longitude float');
	} # end if
	if ( ! exists $$data{'asset_id'} ) {
		$dbh->do('ALTER TABLE Locations add asset_id INTEGER');
		$dbh->do('ALTER TABLE Locations ADD FOREIGN KEY (asset_id) REFERENCES Assets (id)');
	} # end if
	if ( ! exists $$data{'album_id'} ) {
		$dbh->do('ALTER TABLE Locations add album_id INTEGER');
		$dbh->do('ALTER TABLE Locations ADD FOREIGN KEY (album_id) REFERENCES Photo_Albums (id)');
	} # end if
	$dbh->do('ALTER TABLE Locations DROP CONSTRAINT locations_name_key');
	$dbh->do('CREATE INDEX locations_name_idx on locations (name)');
		
} # end if
if ( ! sets::isin( 'events', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Events.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='events'", 'column_name');
	if ( ! exists $$data{'album_id'} ) {
		$dbh->do(q`ALTER TABLE events add album_id INTEGER` );
		$dbh->do(q`ALTER TABLE events add FOREIGN KEY (album_id) REFERENCES photo_albums (id)` );
	} # end if
	if ( ! exists $$data{'asset_id'} ) {
		$dbh->do(q`ALTER TABLE events add asset_id INTEGER` );
		$dbh->do(q`ALTER TABLE events add FOREIGN KEY (asset_id) REFERENCES assets (id)` );
	} # end if
} # end if
if ( ! sets::isin( 'event_attendance', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Event_Attendance.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'user_relationships', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/User_Relationships.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'messages', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Messages.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='messages'", 'column_name');
	if ( ! exists $$data{'conversation_id'} ) {
		$dbh->do('ALTER TABLE Messages add conversation_id INTEGER');
	} # end if
} # end if
if ( ! sets::isin( 'object_types', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Object_Types.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
	$dbh->do(q`INSERT INTO object_types (name,human) values ('openprint::Comment', 'comment')`);
	$dbh->do(q`INSERT INTO object_types (name,human) values ('openprint::Like', 'like')`);
	$dbh->do(q`INSERT INTO object_types (name,human) values ('openprint::Host', 'host')`);
}
if ( sets::isin( 'log', \@tables ) ) {
	$dbh->do('ALTER TABLE log RENAME TO logs');
	$dbh->do('ALTER sequence log_id_seq RENAME TO logs_id_seq');
	@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
} # en dif
if ( ! sets::isin( 'logs', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Logs.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='logs'", 'column_name');
	if ( exists $$data{'action_type'} ) {
		$dbh->do('ALTER TABLE Logs rename action_type to action_id');
		$dbh->do('ALTER TABLE Logs ADD FOREIGN KEY (action_id) REFERENCES Log_Actions (id)');
	} # end if
	if ( ! exists $$data{'object_type_id'} ) {
		$dbh->do('ALTER TABLE Logs add object_type_id INTEGER');
		$dbh->do('ALTER TABLE Logs add FOREIGN KEY (object_type_id) REFERENCES Object_types (id)');
	}
	if (  exists $$data{'object'} ) {
		$dbh->do('UPDATE Logs set object_type_id = (SELECT id FROM object_types where name=object)');
		$dbh->do('ALTER TABLE Logs DROP object');
	}
	if ( ! exists $$data{'object_id'} ) {
		$dbh->do('ALTER TABLE Logs add object_id INTEGER');
	} # end if
} # end if
if ( my $Action = openprint::Log_Action->find_one('name'=>'Switch Company') ) {
	$Action->save({'name'=>'Select Company','description'=>'Select Company'});
} # end if
my %config_actions = (
	'Update Configuration' => 77,
	'Login Failed'	=> 78,
	'Select Company'	=>	79,
);
foreach my $config_action ( keys %config_actions ) {
	my $Action = openprint::Log_Action->find_one('name'=>$config_action);
	if ( $Action ) {
		if ( $Action->id() != $config_actions{$config_action} ) {
			my $RealAction = openprint::Log_Action->find_one('id'=>$config_actions{$config_action});
			if ( ! $RealAction ) {
				my $New = $Action->copy();
				$New->save({'id'=>$config_actions{$config_action}});
				foreach my $Log ( openprint::Log->find('action_id'=>$Action->id()) ) {
					$Log->save({'action_id'=>$config_actions{$config_action}});
				} # end foreach Log
			} elsif ( $RealAction->name() eq $config_action ) {
				foreach my $Log ( openprint::Log->find('action_id'=>$Action->id()) ) {
					$Log->save({'action_id'=>$config_actions{$config_action}});
				} # end foreach Log
			} else {
				die "Need to manually update $config_actions{$config_action} $config_action entries";
			} # end if
			$Action->destroy();
		} # end if
	} # end if
} # end foreach config_action


if ( ! sets::isin( 'comments', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Comments.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='comments'", 'column_name');
	if ( ! exists $$data{'approved'} ) {
		$dbh->do('ALTER TABLE Comments add approved boolean not null default false');
	} # endif
	if ( exists $$data{'object_type'} ) {
		if ( ! exists $$data{'object_type_id'} ) {
		$dbh->do('ALTER TABLE comments add object_type_id INTEGER');
		$dbh->do('UPDATE comments set object_type_id=(SELECT id FROM object_types WHERE name=object_type)');
		$dbh->do('ALTER TABLE comments add FOREIGN KEY (object_type_id) REFERENCES object_types (id)');
		$dbh->do('ALTER TABLE comments alter object_type_Id SET NOT NULL');
		} # end if
		$dbh->do('ALTER TABLE comments DROP object_type');
		$dbh->do('CREATE INDEX comments_idx ON comments ( object_type_id, object_id )');
	} # end if
}
if ( ! sets::isin( 'equipment_shifts', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Equipment_Shifts.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='equipment_shifts'", 'column_name');
	if ( ! exists $$data{'starttime_seconds'} ) {
		if ( exists $$data{'starttime'} ) {
			$dbh->do('ALTER TABLE Equipment_Shifts ADD starttime_seconds INTEGER');
			$dbh->do('update equipment_shifts set starttime_seconds = extract(epoch from starttime)');
			$dbh->do('ALTER TABLE Equipment_shifts drop starttime');
		} # end if
	} # end if
	if ( ! exists $$data{'duration_seconds'} ) {
		if ( exists $$data{'duration'} ) {
			$dbh->do('ALTER TABLE Equipment_Shifts ADD duration_seconds INTEGER');
			$dbh->do('update equipment_shifts set duration_seconds = extract(epoch from duration)');
			$dbh->do('ALTER TABLE Equipment_shifts drop duration');
		} # end if
	} # end if
} # end if
if ( ! sets::isin( 'privacy_groups', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Privacy_Groups.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'project_types', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Project_Types.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='project_types'", 'column_name');
	if ( ! exists $$data{'please_call'} ) {
		$dbh->do('ALTER TABLE Project_Types add please_call boolean not null default false');
	} # endif
}
if ( ! sets::isin( 'emailcampaigns', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/EmailCampaigns.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='emailcampaigns'", 'column_name');
	if ( ! exists $$data{'nextrun'} ) {
		$dbh->do('ALTER TABLE emailcampaigns add nextrun TIMESTAMP WITH TIME ZONE');
	} # end if
	if ( ! exists $$data{'email_subject'} ) {
		$dbh->do('ALTER TABLE emailcampaigns add email_subject TEXT');
	} # end if
	if ( ! exists $$data{'email_from'} ) {
		if ( exists $$data{'fromemail'} ) {
		$dbh->do('ALTER TABLE emailcampaigns rename column fromemail to email_from');
		} else {
		$dbh->do('ALTER TABLE emailcampaigns add email_from TEXT');
		} # end if
	} # end if
	if ( ! exists $$data{'email_text'} ) {
		if ( exists $$data{'emailtext'} ) {
		$dbh->do('ALTER TABLE emailcampaigns rename column emailtext to email_text');
		} else {
		$dbh->do('ALTER TABLE emailcampaigns add email_text TEXT');
		} # end if
	} # end if
	if ( ! exists $$data{'attachments'} ) {
		$dbh->do('ALTER TABLE emailcampaigns add attachments TEXT');
	} # end if
	if ( ! exists $$data{'timeofday'} ) {
		$dbh->do('ALTER TABLE emailcampaigns ADD timeofday TIME WITHOUT TIME ZONE');
	} # end if
	if ( ! exists $$data{'template_id'} ) {
		if ( ! sets::isin( 'emailtemplates', \@tables ) ) {
			$dbh->do( misc::load_file( $log, '../openprint/sql/EmailTemplates.sql' ) );
			die $dbh->errstr() if $dbh->errstr();
		}
		$dbh->do('ALTER TABLE emailcampaigns add template_id INTEGER');
		$dbh->do('ALTER TABLE emailcampaigns add FOREIGN KEY (template_id) REFERENCES emailtemplates(id)');
		
	} # end if
} # end if
if ( ! sets::isin( 'emailcampaigns_id_seq', \@sequences ) ) {
	if ( sets::isin( 'emailcampaign_id_seq', \@sequences ) ) {
		$dbh->do('ALTER SEQUENCE emailcampaign_id_seq RENAME to emailpaigns_id_seq');
	} 
}
if ( ! sets::isin( 'emailcampaign_log', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/EmailCampaign_Log.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
}
if ( ! sets::isin( 'currencies_id_seq', \@sequences ) ) {
	if ( sets::isin( 'currencyindex_seq', \@sequences ) ) {
		$dbh->do('DROP SEQUENCE currencyindex_seq');
	} # end if
	$dbh->do('CREATE SEQUENCE currencies_id_seq');
	$dbh->do("SELECT setval('currencies_id_seq', (select max(id) FROM currencies) )");
	$dbh->do("ALTER TABLE CURRENCIES ALTER COLUMN ID SET DEFAULT nextval('currencies_id_seq')");
} # end if
foreach my $thingy ( 'names','finishes','colours', 'weights','qualities' ) {
if ( sets::isin( 'paper'.$thingy, \@tables ) ) {
$log->warn("Renaming paper$thingy");
	$dbh->do("ALTER TABLE Paper$thingy rename to Stock$thingy");
	$dbh->do("ALTER TABLE stock$thingy rename column shortname to name");
	$dbh->do("ALTER TABLE stock$thingy drop column longname");
	if ( sets::isin( $thingy.'_id_seq' ) ) {
		$dbh->do('ALTER SEQUENCE paper'.$thingy.'_id_seq RENAME TO stock'.$thingy.'_id_seq');
	} # end if
} # end if
} # end foreach thingy
@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
if ( sets::isin( 'stocknames', \@tables ) ) {
	$dbh->do('ALTER TABLE stocknames rename to stockbrands');
} # end if
my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='papers'", 'column_name');
	$dbh->do('ALTER TABLE Papers rename column name_id to brand_id') if exists $$data{'name_id'};
if ( sets::isin( 'papername_id_seq', \@sequences ) ) {
	$dbh->do('ALTER SEQUENCE papername_id_seq RENAME TO stockbrands_id_seq');
} elsif ( ! sets::isin( 'stockbrands_id_seq', \@sequences ) ) {
	$dbh->do('CREATE SEQUENCE stockbrands_id_seq');
	$dbh->do(q`ALTER TABLE stockbrands alter id set default nextval('stockbrands_id_seq')`);
} # end if

if ( sets::isin( 'paperfinish_id_seq', \@sequences ) ) {
	$dbh->do('ALTER SEQUENCE paperfinish_id_seq RENAME TO stockfinishes_id_seq');
} # end if
if ( sets::isin( 'papercolour_id_seq', \@sequences ) ) {
	$dbh->do('ALTER SEQUENCE papercolour_id_seq RENAME TO stockcolours_id_seq');
} # end if
if ( sets::isin( 'paperweight_id_seq', \@sequences ) ) {
	$dbh->do('ALTER SEQUENCE paperweight_id_seq RENAME TO stockweights_id_seq');
} # end if
my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='manufacturers'", 'column_name');
$dbh->do("ALTER TABLE manufacturers rename column shortname to name") if exists $$data{'shortname'};
$dbh->do("ALTER TABLE manufacturers drop column longname") if exists $$data{'longname'};
if ( ! sets::isin( 'bookmarks', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Bookmarks.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
}
if ( ! $config{'public_URIs'} ) {
$dbh->do(q`insert into Configuration values ('public_URIs', '/,/index.html,/account/login.html,/account/registration.html', 'text', 'Comma separated list of pages on the site that can be read without logging in','Miscellaneous Settings' );` );
} # end if
if ( ! sets::isin( 'page_settings', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Page_Settings.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
}

if ( ! sets::isin( 'opinion_types', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Opinion_Types.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
}
if ( ! sets::isin( 'likes', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Opinions.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='likes'", 'column_name');
	if ( ! exists $$data{'created_on'} ) {
		$dbh->do('ALTER TABLE likes add created_on TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()');
	} # end if
	if ( exists $$data{'object_type'} ) {
		if ( ! exists $$data{'object_type_id'} ) {
		$dbh->do('ALTER TABLE likes add object_type_id INTEGER');
		$dbh->do('UPDATE likes set object_type_id=(SELECT id FROM object_types WHERE name=object_type)');
		$dbh->do('ALTER TABLE likes add FOREIGN KEY (object_type_id) REFERENCES object_types (id)');
		$dbh->do('ALTER TABLE likes alter object_type_Id SET NOT NULL');
		
		} # end if
		$dbh->do('ALTER TABLE likes DROP object_type');
		$dbh->do('CREATE INDEX likes_idx ON comments ( object_type_id, object_id )');
	} # end if
	if ( ! exists $$data{'value'} ) {
		$dbh->do('ALTER TABLE likes ADD value INTEGER');
		$dbh->do('ALTER TABLE likes ADD FORIEGN KEY (value) REFERENCES opinion_types (id)');
	} # end if
	if ( ! exists $$data{'opinion_type_id'} ) {
		$dbh->do('ALTER TABLE likes ADD opinion_type_id INTEGER');
		$dbh->do('ALTER TABLE likes ADD FOREIGN KEY (opinion_type_id) REFERENCES Opinion_Types (id)');
		$dbh->do('UPDATE likes SET opinion_type_id=value');
		$dbh->do('DELETE FROM Likes where opinion_type IS NULL');
		$dbh->do( 'ALTER TABLE likes DROP CONSTRAINT likes_pkey');
		$dbh->do( 'ALTER TABLE likes ADD PRIMARY KEY (object_id, object_type_id, user_id, opinion_type_id)' );
	} # end if
}
if ( ! sets::isin( 'opinions', \@tables ) ) {
	if ( sets::isin( 'likes', \@tables ) ) {
		$dbh->do('ALTER TABLE likes RENAME to opinions');
		$dbh->do( 'ALTER TABLE opinions DROP CONSTRAINT likes_pkey');
		$dbh->do( 'ALTER TABLE opinions ADD PRIMARY KEY (object_id, object_type_id, user_id, opinion_type_id)' );
	} else {
		$dbh->do( misc::load_file( $log, '../openprint/sql/Opinions.sql' ) );
		die $dbh->errstr() if $dbh->errstr();
	} # end if
} # end if

if ( ! sets::isin( 'keywords', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Keywords.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
}
if ( ! sets::isin( 'privacy', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Privacy.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='privacy'", 'column_name');
	if ( exists $$data{'value'} ) {
		$dbh->do('ALTER TABLE privacy RENAME value to mode');
	} # end if
	if ( ! exists $$data{'usergroup_id'} ) {
		$dbh->do('ALTER TABLE privacy ADD usergroup_id INTEGER[]');
	} # end if
	if ( ! exists $$data{'relationship_type_id'} ) {
		$dbh->do('ALTER TABLE privacy ADD relationship_type_id INTEGER[]');
	} # end if
	if ( exists $$data{'relationship_id'} ) {
		$dbh->do('ALTER TABLE Privacy DROP relationship_id');
	} # end if
	if ( ! exists $$data{'user_id'} ) {
		$dbh->do('ALTER TABLE privacy ADD user_id INTEGER[]');
	} # end if
}
if ( ! sets::isin( 'object_assets', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Object_Assets.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
}

if ( ! sets::isin( 'surveys', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Surveys.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='surveys'", 'column_name');
	if ( ! $$data{'created_on'} ) { 
		$dbh->do('ALTER TABLE surveys add created_on TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()');
	} # end if
	if ( ! $$data{'created_on'} ) { 
		$dbh->do('ALTER TABLE surveys ADD created_by INTEGER');
		$dbh->do('ALTER TABLE surveys ADD FOREIGN KEY (created_by) REFERENCES Users (id)');
	} # end if
} # end if

if ( ! sets::isin( 'survey_question_categories', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Survey_Question_Categories.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='survey_question_categories'", 'column_name');
	if ( ! exists $$data{'sorting'} ) {
		$dbh->do('ALTER TABLE survey_question_categories ADD sorting INTEGER');
	} # end if
}
if ( ! sets::isin( 'survey_questions', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Survey_Questions.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='survey_questions'", 'column_name');
	if ( ! $$data{'type'} ) { 
		$dbh->do('ALTER TABLE survey_questions add type TEXT');
	} # end if
	if ( ! $$data{'alignment'} ) { 
		$dbh->do('ALTER TABLE survey_questions ADD alignment BOOLEAN');
	} # end if
	if ( ! $$data{'sorting'} ) { 
		$dbh->do('ALTER TABLE survey_questions ADD sorting INTEGER');
	} # end if
} # end if
if ( ! sets::isin( 'survey_responses', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Survey_Responses.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='survey_responses'", 'column_name');
	if ( ! $$data{'created_on'} ) { 
		$dbh->do('ALTER TABLE survey_responses add created_on TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()');
	} # end if
	if ( ! $$data{'public'} ) { 
		$dbh->do('ALTER TABLE survey_responses ADD public BOOLEAN');
	} # end if
	if ( ! $$data{'answer_ids'} ) {
		$dbh->do('ALTER TABLE survey_responses ADD answer_ids INTEGER[]');
		if ( $$data{'answer_id'} ) {
			$dbh->do('UPDATE survey_responses set answer_ids = ARRAY[answer_id]');
			$dbh->do('ALTER TABLE survey_responses DROP answer_id');
		} # end if
	} # end if
} # end if
if ( ! sets::isin( 'promo_codes', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Promo_Codes.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
}
if ( ! sets::isin( 'product_prices', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Product_Prices.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='product_prices'", 'column_name');
	if ( ! exists $$data{'discountable'} ) {
		$dbh->do('ALTER TABLE product_prices ADD discountable BOOLEAN NOT NULL default true');
	} # end if
	if ( ! exists $$data{'owner_id'} ) {
		$dbh->do('ALTER TABLE Product_Prices ADD owner_id INTEGER');
		$dbh->do('ALTER TABLE Product_Prices ADD FOREIGN KEY (owner_id) REFERENCES companies (id)');
	}
}

my $ServiceType = openprint::ServiceType->find_one('name'=>'Signature');
if ( ! $ServiceType ) {
	if ( $ServiceType = openprint::ServiceType->find_one('name'=>'AdditionalSignature') ) {
		$ServiceType->save({'name'=>'Signature','type'=>'Printing','url'=>'prin/Signature.html'});
	} # end if
} # end if

if ( sets::isin( 'paper_purchase_orders', \@tables ) ) {
	if ( sets::isin( 'paper_purchase_order_contents', \@tables ) ) {
		$dbh->do('DROP TABLE paper_purchase_order_contents');
	}
	$dbh->do('DROP TABLE paper_purchase_orders');
}
if ( ! $config{'Timezone'} ) {
$dbh->do(q`insert into Configuration values ('Timezone', 'America/Toronto', 'text', 'Timezone','Miscellaneous Settings' );` );
	
} # end if
if ( ! sets::isin( 'schedule', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Schedule.sql}) );
	die if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='schedule'", 'column_name');
	if ( ! exists $$data{'stock'} ) {
		$dbh->do('ALTER TABLE Schedule add stock text');
	} 
	if ( ! exists $$data{'stock_verified'} ) {
		$dbh->do('ALTER TABLE Schedule add stock_verified boolean not null default false');
	} 
	if ( ! exists $$data{'tentative'} ) {
		$dbh->do('ALTER TABLE Schedule add tentative boolean');
	} 
	if ( ! exists $$data{'comment'} ) {
		$dbh->do('ALTER TABLE Schedule add comment text');
	} 
	if ( ! exists $$data{'servicetype_id'} ) {
		$dbh->do('ALTER TABLE Schedule add servicetype_id INTEGER');
	} 
	if ( ! exists $$data{'pertains_id'} ) {
		$dbh->do('ALTER TABLE Schedule add pertains_id INTEGER[]');
	} 
	if ( ! exists $$data{'created_on'} ) {
		$dbh->do('ALTER TABLE Schedule add created_on TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()');
	} 
	$dbh->do('ALTER TABLE SChedule alter projectindex drop not null');
	if ( exists $$data{'serviceindex'} ) {
		$dbh->do('ALTER TABLE SChedule drop serviceindex');
	} # end if
	if ( ! exists $$data{'service_id'} ) {
		$dbh->do('ALTER TABLE Schedule add service_id INTEGER[]');
	} 
}

if ( ! sets::isin( 'conversations', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Conversations.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
}

if ( sets::isin( 'tbl_projecttype_defaults', \@tables ) ) {
	if ( ! sets::isin( 'projecttype_defaults', \@tables ) ) {
		$dbh->do('ALTER TABLE tbl_projecttype_defaults RENAME TO projecttype_defaults');
		unshift @tables, 'projecttype_defaults';
		$dbh->do('CREATE SEQUENCE projecttype_defaults_id_seq');
		$dbh->do(q`ALTER TABLE projecttype_defaults ALTER id SET default nextval('projecttype_defaults_id_seq')`);
		$dbh->do(q`SELECT setval('projecttype_defaults_id_seq', (SELECT max(id) FROM projecttype_defaults));`);
	} else {
		$dbh->do('DROP TABLE tbl_projecttype_defaults');
	} # end if
	$dbh->do('DROP SEQUENCE tbl_projecttype_defaults_id_seq') if sets::isin('tbl_projecttype_defaults_id_seq', \@sequences );
} # end if
if ( ! sets::isin( 'projecttype_defaults', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/ProjectType_Defaults.sql}) );
	die if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='projecttype_defaults'", 'column_name');
	if ( exists $$data{'lngprojecttypeindex'} ) {
		$dbh->do('ALTER TABLE Projecttype_defaults RENAME COLUMN lngprojecttypeindex to projecttype_id');
	}
	if ( exists $$data{'strfieldname'} ) {
		$dbh->do('ALTER TABLE Projecttype_defaults RENAME COLUMN strfieldname to name');
	}
	if ( exists $$data{'strdefaultvalue'} ) {
		$dbh->do('ALTER TABLE Projecttype_defaults RENAME COLUMN strdefaultvalue to value');
	}
} 
if ( ! sets::isin( 'inventoryconditions', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/InventoryConditions.sql}) );
	die if $dbh->errstr();
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='skid_contents'", 'column_name');
	$dbh->do('insert into inventoryconditions select * from stockqualities');
	$dbh->do('alter table skid_contents ADD condition_id INTEGER');
	if ( exists $$data{'quality_id'} ) {
		$dbh->do('UPDATE skid_contents set condition_id=quality_id');
		$dbh->do('ALTER TABLE skid_contents DROP quality_id');
	} # end if
	$dbh->do('ALTER TABLE Skid_Contents add FOREIGN KEY (condition_id) REFERENCES inventoryconditions (id)');
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='inventoryconditions'", 'column_name');
}
if ( ! sets::isin( 'wall', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Wall.sql}) );
	die if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='wall'", 'column_name');
	if ( ! exists $$data{'reply_to'} ) {
		$dbh->do('ALTER TABLE wall ADD reply_to INTEGER');
		$dbh->do('ALTER TABLE wall ADD FOREIGN KEY (reply_to) REFERENCES Wall (id)');
	} 
	if ( ! exists $$data{'has_replies'} ) {
		$dbh->do('ALTER TABLE wall ADD has_replies BOOLEAN NOT NULL default false');
	} 
}
if ( ! sets::isin( 'views', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Views.sql}) );
	die if $dbh->errstr();
} # en dif
if ( ! sets::isin( 'opinion_availability', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Opinion_Availability.sql}) );
	die if $dbh->errstr();
} # en dif
if ( ! sets::isin( 'company_categories', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Company_Categories.sql}) );
	die if $dbh->errstr();
	$dbh->do(q`ALTER TABLE Companies add category_id INTEGER`);
	$dbh->do(q`ALTER TABLE Companies add FOREIGN KEY (category_id) REFERENCES company_categories (id)`);
} # endif
if ( $config{'Owner'} ) {
	$dbh->do("UPDATE configuration SET name='owner_id' WHERE name='Owner'" );
}
$dbh->disconnect();
1;
__END__
