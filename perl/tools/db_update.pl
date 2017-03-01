#!/usr/bin/perl 
use lib '/var/www/testing/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Paper;
require openprint::PaperPrice;
require openprint::Equipment;
require openprint::EquipmentSpecification;
require openprint::ServicePrice;
require openprint::ServiceType;
require openprint::Service;
require openprint::ServiceCategory;
require openprint::Project;
require openprint::service;
require openprint::Material;
require openprint::MaterialCategory;
require openprint::PaperInventory;
require openprint::Log;
require openprint::Host;
require openprint::Company;

use openprint ();
use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

$openprint::Object::no_cache = 1;

$log = new logger( 'debug' );

$ARGV[1] = $ARGV[0] if ! $ARGV[1];
$ARGV[2] = $ARGV[1] if ! $ARGV[2];
$ARGV[4] = 5432 if ! $ARGV[4];

$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>$ARGV[3], port=>$ARGV[4]) );
my @tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
$log->debug("Tables: @tables");
my @sequences = sql::execute( undef, undef, q`SELECT sequence_name FROM information_schema.sequences where sequence_schema='public'`);

sub load_sql {
	if ( ! $dbh->do( misc::load_file( $log, '../openprint/sql/'.$_[0].'.sql') ) ) {
		my ( $caller, undef, $line ) = caller;
		die ( $dbh->errstr() . ' from line ' . $line );
	}
	@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
	@sequences = sql::execute( undef, undef, q`SELECT sequence_name FROM information_schema.sequences where sequence_schema='public'`);
}

if ( ! sets::isin( 'database_info', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/database_info.sql}) );
	die $dbh->errstr() if $dbh->errstr();
}
my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM database_info LIMIT 1', {} );
if ( ! $data ) {
	sql::insert( undef, undef, 'database_info', 'version', 1, 'updated_on', 'NOW()','backup',0 );
}

my ( $version, $updated_on, $backup ) = sql::execute( undef, undef, q{SELECT version,updated_on, backup FROM database_info ORDER BY updated_on DESC LIMIT 1} );
print "Current Database Version: $version Backups: $backup, Last Updated: $updated_on\n";

if ( ! sets::isin( 'configuration', \@tables ) ) {
	$log->debug("Adding Configuration table");
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Configuration.sql}) );
}

if ( ! sets::isin( 'object_types', \@tables ) ) {
	$log->debug("Adding object_types table");
    $dbh->do( misc::load_file( $log, '../openprint/sql/Object_Types.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
	$dbh->do(q`INSERT INTO object_types (name,human) values ('openprint::Comment', 'comment')`);
	$dbh->do(q`INSERT INTO object_types (name,human) values ('openprint::Like', 'like')`);
	$dbh->do(q`INSERT INTO object_types (name,human) values ('openprint::Host', 'host')`);
}

configuration::init( $log, $dbh );
$config{db_name} = $ARGV[0];

if ( ! sets::isin( 'currencies', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Currencies.sql}) );
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='currencies'", 'column_name');
	if ( ! exists $$data{short} ) {
		$dbh->do('ALTER TABLE Currencies ADD short TEXT');
	} # end if
	$dbh->do('ALTER TABLE currencies ADD sy varchar(4)');
	$dbh->do('UPDATE currencies set sy=symbol');
	$dbh->do('ALTER TABLE currencies DROP COLUMN symbol');
	$dbh->do('ALTER TABLE currencies RENAME COLUMN sy TO symbol');
} # end if

if ( ! sets::isin( 'annualsales', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/AnnualSales.sql}) );
} # end if

if ( ! sets::isin( 'companies', \@tables ) ) {
	if ( ! sets::isin( 'company', \@tables ) ) {
		$dbh->do( misc::load_file( $log, q{../openprint/sql/Companies.sql}) );
		die $dbh->errstr() if $dbh->errstr();
	} else {
		my $ac = sql::start_transaction( $dbh );
		print "Renaming company to companies\n";
		$dbh->do('ALTER TABLE Company RENAME TO Companies');
		my $data2 = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='companies'", 'column_name');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN strName TO name');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN strAddress1 TO address1');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN strAddress2 TO address2');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN strcity TO city');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN strstate TO state') if exists $$data2{strstate};
		$dbh->do('ALTER TABLE Companies RENAME COLUMN strcountry TO country');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN strpostalcode TO postalcode');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN dtmdateentered TO created_on');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN dtmlastupdated TO updated_on') if exists $$data2{dtmlastupdated};
		$dbh->do('ALTER TABLE Companies RENAME COLUMN dtmlastmodified TO updated_on') if exists $$data2{dtmlastmodified};
		$dbh->do('ALTER TABLE Companies RENAME COLUMN lngpricelist TO pricelist_id');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN strgstnumber TO fedtaxnumber');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN strpstnumber TO statetaxnumber');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN strphone TO phone');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN strfax TO fax');

		$dbh->do(q`alter table Companies rename column index to id`);
		$dbh->do(q`alter table Companies rename column strprovstate to state`) if exists $$data2{strprovstate};
		$dbh->do(q`alter table Companies rename column lngsalesperson to salesrep_id`);
		$dbh->do(q`alter table Companies rename column ysnmailinglist to mailinglist`);
		$dbh->do(q`alter table Companies rename column strweburl to url`);
		$dbh->do(q`alter table Companies rename column strcustomgreeting to greeting`);
		$dbh->do(q`alter table Companies rename column dblpricingpercent to discount`);
		$dbh->do(q`alter table Companies rename column strbusinesstype to business_type`);
		$dbh->do(q`alter table Companies rename column strlegalbusname to business_name`);
		$dbh->do(q`alter table Companies rename column legalform to business_form`);
		$dbh->do(q`alter table Companies rename column strpresidentowner to president_owner`);
		$dbh->do(q`alter table Companies rename column dtmbusinessstartdate to established`);
		$dbh->do(q`alter table Companies rename column stremployees to employees`);
		$dbh->do(q`alter table Companies rename column strannualsales to annual_sales`);
		$dbh->do(q`alter table Companies rename column strbankname to bank_name`);
		$dbh->do(q`alter table Companies rename column strbankbranch to bank_branch`);
		$dbh->do(q`alter table Companies rename column strbankphone to bank_phone`);
		$dbh->do(q`alter table Companies rename column strbankaccountno to bank_account`);
		$dbh->do(q`alter table Companies rename column strbankaccountmanager to bank_manager`);
		$dbh->do(q`alter table Companies rename column strbankfax to bank_fax`);
		$dbh->do(q`alter table Companies rename column strbankemail to bank_email`);
		$dbh->do('CREATE SEQUENCE companies_id_seq');
		$dbh->do(q`SELECT setval('companies_id_seq', (SELECT MAX(id) FROM Companies))`);
		$dbh->do(q`ALTER TABLE companies alter id set default nextval('companies_id_seq')`);
		$dbh->do('DROP SEQUENCE IF EXISTS tbl_Customer_lngCustomerID_seq') if sets::isin( 'tbl_customer_lngcustomerid_seq', \@sequences );
		$dbh->do('DROP SEQUENCE IF EXISTS companyindex_seq') if sets::isin( 'companyindex_seq', \@sequences );
		sql::end_transaction( $dbh, $ac );
	} # end if
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='companies'", 'column_name');
	if ( ! exists $$data{mailinglist} ) {
		if ( exists $$data{ysnmailinglist} ) {
			$dbh->do(q`alter table companies rename column ysnmailinglist to mailinglist`);
		} else {
			$dbh->do(q`alter table companies add mailinglist CHAR(1) DEFAULT 'N'`);
		}
		$$data{mailinglist} = '';
	} # end if
	$dbh->do('alter table companies drop column strftplogin') if ( exists $$data{strftplogin} );
	$dbh->do('alter table companies drop column strftppassword') if ( exists $$data{strftppassword} );
	$dbh->do('alter table companies drop column strftphomedir') if ( exists $$data{strftphomedir} );

	if ( ! exists $$data{asset_id} ) {
		$dbh->do('ALTER TABLE companies ADD asset_id INTEGER');
	} # end if
	foreach my $field ( 'name', 'address1', 'address2', 'city','country','state', 'postalcode', 'gst_number', 'pst_number',
			'accountnumber','phone','extension','fax','greeting','business_type','business_name','business_form','president_owner',
			'bank_name','bank_branch','bank_account','bank_manager','bank_phone','bank_fax','bank_email','notes' ) {
		if ( ! $openprint::Company::fields{$field} ) {
			die "Want to add $field to Company but it's not in fields";
		} # end if
		if ( ! exists $$data{$openprint::Company::fields{$field}} ) {
			$dbh->do('ALTER TABLE companies ADD '.$openprint::Company::fields{$field}.' TEXT');
			die $dbh->errstr() if $dbh->errstr();
		} # end if
	} # end foreach
	foreach my $field ( 'created_on', 'updated_on' ) {
		if ( ! $openprint::Company::fields{$field} ) {
			die "Want to add $field to Company but it's not in fields";
		} # end if
		if ( ! exists $$data{$openprint::Company::fields{$field}} ) {
			$dbh->do('ALTER TABLE companies ADD '.$openprint::Company::fields{$field}.' TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()');
			die $dbh->errstr() if $dbh->errstr();
		} # end if
	} # end foreach
	foreach my $field ( 'supplier','reseller', 'gst_exempt','pst_exempt', 'activation', 'mailinglist', 'quote_project_breakdown' ) {
		if ( ! $openprint::Company::fields{$field} ) {
			die "Want to add $field to Company but it's not in fields";
		} # end if
		if ( ! exists $$data{$openprint::Company::fields{$field}} ) {
			$dbh->do('ALTER TABLE companies ADD '.$openprint::Company::fields{$field}.q` CHAR(1) default 'N'`);
			die $dbh->errstr() if $dbh->errstr();
		} # end if
	} # end foreach
	foreach my $field ( 'deleted', 'offers_credit' ) { 
		if ( ! $openprint::Company::fields{$field} ) {
			die "Want to add $field to Company but it's not in fields";
		} # end if
		if ( ! exists $$data{$openprint::Company::fields{$field}} ) {
			$dbh->do('ALTER TABLE companies ADD '.$openprint::Company::fields{$field}.q` BOOLEAN NOT NULL DEFAULT FALSE`);
			die $dbh->errstr() if $dbh->errstr();
		} # end if
	} # end foreach
	foreach my $field ( 'salesrep_id', 'pricelist_id', 'currency_id', 'detail_level',  ) { 
		if ( ! $openprint::Company::fields{$field} ) {
			die "Want to add $field to Company but it's not in fields";
		} # end if
		if ( ! exists $$data{$openprint::Company::fields{$field}} ) {
			$dbh->do('ALTER TABLE companies ADD '.$openprint::Company::fields{$field}.q` INTEGER`);
			die $dbh->errstr() if $dbh->errstr();
		} # end if
	} # end foreach
	if ( ! exists $$data{$openprint::Company::fields{established}} ) {
		$dbh->do('ALTER TABLE companies ADD '.$openprint::Company::fields{established}.q` date`);
		die $dbh->errstr() if $dbh->errstr();
	} # end if
	if ( ! exists $$data{$openprint::Company::fields{discount}} ) {
		$dbh->do('ALTER TABLE companies ADD '.$openprint::Company::fields{discount}.q` numeric(16,4) DEFAULT '0.0000' NOT NULL`);
		die $dbh->errstr() if $dbh->errstr();
	} # end if
	if ( ! exists $$data{$openprint::Company::fields{last_project_id}} ) {
		if ( ! sets::isin( 'projects', \@tables ) ) {
			$dbh->do( misc::load_file( $log, q{../openprint/sql/Projects.sql}) ) or die;
			@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
		}
		$dbh->do('ALTER TABLE companies ADD last_project_id INTEGER');
		$dbh->do('ALTER TABLE companies ADD FOREIGN KEY (last_project_id) REFERENCES Projects (id)');
		$dbh->do('UPDATE companies SET last_project_id = (SELECT MAX(id) FROM projects WHERE company_id=companies.id)');
		die $dbh->errstr() if $dbh->errstr();
	} # end if
	if ( ! exists $$data{$openprint::Company::fields{last_order_id}} ) {
if ( ! sets::isin( 'orders', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Orders.sql}) ) or die $dbh->errstr();
	@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
}
		$dbh->do('ALTER TABLE companies ADD last_order_id INTEGER');
		$dbh->do('ALTER TABLE companies ADD FOREIGN KEY (last_order_id) REFERENCES Orders (id)');
		$dbh->do('UPDATE companies SET last_order_id = (SELECT MAX(id) FROM Orders WHERE company_id=companies.id)');
		die $dbh->errstr() if $dbh->errstr();
	} # end if
	if ( ! exists $$data{$openprint::Company::fields{last_quote_id}} ) {
if ( ! sets::isin( 'quotes', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Quotes.sql}) ) or die $dbh->errstr();
	@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
}
		$dbh->do('ALTER TABLE companies ADD last_quote_id INTEGER');
		$dbh->do('ALTER TABLE companies ADD FOREIGN KEY (last_quote_id) REFERENCES Quotes (id)');
		$dbh->do('UPDATE companies SET last_quote_id = (SELECT MAX(id) FROM Quotes WHERE companyindex=companies.id)');
		die $dbh->errstr() if $dbh->errstr();
	} # end if
	if ( ! exists $$data{$openprint::Company::fields{last_invoice_id}} ) {
		$dbh->do('ALTER TABLE companies ADD last_invoice_id INTEGER');
		$dbh->do('ALTER TABLE companies ADD FOREIGN KEY (last_invoice_id) REFERENCES Invoices (id)');
		$dbh->do('UPDATE companies SET last_invoice_id = (SELECT MAX(id) FROM Invoices WHERE invoicee_id=companies.id)');
		die $dbh->errstr() if $dbh->errstr();
	} # end if

} # end if


if ( ! sets::isin( 'quotelevels', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/QuoteLevels.sql}) );
	@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
	die "Unable to create quotelevels" if ! sets::isin( 'quotelevels', \@tables );
} # end if

if ( ! sets::isin( 'user_types', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/User_Types.sql}) );
}

if ( ! sets::isin( 'users', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Users.sql}) ) or die $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='users'", 'column_name');
	if ( $data ) {
		print "Updating Users...\n";
		if ( ! exists $$data{deleted} ) {
			my $ac = sql::start_transaction( $dbh );
			$dbh->do(q`alter table Users add deleted boolean`);
			$dbh->do(q`alter table Users alter deleted set default false`);
			$dbh->do(q`update Users set deleted=false`);
			$dbh->do(q`alter table Users alter deleted set not null`);
			sql::end_transaction( $dbh, $ac );
		} 
		if ( ! exists $$data{wage} ) {
			$dbh->do(q`alter table Users add wage float`);
		} # end if
		if ( exists $$data{strfirstname} ) {
			my $ac = sql::start_transaction( $dbh );
			$dbh->do(q`alter table Users rename column strfirstname to firstname`);
			$dbh->do(q`alter table Users rename column strlastname to lastname`);
			$dbh->do(q`alter table Users rename column stremail to email`);
			$dbh->do(q`alter table Users rename column strphone to phone`);
			$dbh->do(q`alter table Users rename column strfax to fax`);
			$dbh->do(q`alter table Users rename column strtitle to title`);
			$dbh->do(q`alter table Users rename column strsalutation to salutation`);
			$dbh->do(q`alter table Users rename column dtmdateentered to created_on`);
			$dbh->do(q`alter table Users rename column dtmlastmodified to updated_on`);
			$dbh->do(q`alter table Users rename column chrtype to type`);
			sql::end_transaction( $dbh, $ac );
		}
		$dbh->do(q`alter table Users rename column strpassword to password`) if exists $$data{strpassword};
		$dbh->do(q{alter table Users drop column ysnHTMLEmails}) if exists $$data{ysnhtmlemails};
		$dbh->do(q{alter table Users drop column stremployeetype}) if exists $$data{stremployeetype};
		$dbh->do(q{alter table Users drop column strmailserverusername}) if exists $$data{strmailserverusername};
		$dbh->do(q{alter table Users drop column strmailserverpassword}) if exists $$data{strmailserverpassword};
		$dbh->do(q{alter table Users drop column lastlogin}) if exists $$data{lastlogin};
		$dbh->do(q{alter table Users rename column index to id}) if exists $$data{index};
		$dbh->do(q`alter table users add deleted boolean`) if ! exists $$data{deleted};
		$dbh->do(q`alter table users add email_quotes_to_myself boolean default false`) if ! exists $$data{email_quotes_to_myself};
		$dbh->do('ALTER TABLE USERS RENAME COLUMN ysnaccountactivation TO web_active') if exists $$data{ysnaccountactivation};
		$dbh->do('ALTER TABLE USERS RENAME COLUMN companyindex TO company_id') if exists $$data{companyindex};
		if ( ! exists $$data{purchasing_limit} ) {
			$dbh->do(q`alter table Users add purchasing_limit	float`);
		} # end if
		if ( ! exists $$data{purchasing_total_limit} ) {
			$dbh->do(q`alter table Users add purchasing_total_limit	float`);
		} # end if
		if ( exists $$data{usertype} and ! exists $$data{type} ) {
			$dbh->do(q`alter table Users rename column usertype to type`);
		} # end if
		if ( exists $$data{strcustomgreeting} ) {
			if ( exists $$data{greeting} ) {
				$dbh->do(q`alter table Users DROP column strcustomgreeting`);
			} else {
				$dbh->do(q`alter table Users rename column strcustomgreeting to greeting`);
			} # end if
		}
		$dbh->do(q{alter table users add howdidyouhearaboutusother text}) if ! exists $$data{howdidyouhearaboutusother};
		if ( ! exists $$data{quote_level} ) {	
			$dbh->do(q`alter table Users add quote_level integer`);
			$dbh->do(q`alter table Users add foreign key (quote_level) REFERENCES QuoteLevels (id)`);
		} # end if
		if ( ! exists $$data{notes} ) {
			$dbh->do('alter table users add notes text');
		} # end if
		if ( ! exists $$data{extension} ) {
			$dbh->do('alter table users add extension text');
		} # end if
		if ( ! exists $$data{password_changed_on} ) {
			$dbh->do('alter table users add password_changed_on TIMESTAMP WITH TIME ZONE');
		} # end if
		if ( ! exists $$data{asset_id} ) {
			$dbh->do('ALTER TABLE users ADD asset_id INTEGER');
		} # end if
		if ( ! exists $$data{ftp_root} ) {
			$dbh->do(q`alter table users add ftp_root text not null default ''`);
		} # end if
		if ( ! exists $$data{email_valid} ) {
			$dbh->do(q`alter table users add email_valid BOOLEAN`);
		} # end if
	} # end if
	if ( sets::isin( 'users_index_seq', \@sequences ) ) {
		if ( ! sets::isin( 'users_id_seq', \@sequences ) ) {
			$dbh->do('CREATE SEQUENCE users_id_seq');
		} # end if
		$dbh->do("ALTER TABLE Users ALTER id set default nextval('users_id_seq')" );
		$dbh->do('DROP SEQUENCE users_index_seq');
		$dbh->do(q`SELECT setval('users_id_seq', (SELECT max(id) FROM users))` );
		@sequences = sql::execute( undef, undef, q`SELECT sequence_name FROM information_schema.sequences where sequence_schema='public'`);
	} # end if
	$dbh->do('ALTER TABLE Users ALTER email DROP NOT NULL');
} # end if

if ( ! sets::isin( 'assets', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Assets.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='assets'", 'column_name');
	if ( ! exists $$data{md5} ) {
		$dbh->do('ALTER TABLE Assets ADD md5 char(32)');
	} # end if
	if ( ! exists $$data{deleted} ) {
		$dbh->do('ALTER TABLE Assets ADD deleted BOOLEAN NOT NULL DEFAULT FALSE');
	} # end if
	if ( ! exists $$data{license} ) {
		$dbh->do('ALTER TABLE Assets ADD license TEXT');
	} # end if
	if ( ! exists $$data{attribution} ) {
		$dbh->do('ALTER TABLE Assets ADD attribution TEXT');
	} # end if
	if ( ! exists $$data{optimised} ) {
		$dbh->do('ALTER TABLE Assets ADD optimised BOOLEAN NOT NULL DEFAULT FALSE');
	} # end if
	if ( ! exists $$data{width} ) {
		$dbh->do('ALTER TABLE Assets ADD width integer');
	} # end if
	if ( ! exists $$data{height} ) {
		$dbh->do('ALTER TABLE Assets ADD height integer');
	} # end if
	if ( ! exists $$data{layout} ) {
		$dbh->do('ALTER TABLE Assets ADD layout text');
	} # end if
	if ( ! exists $$data{source} ) {
		$dbh->do('ALTER TABLE Assets ADD source text');
	} # end if
} # end if

if ( ! sets::isin('articles',\@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Articles.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='articles'", 'column_name');
	if ( ! exists $$data{source} ) {
		$dbh->do('ALTER TABLE articles ADD source TEXT');
	} # end if
	if ( ! exists $$data{keywords} ) {
		$dbh->do('ALTER TABLE articles ADD keywords TEXT');
	} # end if
	if ( ! exists $$data{summary} ) {
		$dbh->do('ALTER TABLE articles ADD summary TEXT');
	} # end if
	if ( ! exists $$data{source_content} ) {
		$dbh->do('ALTER TABLE articles ADD source_content TEXT');
	} # end if
	if ( ! exists $$data{category_id} ) {
		$dbh->do('ALTER TABLE articles ADD category_id INTEGER');
	} # end if
	if ( ! exists $$data{user_type} ) {
		$dbh->do('ALTER TABLE articles ADD user_type CHAR(1)');
		$dbh->do('ALTER TABLE articles ADD FOREIGN KEY (user_type) REFERENCES user_types (identifier)');
	} # end if
	if ( ! exists $$data{anonymous} ) {
	$dbh->do('ALTER TABLE articles ADD anonymous BOOLEAN NOT NULL default false');
	} # end if
	$dbh->do('ALTER TABLE articles ALTER company_id DROP NOT NULL');
	if ( ! exists $$data{commenting} ) {
	$dbh->do('ALTER TABLE articles ADD commenting BOOLEAN NOT NULL default false');
	print "Adding commenting to articles\n";
	} # end if
} # end if
if ( sets::isin( 'article_assets', \@tables ) ) {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='article_assets'", 'column_name');
} else {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Article_Assets.sql' ) );
	die if $dbh->errstr();
} # end if

if ( sets::isin( 'article_categories', \@tables ) ) {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='article_categories'", 'column_name');
	if ( exists $$data{image_filename} ) {
		$dbh->do('ALTER TABLE article_categories DROP image_filename');
	} # end if
	if ( ! exists $$data{album_id} ) {
		$dbh->do('ALTER TABLE article_categories ADD album_id INTEGER');
		$dbh->do('ALTER TABLE article_categories ADD FOREIGN KEY (album_id) REFERENCES Photo_Albums (id)');
	} # end if
	if ( ! exists $$data{description} ) {
		$dbh->do('ALTER TABLE article_categories ADD description TEXT');
	} # end if
	if ( ! exists $$data{summary} ) {
		$dbh->do('ALTER TABLE article_categories ADD summary TEXT');
	} # end if
	if ( ! exists $$data{deleted} ) {
		$dbh->do('ALTER TABLE article_categories ADD deleted BOOLEAN NOT NULL default false');
	} # end if
} else {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Article_Categories.sql' ) );
	die if $dbh->errstr();
}

if ( ! sets::isin( 'photo_albums', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Photo_Albums.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='photo_albums'", 'column_name');
	if ( ! exists $$data{description} ) {
		$dbh->do('ALTER TABLE photo_albums ADD description TEXT');
	} # end if
} # end if

if ( ! sets::isin( 'invoices', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Invoices.sql}) ) or die $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='invoices'", 'column_name');
	if ( ! exists $$data{num} ) {
		$dbh->do('ALTER TABLE Invoices ADD num TEXT');
	} # end if
	if ( ! exists $$data{late_payment_units} ) {
		$dbh->do('ALTER TABLE Invoices ADD late_payment_units TEXT');
	} # end if
	if ( ! exists $$data{early_payment_units} ) {
		$dbh->do('ALTER TABLE Invoices ADD early_payment_units TEXT');
	} # end if
	if ( ! exists $$data{early_payment_amount} ) {
		if ( exists $$data{early_payment_discount} ) {
			$dbh->do('ALTER TABLE invoices RENAME COLUMN early_payment_discount to early_payment_amount');
		} else {
			$dbh->do('ALTER TABLE Invoices ADD early_payment_amount float');
		} # end if
	} # end if
	if ( ! exists $$data{early_payment_date} ) {
		$dbh->do('ALTER TABLE Invoices ADD early_payment_date DATE');
	} # end if
	if ( ! exists $$data{subtotal_override} ) {
		$dbh->do('ALTER TABLE Invoices ADD subtotal_override BOOLEAN NOT NULL default false');
	} # end if
} # end if
if ( ! sets::isin( 'invoice_interests', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Invoice_Interests.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} # end if

if ( ! sets::isin( 'invoices_id_seq', \@sequences ) ) {
	$dbh->do('CREATE SEQUENCE invoices_id_seq');
} # en dif
if ( ! sets::isin( 'order_statuses', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Order_Statuses.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='order_statuses'", 'column_name');
	if ( ! exists $$data{id} ) {
		$dbh->do('DROP TABLE order_statuses');
		$dbh->do( misc::load_file( $log, '../openprint/sql/Order_Statuses.sql' ) );
		die $dbh->errstr() if $dbh->errstr();
	} # end if
}
if ( ! sets::isin( 'order_statuses_id_seq', \@sequences ) ) {
	if ( sets::isin( 'order_status_id_seq', \@sequences ) ) {
		$dbh->do('ALTER SEQUENCE order_status_id_seq RENAME to order_statuses_id_seq');
	} else {
		$dbh->do('CREATE SEQUENCE order_statuses_id_seq');
	} # end if

} # en dif

if ( ! sets::isin( 'paymenttypes', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/PaymentTypes.sql}) ) or die $dbh->errstr();
} else {
} # end if


if ( ! sets::isin( 'orders', \@tables ) ) {
	load_sql( 'Orders' );
}

if ( ! sets::isin( 'payments', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Payments.sql}) );
	die "died error from do " . $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='payments'", 'column_name');
	if ( ! $data ) {
		die 'Unable to load payments';
	} # end if

	if ( ! exists $$data{owner_id} ) {
		$dbh->do('ALTER TABLE Payments add owner_id INTEGER');
		$dbh->do('ALTER TABLE Payments add FOREIGN KEY (owner_id) REFERENCES Companies (id)');
	} # end if
	if ( exists $$data{company_id} ) {
		$dbh->do('ALTER TABLE Payments rename column company_id to payor_id');
		$dbh->do('ALTER TABLE Payments add FOREIGN KEY (payor_id) REFERENCES Companies (id)');
	} # end if
	if ( exists $$data{curamount} ) {
		$dbh->do('ALTER TABLE Payments rename column curamount to amount');
	} # end if
	if ( ! exists $$data{updated_on} ) {
		$dbh->do('ALTER TABLE Payments add updated_on timestamp with time zone not null default NOW()');
	} # end if
	if ( exists $$data{dtmdate} ) {
		if ( ! exists $$data{received_on} ) {
			$dbh->do('ALTER TABLE Payments rename column dtmdate to received_on');
		} else {
			$dbh->do('UPDATE TABLE Payments set received_on=dtmdate where received_on IS NULL');
			$dbh->do('ALTER TABLE Payments drop column dtmdate');
		} # end if
	} elsif ( exists $$data{date} ) {
		if ( ! exists $$data{received_on} ) {
			$dbh->do('ALTER TABLE Payments rename column date to received_on');
		} else {
			$dbh->do('UPDATE Payments SET received_on=date WHERE received_on IS NULL') or die $dbh->errstr();
			$dbh->do('ALTER TABLE Payments DROP COLUMN date') or die $dbh->errstr();
		} # end if
	} elsif ( ! exists $$data{received_on} ) {
		$dbh->do('ALTER TABLE Payments add received_on date NOT NULL default NOW()');
	} # end if
	$data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='payments'", 'column_name');
	if ( ! exists $$data{received_on} ) {
		$dbh->do('ALTER TABLE Payments add received_on date NOT NULL default NOW()');
	} # end if
	if ( exists $$data{strmethod} ) {
		if ( ! exists $$data{method} ) {
			$dbh->do('ALTER TABLE Payments rename column strmethod to method');
		} else {
			$dbh->do('UPDATE TABLE Payments set method=strmethod where method IS NULL');
			$dbh->do('ALTER TABLE Payments drop column method');
		} # end if
	} # end if
	if ( exists $$data{strtransactionid} ) {
		$dbh->do('ALTER TABLE Payments rename column strtransactionid to transaction_id');
	} # end if
	if ( exists $$data{strdescription} ) {
		if ( ! exists $$data{memo} ) {
			$dbh->do('ALTER TABLE Payments rename column strdescription to memo');
		} else {
			$dbh->do('UPDATE TABLE payments set memo=strdescription where memo IS NULL');
			$dbh->do('ALTER TABLE payments drop strdescription');
		} # end if
	} elsif ( ! exists $$data{memo} ) {
		$dbh->do('ALTER TABLE payments add memo text');
	}
	if ( ! exists $$data{completed} ) {
		$dbh->do('ALTER TABLE Payments add completed boolean NOT NULL default false;');
	} # end if
	if ( ! exists $$data{remaining} ) {
		$dbh->do('ALTER TABLE Payments add remaining float;');
	} # end if
	if ( ! exists $$data{deleted} ) {
		$dbh->do('ALTER TABLE Payments add deleted boolean NOT NULL default false;');
	} # end if
	if ( $data and ! exists $$data{type_id} ) {
		$dbh->do('ALTER TABLE payments add type_id INTEGER');
		$dbh->do('ALTER TABLE payments add FOREIGN KEY (type_id) REFERENCES PaymentTypes (id)');
	} # end if
	if ( $data and ! exists $$data{order_id} ) {
		$dbh->do('ALTER TABLE payments add order_id INTEGER');
		$dbh->do('ALTER TABLE payments add FOREIGN KEY (order_id) REFERENCES Orders (id)');
	} # end if
} # end if

	# Check orders structure, don't have to check for existence because we did that twice above
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='orders'", 'column_name');
	if ( ! $$data{supplier_id} ) {
		$dbh->do('ALTER TABLE orders ADD supplier_id INTEGER');
		$dbh->do('ALTER TABLE orders ADD FOREIGN KEY (supplier_id) REFERENCES Companies (Id)');
	} # end if
	if ( ! exists $$data{total} ) {
		if ( exists $$data{curtotalsale} ) {
			$dbh->do('ALTER TABLE orders rename curtotalsale to total');
		} else {
			$dbh->do('ALTER TABLE Orders ADD curtotalsale NUMERIC(10,2)');
		} # end if
	} # end if
	if ( ! exists $$data{company_id} ) {
		if ( exists $$data{companyindex} ) {
			$dbh->do('ALTER TABLE Orders RENAME companyindex to company_id');
		} else {
			$dbh->do('ALTER TABLE Orders ADD company_id INTEGER');
			$dbh->do('ALTER TABLE Orders ADD FOREIGN KEY (company_id) REFERENCES Companies (id)');
		} # end if
	} # end if
	if ( ! exists $$data{strsessionid} ) {
		$dbh->do('ALTER TABLE orders ADD strsessionid text');
	} # e
	if ( ! exists $$data{user_id} ) {
		if ( exists $$data{userindex} ) {
			$dbh->do('ALTER TABLE orders rename userindex to user_id');
		} else {
			$dbh->do('ALTER TABLE orders add user_id INTEGER');
			$dbh->do('ALTER TABLE orders add FOREIGN KEY (user_id) REFERENCES Users (id)');
		} # end if
	} # end if
	if ( ! exists $$data{status_id} ) {
		$dbh->do('ALTER TABLE Orders ADD status_id INTEGER') or die $dbh->errstr();
		$dbh->do('ALTER TABLE Orders ADD FOREIGN KEY (status_id) REFERENCES order_statuses (id)') or die $dbh->errstr();
	} # end if
	if ( exists $$data{strstatus} ) {
		my %Statuses = map { $_->name(), $_ } openprint::Order_Status->find();
		foreach my $status ( sql::execute( undef, undef, 'SELECT DISTINCT strstatus FROM Orders' ) ) {
			next if ! $status;
			if ( ! $Statuses{$status} ) {
				$Statuses{$status} = new openprint::Order_Status();
				$_ = $Statuses{$status}->save({name=>$status});
				die $_ if $_;
			} # end if
			sql::update( undef, undef, 'orders', [ 'strstatus=?', $status ], 'status_id', $Statuses{$status}->id() );	
		} # end foreach status
		$dbh->do('ALTER TABLE orders DROP strstatus');
	} # end if	
	if ( exists $$data{status} ) {
		my %Statuses = map { $_->name(), $_ } openprint::Order_Status->find();
		foreach my $status ( sql::execute( undef, undef, 'SELECT DISTINCT status FROM Orders' ) ) {
			if ( ! $Statuses{$status} ) {
				$Statuses{$status} = new openprint::Order_Status();
				$_ = $Statuses{$status}->save({name=>$status});
				die $_ if $_;
			} # end if
			sql::update( undef, undef, 'orders', [ 'status=?', $status ], 'status_id', $Statuses{$status}->id() );	
		} # end foreach status
		$dbh->do('ALTER TABLE orders DROP status');
	} # end if	
	if ( ! exists $$data{downpayment} ) {
		if ( exists $$data{curdownpayment} ) {
			$dbh->do('ALTER TABLE orders rename curdownpayment to downpayment');
		} else {
			$dbh->do('ALTER TABLE orders add downpayment NUMERIC(10,2)');
		} # end if
	} # end if
	if ( ! exists $$data{created_on} ) {
		if ( exists $$data{orderdate} ) {
			$dbh->do('ALTER TABLE Orders rename orderdate to created_on');
		} elsif ( exists $$data{dtmorderdate} ) {
			$dbh->do('ALTER TABLE Orders rename dtmorderdate to created_on');
		} else {
			$dbh->do('ALTER TABLE orders ADD created_on TIMESTAMP WITH TIME ZONE');
		} # end if
	}	
	if ( ! exists $$data{company_name} ) {
			if ( exists $$data{strcompanyname} ) {
				$dbh->do('ALTER TABLE orders rename strcompanyname to company_name');
			} else {
				$dbh->do('ALTER TABLE ORders ADD company_name TEXT');
			}
	}
	if ( ! exists $$data{administrator_name} ) {
			if ( exists $$data{stradministratorname} ) {
				$dbh->do('ALTER TABLE orders rename stradministratorname to administrator_name');
			} else {
				$dbh->do('ALTER TABLE ORders ADD administrator_name TEXT');
			}
	}
	if ( ! exists $$data{administrator_comments} ) {
			if ( exists $$data{stradministratorcomments} ) {
				$dbh->do('ALTER TABLE orders rename stradministratorcomments to administrator_comments');
			} elsif ( exists $$data{comments} ) {
				$dbh->do('ALTER TABLE orders rename comments to administrator_comments');
			} else {
				$dbh->do('ALTER TABLE ORders ADD administrator_comments TEXT');
			}
	}
	if ( ! exists $$data{extension} ) {
			if ( exists $$data{strext} ) {
				$dbh->do('ALTER TABLE orders rename strext to extension');
			} else {
				$dbh->do('ALTER TABLE ORders ADD extension TEXT');
			}
	}
	if ( ! exists $$data{po} ) {
			if ( exists $$data{strponumber} ) {
				$dbh->do('ALTER TABLE orders rename strponumber to po');
			} elsif ( exists $$data{purchaseordernumber} ) {
				$dbh->do('ALTER TABLE orders rename purchaseordernumber to po');
			} else {
				$dbh->do('ALTER TABLE ORders ADD po TEXT');
			}
	}
	if ( ! exists $$data{currency_id} ) {
			if ( exists $$data{currencyindex} ) {
				$dbh->do('ALTER TABLE orders rename currencyindex to currency_id');
			} else {
				$dbh->do('ALTER TABLE ORders ADD currency_id INTEGER');
				$dbh->do('ALTER TABLE ORders ADD FOREIGN KEY (currency_id) REFERENCES Currencies (id)');
			}
	}
	if ( ! exists $$data{salesrep_id} ) {
			if ( exists $$data{employeeindex} ) {
				$dbh->do('ALTER TABLE orders rename employeeindex to salesrep_id');
			} else {
				$dbh->do('ALTER TABLE ORders ADD salesrep_id INTEGER');
				$dbh->do('ALTER TABLE ORders ADD FOREIGN KEY (salesrep_id) REFERENCES Users (id)');
			}
	}
	foreach my $k ( 'address1', 'address2', 'firstname','lastname', 'city','state','country', 'postalcode', 'phone', 'fax', 'email','alsonotify', 'salutation' ) {
		if ( ! exists $$data{$k} ) {
			if ( exists $$data{'str'.$k} ) {
				$dbh->do("ALTER TABLE orders rename str$k to $k");
			} else {
				$dbh->do("ALTER TABLE ORders ADD $k TEXT");
			}
		}
	} # end foreach
	if ( 0 and ! exists $$data{invoice_id} ) {
#Deprecated
		$dbh->do('ALTER TABLE orders ADD invoice_id INTEGER');
		$dbh->do('ALTER TABLE orders ADD FOREIGN KEY (invoice_id) REFERENCES Invoices (id)');
		if ( exists $$data{oinvoice} ) {
			foreach my $invoice_id ( sql::execute( undef, undef, 'SELECT DISTINCT oinvoice FROM orders' ) ) {
					next if ! $invoice_id;
				my $Invoice = openprint::Invoice->find_one('num lc'=>lc openprint::Invoice->transform('num', $invoice_id ) );
				if ( ! $Invoice ) {
					$Invoice = new openprint::Invoice();
					$_ = $Invoice->save({num=>$invoice_id});
					die $_ if $_;
				} # end if
				sql::update( undef, undef, 'orders', [ 'oinvoice=?', $invoice_id ], 'invoice_id', $Invoice->id() );
			} # end foreach
			$dbh->do('ALTER TABLE Orders DROP oinvoice');
		} # end if
	} # end if
	if ( ! exists $$data{docket} ) {
		if ( exists $$data{lngdocketnumber} ) {
			$dbh->do('ALTER TABLE Orders rename lngdocketnumber to docket');
		} else {
			$dbh->do('ALTER TABLE ORders ADD Docket INTEGER');
		} # end if
	} # end if

	if ( exists $$data{preparedby} ) {
		foreach my $name ( sql::execute( undef, undef, 'SELECT DISTINCT preparedby FROM orders' ) ) {
			next if ! $name;
			my $User = openprint::User->find_one('firstname lc' => lc openprint::User->transform('firstname',$name) );
			if ( ! $User ) {
				$User = new openprint::User();
				$_ = $User->save({firstname=>$name});
				die $_ if $_;
			} # end if
		} # end foreach
		$dbh->do('ALTER TABLE orders DROP preparedby');
	} # end if
	if ( ! exists $$data{id} ) {
		$dbh->do('ALTER TABLE orders rename column index to id');
	} # end if
	$dbh->do('ALTER TABLE Orders ADD paid NUMERIC(10,2)') if ( ! exists $$data{paid} );
	$dbh->do('UPDATE Orders SET paid=(SELECT SUM(amount) FROM Payments WHERE order_id=orders.id)');
	$dbh->do('ALTER TABLE Orders ADD owing NUMERIC(10,2)') if ( ! exists $$data{owing} );
	$dbh->do('UPDATE orders SET owing=total-paid');
	if ( ! exists $$data{terms_accepted} ) {
		$dbh->do('ALTER TABLE ORDERS ADD terms_accepted boolean default false');
	} # end if
	if ( ! exists $$data{cod_percent} ) {
		$dbh->do('ALTER TABLE orders add cod_percent float');
	} # end if
	if ( ! exists $$data{downpayment_percent} ) {
		$dbh->do('ALTER TABLE orders add downpayment_percent float');
	} # end if
	if ( ! exists $$data{updated_on} ) {
		$dbh->do('ALTER TABLE orders ADD updated_on TIMESTAMP WITH TIME ZONE');
		$dbh->do('UPDATE orders SET updated_on=created_on');
		$dbh->do('ALTER TABLE orders ALTER updated_on SET default NOW()');
		$dbh->do('ALTER TABLE orders ALTER updated_on SET NOT NULL');
	} # end if

if ( ! sets::isin( 'order_notifications', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Order_Notifications.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
}
if ( ! sets::isin( 'order_log', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Order_Log.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
}

if ( sets::isin( 'projecttype_categories', \@tables ) ) {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM projecttype_categories LIMIT 1', {} );
	if ( $data and ! exists $$data{sort} ) {
		$dbh->do('ALTER TABLE projecttype_categories ADD sort integer');
	} # end if
} else {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/ProjectType_Categories.sql}) );
} # end if
if ( sets::isin( 'project_types', \@tables ) ) {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='project_types'", 'column_name');
	if ( exists $$data{lngindex} ) {
		$dbh->do('ALTER TABLE Project_Types rename column lngindex to id');
		$dbh->do('ALTER TABLE Project_Types rename column strid to name');
		$dbh->do('ALTER TABLE Project_Types rename column strname to description');
		$dbh->do('ALTER TABLE Project_Types rename column strdetailedurl to url');
		$dbh->do('ALTER TABLE Project_Types rename column lngsort to sorting');
		$dbh->do('CREATE SEQUENCE Project_Types_id_seq');
		$dbh->do(q`SELECT setval('project_types_id_seq', (SELECT MAX(id) FROM PRoject_Types))` );
		$dbh->do(q`DROP SEQUENCE IF EXISTS ProjectTypeIndex` );
	} # end if
	if ( exists $$data{strbasicurl} ) {
		$dbh->do('ALTER TABLE Project_Types drop strbasicurl');
	}
	if ( exists $$data{strtemplateurl} ) {
		$dbh->do('ALTER TABLE Project_Types drop strtemplateurl');
	}
} else {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Project_Types.sql}) );
} # end if
if ( sets::isin( 'projecttype_categories', \@tables ) ) {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM projecttype_categories LIMIT 1', {} );
	if ( $data and ! exists $$data{sort} ) {
		$dbh->do('ALTER TABLE projecttype_categories ADD sort integer');
	} # end if
} else {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/ProjectType_Categories.sql}) );
} # end if
if ( ! sets::isin( 'project_statuses', \@tables ) ) {
	$log->debug("Adding Project_Statuses");
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Project_Statuses.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} # end if

if ( sets::isin( 'tbl_projects', \@tables ) ) {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='tbl_projects'", 'column_name');
	if ( $data ) {
		$dbh->do(q`ALTER TABLE tbl_Projects rename to Projects`);
	} # end if
	@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
} # end if
if ( ! sets::isin( 'projects', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Projects.sql}) ) or die;
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='projects'", 'column_name');
	if ( ! exists $$data{style_id} ) {
		my $ac = sql::start_transaction( $dbh );
		$dbh->do('ALTER TABLE Projects ADD style_id INTEGER');
		$dbh->do('ALTER TABLE Projects ADD FOREIGN KEY (style_id) REFERENCES QuoteLevels (id)');
		sql::end_transaction( $dbh, $ac );
	} # end if
	if ( ! exists $$data{rush} ) {
		print "Adding rush to projects";
		$dbh->do(q`alter table Projects add rush boolean default false`);
	} # end if
	if ( ! exists $$data{predefined} ) {
		my $ac = sql::start_transaction( $dbh );
		print "Adding predefined to Projects\n";
		$dbh->do(q`alter table Projects add predefined boolean`);
		$dbh->do(q`alter table Projects alter predefined set default false`);
		$dbh->do(q`update Projects set predefined=false`);
		$dbh->do(q`ALTER TABLE Projects ALTER predefined set not null`);
		sql::end_transaction( $dbh, $ac );
	} # end if
	if ( ! exists $$data{externalrefnumber} ) {
		$dbh->do('ALTER TABLE projects add externalrefnumber text');
	}
	if ( ! exists $$data{markup} ) {
		$dbh->do('ALTER TABLE projects add markup float');
	}
	if ( ! exists $$data{production_comments} ) {
		$dbh->do('ALTER TABLE projects add production_comments TEXT');
	}
	if ( exists $$data{index} ) {
		$dbh->do('ALTER TABLE Projects rename column index to id');
		$dbh->do('ALTER TABLE Projects rename column companyindex to company_id');
		$dbh->do('ALTER TABLE Projects rename column userindex to user_id');
	} # end if
	if ( ! exists $$data{summary} ) {
		$dbh->do(q`alter table Projects add summary text`) or $log->error($dbh->errstr());
	} # end if
	if ( ! exists $$data{priority} ) {
		$dbh->do(q`ALTER TABLE projects ADD priority INTEGER`) or $log->error($dbh->errstr());
	} # end if
	if ( ! exists $$data{production_comments} ) {
		$dbh->do(q`ALTER TABLE projects ADD production_comments TEXT`) or $log->error($dbh->errstr());
	} # end if
	if ( ! exists $$data{calculated_on} ) {
		$dbh->do(q`ALTER TABLE projects ADD calculated_on TIMESTAMP WITH TIME ZONE`) or $log->error($dbh->errstr());
	} # end if
	if ( ! exists $$data{reprint} ) {
		$dbh->do(q`ALTER TABLE projects ADD reprint BOOLEAN NOT NULL default false`) or $log->error($dbh->errstr());
	} # end if
	if ( ! exists $$data{reprint_reason} ) {
		$dbh->do(q`ALTER TABLE projects ADD reprint_reason TEXT`) or $log->error($dbh->errstr());
	} # end if
} # end if
if ( ! sets::isin( 'servicetype_categories', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/ServiceType_Categories.sql}) );
}

if ( sets::isin( 'tbl_service_types', \@tables ) ) {
	$dbh->do(q{alter table tbl_Service_Types rename column strid to name});
	$dbh->do(q{alter table tbl_Service_Types rename column strname to description});
	$dbh->do(q{alter table tbl_service_types drop column strbasicurl});
	$dbh->do(q{alter table tbl_service_types drop column strtemplateurl});
	$dbh->do(q{alter table tbl_service_types drop column stremployeeurl});
	$dbh->do(q{alter table tbl_Service_types add create_visible boolean});
	$dbh->do(q{update tbl_Service_types set create_visible=true where ysncreatevisible='Y'});
	$dbh->do(q{update tbl_Service_types set create_visible=true where ysncreatevisible='Y'});
	$dbh->do(q{alter table tbl_Service_Types add view_visible boolean});
	$dbh->do(q{update tbl_Service_types set view_visible=true where ysnviewvisible='Y'});
	$dbh->do(q{alter table tbl_Service_Types rename column lngsort to sorting});
	$dbh->do(q{alter table tbl_service_types drop ysncreatevisible});
	$dbh->do(q{alter table tbl_service_types drop ysnviewvisible});
	$dbh->do(q{alter table tbl_service_types rename column lngindex to id});
	$dbh->do(q{alter table tbl_Service_Types rename to Service_Types});
	$dbh->do(q{alter table service_types rename column strcategory to category});
	$dbh->do(q`ALTER TABLE service_types ADD type TEXT`);
	$dbh->do(q`UPDATE service_types SET type=name WHERE type IS NULL`);
	@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
} elsif ( ! sets::isin( 'service_types', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Service_Types.sql}) );
	@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
} # end if

if ( ! sets::isin('service_types_id_seq', \@sequences) ) {
	$dbh->do(q{CREATE SEQUENCE service_types_id_seq});
	$dbh->do(q{select setval('service_types_id_seq', (SELECT Max(id) FROM service_types) )});
} # end if
$dbh->do(q{ALTER TABLE service_types alter id set default nextval('service_types_id_seq')});


if ( ! sets::isin( 'service_types', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Service_Types.sql}) ) or die;
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='service_types'", 'column_name');
	if ( ! exists $$data{deleted} ) {
		$dbh->do('ALTER TABLE service_types ADD deleted BOOLEAN NOT NULL DEFAULT FALSE');
	}
	if ( ! exists $$data{type} ) {
		$dbh->do(q`ALTER TABLE service_types ADD type TEXT`);
	} # end if
	$dbh->do(q`UPDATE service_types SET type=name WHERE type IS NULL`);
	if ( exists $$data{category} ) {
		if ( ! exists $$data{category_id} ) {
			$dbh->do(q`ALTER TABLE service_types add category_id INTEGER`);
			foreach my $c ( sql::execute( undef, undef, 'SELECT DISTINCT category FROM Service_types' ) ) {
				sql::insert( undef, undef, 'servicetype_categories', 'name', $c );
			} # end foreach
			$dbh->do('UPDATE service_types set category_id=(select id from servicetype_categories where name=category)');
		} # end if
		$dbh->do('ALTER TABLE service_types DROP COLUMN category');
	}# end if
	if ( ! exists $$data{summary_visible} ) {
		$dbh->do('ALTER TABLE service_types add summary_visible BOOLEAN NOT NULL default true');
	} # end if
	if ( ! exists $$data{allow_delete} ) {
		$dbh->do('ALTER TABLE service_types add allow_delete BOOLEAN NOT NULL default true');
	} # end if
}# end if
if ( ! sets::isin( 'service_categories_id_seq', \@sequences ) ) {
	$dbh->do('create sequence service_categories_id_seq;');
	$dbh->do(q`alter table service_categories alter id set default nextval('service_categories_id_seq')`);
	$dbh->do(q`select setval('service_categories_id_seq', (select max(id) from service_categories) )`);
	$dbh->do(q`drop sequence servicecategoriesindex_seq`) if sets::isin( 'servicecategoriesindex_seq', \@sequences );
} # en dif

if ( ! sets::isin( 'projecttype_requiredservices', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/ProjectType_RequiredServices.sql}) );
} # end if

if ( ! sets::isin( 'tbl_project_contents', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/tbl_Project_Contents.sql' ) ) or die;
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='tbl_project_contents'", 'column_name');
	if ( ! exists $$data{servicetype_id} ) {
		$log->debug("Adding servicetype_id to tbl_project_contents");
		$dbh->do('ALTER TABLE tbl_project_contents add servicetype_id INTEGER NOT NULL');
	} 
	if ( ! exists $$data{operator_id} ) {
		$log->debug("Adding operator_id to tbl_project_contents");
		$dbh->do('ALTER TABLE tbl_project_contents add operator_id INTEGER');
		$dbh->do('ALTER TABLE tbl_project_contents add FOREIGN KEY (operator_id) REFERENCES Users (id)');
	} 
}
if ( ! sets::isin( 'tbl_service_specifications', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/tbl_Service_Specifications.sql' ) ) or die;
}
if ( ! sets::isin( 'project_log', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Project_Log.sql' ) ) or die;
}
if ( ! sets::isin( 'barcode_log', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Barcode_Log.sql' ) ) or die;
}
#if ( ! sets::isin( 'bindery_schedule', \@tables ) ) {
	#$dbh->do( misc::load_file( $log, '../openprint/sql/Bindery_Schedule.sql' ) ) or die;
#}
if ( ! sets::isin( 'uploads', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Uploads.sql' ) ) or die;
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='uploads'", 'column_name');
	if ( ! exists $$data{type} ) {
		$dbh->do(q`ALTER TABLE uploads add type text`);
	} # end if
	if ( ! exists $$data{complete} ) {
		$log->debug("Add complete BOOLEAN to uploads");
		$dbh->do(q`ALTER TABLE uploads add complete BOOLEAN`);
	} # end if
}
if ( ! sets::isin( 'pressactivities', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/PressActivities.sql' ) ) or die;
}
if ( ! sets::isin( 'project_files', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Project_Files.sql' ) ) or die;
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='project_files'", 'column_name');
	if ( ! $$data{archive} ){ 
		$dbh->do('ALTER TABLE project_files ADD archive TEXT');
	} # end if
	if ( ! $$data{size} ){ 
		$dbh->do('ALTER TABLE project_files ADD size INTEGER');
	} # end if
	if ( ! $$data{deleted} ){ 
		$dbh->do('ALTER TABLE project_files ADD deleted BOOLEAN NOT NULL DEFAULT FALSE');
	} # end if
	if ( ! exists $$data{company_id} ) {
		$dbh->do('ALTER TABLE project_files ADD company_id INTEGER');
		$dbh->do('ALTER TABLE project_files ADD FOREIGN KEY (company_id) REFERENCES Companies (id)');
	} # end if
	$dbh->do('ALTER TABLE project_files ALTER project_id DROP NOT NULL');
	$dbh->do('ALTER TABLE project_files ALTER description DROP NOT NULL');
	
}


if ( ! sets::isin( 'manufacturers', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Manufacturers.sql' ) ) or die $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='manufacturers'", 'column_name');
} 

if ( ! sets::isin( 'todos', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Todos.sql' ) ) or die $dbh->errstr();
}
if ( ! sets::isin( 'bug_statuses', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Bug_Statuses.sql' ) ) or die;
}
if ( ! sets::isin( 'bugs', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Bugs.sql' ) ) or die;
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='bugs'", 'column_name');
	if ( ! exists $$data{deleted} ) {
		$dbh->do('ALTER TABLE bugs add deleted BOOLEAN NOT NULL default False');
	} # end if
}
if ( ! sets::isin( 'bug_comments', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Bug_Comments.sql' ) ) or die;
}

if ( ! sets::isin( 'location_types', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Location_Types.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
}
if ( ! sets::isin( 'locations', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Locations.sql}) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='locations'", 'column_name');
	if ( ! exists $$data{type_id} ) {
	$dbh->do('ALTER TABLE Locations add type_id INTEGER');
	$dbh->do('ALTER TABLE Locations add FOREIGN KEY(type_id) REFERENCES Location_types (id)');
	} # end if
	if ( ! exists $$data{short} ) {
	$dbh->do('ALTER TABLE Locations add short text');
	} # end if
	if ( ! exists $$data{description} ) {
	$dbh->do('ALTER TABLE Locations add description text');
	} # end if
	if ( ! exists $$data{parent_id} ) {
	$dbh->do('ALTER TABLE Locations add parent_id integer');
	$dbh->do('ALTER TABLE Locations add FOREIGN KEY(parent_id) REFERENCES Locations (id)');
	} # end if
	if ( ! exists $$data{created_on} ) {
	$dbh->do('ALTER TABLE Locations add created_on TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()');
	} # end if
	if ( ! exists $$data{updated_on} ) {
	$dbh->do('ALTER TABLE Locations add updated_on TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()');
	} # end if
	if ( ! exists $$data{created_by} ) {
	$dbh->do('ALTER TABLE Locations add created_by INTEGER');
	$dbh->do('ALTER TABLE Locations add FOREIGN KEY (created_by) REFERENCES Users (id)');
	} # end if
	if ( ! exists $$data{postalcode} ) {
	$dbh->do('ALTER TABLE Locations add postalcode text');
	} # end if
	if ( ! exists $$data{address} ) {
	$dbh->do('ALTER TABLE Locations add address text');
	} # end if
	if ( ! exists $$data{url} ) {
	$dbh->do('ALTER TABLE Locations add url text');
	} # end if
	if ( ! exists $$data{latitude} ) {
	$dbh->do('ALTER TABLE Locations add latitude float');
	} # end if
	if ( ! exists $$data{longitude} ) {
	$dbh->do('ALTER TABLE Locations add longitude float');
	} # end if
	if ( ! exists $$data{asset_id} ) {
		$dbh->do('ALTER TABLE Locations add asset_id INTEGER');
		$dbh->do('ALTER TABLE Locations ADD FOREIGN KEY (asset_id) REFERENCES Assets (id)');
	} # end if
	if ( ! exists $$data{album_id} ) {
		$dbh->do('ALTER TABLE Locations add album_id INTEGER');
		$dbh->do('ALTER TABLE Locations ADD FOREIGN KEY (album_id) REFERENCES Photo_Albums (id)');
		die $dbh->errstr() if $dbh->errstr();
	} # end if
	$dbh->do('ALTER TABLE Locations DROP CONSTRAINT IF EXISTS locations_name_key');
	if ( ! sql::execute( undef, undef, q`SELECT * from pg_indexes WHERE indexname=?`, 'locations_name_idx' ) ) {
		$dbh->do('CREATE INDEX locations_name_idx on locations (name)');
	} # end if
	if ( ! exists $$data{deleted} ) {
	$dbh->do('ALTER TABLE Locations add deleted BOOLEAN NOT NULL DEFAULT false');
	} # end if
	if ( sets::isin( 'location_id_seq', \@sequences ) ) {
		if ( ! sets::isin( 'locations_id_seq', \@sequences ) ) {
			$dbh->do('CREATE SEQUENCE locations_id_seq');
			$dbh->do(q`ALTER TABLE locations ALTER id set default nextval('locations_id_seq')`);
			$dbh->do(q`SELECT setval('locations_id_seq', (SELECT MAX(id) FROM Locations ) )`);
		} # end if
		$dbh->do('DROP SEQUENCE location_id_seq');
	} # end if
	if ( ! exists $$data{company_id} ) {
		$dbh->do('ALTER TABLE Locations add company_id INTEGER');
		$dbh->do('ALTER TABLE Locations ADD FOREIGN KEY (company_id) REFERENCES companies (id)');
		print "Added company_id to Locations\n";
		die $dbh->errstr() if $dbh->errstr();
	} # end if
} # end if
if ( ! sets::isin( 'addresses', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Addresses.sql}) );
	die $dbh->errstr() if $dbh->errstr();
}
if ( ! sets::isin( 'tbl_addresses', \@tables ) ) {
	print "Adding tbl_Addresses @tables\n";
	$dbh->do( misc::load_file( $log, q{../openprint/sql/tbl_Addresses.sql}) );
	die $dbh->errstr() if $dbh->errstr();
}
if ( ! sets::isin( 'equipment_categories', \@tables ) ) {
	load_sql( 'Equipment_Categories' );
} # end if
if ( sets::isin( 'tbl_equipment', \@tables ) ) {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='tbl_equipment'", 'column_name');
	if ( ! exists $$data{location_id} ) {
		$dbh->do('ALTER TABLE tbl_Equipment ADD location_id INTEGER');
		$dbh->do('ALTER TABLE tbl_Equipment ADD FOREIGN KEY (location_id) REFERENCES Locations (id)');
	} # end if
	if ( exists $$data{lngindex} ) {
		$dbh->do('ALTER TABLE tbl_Equipment RENAME COLUMN lngindex TO id');
	} # end if
	$dbh->do('ALTER TABLE tbl_Equipment ADD cip3_in TEXT') if ! exists $$data{cip3_in};
	$dbh->do('ALTER TABLE tbl_Equipment ADD cip3_out TEXT') if ! exists $$data{cip3_out};
	$dbh->do('ALTER TABLE tbl_Equipment ADD cip3_hold TEXT') if ! exists $$data{cip3_hold};
	$dbh->do('ALTER TABLE tbl_Equipment ADD cip3_merge TEXT') if ! exists $$data{cip3_merge};
	$dbh->do('ALTER TABLE tbl_Equipment ADD cip3_monitor TEXT') if ! exists $$data{cip3_monitor};
	$dbh->do('ALTER TABLE tbl_Equipment ADD smartscheduling BOOLEAN default false') if ! exists $$data{smartscheduling};
	if ( ! exists $$data{jdf_name} ) {
		$dbh->do(q`alter table tbl_equipment add jdf_name text`);
	} # end if
	if ( ! exists $$data{jdf_id} ) {
		$dbh->do(q`alter table tbl_equipment add jdf_id text`);
	} # end if
	$dbh->do(q`alter table tbl_equipment add message text`) if ! exists $$data{message};
	if ( ! exists $$data{category_id} ) {
		$dbh->do(q`ALTER TABLE tbl_equipment ADD category_id INTEGER[]`);
	} # end if
	if ( exists $$data{useinestimation} ) {
		$log->debug("Renaming useinestimation to useinestimating");
		$dbh->do('ALTER TABLE tbl_Equipment RENAME column useinestimation to useinestimating') or die $dbh->errstr();
	}
	
	if ( exists $$data{strcategory} ) {
		foreach my $category ( sql::execute( undef,undef, 'SELECT DISTINCT strcategory FROM tbl_equipment' ) ) {
			next if ! $category;
			next if sql::execute( undef, undef, 'SELECT name from equipment_categories where name=?', $category );
			sql::insert( undef, undef, 'equipment_categories', 'name', $category );
		} # end foreach category
		$dbh->do('UPDATE tbl_equipment set category_id=array_append( category_id, (SELECT id FROM equipment_categories where name=strcategory) )' ) or die $dbh->errstr();
		$dbh->do('ALTER TABLE tbl_equipment DROP strcategory');
	} # end if
	if ( ! exists $$data{deleted} ) {
		$dbh->do(q`ALTER TABLE tbl_equipment ADD deleted BOOLEAN NOT NULL DEFAULT false`);
	} # end if
} else {
    load_sql( 'Equipment' );
} # end if
if ( ! sets::isin( 'tbl_equipment_specifications', \@tables ) ) {
	my $sql = misc::load_file( $log, q{../openprint/sql/tbl_Equipment_Specifications.sql}) or die "Can't load tbl_Equipment_Specifications.sql";
	$dbh->do($sql);
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='tbl_equipment_specifications'", 'column_name' );
	if ( $data ) {
		if ( exists $$data{lngindex} ) {
			$dbh->do('ALTER TABLE tbl_Equipment_SPecifications rename column lngindex to id');
			$dbh->do('CREATE SEQUENCE tbl_equipment_specifications_id_seq');
			$dbh->do("ALTER TABLE tbl_Equipment_specifications alter column id set default nextval('tbl_equipment_specifications_id_seq')");
			$dbh->do('DROP SEQUENCE EquipmentSpecification_seq');
			$dbh->do("SELECT setval('tbl_equipment_specifications_id_seq', (SELECT MAX(id) FROM tbl_equipment_specifications) )");
		} # end if
		if ( ! exists $$data{interpolate} ) {
			$log->debug("Adding interpolate to tbl_equipment_specifications");
			$dbh->do('ALTER TABLE tbl_equipment_specifications ADD interpolate         BOOLEAN NOT NULL DEFAULT false');
		}
	} # end if
} # end if

if ( ! sets::isin( 'equipment_operators', \@tables ) ) {
	print "Adding Equipment Operators\n";
	$dbh->do( misc::load_file( $log, '../openprint/sql/Equipment_Operators.sql' ) ) or die $dbh->errstr();
	die $dbh->errstr() if $dbh->errstr();
} # end if
	
if ( ! sets::isin( 'stockbrands', \@tables ) ) {
	$dbh->do(misc::load_file( $log, '../openprint/sql/StockBrands.sql') );
	die $dbh->errstr() if $dbh->errstr();
}
if ( ! sets::isin( 'stockfinishes', \@tables ) ) {
	$dbh->do(misc::load_file( $log, '../openprint/sql/StockFinishes.sql') );
	die $dbh->errstr() if $dbh->errstr();
}
if ( ! sets::isin( 'stockcolours', \@tables ) ) {
	$dbh->do(misc::load_file( $log, '../openprint/sql/StockColours.sql') );
	die $dbh->errstr() if $dbh->errstr();
}
if ( ! sets::isin( 'stockweights', \@tables ) ) {
	$dbh->do(misc::load_file( $log, '../openprint/sql/StockWeights.sql') );
	die $dbh->errstr() if $dbh->errstr();
}
if ( ! sets::isin( 'stockqualities', \@tables ) ) {
	$dbh->do(misc::load_file( $log, '../openprint/sql/StockQualities.sql') );
	die $dbh->errstr() if $dbh->errstr();
}
if ( ! sets::isin( 'stockgroups', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/StockGroups.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} # end if

if ( ! sets::isin( 'papers', \@tables ) ) {
	$log->debug("Adding Papers");
	$dbh->do(misc::load_file( $log, '../openprint/sql/Papers.sql') );
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='papers'", 'column_name');
	if ( ! exists $$data{bladecleaning} ) {
		$dbh->do('alter table papers add bladecleaning boolean');
		sql::update( undef, undef, 'papers', 'bladecleaning IS NULL', 'bladecleaning', 'false' );
    } # end if
	if ( ! exists $$data{grain_direction} ) {
		$dbh->do('alter table papers add grain_direction text');
		sql::update( undef, undef, 'papers', 'width > height', 'grain_direction', 'Short' );
		sql::update( undef, undef, 'papers', 'width < height', 'grain_direction', 'Long' );
	} # end if
	if ( ! exists $$data{allocated} ) {
		$dbh->do('alter table papers add allocated integer');
	} # end if
	if ( ! exists $$data{available_to_order} ) {
		$dbh->do('alter table papers add available_to_order integer');
	} # end if
	if ( ! exists $$data{manufacturers_name} ) {
		$dbh->do('ALTER TABLE papers add manufacturers_name TEXT');
	} # end if
	$dbh->do('alter table papers add basis_width float') if ! exists $$data{basis_width};
	$dbh->do('alter table papers add basis_height float') if ! exists $$data{basis_height};
	$dbh->do('alter table papers add basis_mweight float') if ! exists $$data{basis_mweight};
	$dbh->do('alter table papers add grade integer') if ! exists $$data{grade};
	$dbh->do('alter table papers add die_score_required  BOOLEAN NOT NULL default false') if ! exists $$data{die_score_required};
	if ( ! exists $$data{user_type} ) {
		$dbh->do(q`ALTER TABLE papers add user_type char(1) NOT NULL default ''`);
	} # end nif
	if ( ! exists $$data{supplier_id} ) {
		print "Adding supplier_id to Papers\n";
		$dbh->do(q`ALTER TABLE papers add supplier_id INTEGER`);
		$dbh->do(q`ALTER TABLE papers add FOREIGN KEY (supplier_id) REFERENCES companies (id)`);
	} # end nif
	if ( ! exists $$data{supplied} ) {
		print "Adding supplied to Papers\n";
		$dbh->do(q`ALTER TABLE papers add supplied boolean`);
	} # end nif
	if ( ! exists $$data{digital} ) {
		print "Adding digital to Papers\n";
		$dbh->do(q`ALTER TABLE papers add digital boolean`);
	} # end nif
	if ( ! exists $$data{wpsi} ) {
		print "Adding wpsi to Papers\n";
		$dbh->do(q`ALTER TABLE papers add wpsi float`);
	} # end nif
	if ( ! exists $$data{type} ) {
		print "Adding type to Papers\n";
		$dbh->do(q`ALTER TABLE papers add type text`);
	} # end nif
	if ( ! exists $$data{created_on} ) {
		print "Adding created_on to Papers\n";
		$dbh->do(q`ALTER TABLE papers add created_on TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()`);
	} # end nif
	if ( ! exists $$data{department_id} ) {
		print "Adding department_id to Papers\n";
		$dbh->do(q`ALTER TABLE papers add department_id TEXT`);
	} # end nif
} # end if

if ( ! sets::isin( 'paper_recommendations', \@tables ) ) {
	$dbh->do(misc::load_file( $log, '../openprint/sql/Paper_Recommendations.sql') );
	die $dbh->errstr() if $dbh->errstr();
}

if ( sets::isin( 'tbl_material_categories', \@tables ) ) {
	$dbh->do('ALTER TABLE tbl_material_categories RENAME to material_categories');
	@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
} # end if
if ( ! sets::isin( 'material_categories', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Material_Categories.sql}) ) or die $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='material_categories'", 'column_name' );
	$dbh->do(q{alter table tbl_Material_Categories rename column lngindex to id}) if exists $$data{lngindex};
	$dbh->do(q{alter table tbl_Material_Categories rename column strid to name}) if exists $$data{strid};
	$dbh->do(q{alter table tbl_Material_Categories drop column strname}) if exists $$data{strname};
	$dbh->do(q{ALTER TABLE Materials ADD foreign key (category_id) REFERENCES Material_Categories (id)});
	$dbh->do(q{alter table material_categories alter column id drop default});
	if ( sets::isin('materialcategoriesindex_seq', \@sequences ) ) {
		$dbh->do('drop sequence materialcategoriesindex_seq') 
	} 
	if ( ! sets::isin('material_categories_id_seq', \@sequences ) ) {
		$dbh->do('create sequence material_categories_id_seq');
	}
	$dbh->do(q{select setval('material_categories_id_seq', (select max(id) from material_categories))});
	$dbh->do(q{alter table material_categories alter column id set default nextval('material_categories_id_seq')});
}
if ( ! sets::isin( 'materials', \@tables ) ) {
	if ( sets::isin( 'tbl_materials', \@tables ) ) {
		my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Materials LIMIT 1', {} );
		my $ac = sql::start_transaction( $dbh );
		if ( $data ) {
			$dbh->do(q{alter table tbl_Materials rename column lngindex to id}) if ! exists $$data{id};
			$dbh->do(q{alter table tbl_Materials rename column strid to name}) if ! exists $$data{name};
			$dbh->do(q{alter table tbl_Materials rename column strname to description}) if ! exists $$data{description};
			$dbh->do(q{alter table tbl_Materials drop column strdetails}) if exists $$data{strdetails};
			$dbh->do(q{alter table tbl_Materials drop column strdescription}) if exists $$data{strdescription};
			$dbh->do(q{alter table tbl_Materials rename column lngsupplierindex to supplier_id}) if ! exists $$data{supplied_id};
			$dbh->do(q{alter table tbl_Materials rename column lngcategoryindex to category_id}) if ! exists $$data{category_id};

			$dbh->do(q{alter table tbl_Materials rename column ysntaxexempt1 to taxexempt1}) if exists $$data{ysntaxexempt1};
			$dbh->do(q{alter table tbl_Materials rename column ysntaxexempt2 to taxexempt2}) if exists $$data{ysntaxexempt2};
			$dbh->do(q{alter table tbl_Materials rename to Materials});
		} # endif
	} else {
		$dbh->do(misc::load_file( $log, '../openprint/sql/Materials.sql') ) or die $dbh->errstr();
	} # end if
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='materials'", 'column_name' );
	if ( ! exists $$data{manufacturer_id} ) {
		$dbh->do('ALTER TABLE materials add manufacturer_id INTEGER');
		$dbh->do('ALTER TABLE materials add FOREIGN KEY (manufacturer_id) REFERENCES Manufacturers (id)');
	} 
	if ( ! exists $$data{activity_code} ) {
		$dbh->do('ALTER TABLE materials add activity_code text');
	} 
} # end if
if ( sets::isin( 'materialindex_seq', \@sequences ) and ! sets::isin( 'materials_id_seq', \@sequences ) ) {
	$dbh->do('alter sequence materialindex_seq rename to materials_id_seq');
	$dbh->do("ALTER TABLE Materials alter id set default nextval('materials_id_seq')");
}
if ( ! sets::isin( 'material_specifications', \@tables ) ) {
	$dbh->do(misc::load_file( $log, '../openprint/sql/Material_Specifications.sql') );
} else {

	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='material_specifications'", 'column_name');
	$dbh->do('alter table material_specifications add interpolate boolean') if ! exists $$data{interpolate};
	if ( ! exists $$data{equipment_id} ) {
		$dbh->do('ALTER TABLE material_specifications ADD equipment_id INTEGER');
		$dbh->do('ALTER TABLE material_specifications ADD FOREIGN KEY (equipment_id) REFERENCES tbl_Equipment (id)');
	} # end if
} # end if


if ( ! sets::isin( 'skids', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Skids.sql}) ) or die $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='skids'", 'column_name' );
	if ( $data ) {
		if ( ! exists $$data{type} ) {
			$dbh->do('alter table skids add type text');
			$dbh->do('alter table skids add deleted boolean not null default false');
		} # end if
		if ( ! exists $$data{updated_on} ) {
			$dbh->do(q{alter table skids add updated_on timestamp with time zone default NOW()});
			$dbh->do(q{update skids set updated_on=NOW()});
		} # endif
		if ( ! exists $$data{updated_by} ) {
			$dbh->do(q{alter table skids add updated_by INTEGER});
			$dbh->do(q{update skids set updated_by=created_by_id});
			$dbh->do(q{alter table skids alter updated_by SET NOT NULL});
			$dbh->do(q{alter table skids ADD FOREIGN KEY (updated_by) REFERENCES Users (id)});
		} # endif
		if ( ! exists $$data{deleted} ) {
			$dbh->do('alter table skids add deleted BOOLEAN NOT NULL default false');
		} # end if
		if ( ! exists $$data{manufacturers_id} ) {
			$dbh->do('alter table skids add manufacturers_id TEXT');
		} # end if
		if ( ! exists $$data{received_on} ) {
			$dbh->do(q{alter table skids add received_on date});
		} # endif
		if ( ! exists $$data{location_id} ) {
			$log->debug("Adding location_id to skids");
			$dbh->do(q{alter table skids add location_id INTEGER});
			$dbh->do(q{alter table skids ADD FOREIGN KEY (location_id) REFERENCES Locations (id)});
			die $dbh->errstr() if $dbh->errstr();
		} # endif
		if ( exists $$data{location} ) {
			$log->debug("Removing location from skids");
			$dbh->do('ALTER TABLE skids DROP location');
			die $dbh->errstr() if $dbh->errstr();
		} # endif
	} # end if
} # end if 1456

if ( ! sets::isin( 'paper_allocations', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Paper_Allocations.sql' ) ) or die;
} else {
	$data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='paper_allocations'", 'column_name');
	if ( ! exists $$data{docket} ) {
		$log->debug("Adding docket column to paper_allocations");
		$dbh->do('ALTER TABLE paper_allocations ADD docket INTEGER') or die $dbh->errstr();
		$dbh->do('CREATE INDEX paper_allocations_docket_idx on paper_allocations (docket)') or die $dbh->errstr();
	}
}

if ( ! sets::isin( 'tbl_service_defaults', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/tbl_Service_Defaults.sql}) ) or die;
}

if ( sets::isin( 'tbl_services', \@tables ) ) {
	$dbh->do(q{alter table tbl_Services rename column lngindex to id});
	$dbh->do(q{alter table tbl_Services rename column strid to name});
	$dbh->do(q{alter table tbl_Services rename column strname to description});
	$dbh->do(q{alter table tbl_Services drop column strdetails});
	$dbh->do(q{alter table tbl_Services drop column strdescription});
	$dbh->do(q{alter table tbl_Services rename column lngsupplierindex to supplier_id});
	$dbh->do(q{alter table tbl_Services rename column lngcategoryindex to category_id});
	$dbh->do(q{alter table tbl_Services rename column ysntaxexempt1 to taxexempt1});
	$dbh->do(q{alter table tbl_Services rename column ysntaxexempt2 to taxexempt2});
	$dbh->do(q{alter table tbl_Services rename to Services});
	@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
} # end if

if ( sets::isin( 'services', \@tables ) ) {
	if ( sets::isin( 'serviceindex_seq', \@sequences ) ) {
		$dbh->do('DROP SEQUENCE serviceindex_seq');
		$dbh->do('CREATE SEQUENCE services_id_seq');
		$dbh->do("ALTER TABLE Services alter column id set default nextval('services_id_seq')");
		$dbh->do("SELECT setval('services_id_seq', (SELECT MAX(id) FROM Services))");
	} # end if
	my $data = $dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='services'", 'column_name');
	if ( ! exists $$data{owner_id} ) {
		$dbh->do('ALTER TABLE Services add owner_id INTEGER');
		$dbh->do('ALTER TABLE Services add FOREIGN KEY(owner_id) REFERENCES companies (id)');
	} # end if
	if ( ! exists $$data{activity_code} ) {
		$dbh->do('ALTER TABLE Services ADD activity_code TEXT');
	} # end if
	if ( ! exists $$data{servicetype_id} ) {
		$log->debug("Adding servicetype_id to Services");
		$dbh->do('ALTER TABLE Services ADD servicetype_id  INTEGER');
		$dbh->do('ALTER TABLE Services ADD FOREIGN KEY (servicetype_id) REFERENCES service_types (id)');
	} # end if
} else {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Services.sql}) );
} # end if

if ( ! sets::isin( 'inks', \@tables ) ) {
	if ( sets::isin( 'tbl_ink_colours', \@tables ) ) {
		$dbh->do('alter table tbl_ink_colours rename to inks');
		$dbh->do('create sequence inks_id_seq');
		$dbh->do('alter table inks add id INTEGER');
		$dbh->do(q{alter table inks alter id set default nextval('inks_id_seq')});
		$dbh->do(q{DELETE FROM inks WHERE strpmsid like 'PMS%'});
		$dbh->do(q{DELETE FROM inks WHERE strpmsid like 'pms%'});
		$dbh->do(q{update inks set id=nextval('inks_id_seq')});
		$dbh->do(q{alter table inks alter id set NOT NULL});
		$dbh->do(q{alter table inks add service_id INTEGER});
		$dbh->do(q{alter table inks add material_id INTEGER});
		$dbh->do(q{update inks set service_id=(SELECT lngindex from tbl_Services where strid=strserviceid)});
		$dbh->do(q{update inks set material_id=(SELECT lngindex from tbl_Materials where strid=strmaterialid)});
		$dbh->do(q{alter table inks add washups integer});
		$dbh->do(q{alter table inks drop strserviceid});
		$dbh->do(q{alter table inks drop strmaterialid});
		$dbh->do(q{alter table inks rename column strpmsid to pmsid});
		$dbh->do(q{alter table inks add foreign key (material_id) REFERENCES tbl_Materials (lngIndex)});
		$dbh->do(q{alter table inks add foreign key (service_id) REFERENCES tbl_Services (lngIndex)});
		$dbh->do(q{alter table inks add PRIMARY key (id)});
		$dbh->do(q{update inks set washups=1});
		$dbh->do('ALTER TABLE inks add mix BOOLEAN NOT NULL default false') or die $dbh->errstr();
		$dbh->do(q{alter table inks rename column strcolourname to name});
		$dbh->do(q{alter table inks add grades INTEGER[]});
	} else {
		$dbh->do( misc::load_file( $log, q{../openprint/sql/Inks.sql}) );
	} # end if
} else {
	my $data = $dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='inks'", 'column_name');
	if ( ! $$data{mix} ) {
		$dbh->do('ALTER TABLE inks add mix BOOLEAN NOT NULL default false') or die $dbh->errstr();
	} # end if
	if ( ! $$data{grades} ) {
		$dbh->do(q{alter table inks add grades INTEGER[]});
	} # end if
	if ( ! $$data{name} ) {
		if ( $$data{strcolourname} ) {
			$dbh->do('ALTER TABLE inks rename column strcolourname to name');
		} else {
			$dbh->do('ALTER TABLE inks add name TEXT');
		} # end if
	} # end if
	if ( ! exists $$data{mix_service_id} ) {
		$dbh->do('ALTER TABLE Inks ADD mix_service_id INTEGER');
		$dbh->do(q{alter table inks add foreign key (mix_service_id) REFERENCES Services (id)});
	} # end if
} # end if

if ( sets::isin( 'tbl_service_categories', \@tables ) ) {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Service_Categories LIMIT 1', {} );
	if ( $data ) {
		my $ac = sql::start_transaction( $dbh );
		$dbh->do(q{alter table tbl_Service_Categories rename column lngindex to id});
		$dbh->do(q{alter table tbl_Service_Categories rename column strid to name});
		$dbh->do(q{alter table tbl_Service_Categories drop column strname});
		$dbh->do(q{alter table tbl_Service_Categories rename to Service_Categories});
		$dbh->do(q{update Services set category_id=NULL where category_id NOT IN (SELECT id FROM Service_Categories)});
		$dbh->do(q{ALTER TABLE Services ADD foreign key (category_id) REFERENCES Service_Categories (id)});
		sql::end_transaction( $dbh, $ac );
		@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
	} # end if
} # end if
if ( ! sets::isin( 'service_categories', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Service_Categories.sql}) );
} # end if

if ( 0 ) {
sql::insert(undef,undef,'configuration', [
    'name','UseCaptchaOnRegistration',
    'value','N',
    'type','yes/no',
    'description','Use a CAPTCHA on the registration to protect against automated bots.',
    'category','Captcha Settings'] ) if ! $config{UseCaptchaOnRegistration};
sql::insert(undef,undef,'configuration', [
    'name','RegistrationCaptchaLength',
    'value','3',
    'type','text',
    'description','Number of characters in the CAPTCHA on the registration page.',
    'category', 'Captcha Settings'] ) if ! $config{RegistrationCaptchaLength};
sql::insert(undef,undef,'configuration', [
    'name','UnitPriceFormat',
    'value','%.2f',
    'type','text',
    'description','Format String for unit prices.',
    'category', 'Miscellaneous Settings'] ) if ! $config{UnitPriceFormat};
sql::insert(undef,undef,'configuration', [
    'name','DefaultPricelist',
    'type','pricelist',
    'description','Default Pricelist.',
    'category', 'Miscellaneous Settings',
    'value',undef,
] ) if ! exists $config{DefaultPricelist};
sql::insert(undef,undef,'configuration', [
    'name','AcceptCreditApplications',
    'type','yes/no',
    'description','Whether to show links to a credit application page.',
    'category', 'Miscellaneous Settings',
    'value',undef,
] ) if ! exists $config{AcceptCreditApplications};

sql::insert(undef,undef,'configuration', [
    'name','PerfectBindCoverGutter',
    'value',0.125,
    'type','text',
    'description', 'The amount of space to add to each edge on the height of the cover.',
    'category', 'Perfect Binding Settings',
] ) if ! $config{PerfectBindCoverGutter};

sql::insert(undef,undef,'configuration', [
    'name','PerfectBindGlueSpace',
    'value',0.03125,
    'type','text',
    'description','The amount of space to add to the width of the cover to account for the glue.',
    'category', 'Perfect Binding Settings',
    ] ) if ! $config{PerfectBindGlueSpace};

if ( $config{public_URIs} ) {
	my @paths = split(',', $config{public_URIs} );
	for ( my $p=0; $p < @paths; $p +=1 ) {
		if ( $paths[$p] =~ /confirmation_login/ ) {
			$paths[$p] = '/index.html';
		#} elsif ( $paths[$p] =~ /login_confirmation/ ) {
			#$paths[$p] = '/index.html';
		} elsif ( $paths[$p] =~ /overview/ ) {
			$paths[$p] = '/index.html';
		} elsif ( $paths[$p] =~ /search/ ) {
			$paths[$p] = '/index.html';
		} elsif ( $paths[$p] =~ /main(\/account.*)/ ) {
			$paths[$p] = $1;
		} elsif ( $paths[$p] =~ /\.\*(\/account.*)/ ) {
			$paths[$p] = $1;
		}
	} # end foreach
	push @paths, '/main/project/_calc.json' if ! sets::isin( '/main/project/_calc.json', \@paths );
	sql::update( undef, undef, 'configuration', ['name=?', 'public_URIs'], 'value', join(',',sets::union(@paths)) );
} # end inf
} # end if 0
if ( $config{cookie_issue_URIs} ) {
sql::execute( undef, undef, 'delete from configuration where name=?', 'cookie_issue_URIs' );
} # end if


if ( ! sets::isin( 'stockpurposes', \@tables ) ) {
	$dbh->do(q{CREATE TABLE StockPurposes (
				id  SERIAL NOT NULL,
				name   TEXT NOT NULL,
				PRIMARY KEY (id)
				)});
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='skids'", 'column_name' );
	if ( ! exists $$data{purpose_id} ) {
		$dbh->do(q{alter table skid_contents add purpose_id integer});
		$dbh->do(q{alter table skid_contents add foreign key (purpose_id) references stockpurposes (id)});
		$dbh->do(q{insert into stockpurposes (name) values ('House Stock')});
		$dbh->do(q{insert into stockpurposes (name) values ('Job Stock')});
		$dbh->do(q{insert into stockpurposes (name) values ('Sample')});
	}
} # end if

if ( ! sets::isin( 'pricelists', \@tables ) ) {
	$dbh->do(misc::load_file( $dbh, '../openprint/sql/Pricelists.sql' ) );
	die if $dbh->errstr();
}

if ( sets::isin( 'tbl_service_prices', \@tables ) ) {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Service_Prices LIMIT 1', {} );
	if ( $data ) {
		my $ac = sql::start_transaction( $dbh );
		$dbh->do('ALTER TABLE tbl_Service_Prices RENAME TO Service_Prices');
		$dbh->do('ALTER TABLE Service_Prices RENAME COLUMN lnglistindex TO pricelist_id');
		$dbh->do('ALTER TABLE Service_Prices RENAME COLUMN lngserviceindex TO service_id');
		$dbh->do('ALTER TABLE Service_Prices RENAME COLUMN lngequipmentindex TO equipment_id');
		$dbh->do('ALTER TABLE Service_Prices RENAME COLUMN dblcost TO cost');
		$dbh->do('ALTER TABLE Service_Prices RENAME COLUMN dblmarkup TO markup');
		$dbh->do('ALTER TABLE Service_Prices RENAME COLUMN dblprice TO price');
		$dbh->do('ALTER TABLE Service_Prices RENAME COLUMN strunits TO units');
		$dbh->do('ALTER TABLE Service_Prices RENAME COLUMN ysndiscountable TO discountable');
		$dbh->do('ALTER TABLE Service_Prices RENAME COLUMN lngmin TO min');
		$dbh->do('ALTER TABLE Service_Prices RENAME COLUMN lngmax TO max');
		sql::end_transaction( $dbh, $ac );
		@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
	} # end if
} # end if
if ( ! sets::isin( 'service_prices',\@tables )  ) {
	$log->debug("Adding service prices");
	$dbh->do( misc::load_file( $log, '../openprint/sql/Service_Prices.sql' ) );
	die if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='service_prices'", 'column_name' );
	if ( ! exists $$data{owner_id} ) {
		$dbh->do('ALTER TABLE Service_Prices ADD owner_id INTEGER');
		$dbh->do('ALTER TABLE Service_Prices ADD FOREIGN KEY (owner_id) REFERENCES Companies(id)');
	} # end if
	if ( ! exists $$data{supplier_id} ) {
		$dbh->do('ALTER TABLE Service_Prices ADD supplier_id INTEGER');
		$dbh->do('ALTER TABLE Service_Prices ADD FOREIGN KEY (supplier_id) REFERENCES Companies(id)');
	} # end if
	#if ( ! exists $$data{interpolate} ) {
		#$dbh->do('ALTER TABLE Service_Prices ADD interpolate boolean default false');
	#} # end if
	if ( ! exists $$data{period_start} ) {
		$dbh->do('ALTER TABLE Service_Prices ADD period_start TIMESTAMP WITH TIME ZONE');
	} # end if
	if ( ! exists $$data{period_end} ) {
		$dbh->do('ALTER TABLE Service_Prices ADD period_end TIMESTAMP WITH TIME ZONE');
	} # end if
	if ( ! exists $$data{mode} ) {
		$log->debug("Adding mode to service_prices");
		$dbh->do('ALTER TABLE Service_Prices ADD mode text') or die $dbh->errstr();
		if ( ! exists $$data{interpolate} ) {
			$dbh->do("UPDATE Service_Prices set mode='Interpolated' WHERE interpolate iS true") or die $dbh->errstr();
		} # end if
	} # end if
	if ( ! exists $$data{id} ) {
		$log->debug("Adding id SERIAL to Service_prices");
		$dbh->do('ALTER TABLE Service_Prices ADD id SERIAL');
		die $dbh->errstr() if $dbh->errstr();
	} # end if
} # end if
@sequences = sql::execute( undef, undef, q`SELECT sequence_name FROM information_schema.sequences where sequence_schema='public'`);
if ( ! sets::isin( 'service_prices_id_seq',\@sequences ) ) {
	if ( sets::isin( 'serviceprices_id_seq',\@sequences ) ) {
		$dbh->do('ALTER sequence serviceprices_id_seq RENAME TO service_prices_id_seq');
	} else {
		$dbh->do('CREATE SEQUENCE service_prices_id_seq') or die $dbh->errstr();
		$dbh->do(q`SELECT setval('service_prices_id_seq', (SELECT max(id) FROM service_prices))`) or die $dbh->errstr();
	} # end if
} # end if
$dbh->do(q`ALTER TABLE service_prices alter id set default nextval('service_prices_id_seq')`) or die $dbh->errstr();

if ( sets::isin( 'pricelists', \@tables ) ) {
	my $data = $dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='pricelists'", 'column_name' );
	my $ac = sql::start_transaction( $dbh );
	$dbh->do('ALTER TABLE Pricelists RENAME COLUMN currencyindex TO currency_id') if $$data{currencyindex};
	if ( $$data{index} ) {
		$dbh->do('ALTER TABLE Pricelists RENAME COLUMN index TO id');
	} elsif ( ! exists $$data{id} ) {
		$dbh->do('ALTER TABLE Pricelists ADD id SERIAL');
	}
	$dbh->do('ALTER TABLE Pricelists ADD owner_id INTEGER') if ! exists $$data{owner_id};
	$dbh->do('ALTER TABLE Pricelists ADD deleted BOOLEAN NOT NULL default false') if ! exists $$data{deleted};
	$dbh->do('ALTER TABLE Pricelists ADD FOREIGN KEY (owner_id) REFERENCES Companies (id)');
	if ( sets::isin( 'price_lists_id_seq', \@sequences )   ) {
		$dbh->do('DROP SEQUENCE IF EXISTS price_lists_id_seq');
	} 
	if ( ! sets::isin( 'pricelists_id_seq', \@sequences ) ) {
		$dbh->do('CREATE SEQUENCE pricelists_id_seq');
		$dbh->do(q`SELECT setval('pricelists_id_seq', (SELECT MAX(id) FROM Pricelists))`);
		$dbh->do(q`ALTER TABLE pricelists alter id set default nextval('pricelists_id_seq')`);
	} # end if
	die $dbh->errstr() if $dbh->errstr();
	sql::end_transaction( $dbh, $ac );
} # end if

if ( $version < 1901 ) {
	print "Updating to version 1901\n";
	my $ac = sql::start_transaction( $dbh );
	my @Services = openprint::Service->find('name'=>'PressUnitMakeReady');
	push @Services, openprint::Service->find('name'=>'PressUnitMakeReadySheet Work');
	if ( @Services ) {
		my $Service = $Services[0];
		foreach my $Equipment ( openprint::Equipment->find('category any'=>'Printing') ) {
			foreach my $Price ( openprint::ServicePrice->find('equipment_id'=>$Equipment->id(), 'service_id'=>$Service->id() )) {
				if ( $$Price{units} eq 'Per Unit' ) {
					$$Price{cost} = $$Price{cost}/$$Price{min};
					$$Price{price} = $$Price{price}/$$Price{min};
					$Price->save();
				} # end if
			} # end foreach
		} # end foreach
	} # en dif
	sql::insert( undef, undef, 'database_info', 'version', 1901, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1901;
} # end if

if ( ! sets::isin( 'folds', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Folds.sql}) );
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='folds'", 'column_name' );
	if ( $data ) {
		$dbh->do('alter table folds add cutting boolean') if ! exists $$data{cutting};
		$dbh->do('alter table folds add printing_type text') if ! exists $$data{printing_type};
		$dbh->do(q`alter table folds add folds integer`) if ( ! exists $$data{folds} );
		$dbh->do(q`alter table folds add angles integer`) if ( ! exists $$data{angles} );
	} # end if
	if ( sets::isin( 'fold_id_seq', \@sequences ) ) {
		if ( ! sets::isin( 'folds_id_seq', \@sequences ) ) {
			$dbh->do('ALTER SEQUENCE fold_id_seq RENAME TO folds_id_seq');
			$dbh->do(q`ALTER TABLE folds ALTER id SET DEFAULT nextval('folds_id_seq')`);
		} else {
			$dbh->do('DROP SEQUENCE fold_id_seq');
		} # end if
	} # end if
	if ( ! exists $$data{comments} ) {
		$dbh->do('ALTER TABLE folds ADD comments TEXT');
	} # end if
	if ( ! exists $$data{min_imposition_rows} ) {
		$dbh->do('ALTER TABLE folds ADD min_imposition_rows INTEGER');
	} # end if
	if ( ! exists $$data{max_imposition_rows} ) {
		$dbh->do('ALTER TABLE folds ADD max_imposition_rows INTEGER');
	} # end if
	if ( ! exists $$data{min_imposition_columns} ) {
		$dbh->do('ALTER TABLE folds ADD min_imposition_columns INTEGER');
	} # end if
	if ( ! exists $$data{max_imposition_columns} ) {
		$dbh->do('ALTER TABLE folds ADD max_imposition_columns INTEGER');
	} # end if
} # end if
if ( ! sets::isin( 'fold_specifications', \@tables ) ) {
	if ( sets::isin( 'foldspecifications', \@tables ) ) {
		$dbh->do('ALTER TABLE foldspecifications RENAME TO fold_specifications');
	} else {
		$dbh->do( misc::load_file( $log, q{../openprint/sql/Fold_Specifications.sql}) );
	} # end if
} 

if ( ! sets::isin( 'fold_specifications_id_seq', \@sequences ) ) {
	if ( sets::isin( 'foldspecification_id_seq', \@sequences ) ) {
		$dbh->do('ALTER SEQUENCE foldspecification_id_seq RENAME TO fold_specifications_id_seq');
		$dbh->do(q`ALTER TABLE fold_specifications ALTER id SET DEFAULT nextval('fold_specifications_id_seq')`);
		$dbh->do('DROP SEQUENCE foldspecification_id_seq');
	} # end if
	if ( sets::isin( 'foldspecifications_id_seq', \@sequences ) ) {
		$dbh->do('ALTER SEQUENCE foldspecifications_id_seq RENAME TO fold_specifications_id_seq');
		$dbh->do(q`ALTER TABLE fold_specifications ALTER id SET DEFAULT nextval('fold_specifications_id_seq')`);
		$dbh->do('DROP SEQUENCE foldspecifications_id_seq');
	} # end if
} # end if

foreach my $E ( openprint::Equipment->find('Specifications'=>{'Cutting Capable'=>'Y','Stitching Capable'=>'Y'}) ) {
	foreach my $Spec ( $E->Specifications() ) {
		if ( $Spec->name() =~ /Cutting Capable/ ) {
			$Spec->value('When Stitching');
			$Spec->save();
		} # end if
	} # end foreach
}
foreach my $E ( openprint::Equipment->find('category any'=>'Printing') ) {
	foreach my $Spec ( $E->Specifications('name'=>'Envelope Ready') ) {
		$Spec->name('Envelope Capable');
		$Spec->save();
	} 
	foreach my $Spec ( $E->Specifications('name'=>'Default Bleed Size') ) {
		if ( $Spec->max() and ( $Spec->max() == 1 ) ) {
			$Spec->max('');
		} elsif ( $Spec->min() and ( $Spec->min() == 2)  ) {
			$Spec->name('Default Bleed SizeMultiPage');
			$Spec->min('');
		} # end if
		$_ = $Spec->save();
		die $_ if $_;
	} # end foreach
} # end foreach

if ( ! sets::isin( 'skid_verifications', \@tables ) ) {
	my $ac = sql::start_transaction( $dbh );
	$dbh->do('DROP TABLE IF EXISTS skid_verifications');
	$dbh->do('
			CREATE TABLE skid_verifications (
				id SERIAL NOT NULL,
				skid_id INTEGER NOT NULL, FOREIGN KEY (skid_id) REFERENCES skids (id),
				code    TEXT,
				created_on  TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
				PRIMARY KEY (id)
				);' );
	$dbh->do('CREATE INDEX skid_verifications_skid_id_idx ON skid_verifications (skid_id);');
	$dbh->do('CREATE INDEX skid_verifications_code_idx ON skid_verifications (code);');
	sql::end_transaction( $dbh, $ac );
} # end if

if ( ! sets::isin( 'purchaseorders', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/PurchaseOrders.sql}) );
} else {
	$dbh->do('ALTER TABLE PurchaseOrders alter currency_id DROP NOT NULL');
	$dbh->do('ALTER TABLE PurchaseOrders alter created_by DROP NOT NULL');
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='purchaseorders'", 'column_name');
		my $ac = sql::start_transaction( $dbh );
		if ( ! exists $$data{num} ) {
			$dbh->do('ALTER TABLE PurchaseOrders ADD num TEXT');
		} # end if
		if ( ! exists $$data{federaltax_charge} ) {
			$dbh->do('ALTER TABLE purchaseorders add federaltax_charge BOOLEAN');
		} # end if
		if ( ! exists $$data{statetax_charge} ) {
			$dbh->do('ALTER TABLE purchaseorders add statetax_charge BOOLEAN');
		} # end if
		if ( ! exists $$data{shipto_mobile} ) {
			$dbh->do('ALTER TABLE purchaseorders ADD shipto_mobile TEXT');
		} # end if
		if ( ! exists $$data{shipto_contact} ) {
			$dbh->do('ALTER TABLE purchaseorders ADD shipto_contact TEXT');
		} # end if
		if ( ! exists $$data{cancelled} ) {
			$dbh->do('ALTER TABLE purchaseorders add cancelled BOOLEAN');
			$dbh->do('ALTER TABLE purchaseorders alter cancelled set default false');
			$dbh->do('UPDATE purchaseorders set cancelled=false');
			$dbh->do('ALTER TABLE purchaseorders alter cancelled set not null');
		} # end if
		if ( ! exists $$data{authorized} ) {
			$dbh->do('ALTER TABLE purchaseorders add authorized BOOLEAN');
			$dbh->do('UPDATE purchaseorders set authorized=true WHERE authorized_on IS NOT NULL');
		} # end if
		if ( ! exists $$data{manifest_id} ) {
			$dbh->do('ALTER TABLE purchaseorders add manifest_id INTEGER');
			$dbh->do('ALTER TABLE purchaseorders add FOREIGN KEY (manifest_id) REFERENCES Manifests (id)');
		} # end if
		if ( ! exists $$data{contact_id} ) {
			$dbh->do('ALTER TABLE purchaseorders add contact_id INTEGER');
			$dbh->do('ALTER TABLE purchaseorders add FOREIGN KEY (contact_id) REFERENCES Users (id)');
		} # end if
		if ( ! exists $$data{company_id} ) {
			$dbh->do('ALTER TABLE purchaseorders add company_id INTEGER');
			$dbh->do('ALTER TABLE purchaseorders add FOREIGN KEY (company_id) REFERENCES companies (id)');
		} # end if
		$dbh->do('ALTER TABLE PurchaseOrders ALTER delivered_on DROP NOT NULL');
		sql::end_transaction( $dbh, $ac );
} # end if
if ( ! sets::isin( 'manifests', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Manifests.sql}) );
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='manifests'", 'column_name');
	if ( $data ) {
		my $ac = sql::start_transaction( $dbh );
		if ( ! exists $$data{po_id} ) {
			$dbh->do('ALTER TABLE Manifests add po_id INTEGER');
			$dbh->do('ALTER TABLE Manifests add FOREIGN KEY (po_id) REFERENCES PurchaseOrders (id)');
		} # end if
		if ( ! exists $$data{supplier_id} ) {
			$dbh->do('ALTER TABLE Manifests add supplier_id INTEGER');
			$dbh->do('ALTER TABLE Manifests add FOREIGN KEY (supplier_id) REFERENCES Companies (id)');
		} # end if
		if ( ! exists $$data{docket} ) {
			$dbh->do('ALTER TABLE Manifests add docket INTEGER');
		} # end if
		if ( ! exists $$data{delivered_on_switch} ) {
			$dbh->do('ALTER TABLE Manifests add delivered_on_switch TEXT');
		} # end if
		if ( ! exists $$data{vendor_sms} ) {
			$dbh->do('ALTER TABLE Manifests add vendor_sms TEXT');
		} # end if
		if ( ! exists $$data{shipto_sms} ) {
			$dbh->do('ALTER TABLE Manifests add shipto_sms TEXT');
		} # end if
		if ( ! exists $$data{name} ) {
			$dbh->do('ALTER TABLE Manifests RENAME COLUMN id TO name');
			$dbh->do('ALTER TABLE Manifests ADD id SERIAL');
			$dbh->do('ALTER TABLE Manifest_Content_Types add m_id INTEGER');
			$dbh->do('UPDATE manifest_content_types set m_id=(SELECT id from manifests where name=manifest_id)');
			$dbh->do('ALTER TABLE manifest_content_types drop manifest_id');
			$dbh->do('ALTER TABLE manifest_content_types rename column m_id to manifest_id');

			$dbh->do('ALTER TABLE ManifestContents add m_id INTEGER');
			$dbh->do('UPDATE manifestcontents set m_id=(SELECT id from manifests where name=manifest_id)');
			$dbh->do('ALTER TABLE manifestcontents drop manifest_id');
			$dbh->do('ALTER TABLE manifestcontents rename column m_id to manifest_id');

			$dbh->do('ALTER TABLE manifests DROP CONSTRAINT "manifests_pkey"');
			$dbh->do('ALTER TABLE manifests ADD PRIMARY KEY (id)');

			$dbh->do('ALTER TABLE manifest_content_types add foreign key (manifest_id) REFERENCES Manifests (id)');
			$dbh->do('ALTER TABLE manifestcontents add foreign key (manifest_id) REFERENCES Manifests (id)');
			$dbh->do('CREATE INDEX Manifests_name_idx ON Manifests (name)');
		} # end if
		if ( ! exists $$data{deleted} ) {
			$dbh->do('ALTER TABLE Manifests add deleted BOOLEAN NOT NULL default false');
		} # end if
		sql::end_transaction( $dbh, $ac );
		die "Blah" if $dbh->errstr();
	} # end if
} # end if

if ( ! sets::isin( 'purchaseorder_contenttypes', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/PurchaseOrder_ContentTypes.sql}) ) or die $dbh->errstr();
}
if ( ! sets::isin( 'purchaseorder_items', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/PurchaseOrder_Items.sql}) ) or die $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='purchaseorder_items'", 'column_name');
	if ( ! $$data{created_on} ) {
		$dbh->do('ALTER TABLE purchaseorder_items ADD created_on TIMESTAMP WITH TIME ZONE');
	} # end if
	if ( ! $$data{updated_on} ) {
		$dbh->do('ALTER TABLE purchaseorder_items ADD updated_on TIMESTAMP WITH TIME ZONE');
	} # end if
} # en dif
if ( ! sets::isin( 'purchaseorder_contents', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/PurchaseOrder_Contents.sql}) ) or die $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='purchaseorder_contents'", 'column_name');
	if ( ! exists $$data{object_type_id} ) {
		$dbh->do('ALTER TABLE purchaseorder_contents ADD object_type_id INTEGER');
		$dbh->do('ALTER TABLE purchaseorder_contents ADD FOREIGN KEY (object_type_id) REFERENCES Object_Types (id)');
		$dbh->do('ALTER TABLE purchaseorder_contents ADD object_id INTEGER');
	}
} # en dif
if ( ! sets::isin( 'purchaseorder_items_to_inventory_items', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/PurchaseOrder_Items_to_Inventory_Items.sql}) ) or die $dbh->errstr();
}

if ( ! sets::isin( 'user_purchaseorder_limits', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/User_PurchaseOrder_Limits.sql}) ) or die $dbh->errstr();
	die 'user_purchaseorder_limits' if $dbh->errstr();
} # end if

if ( ! sets::isin( 'manifest_content_types', \@tables ) ) {
	load_sql( 'Manifest_Content_Types' );
}
if ( ! sets::isin( 'manifestcontents', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/ManifestContents.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='manifestcontents'", 'column_name');
	if ( ! exists $$data{location_id} ) {
		$dbh->do('ALTER TABLE manifestcontents ADD location_id INTEGER');
		$dbh->do('ALTER TABLE manifestcontents ADD FOREIGN KEY (location_id) REFERENCES Locations (id)');
	} # end if
}

foreach my $Type ( openprint::ServiceType->find('name'=>'BulkSkids', type=>undef ) ) {
    $Type->type( 'Skids' );
    $Type->save();
}
foreach my $Type ( openprint::ServiceType->find('name'=>'PlainCartons', type=>undef ) ) {
    $Type->type( 'Skids' );
    $Type->save();
}
foreach my $Type ( openprint::ServiceType->find('name'=>'Bundling', type=>undef ) ) {
    $Type->type( 'Packaging' );
    $Type->save();
}
foreach my $Type ( openprint::ServiceType->find('name'=>'ShrinkWrap', type=>undef ) ) {
    $Type->type( 'Packaging' );
    $Type->save();
}
foreach my $Type ( openprint::ServiceType->find('name'=>'KraftWrap', type=>undef ) ) {
    $Type->type( 'Packaging' );
    $Type->save();
}
foreach my $Type ( openprint::ServiceType->find('name'=>'ColourCorrection', type=>undef ) ) {
    $Type->type( 'Prepress' );
    $Type->save();
}
foreach my $Type ( openprint::ServiceType->find('name'=>'CDBurning', type=>undef ) ) {
    $Type->type( 'Prepress' );
    $Type->save();
}

if ( ! sets::isin( 'stockgroups', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/StockGroups.sql}) );
} # end if

if ( ! sets::isin( 'papers', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Papers.sql}) ) or die $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='papers'", 'column_name');
	if ( ! exists $$data{material_id} ) {
		my $ac = sql::start_transaction( $dbh );
		print "Adding material_id to Papers";
		$dbh->do(q`alter table Papers add material_id INTEGER`);
		$dbh->do( misc::load_file( $log, q{../openprint/sql/StockMaterials.sql}) );
		$dbh->do(q`insert into stockmaterials (name) values ('Paper')`);
		$dbh->do(q`alter table Papers add foreign key (material_id) REFERENCES Stockmaterials (id)`);
		$dbh->do(q`update Papers set material_id=1`);
		sql::end_transaction( $dbh, $ac );
	} # end if
	$dbh->do(q{alter table papers add minimum_order integer}) if ! exists $$data{minimum_order};
	$dbh->do(q{alter table papers add inventory_number	text}) if ! exists $$data{inventory_number};
	$dbh->do(q{alter table papers add full_packages boolean}) if ! exists $$data{full_packages};
	if ( exists $$data{req_die_scoring} ) {
		$dbh->do(q{alter table papers rename column req_die_scoring to diescoring});
	} else {
		$dbh->do(q{alter table papers add diescoring boolean}) if ! exists $$data{diescoring};
	}
	if ( ! exists $$data{group_id} ) {
		$dbh->do(q`ALTER TABLE papers ADD group_id INTEGER`);
		$dbh->do(q`ALTER TABLE papers ADD FOREIGN KEY (group_id) REFERENCES StockGroups (id)`);
	} # end if
	if ( ! exists $$data{message} ) {
		$dbh->do(q`alter table papers add message text`);
	} # end if
	if ( ! exists $$data{in_stock} ) {
		$dbh->do(q`alter table papers add in_stock integer`);
	} # end if
	if ( ! exists $$data{parts} ) {
		$dbh->do(q`alter table papers add parts integer`);
	} # end if
	if ( ! exists $$data{sheets_per_package} ) {
		$dbh->do(q`alter table papers add sheets_per_package integer`);
	} # end if
} # end if

if ( ! sets::isin( 'rfidtags', \@tables ) ) {
	$dbh->do(misc::load_file( $log, q{../openprint/sql/RFID.sql}) );
} # end if

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM skids LIMIT 1', {} );
if ( $data and ! exists $$data{rfidtag_id} ) {
	$dbh->do(q`alter table skids add rfidtag_id TEXT`);
	$dbh->do(q`alter table skids add FOREIGN KEY (rfidtag_id) REFERENCES RFIDTags (id)`);
} # end if

if ( ! sets::isin( 'user_service_defaults', \@tables ) ) {
		$dbh->do( misc::load_file( $log, q{../openprint/sql/User_Service_Defaults.sql}) );
} # end if


if ( ! sets::isin( 'product_categories', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Product_Categories.sql}) );
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='product_categories'", 'column_name');
	$dbh->do('ALTER TABLE Product_Categories ADD deleted boolean') if ! exists $$data{deleted};
	if ( ! exists $$data{parent_id} ) {
		$log->debug("Adding parent_id t product_categories");
		$dbh->do('ALTER TABLE Product_Categories ADD parent_id INTEGER') or die $dbh->errstr();
		$dbh->do('ALTER TABLE Product_Categories ADD FOREIGN KEY (parent_id) REFERENCES Product_Categories (id)') or die $dbh->errstr();
	}
} # end if

if ( ! sets::isin( 'products', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Products.sql}) );
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='products'", 'column_name');
	if ( ! $data ) { die $openprint::dbh->errstr(); }
	$dbh->do('ALTER TABLE Products ADD deleted boolean') if ! exists $$data{deleted};
	$dbh->do('ALTER TABLE Products ADD sort INTEGER') if ! exists $$data{sort};
	if ( ! exists $$data{project_id} ) {
		$dbh->do('ALTER TABLE Products ADD project_id INTEGER');
		$dbh->do('ALTER TABLE Products ADD FOREIGN KEY (project_id) REFERENCES projects (id)');
	} # en dif
	if ( ! exists $$data{owner_id} ) {
		$dbh->do('ALTER TABLE Products ADD owner_id INTEGER');
		$dbh->do('ALTER TABLE Products ADD FOREIGN KEY (owner_id) REFERENCES companies (id)');
	}
	if ( exists $$data{ysntaxexempt1} ) {
		if ( ! exists $$data{taxexempt1} ) {
			$dbh->do(q{alter table products rename column ysntaxexempt1 to taxexempt1});
		} else {
			$dbh->do(q{alter table products drop column ysntaxexempt1});
		} # end if
	} elsif ( ! exists $$data{taxexempt1} ) {
		$dbh->do(q{alter table products add ysntaxexempt1 CHAR(1) default 'N'});
	} # end if
	if ( exists $$data{ysntaxexempt2} ) {
		if ( ! exists $$data{taxexempt2} ) {
			$dbh->do(q{alter table products rename column ysntaxexempt2 to taxexempt2});
		} else {
			$dbh->do(q{alter table products drop column ysntaxexempt2});
		} # end if
	} elsif ( ! exists $$data{taxexempt2} ) {
		$dbh->do(q{alter table products add ysntaxexempt2 CHAR(1) default 'N'});
	} # end if
	if ( ! exists $$data{created_on} ) {
		$dbh->do('alter table products add created_on TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()');
	} # end if
	if ( ! exists $$data{id} ) {
		$dbh->do('ALTER TABLE products ADD id SERIAL');
		$dbh->do('ALTER TABLE products ADD PRIMARY KEY (id)');
	} # end if
	if ( ! exists $$data{album_id} ) {
		$dbh->do('ALTER TABLE products ADD album_id INTEGER');
		$dbh->do('ALTER TABLE products ADD FOREIGN KEY (album_id) REFERENCES Photo_Albums (id)');
	} # end if
	if ( ! exists $$data{manufacturer_id} ) {
		$dbh->do('ALTER TABLE products ADD manufacturer_id INTEGER');
		$dbh->do('ALTER TABLE products ADD FOREIGN KEY (manufacturer_id) REFERENCES Manufacturers (id)');
	} # end if
	if ( ! exists $$data{category_id} ) {
		$dbh->do('ALTER TABLE products ADD category_id INTEGER');
		$dbh->do('ALTER TABLE products ADD FOREIGN KEY (category_id) REFERENCES Product_Categories (id)');
	} # end if
	if ( ! exists $$data{weight} ) {
		$dbh->do('ALTER TABLE products ADD weight float');
	} # end if
	if ( ! exists $$data{supplier_id} ) {
		print "Adding supplier_id to Products\n";
		$dbh->do('ALTER TABLE Products ADD supplier_id INTEGER');
		$dbh->do('ALTER TABLE Products ADD FOREIGN KEY (supplier_id) REFERENCES companies (id)');
	}
} # end if

if ( ! sets::isin( 'product_specifications', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Product_Specifications.sql}) );
} # end if
if ( ! sets::isin( 'product_prices', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Product_Prices.sql}) );
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='product_prices'", 'column_name');
	if ( ! exists $$data{supplier_id} ) {
		$dbh->do('ALTER TABLE product_prices ADD supplier_id INTEGER');
		$dbh->do('ALTER TABLE product_prices ADD FOREIGN KEY (supplier_id) REFERENCES companies (id)');
	} # end if
} # end if

if ( ! sets::isin( 'invoiced_products', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Invoiced_Products.sql}) );
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='invoiced_products'", 'column_name');
	if ( $data and ! exists $$data{description} ) {
		$dbh->do('ALTER TABLE Invoiced_Products add description text');
	} # end if
} # end if
if ( ! sets::isin( 'sessions', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Sessions.sql}) );
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='sessions'", 'column_name');
	if ( ! exists $$data{a_session} ) {
		$dbh->do('ALTER TABLE sessions add a_session TEXT');
	}
	if ( ! exists $$data{id} ) {
		$dbh->do('ALTER TABLE sessions add id TEXT');
		$dbh->do('ALTER TABLE sessions add PRIMARY KEY (id)');
	}
} # end if

if ( sets::isin( 'tbl_quotes', \@tables ) ) {
	$dbh->do('ALTER TABLE tbl_Quotes rename to Quotes');
	$dbh->do('ALTER TABLE Quotes rename column index to id');
	$dbh->do('ALTER TABLE tbl_Quote_Users_For rename column quoteindex to quote_id');
	$dbh->do('ALTER TABLE tbl_Quote_Users_By rename column quoteindex to quote_id');
	$dbh->do('ALTER TABLE tbl_Quote_Details rename column quoteindex to quote_id');
	$dbh->do('ALTER TABLE tbl_Quote_Details rename column projectindex to project_id');
	$dbh->do('DROP SEQUENCE IF EXISTS quotes_id_seq');
	$dbh->do('CREATE SEQUENCE quotes_id_seq');
	$dbh->do("SELECT setval('quotes_id_seq', (select MAX(id) FROM Quotes) )");
	$dbh->do("ALTER TABLE Quotes alter column id set default nextval('quotes_id_seq')");
	push @tables, 'quotes';
} # end if

if ( ! sets::isin( 'quotes', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Quotes.sql' ) );
	die if $dbh->errstr();
} # end if

my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='quotes'", 'column_name');
	if ( $data ) {
		$dbh->do('ALTER TABLE quotes DROP column strsessionid') if ( exists $$data{strsessionid} );
		if ( ! exists $$data{currency_id} ) {
			$dbh->do('ALTER TABLE quotes add currency_id INTEGER');
			$dbh->do('ALTER TABLE quotes add FOREIGN KEY (currency_id) REFERENCES Currencies (id)');
			$dbh->do('UPDATE TABLE Quotes set currency_id = (SELECT id FROM currencies where name=strcurrencyname)');
		} # end if
		$dbh->do('ALTER TABLE quotes DROP column strcurrencyname') if ( exists $$data{strcurrencyname} );
		$dbh->do('ALTER TABLE quotes DROP column strcurrencysymbol') if ( exists $$data{strcurrencysymbol} );
		$dbh->do('ALTER TABLE quotes ADD deleted BOOLEAN NOT NULL DEFAULT FALSE') if ! exists $$data{deleted};
	} # end if

if ( ! sets::isin( 'tbl_quote_details', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/tbl_Quote_Details.sql' ) );
	die if $dbh->errstr();
}
if ( ! sets::isin( 'tbl_quote_users_for', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/tbl_Quote_Users_For.sql' ) );
	die if $dbh->errstr();
}
if ( ! sets::isin( 'tbl_quote_users_by', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/tbl_Quote_Users_By.sql' ) );
	die if $dbh->errstr();
}
if ( ! sets::isin( 'quote_log', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Quote_Log.sql' ) );
	die if $dbh->errstr();
} 
my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='quote_log'", 'column_name');
	if ( $$data{dtmwhen} ) {
		$dbh->do(q{alter table quote_log rename column dtmwhen to created_on});
	} # end if
	if ( ! exists $$data{id} ) {
		$dbh->do(q{alter table quote_log add id SERIAL NOT NULL});
		$dbh->do(q{alter table quote_log drop constraint quote_log_pkey});
		$dbh->do(q{alter table quote_log add PRIMARY KEY (id)});
	} # end if
	if ( ! exists $$data{company_id} ) {
		$dbh->do(q{alter table quote_log add company_id INTEGER});
		$dbh->do(q{alter table quote_log add FOREIGN KEY (company_id) REFERENCES companies (id)});
	} 

my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='tbl_quote_details'", 'column_name');
if ( $data ) {
	my $ac = sql::start_transaction( $dbh );
	$dbh->do(q`alter table tbl_Quote_Details add include_detailed boolean default false`) if ! exists $$data{include_detailed};
	if ( ! exists $$data{template_id} ) {
	$dbh->do(q`alter table tbl_Quote_Details add template_id INTEGER`);
	$dbh->do(q`alter table tbl_Quote_Details add foreign key (template_id) REFERENCES QuoteLevels (id)`);
	} # end if
	$dbh->do(q`alter table tbl_Quote_Details add id SERIAL NOT NULL`) if ! exists $$data{id};
	$dbh->do(q`alter table tbl_Quote_Details DROP dblmarkup`) if exists $$data{dblmarkup};
	$dbh->do(q`ALTER TABLE tbl_Quote_Details rename projectindex to project_id`) if exists $$data{projectindex};
	sql::end_transaction( $dbh, $ac );
} # end if
new openprint::ServiceType_Category()->save({'name'=>'Materials','sorting'=>8}) if ! openprint::ServiceType_Category->find('name'=>'Materials');
if ( my $ServiceType = openprint::ServiceType->find_one('name'=>'Paper') ) {
	$ServiceType->save({'category'=>'Materials'}) if $ServiceType->category() ne 'Materials';
} else {
	my $PaperService = new openprint::ServiceType();
    $PaperService->save({'name'=>'Paper',
            'description'=>'Paper',
            'url'=>'Paper.html',
            'type'=>'Paper',
            'category'=>'Materials',
            'sorting'=>1000,
            'create_visible'=>'N',
            'view_visible'=>'Y',
            });
} # end if
foreach my $E ( openprint::Equipment->find('Specifications'=>{'Type'=>'Press'}) ) {
    foreach my $Spec ( openprint::EquipmentSpecification->find('equipment_id'=>$E->id(), 'name'=>'Press Run Overs Rate') ) {
        $Spec->name('MakeReady Overs Rate');
        $Spec->save();
print "Updating Press RUn Overs Rate to MakeReady Overs Rate\n";
    } # end if
    foreach my $Spec ( openprint::EquipmentSpecification->find('equipment_id'=>$E->id(), 'name'=>'Press Run Overs Minimum') ) {
        $Spec->name('Overs Minimum');
        $Spec->save();
print "Updating Press RUn Overs Rate to MakeReady Overs Minimum\n";
    } # end if
    if ( ! $E->Specification('Sheeter') ) {
        my $Spec = new openprint::EquipmentSpecification();
        $Spec->save({'name'=>'Sheeter','value'=>'Y','equipment_id'=>$E->id()});
        print "Adding Sheeter setting on . " . $E->name() . "\n";
    } # end if
} # end foreach E

if ( my @C = openprint::MaterialCategory->find('name'=>'Plain Cartons') ) {
	foreach ( @C ) {
		$_->save({'name'=>'PlainCartons'});
	}
} elsif ( ! openprint::MaterialCategory->find('name'=>'PlainCartons') ) {
    my $Category = new openprint::MaterialCategory();
    $Category->save({'name'=>'PlainCartons'});
    print "Adding PlainCartons Category\n";
} # end if

foreach my $M ( openprint::Material->find('name like'=>'Plain Carton%') ) {
	if ( my ( $w, $h, $d ) = $M->name() =~ /Plain Carton (\d+)x(\d+)x(\d+)/ ) {
		if ( $d and ! $M->specification('Depth') ) {
			my $S = new openprint::MaterialSpecification();
			$S->save({
				'material_id'	=>	$M->id(),
				'name'			=>	'Depth',
				'value'			=>	$d,
			});
		} # endif
		if ( $w and ! $M->specification('Width') ) {
			my $S = new openprint::MaterialSpecification();
			$S->save({
				'material_id'	=>	$M->id(),
				'name'			=>	'Width',
				'value'			=>	$w,
			});
		} # end if
		if ( $h and ! $M->specification('Height') ) {
			my $S = new openprint::MaterialSpecification();
			$S->save({
				'material_id'	=>	$M->id(),
				'name'			=>	'Height',
				'value'			=>	$h,
			});
		} # end if
	} # end if
	if ( ! $M->specification('Maximum Weight') ) {
		my $S = new openprint::MaterialSpecification();
		$S->save({
				'material_id'	=>	$M->id(),
				'name'	=>	'Maximum Weight',
				'value'	=>	'40',
				});
	} # end if
	next if $M->Category()->name() eq 'PlainCartons';
	foreach my $C ( openprint::MaterialCategory->find('name'=>'PlainCartons') ) {
		$M->category_id( $C->id() );
		last;
	} # end foreach $C
	$M->save();
} # end foreach $M
if ( ! openprint::MaterialCategory->find('name'=>'BulkSkids') ) {
    print "Adding BulkSkids Category\n";
    my $Category = new openprint::MaterialCategory();
    $Category->save({'name'=>'BulkSkids'});
} # end if

if ( my $M = openprint::Material->find_one('name'=>'BulkSkids') ) {
	if ( ! openprint::Material->find('name'=>'BulkSkid') ) {
		$M->save({'name'=>'BulkSkid'});
	} 
}
foreach my $M ( openprint::Material->find('name'=>'BulkSkid') ) {
	if ( ! $M->specification('Maximum Weight') ) {
		my $S = new openprint::MaterialSpecification();
		$S->save({
				'material_id'	=>	$M->id(),
				'name'	=>	'Maximum Weight',
				'value'	=>	'1500',
				});
	} # end if
	if ( ! $M->specification('Depth') ) {
		my $S = new openprint::MaterialSpecification();
		$S->save({
			'material_id'	=>	$M->id(),
			'name'			=>	'Depth',
			'value'			=>	56,
		});
	} # endif
	next if $M->Category()->name() eq 'BulkSkids';
	foreach my $C ( openprint::MaterialCategory->find('name'=>'BulkSkids') ) {
		$M->category_id( $C->id() );
		last;
	} # end foreach $C
	$M->save();
} # end foreach $M

foreach my $S ( openprint::ServiceType->find('name'=>['SaddleStitching','LoopStitching']) ) {
	if ( $S->type() ne 'Stitching' ) {
		$S->type('Stitching');
		$S->save();
	} # end if
} # end foreach

new openprint::ServiceType_Category()->save({'name'=>'Coatings','sorting'=>2}) if ! openprint::ServiceType_Category->find('name'=>'Coatings');
if ( my $S = openprint::ServiceType->find_one('name'=>'Aqueous') ) {
	$S->save({'category'=>'Coatings'}) if $S->category() ne 'Coatings';
} else {
	print "Adding Aqueous ServiceType\n";
	my $S = new openprint::ServiceType();
	$S->save({
		'name'	=>	'Aqueous',
		'description'	=>	'Aqueous',
		'type'		=>	'Aqueous',
		'category'	=>	'Coatings',
		'url'		=>	'spec/Aqueous.html',
		'create_visible'	=>	0,
		'view_visible'		=>	1,
});
} # end if

foreach my $ST ( openprint::ServiceType->find('name'=>'DieCutting') ) {
	my $error = $ST->save({'url'=>'bind/DieCutting.html'}) if $ST->url() ne 'bind/DieCutting.html';
	die 'Error saving '.$ST->to_string().': '.$error if $error;
}

if ( ! openprint::ServiceCategory->find('name'=>'Coating') ) {
	print "Adding Coating Service Category\n";
	my $SC = new openprint::ServiceCategory();
	$SC->save({
		'name'=>'Coating',
	});
} # end if
if ( my @S = openprint::Service->find('name'=>'Perforation') ) {
	foreach my $S ( @S ) {
		$S->save({'name'=>'Perforating'});
	}
} # end if
if ( my @S = openprint::Service->find('name'=>'PerforationMakeReady') ) {
	foreach my $S ( @S ) {
		$S->save({'name'=>'PerforatingMakeReady'});
	}
} # end if
if ( ! openprint::Material->find('name'=>'PerforatingWheel') ) {
	if ( my @M = openprint::Material->find('name'=>'PerforatingRule') ) {
		foreach my $M ( @M ) {
			my $New = $M->copy();
			$New->save({'name'=>'PerforatingWheel'});
			foreach my $P ( $M->prices() ) {
				$P=$P->copy();
				$P->save({'material_id'=>$New->id()});
			} # end foreach
		} # end foreach $M
	} # en d if
} # end if

foreach my $S ( openprint::Service->find('name'=>'Aqueous') ) {
	foreach my $type ( 'Gloss', 'Matte', 'Satin', 'SoftTouch' ) {
		if ( ! openprint::Service->find('name'=>"Aqueous $type Overall") ) {
			print "Converting Service Aqueous\n";
			my $S2 = $S->copy();
			$S2->name("Aqueous $type Overall");
			$S2->description("Aqueous $type Overall");
			$S2->category('Coating');
			$S2->save();
			foreach my $P ( $S->prices() ) {
				$P = $P->copy();
				$P->service_id( $S2->id() );
				$P->units('per 1000 impressions');
				$P->save();
			} # end foreach
		} # end if
		if ( ! openprint::Service->find('name'=>"Aqueous $type Spot") ) {
			print "Converting Service Aqueous\n";
			my $S2 = $S->copy();
			$S2->name("Aqueous $type Spot");
			$S2->description("Aqueous $type Spot");
			$S2->category('Coating');
			$S2->save();
			foreach my $P ( $S->prices() ) {
				$P = $P->copy();
				$P->service_id( $S2->id() );
				$P->units('per 1000 impressions');
				$P->save();
			} # end foreach
		} # end if
	} # end foreach type
	$S->delete();
} # end if

if ( 0 ) {
foreach my $S ( openprint::Service->find('name'=>'AqueousMakeReady') ) {

	if ( ! openprint::Service->find('name'=>'Aqueous Gloss Overall MakeReady') ) {
		print "Converting Service Aqueous MakeReady\n";
		$S->name('Aqueous Gloss Overall MakeReady');
		$S->description('Aqueous Gloss Overall MakeReady');
		$S->save();
	} # en dif
	if ( ! openprint::Service->find('name'=>'Aqueous Matte Overall MakeReady') ) {
		my $S2 = $S->copy();
		$S2->name('Aqueous Matte Overall MakeReady');
		$S2->description('Aqueous Overall Matte MakeReady');
		$S2->save();
		foreach my $P ( $S->prices() ) {
			$P = $P->copy();
			$P->service_id( $S2->id() );
			$P->units('per 1000 impressions');
			$P->save();
		} # end foreach
	} # en dif
	if ( ! openprint::Service->find('name'=>'Aqueous Satin Overall MakeReady') ) {
		my $S2 = $S->copy();
		$S2->name('Aqueous Satin Overall MakeReady');
		$S2->description('Aqueous Overall Satin MakeReady');
		$S2->save();
		foreach my $P ( $S->prices() ) {
			$P = $P->copy();
			$P->service_id( $S2->id() );
			$P->units('per 1000 impressions');
			$P->save();
		} # end foreach
	} # en dif
	if ( ! openprint::Service->find('name'=>'Aqueous SoftTouch Overall MakeReady') ) {
		my $S2 = $S->copy();
		$S2->name('Aqueous SoftTouch Overall MakeReady');
		$S2->description('Aqueous Overall SoftTouch MakeReady');
		$S2->save();
		foreach my $P ( $S->prices() ) {
			$P = $P->copy();
			$P->service_id( $S2->id() );
			$P->units('per 1000 impressions');
			$P->save();
		} # end foreach
	} # en dif
} # end if
}
if ( ! openprint::ServiceType->find('name'=>'Varnish') ) {
	print  "Adding Varnish ServiceType\n";
	my $S = new openprint::ServiceType();
	$S->save({
		'name'	=>	'Varnish',
		'description'	=>	'Varnish',
		'type'		=>	'Varnish',
		'category'	=>	'Printing',
		'url'		=>	'spec/Varnish.html',
		'create_visible'	=>	0,
		'view_visible'		=>	1,
});
} # end if
foreach my $S ( openprint::Service->find('name'=>'VarnishInLine') ) {
	print "Converting VarnishInLine to coatings\n";
	if ( ! openprint::Service->find('name'=>'Varnish Gloss Overall') ) {
		$S->name('Varnish Gloss Overall');
		$S->description('Varnish Gloss Overall');
		$S->category('Coating');
		$S->save();
		if ( ! openprint::Ink->find( name=>'Varnish Gloss Overall' ) ) {
			my $Ink = new openprint::Ink();
			$Ink->save({ name=>'Varnish Gloss Overall', service_id=>$S->id(), washups=>1 });
		} # end if
	} # end if

	if ( ! openprint::Service->find('name'=>'Varnish Gloss Spot') ) {
		my $S2 = $S->copy();
		$S2->name('Varnish Gloss Spot');
		$S2->description('Varnish Gloss Spot');
		$S2->save();
		foreach my $P ( $S->prices() ) {
			$P = $P->copy();
			$P->service_id( $S2->id() );
			$P->save();
		} # end foreach
		if ( ! openprint::Ink->find( name=>'Varnish Gloss Spot' ) ) {
			my $Ink = new openprint::Ink();
			$Ink->save({ name=>'Varnish Gloss Spot', service_id=>$S2->id(), washups=>1 });
		} # end if
	} # end if
	if ( ! openprint::Service->find('name'=>'Varnish Matte Overall') ) {
		my $S2 = $S->copy();
		$S2->name('Varnish Matte Overall');
		$S2->description('Varnish Matte Overall');
		$S2->save();
		foreach my $P ( $S->prices() ) {
			$P = $P->copy();
			$P->service_id( $S2->id() );
			$P->save();
		} # end foreach
		if ( ! openprint::Ink->find( name=>'Varnish Matte Overall' ) ) {
			my $Ink = new openprint::Ink();
			$Ink->save({ name=>'Varnish Matte Overall', service_id=>$S2->id(), washups=>1 });
		} # end if
	} # en dif
	if ( ! openprint::Service->find('name'=>'Varnish Matte Spot') ) {
		my $S2 = $S->copy();
		$S2->name('Varnish Matte Spot');
		$S2->description('Varnish Matte Spot');
		$S2->save();
		foreach my $P ( $S->prices() ) {
			$P = $P->copy();
			$P->service_id( $S2->id() );
			$P->save();
		} # end foreach
		if ( ! openprint::Ink->find( name=>'Varnish Matte Spot' ) ) {
			my $Ink = new openprint::Ink();
			$Ink->save({ name=>'Varnish Matte Spot', service_id=>$S2->id(), washups=>1 });
		} # end if
	} # end if
} # end if
foreach my $S ( openprint::Service->find('name'=>'VarnishMakeReady') ) {
	if ( ! openprint::Service->find('name'=>'Varnish Gloss Overall MakeReady') ) {
		print "Converting VarnishInLineMake Readies\n";
		$S->name('Varnish Gloss Overall MakeReady');
		$S->description('Varnish Gloss Overall MakeReady');
		$S->save();
	} # en dif

	if ( ! openprint::Service->find('name'=>'Varnish Gloss Spot MakeReady') ) {
		print "Converting VarnishMakeReadies To Varnish Gloss Spot MakeReady\n";
		my $S2 = $S->copy();
		$S2->name('Varnish Gloss Spot MakeReady');
		$S2->description('Varnish Gloss Spot MakeReady');
		$S2->save();

		foreach my $P ( $S->prices() ) {
			$P = $P->copy();
			$P->service_id( $S2->id() );
			$P->save();
		} # end foreach
	} # end if

	if ( ! openprint::Service->find('name'=>'Varnish Matte Overall MakeReady') ) {
		print "Converting VarnishMakeReadies To Varnish Matte Overall MakeReady\n";
		my $S2 = $S->copy();
		$S2->name('Varnish Matte Overall MakeReady');
		$S2->description('Varnish Matte Overall MakeReady');
		$S2->save();
		foreach my $P ( $S->prices() ) {
			$P = $P->copy();
			$P->service_id( $S2->id() );
			$P->save();
		} # end foreach
	} # en dif
	if ( ! openprint::Service->find('name'=>'Varnish Matte Spot MakeReady') ) {
		print "Converting VarnishMakeReadies To Varnish Matte Spot MakeReady\n";
		my $S2 = $S->copy();
		$S2->name('Varnish Matte Spot MakeReady');
		$S2->description('Varnish Matte Spot MakeReady');
		$S2->save();
		foreach my $P ( $S->prices() ) {
			$P = $P->copy();
			$P->service_id( $S2->id() );
			$P->save();
		} # end foreach
	} # en dif
}

foreach my $E ( openprint::Equipment->find('Specifications'=>{'Aqueous Coating'=>'Y'}) ) {
	my $S = $E->Specification('Aqueous Coating');
	$S->name('Aqueous Capable');
	$S->save();
} # end foreach E


if ( sets::isin( 'ordered_products', \@tables ) ) {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='ordered_products'", 'column_name');
	if ( $data and ! exists $$data{project_id} ) {
		$dbh->do('ALTER TABLE Ordered_Products add project_id integer');
		$dbh->do('ALTER TABLE Ordered_Products add foreign key (project_id) references projects (id)');
	} # end if
	if ( ! exists $$data{comments} ) {
		$log->debug("Adding comments to ordered_products");
		$dbh->do('ALTER TABLE Ordered_Products add comments text') or die $dbh->errstr();
	}
} else {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Ordered_Products.sql}) );
}
my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM products LIMIT 1', {} );
if ( $data and ! exists $$data{project_id} ) {
print "Adding project_id to Products\n";
	$dbh->do(q`alter table products add project_id INTEGER`);
	$dbh->do(q`alter table products add FOREIGN KEY (project_id) REFERENCES Projects (id)`);
} # end if
my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Projects LIMIT 1', {} );
if ( $data and ! exists $$data{predefined} ) {
print "Adding predefined to Projects\n";
	my $ac = sql::start_transaction( $dbh );
	$dbh->do(q`alter table Projects add predefined boolean`);
	$dbh->do(q`alter table Projects alter predefined set default false`);
	$dbh->do(q`update Projects set predefined=false`);
	$dbh->do(q`alter table Projects alter predefined set not null`);
	sql::end_transaction( $dbh, $ac );
} # end if

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM RFIDScanners LIMIT 1', {} );
if ( $data ) {
	if ( ! exists $$data{monitor} ) {
		$dbh->do('ALTER TABLE RFIDScanners ADD monitor boolean not null default false');
	} # end if
} # end if

if ( ! sets::isin( 'surveys', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Surveys.sql}) ) or die $dbh->errstr();
	push @tables, 'surveys';
} # end if
if ( ! sets::isin( 'survey_question_categories', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Survey_Question_Categories.sql}) ) or die $dbh->errstr();
} # end if
if ( ! sets::isin( 'survey_questions', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Survey_Questions.sql}) ) or die $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='survey_questions'", 'column_name');
	if ( ! exists $$data{allow_comments} ) {
		$dbh->do('alter table survey_questions add allow_comments BOOLEAN NOT NULL DEFAULT false');
	}
	if ( ! exists $$data{allow_public} ) {
		$dbh->do('alter table survey_questions add allow_public BOOLEAN NOT NULL DEFAULT false');
	}
} # end if
if ( ! sets::isin( 'survey_answers', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Survey_Answers.sql}) ) or die $dbh->errstr();
} # end if
if ( ! sets::isin( 'survey_responses', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Survey_Responses.sql}) ) or die $dbh->errstr();
} # end if

if ( ! sets::isin( 'survey_question_available_answers', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Survey_Question_Available_Answers.sql}) ) or die $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='survey_question_available_answers'", 'column_name');
} # end if


if ( ! sets::isin( 'order_id_seq', \@sequences ) ) {
	$dbh->do('create sequence order_id_seq');
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='orders'", 'column_name');
	if ( exists $$data{index} ) {
	$dbh->do(q`select setval('order_id_seq', (select max(index) from orders) )`);
	$dbh->do(q`alter table orders alter column index set default nextval('order_id_seq');`);
	} else {
	$dbh->do(q`select setval('order_id_seq', (select max(id) from orders) )`);
	$dbh->do(q`alter table orders alter column id set default nextval('order_id_seq');`);
	} # end if
}

if ( ! sets::isin( 'order_contents', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Order_Contents.sql' ) ) or die;
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='order_contents'", 'column_name');
	if ( ! $$data{id} ) {
		$dbh->do('ALTER TABLE order_contents add id SERIAL');
	} # end if
}


if ( ! sets::isin( 'skid_contents', \@tables ) ) {
	$dbh->do(misc::load_file( $log, '../openprint/sql/Skid_Contents.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='skid_contents'", 'column_name');
	if ( ! exists $$data{id} ) {
		$dbh->do('alter table skid_contents add id serial');
		$dbh->do('alter table skid_contents drop constraint skid_contents_pkey');
		$dbh->do('alter table skid_contents add primary key (id)');
		$dbh->do('create index skid_contents_skid_id_idx on skid_contents (skid_id)');
	} # end if
} # end if
foreach my $ServiceType ( openprint::ServiceType->find() ) {
	if ( $ServiceType->name() eq 'PerfectBound' ) {
		$ServiceType->type('PerfectBound') if ( $ServiceType->type() ne 'PerfectBound' );
		if ( $ServiceType->url() ne 'bind/PerfectBound.html' ) {
			$ServiceType->url('bind/PerfectBound.html');
			$log->warn('URL: ' . $ServiceType->url() );
		} # end if
		$ServiceType->save();
	} # end if
} # end foreach ServiceType

if ( ! sets::isin( 'emailcampaigns', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/EmailCampaigns.sql}) );
} 
if ( ! sets::isin( 'emailtemplates', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/EmailTemplates.sql}) );
} 

if ( ! sets::isin( 'paper_inventory', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Paper_Inventory.sql}) );
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='paper_inventory'", 'column_name');
	if ( $data ) {
		$dbh->do(q{alter table paper_inventory rename column updatetime to updated_on}) if exists $$data{updatetime};
		if ( ! exists $$data{id} ) {
			my $ac = sql::start_transaction( $dbh );
			$dbh->do(q{alter table paper_inventory add id integer});
			$dbh->do(q{create sequence paperinventory_id_seq});
			$dbh->do(q{alter table paper_inventory alter id set default nextval('paperinventory_id_seq')});
			$dbh->do(q{update paper_inventory set id=nextval('paperinventory_id_seq')});
			$dbh->do(q{alter table paper_inventory alter id set not null});
			$dbh->do(q{alter table paper_inventory add primary key(id)});
			sql::end_transaction( $dbh, $ac );
		} # end if
		if ( ! exists $$data{docket} ) {
			$dbh->do('alter table paper_inventory add docket integer');
		} # end if
		if ( ! exists $$data{project_id} ) {
			$dbh->do('alter table paper_inventory add project_id integer');
			$dbh->do('alter table paper_inventory add FOREIGN KEY (project_id) REFERENCES Projects (id)');
		} # end if
		if ( exists $$data{poindex} ) {
			$dbh->do('alter table paper_inventory DROP poindex');
		} # end if
		if ( exists $$data{po_id} ) {
			$dbh->do('alter table paper_inventory DROP po_id');
		} # end if
	} # end if
	#foreach my $PI ( openprint::PaperInventory->find('docket'=>undef) ) {
		#$PI->save() if $PI->docket();
	#} # end foreach
} # end if

if ( ! sets::isin( 'taxes', \@tables ) ) {
} else {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Taxes LIMIT 1', {} );
	if ( $data ) {
		if ( exists $$data{dblfederalpercent} ) {
			$dbh->do( 'ALTER TABLE Taxes rename column dblfederalpercent to federaltax' );
		} # end if
		if ( exists $$data{dblstatepercent} ) {
			$dbh->do( 'ALTER TABLE Taxes rename column dblstatepercent to statetax' );
		} # end if
		if ( exists $$data{dblharmonisedpercent} ) {
			$dbh->do( 'ALTER TABLE Taxes rename column dblharmonisedpercent to harmonizedtax' );
		} # end if
		if ( ! exists $$data{id} ) {
			$dbh->do( 'ALTER TABLE Taxes add id SERIAL' );
			( $_ ) = sql::execute( undef, undef, "SELECT EXISTS ( SELECT * FROM information_schema.table_constraints WHERE constraint_name='taxes_pkey' AND table_name='taxes' ) " );
			if ( $_ ) {
				$dbh->do( 'ALTER TABLE Taxes DROP Constraint taxes_pkey');
			} # end if
			$dbh->do( 'ALTER TABLE Taxes add PRIMARY KEY(id)' );
		} # end if
	} # end if
}

if ( ! sets::isin( 'manifest_content_types', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Manifest_Content_Types.sql}) );
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM manifestcontents LIMIT 1', {} );
	if ( $data ) {
		if ( ! exists $$data{type_id} ) {
			require openprint::Manifest;
			$dbh->do('alter table manifestcontents add type_id integer');
			foreach my $Manifest ( openprint::Manifest->find() ) {
				my @Contents = $Manifest->Contents();

				if ( @Contents ) {
					my $T = new openprint::Manifest_Content_Type();
					$_ = $T->save({
						'manifest_id'	=>	$Manifest->id(),
						'docket'		=>	$Contents[0]->docket(),
						'po_id'			=>	$Manifest->po_id(),
					});
					die $_ if $_;
					foreach my $C ( @Contents ) {
						$C->save({'type_id'=>$T->id()});
					} # end foreach
				} # end if
			} # end foreach Manifest
			$dbh->do('alter table manifestcontents alter type_id set not null');
			$dbh->do('alter table manifestcontents add foreign key (type_id) references manifest_content_types (id)');
		} # end if
		if ( ! exists $$data{docket} ) {
			$dbh->do('alter table manifestcontents add docket integer');
		} # end if
	} # end if
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='manifest_content_types'", 'column_name');
	if ( $data and ! exists $$data{supplier_invoice} ) {
		$dbh->do('alter table manifest_content_types add supplier_invoice text');
	} # end if
	if ( ! exists $$data{item_count} ) {
		$dbh->do('ALTER TABLE manifest_content_types ADD item_count INTEGER');
	} # end if
	if ( ! exists $$data{type} ) {
		$dbh->do('ALTER TABLE manifest_content_types ADD type TEXT');
	} # end if
	if ( ! exists $$data{manufacturers_name} ) {
		$dbh->do('ALTER TABLE manifest_content_types ADD manufacturers_name TEXT');
	} # end if
	if ( ! exists $$data{cost_units} ) {
		$dbh->do('ALTER TABLE manifest_content_types ADD cost_units TEXT');
	} # end if
} 

foreach my $Currency ( openprint::Currency->find('short'=>'CDN') ) {
$Currency->save({'short'=>'CAD'});
}# end foreach Currency

	if ( ! $config{TechSupportEmail} ) {
		sql::insert(undef,undef,'configuration', [
				'name'=>'TechSupportEmail',
				'value'=>'"Isaac Connor" <iconnor@connortechnology.com>',
				'type'=>'text',
				'description'=>'Email address to send technical support requests to.',
				'category'=> 'Email Notifications'] );
	} # end if
	if ( ! $config{AdministratorEmail} ) {
		sql::insert(undef,undef,'configuration', [
				'name'=>'AdministratorEmail',
				'value'=>'"Isaac Connor" <iconnor@connortechnology.com>',
				'type'=>'text',
				'description'=>'Email address of the person in charge of the website.',
				'category'=> 'Email Notifications'] );
	} # end if
	if ( ! $config{AccountingEmail} ) {
		sql::insert(undef,undef,'configuration', [
				'name'=>'AccountingEmail',
				'value'=>'"Isaac Connor" <iconnor@connortechnology.com>',
				'type'=>'text',
				'description'=>'Email address of the person in charge of accounting.',
				'category'=> 'Email Notifications'] );
	} # end if
	if ( ! $config{QuotingEmail} ) {
		sql::insert(undef,undef,'configuration', [
				'name'=>'QuotingEmail',
				'value'=>'"Isaac Connor" <iconnor@connortechnology.com>',
				'type'=>'text',
				'description'=>'Email address to send quotes to.',
				'category'=> 'Email Notifications'] );
	} # end if
	if ( ! $config{UserRegistrationEmail} ) {
		sql::insert(undef,undef,'configuration', [
				'name'=>'UserRegistrationEmail',
				'value'=>'"Isaac Connor" <iconnor@connortechnology.com>',
				'type'=>'text',
				'description'=>'Email address to send new user registrations to.',
				'category'=> 'Email Notifications'] );
	} # end if
	if ( ! $config{CreditApplicationEmail} ) {
		sql::insert(undef,undef,'configuration', [
				'name'=>'CreditApplicationEmail',
				'value'=>'"Isaac Connor" <iconnor@connortechnology.com>',
				'type'=>'text',
				'description'=>'Email address to send new credit applications to.',
				'category'=> 'Email Notifications'] );
	} # end if
	if ( ! $config{ResellerApplicationEmail} ) {
		sql::insert(undef,undef,'configuration', [
				'name'=>'ResellerApplicationEmail',
				'value'=>'"Isaac Connor" <iconnor@connortechnology.com>',
				'type'=>'text',
				'description'=>'Email address to send new reseller applications to.',
				'category'=> 'Email Notifications'] );
	} # end if
	if ( ! $config{HelpdeskEmail} ) {
		sql::insert(undef,undef,'configuration', [
				'name'=>'HelpdeskEmail',
				'value'=>'"Isaac Connor" <iconnor@connortechnology.com>',
				'type'=>'text',
				'description'=>'Email address to send helpdesk requests to.',
				'category'=> 'Email Notifications'] );
	} # end if
	if ( ! $config{RMAEmail} ) {
		sql::insert(undef,undef,'configuration', [
				'name'=>'RMAEmail',
				'value'=>'"Isaac Connor" <iconnor@connortechnology.com>',
				'type'=>'text',
				'description'=>'Email address to send RMA requests to.',
				'category'=> 'Email Notifications'] );
	} # end if
	if ( ! $config{InventoryEmail} ) {
		sql::insert(undef,undef,'configuration', [
				'name'=>'InventoryEmail',
				'value'=>'"Isaac Connor" <iconnor@connortechnology.com>',
				'type'=>'text',
				'description'=>'Email address to send Inventory notifications to.',
				'category'=> 'Email Notifications'] );
	} # end if
if ( ! sets::isin( 'productionfeedback', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/ProductionFeedback.sql}) );
} else {
	$dbh->do('alter table productionfeedback alter service_id drop not null');
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='productionfeedback'", 'column_name');
	if ( ! $$data{signature_id} ) {
		$dbh->do('alter table productionfeedback add signature_id INTEGER');
		$dbh->do('alter table productionfeedback add foreign key (signature_iD) references signaturecapture (id)');
	} # end if
} # end if
if ( ! sets::isin( 'cip3_ppf', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/CIP3_PPF.sql}) );
} # end if

if ( ! sets::isin( 'employeenumbers', \@tables ) ) {
		$dbh->do( misc::load_file( $log, q{../openprint/sql/EmployeeNumbers.sql}) );
} else {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM EmployeeNumbers LIMIT 1', {} );
	if ( $data ) {
		if ( exists $$data{lngemployeeid} ) {
			$dbh->do('alter table employeenumbers rename column lngemployeeid to id');
			$dbh->do('alter table employeenumbers rename column lngmin to min');
			$dbh->do('alter table employeenumbers rename column lngmax to max');
		} # end if
	} # end if
} # end if

if ( ! sets::isin( 'schedule', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Schedule.sql}) );
	die if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='schedule'", 'column_name');
	if ( $data ) {
		if ( ! exists $$data{id} ) {
			$dbh->do('ALTER TABLE Schedule ADD id SERIAL');
		} # end if
		if ( exists $$data{serviceindex} and ! exists $$data{service_id} ) {
			$dbh->do('ALTER TABLE Schedule ADD service_id INTEGER[]');
			$dbh->do('UPDATE Schedule SET service_id=ARRAY[serviceindex]');
#$dbh->do('ALTER TABLE Schedule DROP serviceindex');
		} # end if
		if ( ! exists $$data{starttime_locked} ) {
			$dbh->do('ALTER TABLE Schedule ADD starttime_locked boolean');
		} # end if
		if ( ! exists $$data{impressions} ) {
			$dbh->do('ALTER TABLE Schedule ADD impressions integer');
		} # end if
	} # end if
	$dbh->do('ALTER TABLE Schedule ADD speed INTEGER') if ! exists $$data{speed};
} # end if

if ( ! sets::isin( 'labels', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Labels.sql}) );
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='labels'", 'column_name');
	if ( ! exists $$data{deleted} ) {
		$log->debug("Add deleted to labels");
		$dbh->do('ALTER TABLE labels ADD deleted BOOLEAN NOT NULL DEFAULT FALSE') or die $dbh->errstr();
	}
} # end if

if ( sets::isin('shifts',\@tables) and ! sets::isin( 'equipment_shifts', \@tables ) ) {
	$dbh->do( 'ALTER TABLE Shifts rename to Equipment_Shifts' );
} elsif ( ! sets::isin( 'equipment_shifts', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Equipment_Shifts.sql}) );
	die if $dbh->errstr();
} # end if

@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
if ( sets::isin( 'equipment_shifts', \@tables ) ) {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='equipment_shifts'", 'column_name');
	if ( ! exists $$data{id} ) {
		$dbh->do('ALTER TABLE Equipment_Shifts drop constraint shifts_pkey');
		$dbh->do('ALTER TABLE Equipment_shifts add id serial');
		$dbh->do('ALTER TABLE Equipment_shifts add PRIMARY KEY (id)');
	} # end if
} # end if

if ( ! sets::isin('shifts',\@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Shifts.sql}) );
	die if $dbh->errstr();
} # end if

if ( ! sets::isin('user_notification_types',\@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/User_Notification_Types.sql}) );
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='user_notification_types'", 'column_name');
	if ( ! exists $$data{sort} ) {
		$dbh->do('ALTER TABLE user_notification_types ADD sort INTEGER');
	} # end if
} # end if
if ( ! sets::isin('user_notifications',\@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/User_Notifications.sql}) );
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='user_notifications'", 'column_name');
    if ( ! exists $$data{company_id} ) {
		$log->debug("Adding company_id to notifications");
        $dbh->do('ALTER TABLE user_notifications ADD company_id INTEGER');
        $dbh->do('ALTER TABLE user_notifications ADD FOREIGN KEY (company_id) REFERENCES companies (id)');
    } # end if

} # end if

if ( ! sets::isin( 'claims', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Claims.sql}) );
} else {
my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='claims'", 'column_name');
	if ( ! exists $$data{cancelled_on} ) {
		$dbh->do('ALTER TABLE claims add cancelled_on TIMESTAMP WITH TIME ZONE');
	} # end if
	if ( ! exists $$data{paid_on} ) {
		$dbh->do('ALTER TABLE claims ADD paid_on DATE');
	} # end if
} # end if
if ( ! sets::isin( 'claim_contenttypes', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Claim_ContentTypes.sql}) );
} # end if
if ( ! sets::isin( 'claim_contents', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Claim_Contents.sql}) );
} # end if

if ( $version < 1907 ) {
	print "Updating to version 1907\n";
	my $ac = sql::start_transaction( $dbh );
foreach my $E ( openprint::Equipment->find('Specifications'=>{'Type'=>'Press'}) ) {
	print "Looking for Feed on " . $E->strid();
	my $Spec = $E->Specification('Feed');
	if ( ! $Spec ) {
		print "No Feed found, adding it.\n";
		$Spec = new openprint::EquipmentSpecification();
		$Spec->equipment_id( $E->id() );
		$Spec->name( 'Feed' );
		$Spec->value('Sheet');
		print $Spec->save();
	} elsif ( $Spec->value() eq 'Web' ) {
		print "Web found, converting to Roll.\n";
		$Spec->value('Roll');
		print $Spec->save();
	} # end if
	print "no change.\n";
} # end foreach
	sql::insert( undef, undef, 'database_info', 'version', 1907, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1907;
} # end if
if ( $version < 1908 ) {
	print "Updating to version 1908\n";
	my $ac = sql::start_transaction( $dbh );
	#sql::insert( undef, undef, 'configuration', { 'name'=>'ProjectViewDisclaimer','value'=>'','type'=>'text','description'=>'Text to display at the bottom of the project view page', 'category'=>'Disclaimers'} ) if ! $config{ProjectViewDisclaimer};
	#sql::insert( undef, undef, 'configuration', { 'name'=>'OrderViewDisclaimer','value'=>'','type'=>'text','description'=>'Text to display at the bottom of the order view page', 'category'=>'Disclaimers'}) if ! $config{OrderViewDisclaimer};
	#sql::insert( undef, undef, 'configuration', { 'name'=>'QuoteViewDisclaimer','value'=>'','type'=>'text','description'=>'Text to display at the bottom of the quote view page', 'category'=>'Disclaimers'}) if ! $config{QuoteViewDisclaimer};

	sql::insert( undef, undef, 'database_info', 'version', 1908, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1908;
} # end if
if ( $version < 1910 ) {
	print "Updating to version 1910\n";
	my $ac = sql::start_transaction( $dbh );
	$dbh->do('alter table service_types add unique(name);');
	sql::insert( undef, undef, 'database_info', 'version', 1910, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1910;
} # end if
if ( $version < 1914 ) {
	print "Updating to version 1914\n";
	my $ac = sql::start_transaction( $dbh );
	sql::update( undef, undef, 'service_types',['strdetailedurl=?','bind/padding.html'], 'strdetailedurl', 'bind/Padding.html' );
	sql::insert( undef, undef, 'database_info', 'version', 1914, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1914;
} # end if
my $new_version = 1921;
if ( $version < $new_version ) {
	print "Updating to version $new_version\n";
	my $ac = sql::start_transaction( $dbh );
	sql::insert( undef, undef, 'database_info', 'version', $new_version, 'backup', $backup );
	foreach my $E ( openprint::Equipment->find(Specifications=>{Type=>'Press'}) ) {
		if ( ( $_ = $E->specification('Double Overs For Covers') ) and ( $_ eq 'Y' ) ) {
			sql::insert( undef, undef, 'tbl_Equipment_Specifications',[
					'lngEquipmentIndex',    $E->id(),
					'dblMin',               undef,
					'dblMax',               undef,
					'strUnits',             'Percent',
					'strName',              'Covers Overs Percentage',
					'strValue',             100,
					'interpolate',          0,
					] );

		} else {
			sql::insert( undef, undef, 'tbl_Equipment_Specifications',[
					'lngEquipmentIndex',    $E->id(),
					'dblMin',               undef,
					'dblMax',               undef,
					'strUnits',             'Percent',
					'strName',              'Covers Overs Percentage',
					'strValue',             0,
					'interpolate',          0,
					] );
		} # end if
		sql::execute( undef, undef, 'DELETE FROM tbl_Equipment_Specifications WHERE lngEquipmentindex=? AND strname=?', $E->id(), 'Double Overs For Covers' );
	} # end foreac E
	sql::end_transaction( $dbh, $ac );
	$version = $new_version;
} # end if

if ( ! sets::isin( 'paper_prices', \@tables ) ) {
	load_sql( 'Paper_Prices' );
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='paper_prices'", 'column_name');
	if ( ! exists $$data{equipment_id} ) {
		$dbh->do('ALTER TABLE paper_prices add equipment_id INTEGER');
		$dbh->do('ALTER TABLE paper_prices add FOREIGN KEY (equipment_id) REFERENCES tbl_Equipment (id)');
	} # end if
	if ( ! exists $$data{service} ) {
		$dbh->do('ALTER TABLE paper_prices add service text');
		$dbh->do(q`UPDATE paper_prices set service='Material'`);
	} # end if
} # end if
foreach my $PP ( openprint::PaperPrice->find('units'=>'Per M') ) {
	$PP->cost( sprintf('%.2f', $PP->cost() * 100 / $PP->Paper()->mweight() ) );
	$PP->price( sprintf('%.2f', $PP->price() * 100 / $PP->Paper()->mweight() ) );
	$PP->units('Per 100lbs');
	$PP->save();
}
if ( ! sets::isin( 'companies_accountingcontacts', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Companies_AccountingContacts.sql}) );
} # end if

if ( 0 and my $PaddingServiceType = openprint::ServiceType->find_one('name'=>'Padding') ) {
	sql::update( undef, undef, 'tbl_service_defaults', ['lngservicetypeindex=? AND strfieldname=? AND strdefaultvalue=?',
			$PaddingServiceType->id(), 'rdbCardboardBacking','Y'], [ 'strfieldname', 'Backing', 'strdefaultvalue', 'Cardboard' ] );
	sql::update( undef, undef, 'tbl_service_defaults', ['lngservicetypeindex=? AND strfieldname=? AND strdefaultvalue=?',
			$PaddingServiceType->id(), 'rdbCardboardBacking','N'], [ 'strfieldname', 'Backing', 'strdefaultvalue', 'None']  );
} # end if

if ( ! sets::isin( 'projecttype_blockedservices', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/ProjectType_BlockedServices.sql}) );
} # end if

if ( sets::isin( 'tbl_projecttype_defaults', \@tables ) ) {
	$dbh->do('alter table tbl_projecttype_defaults rename to projecttype_defaults');
	@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
} 

if ( ! sets::isin( 'projecttype_defaults', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/ProjectType_Defaults.sql}) );
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='projecttype_defaults'", 'column_name');
	if ( ! exists $$data{id} ) {
		$dbh->do('ALTER TABLE projecttype_defaults ADD id SERIAL');
		$dbh->do('ALTER TABLE projecttype_defaults ADD PRIMARY KEY (id)');
	} # end if
	if ( exists $$data{strfieldname} ) {
		if ( ! exists $$data{name} ) {
			$dbh->do('ALTER TABLE projecttype_defaults RENAME strfieldname to name');
		} # end if
	}
	if ( exists $$data{strdefaultvalue} ) {
		$dbh->do('ALTER TABLE projecttype_defaults RENAME strdefaultvalue to value');
	} # end if
} # end if
sql::update( undef, undef, 'projecttype_defaults', ['name=? AND value=?','rdbCardboardBacking','Y'], [ 'name', 'Backing', 'value', 'Cardboard' ] );
sql::update( undef, undef, 'projecttype_defaults', ['name=? AND value=?','rdbCardboardBacking','N'], [ 'name', 'Backing', 'value', 'None']  );

foreach my $PT ( openprint::ProjectType->find() ) {
	if ( $PT->name() =~ / / ) {
		$_ = $PT->name();
		$_ =~ s/ //g;
		$PT->name( $_ );
		$PT->save();
	} # end if
} # end foreach
if ( ! sets::isin( 'projecttemplate', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/ProjectType_Templates.sql}) );
	die if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='projecttemplate'", 'column_name');
	if ( ! exists $$data{message} ) {
		$dbh->do('ALTER TABLE projecttemplate ADD message TEXT');
	}
	if ( ! exists $$data{name} ) {
		$dbh->do('ALTER TABLE projecttemplate ADD name TEXT');
		$dbh->do('UPDATE projecttemplate set name=type');
	}
} # end if

my $hosts_table;
if ( ! sets::isin( 'hosts', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Hosts.sql}) );
	$hosts_table = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='hosts'", 'column_name');
} else {
	$hosts_table = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='hosts'", 'column_name');
	if ( ! exists $$hosts_table{dhcp} ) {
		$dbh->do('ALTER TABLE hosts add dhcp boolean default false');
	} # end if
	if ( ! exists $$hosts_table{count} ) {
		$dbh->do('ALTER TABLE hosts add count integer');
	} # end if
	$dbh->do('ALTER TABLE hosts ALTER count SET default 0') or die $openprint::dbh->errstr();
	$dbh->do('UPDATE hosts SET count=0 WHERE count IS NULL') or die $openprint::dbh->errstr();
	$dbh->do('ALTER TABLE hosts ALTER count SET NOT NULL') or die $openprint::dbh->errstr();

	if ( ! exists $$hosts_table{location_id} ) {
		$dbh->do('ALTER TABLE hosts add location_id INTEGER');
		$dbh->do('ALTER TABLE hosts add FOREIGN KEY (location_id) REFERENCES Locations (id)');
	} # end if
	if ( ! exists $$hosts_table{resolved_on} ) {
		$dbh->do('ALTER TABLE hosts ADD resolved_on TIMESTAMP WITH TIME ZONE');
	} # end if
	if ( ! exists $$hosts_table{notify_frequency} ) {
		$log->debug("Add notify_frequency to hosts");
		$dbh->do('ALTER TABLE hosts ADD notify_frequency INTEGER');
	} # end if
}

if ( ! sets::isin( 'host_interfaces', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Host_Interfaces.sql}) );
	if ( exists $$hosts_table{mac} ) {
	$dbh->do('INSERT INTO host_interfaces (host_id, mac,ip, dhcp) SELECT id,unnest(mac),ip, dhcp FROM hosts');
	$dbh->do('INSERT INTO host_interfaces (host_id, mac,ip, dhcp) SELECT id,NULL,ip, dhcp from hosts where mac IS NULL');
	$dbh->do('ALTER TABLE Hosts drop mac');
	$dbh->do('ALTER TABLE Hosts drop ip');
	$dbh->do('ALTER TABLE Hosts drop dhcp');
	}
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='host_interfaces'", 'column_name');
	if ( ! exists $$data{id} ) {
		$dbh->do('ALTER TABLE host_interfaces ADD id serial');
		$dbh->do('ALTER TABLE host_interfaces ADD PRIMARY KEY (id)');
	}
	#my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='hosts'", 'column_name');
	if ( exists $$data{dhcp} ) {
		$dbh->do('ALTER TABLE hosts DROP dhcp');
	} # end if
	if ( ! exists $$data{connected_to} ) {
		$log->debug("Adding connected_to to host_interfaces");
		$dbh->do('ALTER TABLE host_interfaces ADD connected_to macaddr') or die $openprint::dbh->errstr();
	}
	if ( ! exists $$data{monitor} ) {
		$log->debug("Adding connected_to to host_interfaces");
		$dbh->do('ALTER TABLE host_interfaces ADD monitor boolean not null default false') or die $openprint::dbh->errstr();
		$dbh->do('UPDATE host_interfaces SET monitor=(SELECT monitored from hosts where id=host_id) WHERE host_id IN (SELECT id FROM hosts WHERE monitor=true)') or die $openprint::dbh->errstr();
	}
	if ( ! exists $$data{online} ) {
		$log->debug("Adding online to host_interfaces");
		$dbh->do('ALTER TABLE host_interfaces ADD online boolean') or die $openprint::dbh->errstr();
	}
}
if ( ! sets::isin( 'host_info', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Host_Info.sql}) );
}

if ( sets::isin('log',\@tables ) ) {
	if ( ! sets::isin('logs',\@tables ) ) {
		$dbh->do('ALTER TABLE log RENAME TO logs');
	} else {
		$dbh->do('DROP TABLE log');
	} # end if
} # end if

if ( ! sets::isin('logs',\@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Logs.sql}) );
	die if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='logs'", 'column_name');
	if ( ! exists $$data{host_id} ) {
		$dbh->do('ALTER TABLE logs add host_id INTEGER');
		$dbh->do('ALTER TABLE Logs add FOREIGN KEY (host_id) REFERENCES Hosts (id)');
	} # end if
	$dbh->do('ALTER TABLE Logs DROP COLUMN ip_address') if ( exists $$data{ip_address} );
	$dbh->do('ALTER TABLE Logs DROP COLUMN hostname') if ( exists $$data{hostname} );
} # end if
if ( 0 and ! openprint::Host->find_one() ) {
	foreach my $Log ( openprint::Log->find('host_id'=>undef) ) {
		my $data = $openprint::dbh->selectrow_hashref( "SELECT * FROM Log WHERE id=$$Log{id}", {} );
		next if ! $$data{ip_address};
		my $Host = openprint::Host->find_one('ip'=>$$data{ip_address});
		if ( ! $Host ) {
			$Host = new openprint::Host();
			$Host->save({'ip'=>$$data{ip_address},'hostname'=>$$data{hostname}});
		} # end if
		$Log->save({'host_id'=>$Host->id()}) if $Host->id();
		die if $dbh->errstr();
	} # end foreach Log
} # end if

foreach my $c ( 1 .. 4 ) {
	foreach my $Service ( openprint::Service->find('name'=>$c.'ColourImpressionPerfecting') ) {
		$_ = $Service->save({'name'=>'PerfectingImpression'.$c.'/'.$c});
		print $_ if $_;
		foreach my $c2 ( $c .. 4 ) {
			my $Second = openprint::Service->find_one( name=>$c2.'ColourImpressionPerfecting');
			if ( $Second ) {
				my $New = $Second->copy();
				$New->save({name=>'PerfectingImpression'.$c2.'/'.$c});
				foreach my $P ( $Second->prices() ) {
					my $c_price = openprint::ServicePrice->find_one( service_id=>$$Service{id}, min=>$$P{min} );
					if ( $c_price ) {
						$P = $P->copy();
						$P->save({service_id=>$$New{id},cost=>($$P{cost}+$$c_price{cost})/2, price=>($$P{price}+$$c_price{price})/2});
					} # end if
				} # end if
			} # end if
		} # end foreach c .. 4
	} # end foreach Service
} # end foreach 1 .. 4
foreach my $Service ( openprint::Service->find('name'=>'2ColourImpressionPerfecting') ) {
	$_ = $Service->save({'name'=>'PerfectingImpression2/2'});
	print $_ if $_;
} # end foreach Service
foreach my $Service ( openprint::Service->find('name'=>'3ColourImpressionPerfecting') ) {
	$_ = $Service->save({'name'=>'PerfectingImpression3/3'});
	print $_ if $_;
} # end foreach Service
foreach my $Service ( openprint::Service->find('name'=>'4ColourImpressionPerfecting') ) {
	$_ = $Service->save({'name'=>'PerfectingImpression4/4'});
	print $_ if $_;
} # end foreach Service
if ( sets::isin('product_id_seq', \@sequences ) ) {
	$dbh->do('ALTER SEQUENCE product_id_seq RENAME TO products_id_seq');
}

foreach my $aq ( 'Gloss', 'Matte', 'Satin', 'SoftTouch' ) {
foreach my $S ( openprint::Service->find('name'=>'Aqueous '.$aq) ) {
	if ( $S->category() ne 'Coating' ) {
		$S->save({'category'=>'Coating'});
	} # end if
} # end foreach
}
if ( ! sets::isin( 'mars', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/mars.sql}) );
	die $dbh->errstr() if $dbh->errstr();
}

if ( ! sets::isin( 'car', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/CAR.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='car'", 'column_name');
	if ( ! exists $$data{reprint_quantity} ) {
		$dbh->do('ALTER TABLE car ADD reprint_quantity INTEGER');
	}
	if ( ! exists $$data{reprint_value} ) {
		$dbh->do('ALTER TABLE car ADD reprint_value NUMERIC(10,2)');
	}
} # en dif

if ( ! sets::isin( 'usergroups', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Usergroups.sql}) );
	die if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='usergroups'", 'column_name');
	if ( ! $$data{duration} ) {
		$dbh->do('ALTER TABLE usergroups ADD duration INTERVAL');
	} # end if
	if ( ! $$data{asset_id} ) {
		$dbh->do('ALTER TABLE usergroups ADD asset_id INTEGER');
		$dbh->do('ALTER TABLE usergroups ADD FOREIGN KEY (asset_id) REFERENCES Assets (id)');
	} # end if
	if ( ! $$data{description} ) {
		$log->debug("Add description to usergroups");
		$dbh->do('ALTER TABLE usergroups ADD description TEXT') or die $dbh->errstr();
	} # end if
} # end if
if ( ! sets::isin( 'users_in_usergroups', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Users_in_Usergroups.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'marketing_categories', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Marketing_Categories.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'users_in_marketing_categories', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Users_In_Marketing_Categories.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'companies_in_marketing_categories', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Companies_In_Marketing_Categories.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'bitcoin_addresses', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Bitcoin_Addresses.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'blocklist', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Blocklist.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='blocklist'", 'column_name');
	if ( ! exists $$data{reason} ) {
		$dbh->do('ALTER TABLE blocklist ADD reason TEXT');
	}
	if ( ! exists $$data{unblock} ) {
		$dbh->do('ALTER TABLE blocklist ADD unblock BOOLEAN NOT NULL DEFAULT false');
	}
} # end if
if ( ! sets::isin( 'lexicon', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Lexicon.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'assistants', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Assistants.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'rma_types', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/RMA_Types.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'rma_priorities', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/RMA_Priorities.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'rma_statuses', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/RMA_Statuses.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='rma_statuses'", 'column_name');
	if ( ! exists $$data{current_status_id} ) {
		$dbh->do('ALTER TABLE rma_statuses ADD current_status_id INTEGER[]');
	} # end if
} # end if
if ( ! sets::isin( 'rma', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/RMA.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='rma'", 'column_name');
	if ( ! exists $$data{updated_on} ) {
		$dbh->do('ALTER TABLE rma ADD updated_on TIMESTAMP WITH TIME ZONE NOT NULL default NOW()');
	} # end if
	if ( ! exists $$data{received_on} ) {
		$dbh->do('ALTER TABLE rma ADD received_on TIMESTAMP WITH TIME ZONE NOT NULL default NOW()');
	} # end if
	if ( ! exists $$data{approved} ) {
		$dbh->do('ALTER TABLE rma add approved BOOLEAN NOT NULL DEFAULT FALSE');
	} # end if
	if ( exists $$data{approve} ) {
		$dbh->do(q`UPDATE rma SET approved=true WHERE approve='Y'`);
		$dbh->do('ALTER TABLE rma DROP approve');
	} # end if
	if ( ! exists $$data{type_id} ) {
		$dbh->do('ALTER TABLE rma ADD type_id INTEGER');
		$dbh->do('ALTER TABLE rma ADD FOREIGN KEY (type_id) REFERENCES RMA_Types (id)');
	} # end if
	if ( exists $$data{type} ) {
		foreach my $type ( sql::execute( undef, undef, 'SELECT DISTINCT type FROM RMA' ) ) {
			next if ! openprint::RMA_Type->transform('name',$type);
			if ( ! openprint::RMA_Type->find_one(name=>$type) ) {
				my $Type = new openprint::RMA_Type();
				$Type->save({name=>$type});
			} # end if
		} # end foreach
		$dbh->do('UPDATE rma set type_id=(SELECT id FROM rma_types WHERE name=type)');
		$dbh->do('ALTER TABLE rma DROP type');
	} # end if
	if ( ! exists $$data{status_id} ) {
		if ( exists $$data{statusid} ) {
			$dbh->do('ALTER TABLE rma RENAME column statusid TO status_id');
		} else {
		$dbh->do('ALTER TABLE rma ADD status_id INTEGER');
		} # end if
		$dbh->do('ALTER TABLE rma ADD FOREIGN KEY (status_id) REFERENCES RMA_Statuses (id)');
	} # end if
	if ( ! exists $$data{tester_id} ) {
		$dbh->do('ALTER TABLE RMA ADD tester_id INTEGER');
		$dbh->do('ALTER TABLE RMA ADD FOREIGN KEY (tester_id) REFERENCES Users (id)');
		if ( exists $$data{tester} ) {
			foreach my $tester ( sql::execute( undef, undef, 'SELECT DISTINCT tester FROM RMA')) {
				my $User = openprint::User->find_one('firstname lc'=>lc openprint::User->transform('firstname', $tester) );
				if ( ! $User ) {
					$User = new openprint::User();
					$_ = $User->save({firstname=>$tester,email=>$tester} );
					die $_ if $_;
				} # end if
				sql::update( undef, undef, 'rma', [ 'tester=?', $tester ], 'tester_id', $User->id() );
			} # end foreach po
			$dbh->do('ALTER TABLE RMA DROP tester');
		} # end if
	} # end if
	if ( ! exists $$data{po_id} ) {
		$dbh->do('ALTER TABLE RMA ADD po_id INTEGER');
		$dbh->do('ALTER TABLE RMA ADD FOREIGN KEY (po_id) REFERENCES PurchaseOrders (id)');
		if ( exists $$data{ponumber} ) {
			foreach my $po ( sql::execute( undef, undef, 'SELECT DISTINCT ponumber FROM RMA')) {
				my $PO = openprint::PurchaseOrder->find_one(num=>$po);
				if ( ! $PO ) {
					$PO = new openprint::PurchaseOrder();
					$_ = $PO->save({num=>$po}, 1);
					die $_ if $_;
				} # end if
				sql::update( undef, undef, 'rma', [ 'ponumber=?', $po ], 'po_id', $PO->id() );
			} # end foreach po
			$dbh->do('ALTER TABLE RMA DROP ponumber');
		} # end if
	} # end if
	if ( ! exists $$data{description} ) {
		if ( exists $$data{customer_problem} ) {
			$dbh->do('ALTER TABLE RMA rename column customer_problem to description');
		} else {
			$dbh->do('ALTER TABLE RMA add description TEXT');
		} # end if
	} # end if
	if ( ! exists $$data{comments} ) {
		if ( exists $$data{remarks} ) {
			$dbh->do('ALTER TABLE RMA rename column remarks to comments');
		} else {
			$dbh->do('ALTER TABLE RMA add comments TEXT');
		} # end if
	} # end if
	if ( ! exists $$data{priority_id} ) {
		$dbh->do('ALTER TABLE RMA ADD priority_id integer');
		$dbh->do('ALTER TABLE RMA ADD FOREIGN KEY (priority_id) REFERENCES RMA_Priorities (id)');
	} # end i
	if ( exists $$data{priority} ) {
		$dbh->do('ALTER TABLE RMA DROP priority');
	} # end if
	if ( ! exists $$data{warranty} ) {
		$dbh->do('ALTER TABLE RMA ADD warranty text');
	} # end i
	if ( ! exists $$data{estimate_required} ) {
		$dbh->do('ALTER TABLE RMA ADD estimate_required BOOLEAN');
	} # end i
	if ( ! exists $$data{created_on} ) {
		$dbh->do('ALTER TABLE RMA ADD created_on TIMESTAMP WITH TIME ZONE');
		$dbh->do('UPDATE RMA set created_on=received_on');
		$dbh->do('ALTER TABLE RMA ALTER created_on set default NOW()');
		$dbh->do('ALTER TABLE RMA ALTER created_on set NOT NULL');
	} # end if
	if ( ! exists $$data{product_id} ) {
		my $ac = sql::start_transaction( $dbh );
		$dbh->do('ALTER TABLE rma ADD product_id INTEGER');
		$dbh->do('ALTER TABLE rma ADD FOREIGN KEY (product_id) REFERENCES Products (id)');
		if ( exists $$data{unitname} ) {
			foreach my $product ( sql::execute( undef, undef, 'SELECT distinct unitname FROM rma' ) ) {
				next if ! $product;
				my $Product = openprint::Product->find_one('name lc'=>lc openprint::Product->transform('name', $product ) );
				if ( ! $Product ) {
					$Product = new openprint::Product();
					$_ = $Product->save({name=>$product});
					die $_ if $_;
				} # end if
				sql::update(undef,undef, 'rma', [ 'unitname=?', $product ], 'product_id', $Product->id() );
			} # end foreach
			$dbh->do('ALTER TABLE rma DROP unitname');
		} # end if
		sql::end_transaction( $dbh, $ac );
	} # end if
	if ( ! exists $$data{shipto_address_id} ) {
		$dbh->do('ALTER TABLE rma add shipto_address_id INTEGER');
		$dbh->do('ALTER TABLE rma add FOREIGN KEY (shipto_address_id) REFERENCES Addresses (id)');
	} # end if
	if ( ! exists $$data{project_id} ) {
		$dbh->do('ALTER TABLE rma ADD project_id INTEGER');
		$dbh->do('ALTER TABLE rma ADD FOREIGN KEY (project_id) REFERENCES projects (id)');
	} # end if
	if ( ! exists $$data{order_id} ) {
		$dbh->do('ALTER TABLE rma ADD order_id INTEGER');
		$dbh->do('ALTER TABLE rma ADD FOREIGN KEY (order_id) REFERENCES orders (id)');
	} # end if
	if ( ! exists $$data{user_id} ) {
		$dbh->do('ALTER TABLE rma ADD user_id INTEGER');
		$dbh->do('ALTER TABLE rma ADD FOREIGN KEY (user_id) REFERENCES users (id)');
	} # end if
	if ( ! sets::isin( 'rma_id_seq', \@sequences ) ) {
		$dbh->do('CREATE SEQUENCE rma_id_seq');
	} # end if
	$dbh->do(q`select setval('rma_id_seq',(SELECT Max(id) FROM RMA));`);
	if ( !exists $$data{rmanumber} ) {
		$dbh->do('ALTER TABLE rma ADD rmanumber TEXT');
	} # end if
	
} # end if
if ( ! sets::isin( 'rma_logs', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/RMA_Logs.sql}) );
	die $dbh->errstr() if $dbh->errstr();
}
if ( ! sets::isin( 'glossary', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Glossary.sql}) );
	die $dbh->errstr() if $dbh->errstr();
}
if ( ! sets::isin( 'faults', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Faults.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='faults'", 'column_name');
	if ( exists $$data{faults} ) {
		$dbh->do('ALTER TABLE faults RENAME COLUMN faults to name');
	} 
	if ( exists $$data{faultdescription} ) {
		$dbh->do('ALTER TABLE faults RENAME COLUMN faultdescription to description');
	} 
	$dbh->do(q`SELECT setval('faults_id_seq', (SELECT MAX(id) FROM Faults) )`);
}
if ( ! sets::isin( 'faults_found', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Faults_Found.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='faults_found'", 'column_name');
	if ( ! exists $$data{fault_id} ) {
		my $ac = sql::start_transaction( $dbh );
		$dbh->do('ALTER TABLE faults_found ADD fault_id INTEGER');	
		$dbh->do('ALTER TABLE faults_found ADD FOREIGN KEY (fault_id) REFERENCES Faults (id)');	
		if ( exists $$data{faults} ) {
			require openprint::Fault;
			$dbh->do('UPDATE faults_found SET fault_id = (SELECT id FROM Faults WHERE faults.name=faults_found.faults)');
			die $dbh->errstr() if $dbh->errstr();
			foreach my $fault ( sql::execute( undef, undef, 'SELECT DISTINCT faults FROM faults_found WHERE fault_id IS NULL' ) ) {
				next if ! $fault;
				my $Fault = openprint::Fault->find_one('name lc'=>lc $fault);
				if ( ! $Fault ) {
					$Fault = new openprint::Fault();
					$_ = $Fault->save({name=>$fault});
					die $_ if $_;
				} # end if
				sql::update( undef, undef, 'faults_found', [ 'faults=?', $fault ], 'fault_id', $Fault->id() );
			} # end foreach fault
			$dbh->do('ALTER TABLE Faults_Found DROP Faults');
		} # end if
		sql::end_transaction( $dbh, $ac );
	} # end if
	if ( exists $$data{fauldescription_action_taken} ) {
		$dbh->do('ALTER TABLE faults_found RENAME COLUMN FaulDescription_Action_Taken TO action');
	} 
	if ( exists $$data{faultqty} ) {
		$dbh->do('ALTER TABLE faults_found RENAME COLUMN Faultqty TO quantity');
	} # end if	
	if ( ! exists $$data{user_id} ) {
		my $ac = sql::start_transaction( $dbh );
		$dbh->do('ALTER TABLE faults_found ADD column user_id INTEGER');
		$dbh->do('ALTER TABLE faults_found ADD FOREIGN KEY (user_id) REFERENCES Users (id)');
		if ( exists $$data{repairedby} ) {
			my @data = sql::execute( undef, undef, 'SELECT id, repairedby FROM RMA' );
			require openprint::Fault_Found;
			while ( my ( $rma_id, $repaired_by ) = splice @data,0, 2 ) {
				next if ! $repaired_by;
				my $User = openprint::User->find_one('firstname lc'=>lc $repaired_by);
				if ( ! $User ) {
					$User = new openprint::User();
					$_ = $User->save({firstname=>$repaired_by, type=>'E' });
					die $_ if $_;
				} # end if
				sql::update(undef,undef,'faults_found', [ 'rma_id=?', $rma_id ], 'user_id', $User->id() );
			} # end while
			die $dbh->errstr() if $dbh->errstr();
			$dbh->do('ALTER TABLE RMA DROP repairedby');
		} # end if
		sql::end_transaction( $dbh, $ac );
	} # end if
	if ( ! exists $$data{repaired_on}  ) {
		my $ac = sql::start_transaction( $dbh );
		$dbh->do('ALTER TABLE Faults_Found ADD COLUMN repaired_on TIMESTAMP WITH TIME ZONE');
		if ( exists $$data{daterepaired} ) {
			my @data = sql::execute( undef, undef, 'SELECT id, daterepaired FROM RMA' );
			require openprint::Fault_Found;
			while ( my ( $rma_id, $repaired_on ) = splice @data,0, 2 ) {
				next if ! $repaired_on;
				sql::update(undef,undef,'faults_found', [ 'rma_id=?', $rma_id ], 'repaired_on', $repaired_on );
			} # end while
			$dbh->do('ALTER TABLE Faults_Found ALTER repaired_on SET default NOW()');
			#$dbh->do('ALTER TABLE Faults_Found ALTER repaired_on SET not null');
			$dbh->do('ALTER TABLE RMA DROP daterepaired');
			die $dbh->errstr() if $dbh->errstr();
		} # end if
		sql::end_transaction( $dbh, $ac );
	} # end if 
}
@sequences = sql::execute( undef, undef, q`SELECT sequence_name FROM information_schema.sequences where sequence_schema='public'`);
if ( ! sets::isin( 'faults_found_id_seq', \@sequences ) ) {
	if ( sets::isin( 'fault_found_id_seq', \@sequences ) ) {
		$dbh->do('ALTER SEQUENCE fault_found_id_seq RENAME TO faults_found_id_seq');
	} else {
		$dbh->do('CREATE SEQUENCE faults_found_id_seq');
	} # end if
	$dbh->do(q`ALTER TABLE Faults_Found ALTER ID SET default nextval('faults_found_id_seq')` );
	$dbh->do(q`SELECT setval( 'faults_found_id_seq', (SELECT max(id) FROM rma) )`);
} # end if

if ( ! sets::isin( 'tests', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Tests.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='tests'", 'column_name');
	if ( ! exists $$data{mandatory} ) {
		$dbh->do('ALTER TABLE tests ADD mandatory   BOOLEAN NOT NULL DEFAULT False');
	} # end if
} 
if ( ! sets::isin( 'test_result_results', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Test_Result_Results.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} 
if ( ! sets::isin( 'test_results', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Test_Results.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='test_results'", 'column_name');
	if ( exists $$data{technician} ) {
		if ( ! exists $$data{technician_id} ) {
			$dbh->do('ALTER TABLE test_results ADD technician_id INTEGER');
			$dbh->do('ALTER TABLE test_results ADD FOREIGN KEY (technician_id) REFERENCES Users (id)');
		} # end if
		$dbh->do('UPDATE test_results set technician_id =(SELECT id FROM Users WHERE firstname=technician)');
		foreach my $name ( sql::execute(undef,undef, 'SELECT DISTINCT technician FROM test_results WHERE technician_id IS NULL')){
			next if ! $name;
			my $User = openprint::User->find_one('firstname lc'=> lc $name);
			if ( ! $User ) {
				$User = new openprint::User();
				$_ = $User->save({
					firstname=>$name,
					type	=>	'E',
				});
				die $_ if $_;
			} # end if
			sql::update( undef, undef, 'test_results', [ 'technician=?', $name ], 'technician_id', $User->id() );
		} # end foreach
		$dbh->do('ALTER TABLE test_results DROP technician');
	} # end if exists technician
	if ( exists $$data{employeename} ) {
		if ( ! exists $$data{employee_id} ) {
			$dbh->do('ALTER TABLE test_results ADD employee_id INTEGER');
			$dbh->do('ALTER TABLE test_results ADD FOREIGN KEY (employee_id) REFERENCES Users (id)');
		} # end if
		$dbh->do('UPDATE test_results set employee_id =(SELECT id FROM Users WHERE firstname=employeename)');
		foreach my $name ( sql::execute(undef,undef, 'SELECT DISTINCT employeename FROM test_results WHERE employee_id IS NULL')){
			next if ! $name;
			my $User = openprint::User->find_one('firstname lc'=> lc $name);
			if ( ! $User ) {
				$User = new openprint::User();
				$_ = $User->save({
					firstname=>$name,
					type	=>	'E',
				});
				die $_ if $_;
			} # end if
			sql::update( undef, undef, 'test_results', [ 'employeename=?', $name ], 'employee_id', $User->id() );
		} # end foreach
		$dbh->do('ALTER TABLE test_results DROP employeename');
	} # end if
	if ( exists $$data{wtest} ) {
		require openprint::Test_Result_Result;
		if ( ! exists $$data{result_id} ) {
			$dbh->do('ALTER TABLE test_results ADD result_id INTEGER');
			$dbh->do('ALTER TABLE test_results ADD FOREIGN KEY (result_id) REFERENCES Test_Result_Results (id)');
		} # end if
		$dbh->do('UPDATE test_results set result_id =(SELECT id FROM Test_Result_Results WHERE name=wtest)');
		foreach my $name ( sql::execute(undef,undef, 'SELECT DISTINCT wtest FROM test_results WHERE result_id IS NULL')){
			my $Result = openprint::Test_Result_Result->find_one('name lc'=>$name);
			if ( ! $Result ) {
				$Result = new openprint::Test_Result_Result();
				$_ = $Result->save({
					name=>$name,
				});
				die $_ if $_;
			} # end if
			sql::update( undef, undef, 'test_results', [ 'wtest=?', $name ], 'result_id', $Result->id() );
		} # end foreach
		$dbh->do('ALTER TABLE test_results DROP wtest');
	} # end if
	if ( exists $$data{wdate} ) {
		$dbh->do('ALTER TABLE test_results rename column wdate to tested_on');
	} 
	if ( exists $$data{problemlevel} ) {
			$dbh->do('ALTER TABLE test_results rename column problemlevel to problem_level');
	}
	if ( exists $$data{wremarks} ) {
		$dbh->do('ALTER TABLE test_results rename column wremarks to remarks');
	}
	if ( ! exists $$data{test_id} ) {
		$dbh->do('ALTER TABLE test_results add test_id INTEGER');
		$dbh->do('ALTER TABLE test_results add FOREIGN KEY (test_id) REFERENCES tests (id)');
		die $dbh->errstr() if $dbh->errstr();
	} # end if
	$dbh->do(q`SELECT setval( 'test_results_id_seq', (SELECT MAX(id) FROM test_results) )`);
}
if ( ! sets::isin( 'rma_parts', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/RMA_Parts.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='rma_parts'", 'column_name');
	if ( ! exists $$data{product_id} ) {
		my $ac = sql::start_transaction( $dbh );
		$dbh->do('ALTER TABLE rma_parts ADD product_id INTEGER');
		$dbh->do('ALTER TABLE rma_parts ADD FOREIGN KEY (product_id) REFERENCES Products (id)');
		if ( exists $$data{name} ) {
			foreach my $product ( sql::execute( undef, undef, 'SELECT distinct name FROM rma_parts' ) ) {
				my $Product = openprint::Product->find_one('name lc'=>lc openprint::Product->transform('name', $product ) );
				if ( ! $Product ) {
					$Product = new openprint::Product();
					$_ = $Product->save({name=>$product});
					die $_ if $_;
				} # end if
				sql::update(undef,undef, 'rma_parts', [ 'name=?', $product ], 'product_id', $Product->id() );
			} # end foreach
			$dbh->do('ALTER TABLE rma_parts DROP name');
		} # end if
		sql::end_transaction( $dbh, $ac );
	} # end if
} # end if
if ( sets::isin( 'upgrade_type', \@tables ) ) {
	$dbh->do('ALTER TABLE upgrade_type RENAME to Upgrade_Types') or die $dbh->errstr();
	$dbh->do('ALTER TABLE upgrade_types RENAME utype to name') or die $dbh->errstr();
	$dbh->do('ALTER TABLE upgrade_types RENAME ucategory to category') or die $dbh->errstr();
	$dbh->do('ALTER SEQUENCE upgrade_type_id_seq RENAME TO upgrade_types_id_seq') or die $dbh->errstr();
	$dbh->do(q`ALTER TABLE Upgrade_Types ALTER ID SET DEFAULT nextval('upgrade_types_id_seq')`) or die $dbh->errstr();
	@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
	@sequences = sql::execute( undef, undef, q`SELECT sequence_name FROM information_schema.sequences where sequence_schema='public'`);
} # end if
if ( ! sets::isin( 'upgrade_types', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Upgrade_Types.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} else {
	$dbh->do(q`SELECT setval('upgrade_types_id_seq', (SELECT MAX(id) FROM upgrade_types))`) or die $dbh->errstr();
}
if ( ! sets::isin( 'upgrades', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Upgrades.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} else {
	$dbh->do(q`SELECT setval('upgrades_id_seq', (SELECT MAX(id) FROM upgrades))`) or die $dbh->errstr();
}
if ( sets::isin( 'upgrade', \@tables ) ) {
	require openprint::Upgrade;
	my @data = sql::execute( undef, undef, 'SELECT * from Upgrade' );
	while ( my ( $id, $rma_id, $type, $firmware, $hardware, $board ) = splice ( @data, 0, 6 ) ) {
		next if ! $rma_id;
		my $U = new openprint::Upgrade();
		$_ = $U->save({rma_id=>$rma_id, type=>'Firmware', new_version=>$firmware } ) if $firmware;
		die $_ if $_;
		$U = new openprint::Upgrade();
		$_ = $U->save({rma_id=>$rma_id, type=>'Hardware', new_version=>$hardware} ) if $hardware;
		die $_ if $_;
		$U = new openprint::Upgrade();
		$_ = $U->save({rma_id=>$rma_id, type=>'Board', new_version=>$board} ) if $board;
		die $_ if $_;
	} # end while
	$dbh->do('DROP TABLE upgrade');
} # end if
if ( ! sets::isin( 'stockqualities', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/StockQualities.sql}) );
	die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='stockqualities'", 'column_name');
	if ( ! exists $$data{message} ) {
		$dbh->do('ALTER TABLE stockqualities ADD message text');
	} # end

}
if ( ! sets::isin( 'stockqualities_id_seq', \@sequences ) ) {
	if ( sets::isin( 'paperqualities_id_seq', \@sequences ) ) {
		$dbh->do('ALTER SEQUENCE paperqualities_id_seq RENAME to stockqualities_id_seq');
	} else {
		$dbh->do('CREATE SEQUENCE stockqualities_id_seq');
	} # end if
	$dbh->do(q`ALTER TABLE stockqualities ALTER id SET default nextval('stockqualities_id_seq')`);
	$dbh->do(q`SELECT setval('stockqualities_id_seq', (SELECT max(id) FROM stockqualities))`);
} # end if
if ( ! sets::isin( 'event_categories', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Event_Categories.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} 

if ( ! sets::isin( 'events', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Events.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='events'", 'column_name');
	if ( ! exists $$data{album_id} ) {
		$dbh->do(q`ALTER TABLE events add album_id INTEGER` );
		$dbh->do(q`ALTER TABLE events add FOREIGN KEY (album_id) REFERENCES photo_albums (id)` );
	} # end if
	if ( ! exists $$data{asset_id} ) {
		$dbh->do(q`ALTER TABLE events add asset_id INTEGER` );
		$dbh->do(q`ALTER TABLE events add FOREIGN KEY (asset_id) REFERENCES assets (id)` );
	} # end if
	if ( ! exists $$data{url} ) {
		$dbh->do(q`ALTER TABLE events add url TEXT` );
	} # end if
	if ( ! exists $$data{published} ) {
		$dbh->do(q`ALTER TABLE events add published BOOLEAN NOT NULL Default false` );
	} # end if
	if ( ! exists $$data{template} ) {
		$dbh->do(q`ALTER TABLE events add template BOOLEAN NOT NULL Default false` );
	} # end if
	if ( ! exists $$data{template_id} ) {
		$dbh->do(q`ALTER TABLE events add template_id INTEGER` );
		$dbh->do(q`ALTER TABLE events add FOREIGN KEY (template_id) REFERENCES Events (id)` );
	} # end if
} # end if
if ( ! sets::isin( 'event_attendance', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Event_Attendance.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'event_invitations', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Event_Invitations.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='event_invitations'", 'column_name');
	if ( ! exists $$data{sent_on} ) {
		$dbh->do('ALTER TABLE event_invitations ADD sent_on timestamp with time zone');
	} # end if
} # end if
if ( ! sets::isin( 'authorizations', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Authorizations.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='authorizations'", 'column_name');
	if ( ! exists $$data{setting} ) {
		$dbh->do('ALTER TABLE authorizations ADD setting TEXT' );
	} # end if
}
if ( ! sets::isin( 'page_settings', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Page_Settings.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='page_settings'", 'column_name');
	if ( ! exists $$data{keywords} ) {
		$dbh->do('ALTER TABLE page_settings add keywords TEXT');
	} # end if
	if ( ! exists $$data{description} ) {
		$dbh->do('ALTER TABLE page_settings add description TEXT');
	} # end if
	if ( ! exists $$data{user_ids} ) {
		$dbh->do('ALTER TABLE page_settings add user_ids INTEGER[]');
	} # end if
	if ( ! exists $$data{usergroup_ids} ) {
		$dbh->do('ALTER TABLE page_settings add usergroup_ids INTEGER[]');
	} # end if
	if ( ! exists $$data{message} ) {
		$dbh->do('ALTER TABLE page_settings ADD message TEXT');
	} # end if
}
my $data = 0;
if ( sets::isin( 'emailcampaigns', \@tables ) ) {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='emailcampaigns'", 'column_name');
	if ( ! exists $$data{deleted} ) {
		print "Adding deleted to email_campaigns\n";
		$dbh->do('ALTER TABLE emailcampaigns ADD deleted BOOLEAN NOT NULL default false');
	} # end if
} else {
	$_ = misc::load_file( $log, q{../openprint/sql/EmailCampaigns.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if

if ( sets::isin( 'trade_references', \@tables ) ) {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='trade_references'", 'column_name');
} else {
		$dbh->do( misc::load_file( $log, q{../openprint/sql/Trade_References.sql}) );
} # end if
if ( sets::isin( 'sales_logs', \@tables ) ) {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='sales_logs'", 'column_name');
} else {
	$log->debug("Adding Sales Logs");
		$dbh->do( misc::load_file( $log, q{../openprint/sql/Sales_Logs.sql}) ) or die $dbh->errstr();
} # end if

if ( ! sets::isin( 'inventory_checks', \@tables ) ) {
	$log->debug("Creating Inventory Checks Tables");
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Inventory_Checks.sql}) ) or die $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='inventory_checks'", 'column_name');
	if ( ! exists $$data{location_id} ) {
		$log->debug("Adding location_id to Invengtory_Checks");
		$dbh->do( 'ALTER TABLE inventory_checks add location_id INTEGER') or die $dbh->errstr();
		$dbh->do( 'ALTER TABLE inventory_checks add foreign key (location_id) REFERENCES Locations (id);') or die $dbh->errstr();
	}
}
if ( ! sets::isin( 'helpdesk', \@tables ) ) {
	$log->debug("Creating HelpDesk Table");
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Helpdesk.sql}) ) or die $dbh->errstr();
}
if ( sets::isin( 'invoice_logs', \@tables ) ) {
	$log->debug("deprecating invoice_logs");
	my $ac = sql::start_transaction( $dbh );
	my $sth = $dbh->prepare('SELECT * from Invoice_logs');
	my $res = $sth->execute() or die $dbh->errstr();
	while ( my $invoice_log = $sth->fetchrow_hashref() ) {
		my $action;
		if ( $$invoice_log{description} =~ /^Invoice updated/ ) {
			$action = 'Invoice Edit';
		} elsif ( $$invoice_log{description} =~ /^Invoice emailed/ ) {
			$action = 'Invoice Sent';
		} elsif ( $$invoice_log{description} =~ /^Sent/ ) {
			$action = 'Invoice Sent';
		} elsif ( $$invoice_log{description} =~ /^Emailed/ ) {
			$action = 'Invoice Sent';
		} elsif ( $$invoice_log{description} =~ /^Invoice posted/ ) {
			$action = 'Invoice Posted';
		} elsif ( $$invoice_log{description} =~ /^Invoice unposted/ ) {
			$action = 'Invoice Unposted';
		} elsif ( $$invoice_log{description} =~ /^Added/ ) {
			$action = 'Invoice Interest Added';
		} elsif ( $$invoice_log{description} eq '' ) {
			next;
		} else {
	die "unhandled desc: $$invoice_log{description}";
		}
		
		my $Log = (new openprint::Log())->save({
			object_id	=>	$$invoice_log{invoice_id},
			object_type	=>	'openprint::Invoice',
			user_id		=>	$$invoice_log{user_id},
			date_time	=>	$$invoice_log{created_on},
			note		=>	$$invoice_log{description},
			action		=>	$action,
		});
		die if $dbh->errstr();
    }
	sql::end_transaction( $dbh, $ac );

} # end if

if ( ! sets::isin( 'quote_log', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Quote_Log.sql}) );
} # end if
if ( ! sets::isin( 'quoted_products', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Quoted_Products.sql}) );
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='quoted_products'", 'column_name');
	if ( ! exists $$data{comments} ) {
		$dbh->do('ALTER TABLE quoted_products ADD comments TEXT');
	} # end if
} # end if

if ( sets::isin( 'quotes', \@tables ) ) {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='quotes'", 'column_name');
	if ( $data ) {
		$dbh->do('ALTER TABLE quotes add reference text') if ! exists $$data{reference};
		$dbh->do('ALTER TABLE quotes add comments text') if ! exists $$data{comments};
		$dbh->do('ALTER TABLE quotes add deleted boolean default false') if ! exists $$data{deleted};
	} # end if
} # end if
if ( sets::isin( 'invoiced_products', \@tables ) ) {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM invoiced_products LIMIT 1', {} );
	if ( $data ) {
		$dbh->do('ALTER TABLE invoiced_products add po text') if ! exists $$data{po};
	} # end if
} # end if
if ( sets::isin( 'hosts', \@tables ) ) {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='hosts'", 'column_name');
	$dbh->do('ALTER TABLE hosts add block boolean') if ! exists $$data{block};
	$dbh->do('ALTER TABLE hosts add monitor boolean') if ! exists $$data{monitor};
} # end if

my $data = 0;
if ( sets::isin( 'ordered_products', \@tables ) ) {
	$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM ordered_products LIMIT 1', {} );
} # end if
if ( $data ) {
	$dbh->do('ALTER TABLE Ordered_products drop column gst') if ( exists $$data{gst} );
	$dbh->do('ALTER TABLE Ordered_products drop column pst') if ( exists $$data{pst} );
	$dbh->do('ALTER TABLE Ordered_products drop column hst') if ( exists $$data{hst} );
}

if ( ! sets::isin( 'invoices', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Invoices.sql} ) );
}

if ( sets::isin( 'taxes', \@tables ) ) {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='taxes'", 'column_name');
	if ( $data ) {
		if ( exists $$data{dblfederalpercent} ) {
			$dbh->do('ALTER TABLE taxes rename column dblfederalpercent to federaltax');
		} 
		if ( exists $$data{dblstatepercent} ) {
			$dbh->do('ALTER TABLE taxes rename column dblstatepercent to statetax');
		} 
		if ( exists $$data{dblharmonisedpercent} ) {
			$dbh->do('ALTER TABLE taxes rename column dblharmonisedpercent to harmonizedtax');
		} 
		if ( ! exists $$data{name} ) {
			$dbh->do('ALTER TABLE taxes add name text');
		} # end if
		if ( ! exists $$data{rate} ) {
			$dbh->do('ALTER TABLE taxes add rate float');
			$dbh->do('UPDATE Taxes set rate=federaltax where federaltax IS NOT NULL');
			$dbh->do('UPDATE Taxes set rate=statetax where statetax IS NOT NULL');
			$dbh->do('UPDATE Taxes set rate=harmonizedtax where harmonizedtax IS NOT NULL');
		} # end if
		if ( ! exists $$data{period_start} ) {
			$dbh->do('ALTER TABLE taxes add period_start date');
		} # end if
		if ( ! exists $$data{period_end} ) {
			$dbh->do('ALTER TABLE taxes add period_end date');
		} # end if
		if ( exists $$data{federaltax} ) {
			$dbh->do('ALTER TABLE taxes DROP column federaltax');
		}
		if ( exists $$data{statetax} ) {
			$dbh->do('ALTER TABLE taxes DROP column statetax');
		}
		if ( exists $$data{harmonizedtax} ) {
			$dbh->do('ALTER TABLE taxes DROP column harmonizedtax');
		}
		$dbh->do(q`UPDATE Taxes set name='HST' WHERE country='CA'`);
	} # end if data
} else {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Taxes.sql' ) ) or die $dbh->errstr();
} # end if
if ( ! sets::isin('currency_conversions', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Currency_Conversions.sql}) );
	die if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='currency_conversions'", 'column_name');
	if ( ! exists $$data{period_start} ) {
		$dbh->do('ALTER TABLE currency_conversions ADD period_start TIMESTAMP WITH TIME ZONE');
	} # end if
	if ( ! exists $$data{period_end} ) {
		$dbh->do('ALTER TABLE currency_conversions ADD period_end TIMESTAMP WITH TIME ZONE');
	} # end if
	if ( ! exists $$data{id} ) {
		$dbh->do('ALTER TABLE currency_conversions ADD id SERIAL');
	} # end if
	$dbh->do( 'ALTER TABLE currency_conversions DROP CONSTRAINT currency_conversions_pkey');
	$dbh->do( 'ALTER TABLE currency_conversions ADD PRIMARY KEY (id)' );
	$dbh->do( 'DROP INDEX IF EXISTS currency_conversion_to_from_period_end_idx' );
	$dbh->do( 'CREATE INDEX currency_conversion_to_from_period_end_idx ON currency_conversions (to_id,from_id,period_end)' );
} # end if
if ( ! sets::isin( 'invoice_taxes', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Invoice_Taxes.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if

$dbh->do("UPDATE companies set country='CA' WHERE country='Canada'");
$dbh->do("UPDATE companies set state='ON' WHERE state='Ontario'");
$dbh->do("UPDATE taxes set country='CA' WHERE country='Canada'");
$dbh->do("UPDATE taxes set state='ON' WHERE state='Ontario'");
if ( ! openprint::Invoice_Tax->find_one() ) {
	my $ac = sql::start_transaction( $dbh );
	foreach my $Invoice ( openprint::Invoice->find() ) {
		my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM invoices WHERE id=? LIMIT 1', {}, $Invoice->id() );
		foreach my $Tax ( openprint::Tax->find(
					'country'			=>	$Invoice->Invoicee()->country(), 
					'state'				=>	$Invoice->Invoicee()->state(), 
					'period_start null_or_<='	=>	$Invoice->created_on(),
					'period_end null_or_>='		=>	$Invoice->created_on(),
			) ) {
			my $new_amount;

			if ( ( $Tax->name() eq 'GST' ) and ( $new_amount != $$data{federaltax} ) ) {
				$new_amount = $$data{federaltax};
			} elsif ( $Tax->name() eq 'PST' ) {
				if ( new openprint::Company( $config{owner} )->pst_number() and ( $new_amount != $$data{statetax} ) ) {
				$new_amount = $$data{statetax};
				} # end if
			} else {
				$new_amount = Math::Round::nearest(0.01, $Invoice->subtotal() * ( $Tax->rate()/100 ) );
			} # end if
				
			my $Invoice_Tax = new openprint::Invoice_Tax();
			$_ = $Invoice_Tax->save({
				'invoice_id'	=>	$Invoice->id(),
				'tax_id'		=>	$Tax->id(),
				'rate'			=>	$Tax->rate(),
				'amount'		=>	$new_amount,
			});
			die( $_ ) if $_;
		} # end foreach tax
	} # end foreach Invoice
	sql::end_transaction( $dbh, $ac );
} # end if

if ( ! sets::isin('order_taxes', \@tables ) ) {
	$dbh->do(misc::load_file( $log, '../openprint/sql/Order_Taxes.sql' ));
} # end if

if ( ! openprint::Order_Tax->find_one() ) {
	my $ac = sql::start_transaction( $dbh );
	foreach my $Order ( openprint::Order->find() ) {
		my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Orders WHERE id=? LIMIT 1', {}, $Order->id() );
		if ( ! $data ) {
			die 'Error loading order ' . $Order->id() . ' : ' . $openprint::dbh->errstr();
		} # end if
		foreach my $Tax ( openprint::Tax->find(
					'country'			=>	$Order->country(), 
					'state'				=>	$Order->state(), 
					'period_start null_or_<='	=>	$Order->created_on(),
					'period_end null_or_>='		=>	$Order->created_on(),
			) ) {
			my $new_amount = 0;

			if ( ( $Tax->name() eq 'GST' ) and ( $new_amount != $$data{curfedtax} ) ) {
				$new_amount = $$data{curfedtax};
			} elsif ( $Tax->name() eq 'PST' ) {
				if ( new openprint::Company( $config{owner} )->pst_number() and ( $new_amount != $$data{curprovtax} ) ) {
				$new_amount = $$data{curprovtax};
				} # end if
			} else {
				$new_amount = Math::Round::nearest(0.01, $Order->subtotal() * ( $Tax->rate()/100 ) );
			} # end if
				
			my $Order_Tax = new openprint::Order_Tax();
			$_ = $Order_Tax->save({
				'order_id'	=>	$Order->id(),
				'tax_id'		=>	$Tax->id(),
				'rate'			=>	$Tax->rate(),
				'amount'		=>	$new_amount,
			});
			die( $_ ) if $_;
		} # end foreach tax
	} # end foreachOrder 
	sql::end_transaction( $dbh, $ac );
} # end if
if ( ! sets::isin('purchaseorder_items', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/PurchaseOrder_Items.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if
if ( sets::isin('purchaseorders', \@tables ) ) {
	$data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='purchaseorders'", 'column_name');
	if ( $data ) {
		if ( ! exists $$data{manifest_id} ) {
			$dbh->do('ALTER TABLE purchaseorders add manifest_id integer');
			$dbh->do('ALTER TABLE purchaseorders add FOREIGN KEY (manifest_id) REFERENCES Manifests (id)');
		} # end if
		$dbh->do('ALTER TABLE purchaseorders add authorized boolean default false') if ! exists $$data{authorized};
		$dbh->do('ALTER TABLE purchaseorders add cancelled boolean default false') if ! exists $$data{cancelled};
		$dbh->do('ALTER TABLE purchaseorders add vendor_contact text') if ! exists $$data{vendor_contact};
		$dbh->do('ALTER TABLE purchaseorders add vendor_sms text') if ! exists $$data{vendor_sms};
		$dbh->do('ALTER TABLE purchaseorders add shipto_contact text') if ! exists $$data{shipto_contact};
		$dbh->do('ALTER TABLE purchaseorders add shipto_mobile text') if ! exists $$data{shipto_mobile};
		$dbh->do('ALTER TABLE purchaseorders add shipto_sms text') if ! exists $$data{shipto_sms};
		$dbh->do('ALTER TABLE purchaseorders add delivered_on_switch text') if ! exists $$data{delivered_on_switch};
	} # end if
} else {
	$_ = misc::load_file( $log, q{../openprint/sql/PurchaseOrders.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if
if ( sets::isin('purchaseorder_contents', \@tables ) ) {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='purchaseorder_contents'", 'column_name');
	if ( ! exists $$data{item_id} ) {
		$dbh->do('ALTER TABLE purchaseorder_Contents ADD item_id INTEGER');
		if ( exists $$data{item} ) {
			require openprint::PurchaseOrder_Item;
			foreach my $C ( openprint::PurchaseOrder_Content->find() ) {
				my $Item = openprint::PurchaseOrder_Item->find_one('name lc'=> lc $openprint::PurchaseOrder_Item->transform('name', $$C{item} ) );
				if ( ! $Item ) {
					$Item = new openprint::PurchaseOrder_Item();
					$Item->save({'name'=>$$C{item},'type_id'=>$$C{type_id},'price'=>$$C{price},'vendor_id'=>$C->PurchaseOrder()->supplier_id(),'company_id'=>$C->PurchaseOrder()->company_id()});
				} # end if
				$C->save({'item_id'=>$$Item{id}});
			} # end if
		} # end if
		#$dbh->do('alter table purchaseorder_contents drop column item');
	} # end if
	if ( ! exists $$data{created_on} ) {
		$dbh->do('ALTER TABLE PurchaseOrder_Contents ADD created_on TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()');
	} # end if
	if ( ! exists $$data{product} ) {
		$dbh->do('ALTER TABLE PurchaseOrder_Contents ADD product text');
	} # end if
} else {
	$_ = misc::load_file( $log, q{../openprint/sql/PurchaseOrder_Contents.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if
if ( ! sets::isin('purchaseorder_taxes', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/PurchaseOrder_Taxes.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if

if ( 0 ) {
	if ( ! openprint::PurchaseOrder_ContentType->find_one('name'=>'Other') ) {
		my $PO_CT = new openprint::PurchaseOrder_ContentType();
		$PO_CT->save({'name'=>'Other'});
	} # end if
	if ( ! openprint::PurchaseOrder_ContentType->find_one('name'=>'Roll Stock') ) {
		my $PO_CT = new openprint::PurchaseOrder_ContentType();
		$PO_CT->save({'name'=>'Roll Stock'});
	} # end if
	if ( ! openprint::PurchaseOrder_ContentType->find_one('name'=>'Sheet Stock') ) {
		my $PO_CT = new openprint::PurchaseOrder_ContentType();
		$PO_CT->save({'name'=>'Sheet Stock'});
	} # end if
} # end if

if ( $config{'Default State Tax'} ) {
	$dbh->do("DELETE FROM Configuration WHERE name='Default State Tax'");
}
if ( $config{'Default Federal Tax'} ) {
	$dbh->do("DELETE FROM Configuration WHERE name='Default Federal Tax'");
}
	
if ( sets::isin( 'tbl_service_defaults', \@tables ) ) {
	$data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='tbl_service_defaults'", 'column_name');
	if ( ! exists $$data{projecttype_id} ) {
		$dbh->do('ALTER TABLE tbl_service_defaults add projecttype_id INTEGER');
		$dbh->do('ALTER TABLE tbl_service_defaults add FOREIGN KEY (projecttype_id) REFERENCES project_types (id) ');
	} # end if
} # end if
if ( sets::isin( 'project_types', \@tables ) ) {
	$data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='project_types'", 'column_name');
	if ( ! exists $$data{type} ) {
		$dbh->do('ALTER TABLE project_types add type text');
		$dbh->do(q`UPDATE project_types SET type='SinglePage'`);
		$dbh->do(q`UPDATE project_types SET type='MultiPage' WHERE name='MultiPage'`);
		$dbh->do(q`UPDATE project_types SET type='MultiPage' WHERE name='MultiPagePublication'`);
		$dbh->do(q`UPDATE project_types SET type='MultiPage' WHERE name='Magazines'`);
		$dbh->do(q`UPDATE project_types SET type='MultiPage' WHERE name='Newsletters'`);
		$dbh->do(q`UPDATE project_types SET type='MultiPage' WHERE name='Calendars'`);
		die $dbh->errstr() if $dbh->errstr();
	} # end if
} # end if
if ( sets::isin( 'service_types', \@tables ) ) {
	$data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='service_types'", 'column_name');
	if ( ! exists $$data{projecttype_id} ) {
		$dbh->do('ALTER TABLE service_types add projecttype_id INTEGER');
		$dbh->do('ALTER TABLE service_types add FOREIGN KEY (projecttype_id) REFERENCES project_types (id)');
	} # end if
} # end if

if ( ! sets::isin('equipment_stock_settings', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Equipment_Stock_Settings.sql}) );
} # end if
if ( ! sets::isin('signaturecapture', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/SignatureCapture.sql}) );
} # end if
if ( sets::isin( 'emailcampaigns', \@tables ) ) {
$log->debug("has email_campaigns");
	$data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='emailcampaigns'", 'column_name');
	if ( ! $$data{nextrun} ) {
		$dbh->do( 'ALTER TABLE emailcampaigns add nextrun timestamp with time zone' );
	} # end if
	if ( ! exists $$data{email_to} ) {
$log->debug("Add email_to");
		$dbh->do('ALTER TABLE emailcampaigns add email_to text');
	} # end if
	if ( ! exists $$data{email_html} ) {
$log->debug("Add email_html");
		$dbh->do('ALTER TABLE emailcampaigns add email_html text');
	} # end if
} else {
	$log->debug("no has email_campaigns");
} # end if
if ( ! sets::isin( 'paycheques', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Paycheques.sql}) );
} # end if
if ( ! sets::isin( 'timetracks', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Timetracks.sql}) );
} else {
	$data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='timetracks'", 'column_name');
	if ( ! exists $$data{billable} ) {
		$dbh->do('ALTER TABLE timetracks ADD billable BOOLEAN NOT NULL default true');
	} # end if
	if ( ! exists $$data{po} ) {
		$dbh->do('ALTER TABLE timetracks ADD po TEXT');
	} # end if
	if ( ! exists $$data{duration} ) {
		$dbh->do('ALTER TABLE timetracks ADD duration INTERVAL');
	} # end if
	if ( ! exists $$data{duration_override} ) {
		$dbh->do('ALTER TABLE timetracks ADD duration_override BOOLEAN NOT NULL DEFAULT FALSE');
	} # end if
} # end if

if ( sets::isin('users', \@tables ) ) {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='users'", 'column_name');
	if ( ! exists $$data{asset_id} ) {
		$dbh->do('ALTER TABLE users add asset_id INTEGER');
	} # end if
	$dbh->do('ALTER TABLE Users ALTER company_id DROP NOT NULL');
	$dbh->do('ALTER TABLE Users ALTER password DROP NOT NULL');
	$dbh->do('ALTER TABLE Users ALTER firstname DROP NOT NULL');
} # end if

if ( ! sets::isin( 'expense_accounts', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Expense_Accounts.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
}
if ( ! sets::isin( 'expenses', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Expenses.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
} else {
my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='expenses'", 'column_name');
if ( ! exists $$data{amount_locked} ) {
	$dbh->do('ALTER TABLE expenses add amount_locked BOOLEAN NOT NULL default false');
}
if ( ! exists $$data{total_locked} ) {
	$dbh->do('ALTER TABLE expenses add total_locked BOOLEAN NOT NULL default false');
}
if ( ! exists $$data{attention} ) {
	$dbh->do('ALTER TABLE expenses add attention BOOLEAN NOT NULL default false');
}
if ( ! exists $$data{business_use_amount} ) {
	$dbh->do('ALTER TABLE expenses add business_use_amount float');
}
if ( ! exists $$data{account_id} ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Expense_Accounts.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
	$dbh->do('ALTER TABLE expenses add account_id INTEGER');
	$dbh->do('ALTER TABLE expenses add FOREIGN KEY (account_id) REFERENCES Expense_Accounts (id)');
}
if ( ! exists $$data{deleted} ) {
	$dbh->do('ALTER TABLE expenses ADD deleted BOOLEAN NOT NULL default false');
}
}

if ( ! sets::isin( 'host_types', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Host_Types.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
}
if ( sets::isin( 'hosts', \@tables ) ) {
my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='hosts'", 'column_name');
if ( ! exists $$data{count} ) {
	$dbh->do('ALTER TABLE hosts add count integer');
	$dbh->do('UPDATE hosts set count=(SELECT count FROM blacklist WHERE blacklist.ip=hosts.ip)');
}
if ( ! exists $$data{description} ) {
	$dbh->do('ALTER TABLE hosts add description TEXT');
} 
if ( ! exists $$data{blacklist} ) {
	$dbh->do('ALTER TABLE hosts add blacklist BOOLEAN NOT NULL default false');
} # end if
if ( ! exists $$data{whitelist} ) {
	$dbh->do('ALTER TABLE hosts add whitelist BOOLEAN NOT NULL default false');
} # end if
if ( ! exists $$data{created_on} ) {
	$dbh->do('ALTER TABLE hosts add created_on TIMESTAMP WITH TIME ZONE NOT NULL default NOW()');
} # end if
if ( ! exists $$data{updated_on} ) {
	$dbh->do('ALTER TABLE hosts add updated_on TIMESTAMP WITH TIME ZONE NOT NULL default NOW()');
} # end if
if ( ! exists $$data{deleted} ) {
	$dbh->do('ALTER TABLE hosts add deleted BOOLEAN NOT NULL DEFAULT FALSE');
} # end if
if ( ! exists $$data{online} ) {
	$dbh->do('ALTER TABLE hosts add online BOOLEAN');
} # end if
if ( ! exists $$data{type_id} ) {
	$dbh->do('ALTER TABLE hosts add type_id INTEGER');
	$dbh->do('ALTER TABLE hosts add FOREIGN KEY (type_id) REFERENCES Host_types (id)');
} # end if
if ( exists $$data{type} ) {
	$dbh->do('ALTER TABLE hosts drop type');
}
if ( exists $$data{monitor} ) {
	if ( ! exists $$data{monitored} ) {
		$dbh->do('ALTER TABLE hosts RENAME COLUMN monitor to monitored');
	} else {
		$dbh->do('ALTER TABLE hosts DROP COLUMN monitor');
	} # end if
} elsif ( ! exists $$data{monitored} ) {
	$dbh->do('ALTER TABLE hosts add monitored BOOLEAN NOT NULL DEFAULT FALSE');
} # end if
if ( ! exists $$data{offline_seconds} ) {
	$dbh->do('ALTER TABLE hosts add offline_seconds INTEGER');
} # end if
if ( ! exists $$data{state_changed_on} ) {
	$dbh->do('ALTER TABLE hosts add state_changed_on INTEGER');
} # end if
if ( ! exists $$data{notified} ) {
	$dbh->do('ALTER TABLE hosts add notified BOOLEAN NOT NULL DEFAULT FALSE');
} # end if
} # end if

if ( ! sets::isin( 'host_notifications', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Host_Notifications.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
}

if ( ! sets::isin( 'paper_prices', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Paper_Prices.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='paper_prices'", 'column_name');
	if ( ! exists $$data{equipment_id} ) {
		$dbh->do('ALTER TABLE paper_prices add equipment_id INTEGER');
		$dbh->do('ALTER TABLE paper_prices add FOREIGN KEY(equipment_id) REFERENCES tbl_Equipment (id)');
	} # end if
	if ( ! exists $$data{interpolate} ) {
		$log->debug("Add interpolate to paper_prices");
		$dbh->do('ALTER TABLE paper_prices add interpolate BOOLEAN NOT NULL DEFAULT FALSE');
	} # end if
	if ( ! exists $$data{service} ) {
		$dbh->do('ALTER TABLE paper_prices ADD service TEXT');
		$dbh->do("UPDATE paper_prices set service='Material'" );
	} # end if
}

if ( ! sets::isin( 'user_profile_fields', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/User_Profile_Fields.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='user_profile_fields'", 'column_name');
	if ( ! $$data{deleted} ) {
		$dbh->do('ALTER TABLE user_profile_fields add deleted BOOLEAN not null default false');
	} # end if
	if ( ! $$data{searchable} ) {
		$dbh->do('ALTER TABLE user_profile_fields add searchable BOOLEAN not null default false');
	} # end if
	if ( ! $$data{search_default} ) {
		$dbh->do('ALTER TABLE user_profile_fields add search_default TEXT');
	} # end if
	if ( ! $$data{defaults} ) {
		$dbh->do('ALTER TABLE user_profile_fields ADD defaults TEXT[]');
	} # end if
	if ( ! $$data{match} ) {
		$dbh->do('ALTER TABLE user_profile_fields add match TEXT');
	} # end if
	if ( ! $$data{viewable} ) {
		$dbh->do('ALTER TABLE user_profile_fields add viewable BOOLEAN NOT NULL default true');
	} # end if
	if ( ! $$data{on_registration} ) {
		$dbh->do('ALTER TABLE user_profile_fields add on_registration BOOLEAN NOT NULL default false');
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
	if ( ! $$data{deleted} ) {
		$dbh->do('ALTER TABLE company_profile_fields add deleted BOOLEAN not null default false');
	} # end if
	if ( ! $$data{searchable} ) {
		$dbh->do('ALTER TABLE company_profile_fields add searchable BOOLEAN not null default false');
	} # end if
	if ( ! $$data{match} ) {
		$dbh->do('ALTER TABLE company_profile_fields add match TEXT');
	} # end if
	if ( ! $$data{viewable} ) {
		$dbh->do('ALTER TABLE company_profile_fields add viewable BOOLEAN NOT NULL default true');
	} # end if
	if ( ! $$data{on_registration} ) {
		$dbh->do('ALTER TABLE company_profile_fields add on_registration BOOLEAN NOT NULL default false');
	} # end if
	if ( ! $$data{search_default} ) {
		$dbh->do('ALTER TABLE company_profile_fields add search_default TEXT');
	} # end if
	if ( ! $$data{defaults} ) {
		$dbh->do('ALTER TABLE company_profile_fields ADD defaults TEXT[]');
	} # end if
} # end if
if ( ! sets::isin( 'company_profiles', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Company_Profiles.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
} # end if


if ( sets::isin( 'shifts', \@tables ) ) {
my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='shifts'", 'column_name');
if ( ! exists $$data{updated_on} ) {
	$dbh->do('ALTER TABLE shifts add updated_on TIMESTAMP WITH TIME ZONE NOT NULL default nOW()');
} # end if
if ( ! exists $$data{created_on} ) {
	$dbh->do('ALTER TABLE shifts add created_on TIMESTAMP WITH TIME ZONE NOT NULL default nOW()');
} # end if
} 
if ( sets::isin( 'tbl_equipment', \@tables ) ) {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='tbl_equipment'", 'column_name');
	if ( ! exists $$data{sorting} ) {
		$dbh->do('ALTER TABLE tbl_equipment ADD sorting integer');
	} # end if
	if ( ! exists $$data{message} ) {
		$dbh->do('ALTER TABLE tbl_equipment ADD message text');
	} # end if
	if ( ! exists $$data{servicetype_id} ) {
		$dbh->do('ALTER TABLE tbl_equipment ADD servicetype_id INTEGER[]');
	} # end if
	if ( ! exists $$data{category_id} ) {
		$dbh->do('ALTER TABLE tbl_equipment ADD category_id INTEGER[]');
		if ( exists $$data{strcategory} ) {
			$dbh->do('UPDATE tbl_equipment SET category_id = category_id || (SELECT id FROM equipment_categories WHERE name=strcategory)');	
		} # end if
	} # end if
} # end if

if ( sets::isin( 'equipment_shifts', \@tables ) ) {
my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='equipment_shifts'", 'column_name');
if ( ! exists $$data{operator_id} ) {
	$dbh->do('ALTER TABLE equipment_shifts ADD operator_id INTEGER');
	$dbh->do('ALTER TABLE equipment_shifts ADD FOREIGN KEY (operator_id) REFERENCES Users (id)');
} # end if
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
if ( ! sets::isin( 'photos_in_albums', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Photos_in_Albums.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='photos_in_albums'", 'column_name');
	if ( ! exists $$data{id} ) {
		$dbh->do( 'ALTER TABLE photos_in_albums ADD id SERIAL' );
		$dbh->do( 'ALTER TABLE photos_in_albums DROP CONSTRAINT photos_in_albums_pkey');
		$dbh->do( 'ALTER TABLE photos_in_albums ADD PRIMARY KEY (id)' );
	} # end if
	if ( ! exists $$data{sort} ) {
		$dbh->do('ALTER TABLE photos_in_albums ADD sort INTEGER');
		print "Adding sort to photos_in_albums\n";
	}
}
if ( ! sets::isin( 'video_albums', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Video_Albums.sql' ) );
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
	if ( ! exists $$data{conversation_id} ) {
		$dbh->do('ALTER TABLE Messages add conversation_id INTEGER');
	} # end if
} # end if
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
	if ( exists $$data{action_type} ) {
		$dbh->do('ALTER TABLE Logs rename action_type to action_id');
		$dbh->do('ALTER TABLE Logs ADD FOREIGN KEY (action_id) REFERENCES Log_Actions (id)');
	} # end if
	if ( ! exists $$data{object_type_id} ) {
		$dbh->do('ALTER TABLE Logs add object_type_id INTEGER');
		$dbh->do('ALTER TABLE Logs add FOREIGN KEY (object_type_id) REFERENCES Object_types (id)');
	}
	if (  exists $$data{object} ) {
		$dbh->do('UPDATE Logs set object_type_id = (SELECT id FROM object_types where name=object)');
		$dbh->do('ALTER TABLE Logs DROP object');
	}
	if ( ! exists $$data{object_id} ) {
		$dbh->do('ALTER TABLE Logs add object_id INTEGER');
	} # end if
} # end if
my %config_actions = (
	'Add Currency'			=>	76,
	'Update Configuration' => 77,
	'Login Failed'	=> 78,
	'Select Company'	=>	79,
	'Login'		=>	2,
	'Logout'	=>	3,
	'Service Copy'	=>	27,
	'Host blacklisted'	=>	99,
	'Host online'	=>	100,
	'Host offline'	=>	101,
	'Host rebooted'	=>	102,
	'Long response time'	=>	103,
	'Credit Information Imported'	=>	104,
	'Credit Information Changed'	=>	105,
	'Copy Material'	=>	43,
	'Copy Product'	=>	60,
	'Update ProjectType Template'	=>	52,
	'New ProjectType Template'	=>	55,
	'Export ProjectType Templates'	=>	54,
	'License Assigned'	=>	200,
	'License Unassigned'	=>	201,
	'Intrusion'		=>	202,
);
foreach my $config_action ( keys %config_actions ) {
	my $Action = openprint::Log_Action->find_one( name=>$config_action);
	if ( $Action ) {
		if ( $Action->id() != $config_actions{$config_action} ) {
			$log->debug("Must renumber the action: $config_action want $config_actions{$config_action} have $$Action{id}");

			# Look for existing actions with this id
			my $RealAction = openprint::Log_Action->find_one('id'=>$config_actions{$config_action});
			if ( ! $RealAction ) {
				# No existing action
				$log->debug("No existing");

				# Create an action type with the right name, and the right id, but we already have one with the right name, and the wrong id, so... we are renumbering?
				my $ac = sql::start_transaction( $dbh );
				my $New = $Action->copy();
				$New->save({'id'=>$config_actions{$config_action}}, 1 );
				foreach my $Log ( openprint::Log->find('action_id'=>$Action->id()) ) {
					$Log->save({'action_id'=>$config_actions{$config_action}});
				} # end foreach Log
				sql::end_transaction( $dbh, $ac );
			} elsif ( $RealAction->name() eq $config_action ) {
				# Shouldnt happen, basically means that there must be duplicates
				foreach my $Log ( openprint::Log->find('action_id'=>$Action->id()) ) {
					$Log->save({'action_id'=>$config_actions{$config_action}});
				} # end foreach Log
			} else {
				die "Need to manually update $config_actions{$config_action} $config_action entries";
			} # end if
			$Action->destroy();
		} # end if
	} else {
		$log->debug("Adding new action");	
		$Action = new openprint::Log_Action();
		$Action->save({name=>$config_action,id=>$config_actions{$config_action}}, 1);
	} # end if
} # end foreach config_action
die $dbh->errstr() if $dbh->errstr();


if ( ! sets::isin( 'comments', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Comments.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='comments'", 'column_name');
	if ( ! exists $$data{approved} ) {
		$dbh->do('ALTER TABLE Comments add approved boolean not null default false');
	} # endif
	if ( exists $$data{object_type} ) {
		if ( ! exists $$data{object_type_id} ) {
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
	if ( ! exists $$data{starttime_seconds} ) {
		if ( exists $$data{starttime} ) {
			$dbh->do('ALTER TABLE Equipment_Shifts ADD starttime_seconds INTEGER');
			$dbh->do('update equipment_shifts set starttime_seconds = extract(epoch from starttime)');
			$dbh->do('ALTER TABLE Equipment_shifts drop starttime');
		} # end if
	} # end if
	if ( ! exists $$data{duration_seconds} ) {
		if ( exists $$data{duration} ) {
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
	if ( ! exists $$data{please_call} ) {
		$dbh->do('ALTER TABLE Project_Types add please_call boolean not null default false');
	} # endif
}
if ( ! sets::isin( 'emailcampaigns', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/EmailCampaigns.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='emailcampaigns'", 'column_name');
	if ( ! exists $$data{nextrun} ) {
		$dbh->do('ALTER TABLE emailcampaigns add nextrun TIMESTAMP WITH TIME ZONE');
	} # end if
	if ( ! exists $$data{email_subject} ) {
		$dbh->do('ALTER TABLE emailcampaigns add email_subject TEXT');
	} # end if
	if ( ! exists $$data{email_from} ) {
		if ( exists $$data{fromemail} ) {
		$dbh->do('ALTER TABLE emailcampaigns rename column fromemail to email_from');
		} else {
		$dbh->do('ALTER TABLE emailcampaigns add email_from TEXT');
		} # end if
	} # end if
	if ( ! exists $$data{email_text} ) {
		if ( exists $$data{emailtext} ) {
		$dbh->do('ALTER TABLE emailcampaigns rename column emailtext to email_text');
		} else {
		$dbh->do('ALTER TABLE emailcampaigns add email_text TEXT');
		} # end if
	} # end if
	if ( ! exists $$data{attachments} ) {
		$dbh->do('ALTER TABLE emailcampaigns add attachments TEXT');
	} # end if
	if ( ! exists $$data{timeofday} ) {
		$dbh->do('ALTER TABLE emailcampaigns ADD timeofday TIME WITHOUT TIME ZONE');
	} # end if
	if ( ! exists $$data{template_id} ) {
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
	$dbh->do("ALTER TABLE paper$thingy rename to Stock$thingy");
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
	$dbh->do('ALTER TABLE Papers rename column name_id to brand_id') if exists $$data{name_id};
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
$dbh->do("ALTER TABLE manufacturers rename column shortname to name") if exists $$data{shortname};
$dbh->do("ALTER TABLE manufacturers drop column longname") if exists $$data{longname};
if ( ! sets::isin( 'bookmarks', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Bookmarks.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
}
if ( ! $config{public_URIs} ) {
$dbh->do(q`insert into Configuration values ('public_URIs', '/,/index.html,/account/login.html,/account/registration.html', 'text', 'Comma separated list of pages on the site that can be read without logging in','Miscellaneous Settings' );` );
} # end if

if ( ! sets::isin( 'opinion_types', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Opinion_Types.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
}
if ( ! sets::isin( 'opinions', \@tables ) ) {
	if ( sets::isin( 'likes', \@tables ) ) {
		my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='likes'", 'column_name');
		if ( exists $$data{object_type} ) {
			if ( ! exists $$data{object_type_id} ) {
				$dbh->do('ALTER TABLE likes add object_type_id INTEGER');
				$dbh->do('UPDATE likes set object_type_id=(SELECT id FROM object_types WHERE name=object_type)');
				$dbh->do('ALTER TABLE likes add FOREIGN KEY (object_type_id) REFERENCES object_types (id)');
				$dbh->do('ALTER TABLE likes alter object_type_Id SET NOT NULL');
			} # end if
			$dbh->do('ALTER TABLE likes DROP object_type');
			$dbh->do('CREATE INDEX likes_idx ON comments ( object_type_id, object_id )');
		} # end if
		if ( ! exists $$data{created_on} ) {
			$dbh->do('ALTER TABLE likes add created_on TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()');
		} # end if
		if ( ! exists $$data{value} ) {
			$dbh->do('ALTER TABLE likes ADD value INTEGER');
			$dbh->do('ALTER TABLE likes ADD FOREIGN KEY (value) REFERENCES opinion_types (id)');
		} # end if
		if ( ! exists $$data{opinion_type_id} ) {
			$dbh->do('ALTER TABLE likes ADD opinion_type_id INTEGER');
			$dbh->do('ALTER TABLE likes ADD FOREIGN KEY (opinion_type_id) REFERENCES Opinion_Types (id)');
			$dbh->do('UPDATE likes SET opinion_type_id=value');
			if ( $$data{opinion_type} ) {
				$dbh->do('DELETE FROM Likes where opinion_type IS NULL');
			} # end if
		} # end if
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
	if ( exists $$data{value} ) {
		$dbh->do('ALTER TABLE privacy RENAME value to mode');
	} # end if
	if ( ! exists $$data{usergroup_id} ) {
		$dbh->do('ALTER TABLE privacy ADD usergroup_id INTEGER[]');
	} # end if
	if ( ! exists $$data{relationship_type_id} ) {
		$dbh->do('ALTER TABLE privacy ADD relationship_type_id INTEGER[]');
	} # end if
	if ( exists $$data{relationship_id} ) {
		$dbh->do('ALTER TABLE Privacy DROP relationship_id');
	} # end if
	if ( ! exists $$data{user_id} ) {
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
	if ( ! $$data{created_on} ) { 
		$dbh->do('ALTER TABLE surveys add created_on TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()');
	} # end if
	if ( ! $$data{created_on} ) { 
		$dbh->do('ALTER TABLE surveys ADD created_by INTEGER');
		$dbh->do('ALTER TABLE surveys ADD FOREIGN KEY (created_by) REFERENCES Users (id)');
	} # end if
} # end if

if ( ! sets::isin( 'survey_question_categories', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Survey_Question_Categories.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='survey_question_categories'", 'column_name');
	if ( ! exists $$data{sorting} ) {
		$dbh->do('ALTER TABLE survey_question_categories ADD sorting INTEGER');
	} # end if
}
if ( ! sets::isin( 'survey_questions', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Survey_Questions.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='survey_questions'", 'column_name');
	if ( ! $$data{type} ) { 
		$dbh->do('ALTER TABLE survey_questions add type TEXT');
	} # end if
	if ( ! $$data{alignment} ) { 
		$dbh->do('ALTER TABLE survey_questions ADD alignment BOOLEAN');
	} # end if
	if ( ! $$data{sorting} ) { 
		$dbh->do('ALTER TABLE survey_questions ADD sorting INTEGER');
	} # end if
} # end if
if ( ! sets::isin( 'survey_responses', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Survey_Responses.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='survey_responses'", 'column_name');
	if ( ! $$data{created_on} ) { 
		$dbh->do('ALTER TABLE survey_responses add created_on TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()');
	} # end if
	if ( ! $$data{public} ) { 
		$dbh->do('ALTER TABLE survey_responses ADD public BOOLEAN');
	} # end if
	if ( ! $$data{answer_ids} ) {
		$dbh->do('ALTER TABLE survey_responses ADD answer_ids INTEGER[]');
		if ( $$data{answer_id} ) {
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
	if ( ! exists $$data{discountable} ) {
		$dbh->do('ALTER TABLE product_prices ADD discountable BOOLEAN NOT NULL default true');
	} # end if
	if ( ! exists $$data{owner_id} ) {
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
if ( ! $config{Timezone} ) {
$dbh->do(q`insert into Configuration values ('Timezone', 'America/Toronto', 'text', 'Timezone','Miscellaneous Settings' );` );
	
} # end if

if ( ! sets::isin( 'order_invoices', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Order_Invoices.sql}) );
	die if $dbh->errstr();
}

if ( ! sets::isin( 'schedule', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Schedule.sql}) );
	die if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='schedule'", 'column_name');
	if ( ! exists $$data{stock} ) {
		$dbh->do('ALTER TABLE Schedule add stock text');
	} 
	if ( ! exists $$data{stock_verified} ) {
		$dbh->do('ALTER TABLE Schedule add stock_verified boolean not null default false');
	} 
	if ( ! exists $$data{tentative} ) {
		$dbh->do('ALTER TABLE Schedule add tentative boolean');
	} 
	if ( ! exists $$data{comment} ) {
		$dbh->do('ALTER TABLE Schedule add comment text');
	} 
	if ( ! exists $$data{servicetype_id} ) {
		$dbh->do('ALTER TABLE Schedule add servicetype_id INTEGER');
	} 
	if ( ! exists $$data{pertains_id} ) {
		$dbh->do('ALTER TABLE Schedule add pertains_id INTEGER[]');
	} 
	if ( ! exists $$data{created_on} ) {
		$dbh->do('ALTER TABLE Schedule add created_on TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()');
	} 
	$dbh->do('ALTER TABLE SChedule alter projectindex drop not null');
	if ( exists $$data{serviceindex} ) {
		$dbh->do('ALTER TABLE SChedule drop serviceindex');
	} # end if
	if ( ! exists $$data{service_id} ) {
		$dbh->do('ALTER TABLE Schedule add service_id INTEGER[]');
	} 
}

if ( ! sets::isin( 'conversations', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Conversations.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='conversations'", 'column_name');
	if ( ! $$data{deleted} ) {
		$dbh->do('ALTER TABLE conversations add deleted boolean not null default false');
	} # end if
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
	if ( exists $$data{lngprojecttypeindex} ) {
		$dbh->do('ALTER TABLE Projecttype_defaults RENAME COLUMN lngprojecttypeindex to projecttype_id');
	}
	if ( exists $$data{strfieldname} ) {
		$dbh->do('ALTER TABLE Projecttype_defaults RENAME COLUMN strfieldname to name');
	}
	if ( exists $$data{strdefaultvalue} ) {
		$dbh->do('ALTER TABLE Projecttype_defaults RENAME COLUMN strdefaultvalue to value');
	}
} 
if ( ! sets::isin( 'inventoryconditions', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/InventoryConditions.sql}) );
	die if $dbh->errstr();
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='skid_contents'", 'column_name');
	$dbh->do('insert into inventoryconditions select id, name from stockqualities');
	$dbh->do('alter table skid_contents ADD condition_id INTEGER');
	if ( exists $$data{quality_id} ) {
		$dbh->do('UPDATE skid_contents set condition_id=quality_id');
		$dbh->do('ALTER TABLE skid_contents DROP quality_id');
	} # end if
	$dbh->do('ALTER TABLE Skid_Contents add FOREIGN KEY (condition_id) REFERENCES inventoryconditions (id)');
	$data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='paper_allocations'", 'column_name');
	if ( ! exists $$data{condition_id} ) {
		$dbh->do('ALTER TABLE paper_allocations ADD condition_id INTEGER');
		$dbh->do('ALTER TABLE paper_allocations ADD FOREIGN KEY (condition_id) REFERENCES inventoryconditions (id)');
	} # end if
} else {
}
if ( ! sets::isin( 'wall', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Wall.sql}) );
	die if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='wall'", 'column_name');
	if ( ! exists $$data{reply_to} ) {
		$dbh->do('ALTER TABLE wall ADD reply_to INTEGER');
		$dbh->do('ALTER TABLE wall ADD FOREIGN KEY (reply_to) REFERENCES Wall (id)');
	} 
	if ( ! exists $$data{has_replies} ) {
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
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='company_categories'", 'column_name');
	if ( ! exists $$data{short} ) {
		$dbh->do('ALTER TABLE company_categories ADD short text');
	} # end if
} # endif
if ( $config{Owner} ) {
	$dbh->do("UPDATE configuration SET name='owner_id' WHERE name='Owner'" );
}
if ( ! sets::isin( 'purchaseorder_departments', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/PurchaseOrder_Departments.sql}) );
	die if $dbh->errstr();
} # en dif
if ( ! sets::isin( 'banners', \@tables )) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Banners.sql}) );
	die if $dbh->errstr();
} # end if
if ( ! sets::isin( 'product_specifications', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Product_Specifications.sql}) );
	die if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='product_specifications'", 'column_name');
	if ( ! exists $$data{id} ) {
		$dbh->do('ALTER TABLE Product_Specifications add id SERIAL');
		$dbh->do('ALTER TABLE Product_Specifications add PRIMARY KEY (id)');
	} # end if
} # end if
if ( ! sets::isin( 'feeds', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Feeds.sql}) );
	die if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='feeds'", 'column_name');
	if ( ! exists $$data{type} ) {
		$dbh->do('ALTER TABLE feeds add type TEXT');
	} # end if
	if ( ! exists $$data{category_id} ) {
		$dbh->do('ALTER TABLE feeds add category_id INTEGER');
		$dbh->do('ALTER TABLE feeds add FOREIGN KEY (category_id) REFERENCES Article_Categories (id)');
	} # end if
	if ( ! exists $$data{filters} ) {
		$dbh->do('ALTER TABLE feeds add filters TEXT');
	} # en dif
	if ( ! exists $$data{published} ) {
		$dbh->do('ALTER TABLE feeds add published boolean NOT NULL default false');
	} # en dif
	if ( ! exists $$data{active} ) {
		$dbh->do('ALTER TABLE feeds add active boolean NOT NULL default false');
	} # en dif
}
if ( ! sets::isin( 'creditapplications', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Credit_Applications.sql}) );
	die if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='creditapplications'", 'column_name');
	if ( ! exists $$data{grantedcod} ) {
		$dbh->do('ALTER TABLE creditapplications add grantedcod float');
	} # end if
} # end if
if ( ! sets::isin( 'company_credit', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Company_Credit.sql}) );
	die if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='company_credit'", 'column_name');
	if ( ! exists $$data{cod} ) {
		$dbh->do('ALTER TABLE company_credit add cod float');
	} # end if
	if ( ! exists $$data{terms} ) {
		$log->debug("Adding terms to company_credit");
		$dbh->do('ALTER TABLE company_credit add terms integer');
	} # end if
	if ( ! exists $$data{supplier_id} ) {
		$dbh->do('ALTER TABLE company_credit add supplier_id INTEGER');
		$dbh->do('ALTER TABLE company_credit ADD FOREIGN KEY (supplier_id) REFERENCES Companies (id)');
	} # end if
	if ( ! exists $$data{late_payment_amount} ) {
		$dbh->do('ALTER TABLE company_credit add late_payment_amount float');
	} # end if
	if ( ! exists $$data{late_payment_units} ) {
		$dbh->do('ALTER TABLE company_credit add late_payment_units TEXT');
	} # end if
	if ( ! exists $$data{early_payment_amount} ) {
		$dbh->do('ALTER TABLE company_credit add early_payment_amount float');
	} # end if
	if ( ! exists $$data{early_payment_units} ) {
		$dbh->do('ALTER TABLE company_credit add early_payment_units TEXT');
	} # end if
	if ( ! exists $$data{early_payment_days} ) {
		$dbh->do('ALTER TABLE company_credit add early_payment_days INTEGER');
	} # end if
} # end if
if ( ! sets::isin( 'affiliates', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Affiliates.sql}) );
	die if $dbh->errstr();
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='affiliates'", 'column_name');
	if ( ! exists $$data{sort} ) {
		$dbh->do('ALTER TABLE affiliates add sort integer');
	} # end if
}
if ( sets::isin('upload_id_seq', \@sequences ) ) {
	if ( sets::isin( 'uploads_id_seq', \@sequences ) ) {
		# Do nothing
	} else {
		$dbh->do('CREATE SEQUENCE uploads_id_seq');
		$dbh->do(q`SELECT setval('uploads_id_seq', (SELECT MAX (id) FROM Uploads))` );
		$dbh->do(q`ALTER TABLE uploads alter id set default nextval('uploads_id_seq')`);
	} # end if
	$dbh->do('DROP SEQUENCE upload_id_seq');
} # end if

if ( ! sets::isin('paycheques_timetracks', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Paycheques_Timetracks.sql}) );
	die if $dbh->errstr();
} # end if
my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='timetracks'", 'column_name');
if ( exists $$data{paycheque_id} ) {
	require openprint::Timetrack;
	require openprint::Paycheque_Timetrack;
	foreach my $Timetrack ( openprint::Timetrack->find('paycheque_id is null'=>0) ) {
		if ( ! openprint::Paycheque_Timetrack->find_one('paycheque_id'=>$Timetrack->paycheque_id(),'timetrack_id'=>$Timetrack->id()) ) {
			$_ = (new openprint::Paycheque_Timetrack())->save({'paycheque_id'=>$Timetrack->paycheque_id(),'timetrack_id'=>$Timetrack->id()});
			die $_ if $_;
		} # end if
	} # end foreach Timetrack
	$dbh->do('ALTER TABLE timetracks drop paycheque_id');
} # end if
if ( ! sets::isin('object_views', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Object_Views.sql}) );
	die if $dbh->errstr();
} # end if

if ( ! sets::isin('tbl_material_prices',\@tables) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Material_Prices.sql}) );
} else {
$dbh->do( 'update tbl_material_prices set strunits=lower(strunits)');
my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='tbl_material_prices'", 'column_name');
	if ( ! exists $$data{id} ) {
			$log->debug("Adding id to tbl_material_prices");
			$dbh->do('ALTER TABLE tbl_material_prices ADD id SERIAL');
			$dbh->do('ALTER TABLE tbl_material_prices ADD PRIMARY KEY (id)');
	}
	if ( ! sets::isin( 'materialprices_id_seq', \@sequences ) ) {
			$log->debug("renaming sequence for tbl_material_prices");
		$dbh->do('CREATE SEQUENCE materialprices_id_seq');
		$dbh->do("ALTER TABLE tbl_material_prices ALTER id set default nextval('materialprices_id_seq')");
		$dbh->do('DROP SEQUENCE tbl_material_prices_id_seq');
	}
	if ( ! exists $$data{interpolate} ) {
			$log->debug("adding interpolate to tbl_material_prices");
		$dbh->do('ALTER TABLE tbl_material_prices ADD interpolate         BOOLEAN NOT NULL default false');
	}
}
$dbh->do( 'update service_prices set units=lower(units)');
$dbh->do( 'update paper_prices set strunits=lower(strunits)');
foreach my $Company ( openprint::Company->find() ) {
	my $Country;
	if ( $Company->country() ) {
		$Company->country('Canada') if $Company->country() eq 'CANADA';
		if ( $Company->country() =~ /\./ ) {
			$_ = $Company->country();
			$_ =~ s/\.//g;
			$Company->country($_);
		} 
		$Company->country(openprint::Location->transform('name',$Company->country()));


		if ( $countries::countries{$Company->country} ) {
			if ( ! ( $Country = openprint::Location->find_one(short=>$Company->country(),type=>'country' ) ) ) {
				$Country = new openprint::Location();
				$_ = $Country->save({
						short=>$Company->country(),
						name=> $countries::countries{$Company->country},
						type=> 'country',
						});
				die $_ if $_;
			} # end if
		} else {
			if ( ! ( $Country = openprint::Location->find_one('name lc'=>lc $Company->country(),type=>'country' ) ) ) {
				$Country = new openprint::Location();
				$_ = $Country->save({
						name	=> $Company->country(),
						type=> 'country',
				});
				die $_ if $_;
			} # end if
		} # end if
		my $State;
		if ( $Company->country() eq 'CA' ) {
			if ( $provinces::provinces{$Company->state()} ) {
				if ( $Company->state() and ! ( $State = openprint::Location->find_one(short=>$Company->state(),type=>'province' ) ) ) {
					$State = new openprint::Location();
					$_ = $State->save({
							parent_id	=>	$Country->id(),
							short=>$Company->state(),
							name=> $provinces::provinces{$Company->state()},
							type=> 'province',
							});
					die $_ if $_;
				} # end if
			} else {
				if ( $Company->state() and ! ( $State = openprint::Location->find_one('name lc'=>lc $Company->state(),type=>'province' ) ) ) {
					$State = new openprint::Location();
					$_ = $State->save({
							parent_id	=>	$Country->id(),
							#short=>$Company->state(),
							name=> $Company->state(),
							type=> 'province',
							});
					die $_ if $_;
				} # end if
			} # end if
		} else {
			if ( $states::states{$Company->state()} ) {
				if ( $Company->state() and ! ( $State = openprint::Location->find_one(short=>$Company->state(),type=>'state' ) ) ) {
					$State = new openprint::Location();
					$_ = $State->save({
							parent_id	=>	$Country->id(),
							short=>$Company->state(),
							name=> $states::states{$Company->state()},
							type=> 'state',
							});
					die $_ if $_;
				} # end if
			} else {
				if ( $Company->state() and ! ( $State = openprint::Location->find_one('name lc'=>lc $Company->state(),type=>'state' ) ) ) {
					$State = new openprint::Location();
					$_ = $State->save({
							parent_id	=>	$Country->id(),
#short=>$Company->state(),
							name=> $Company->state(),
							type=> 'state',
							});
					die $_ if $_;
				} # end if
			} # end if
		} # end if
		next if ! $State;
		my $City;
		$Company->city(openprint::Location->transform('name', $Company->city() ));
		if ( $Company->city() and ! ( $City = openprint::Location->find_one('name lc'=>lc $Company->city(),type=>'city' ) ) ) {
			$City = new openprint::Location();
			$_ = $City->save({
					parent_id	=>	$State->id(),
					name=> $Company->city(),
					type=> 'city',
					});
					die $_ if $_;
		} # end if
		next if ! $City;
		$Company->address1( openprint::Location->transform('address', $Company->address1() ) );

		if ( $Company->address1() ) {
			my $Address = openprint::Location->find_one('address lc'=>lc ($Company->address1() . ( $Company->address2() ? ( ' ' . $Company->address2() ) : '' )),type=>'place');
			if ( ! $Address ) {
				$Address = new openprint::Location();
				$_ = $Address->save({
					address		=>	($Company->address1() ? $Company->address1() : '' ) . ( $Company->address2() ? (  ' ' . $Company->address2() ) : '' ),
					postalcode	=>	$Company->postalcode(),
					type		=>	'place',
					parent_id	=>	$City->id(),
				});
					die $_ if $_;
			} # end if
		} # end if
	} # end if has coutnry
	
} # end foreach $Company
if ( ! sets::isin('software', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Software.sql}) );
	die if $dbh->errstr();
} # end if
if ( ! sets::isin('licenses', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Licenses.sql}) );
	die if $dbh->errstr();
} # end if
if ( ! sets::isin('license_hosts', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/License_Hosts.sql}) );
	die if $dbh->errstr();
} # end if
if ( sets::isin('operator_shifts', \@tables ) ) {
$dbh->do('DROP TABLE operator_shifts');
}
if ( ! sets::isin('object_specifications', \@tables ) ) {
	$log->debug("Adding Object_Specifications");
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Object_Specifications.sql}) );
	die if $dbh->errstr();
} # end if
	if ( sets::isin('product_specifications', \@tables ) ) {
		if ( ! sql::execute( undef, undef, "SELECT id FROM object_types where name='openprint::Product'" ) ) {
			$dbh->do("INSERT INTO object_types (name,human) values ('openprint::Product', 'Product');") or die $dbh->errstr();
		}
		$dbh->do(q`insert into object_specifications ( object_type_id, object_id, name, value ) SELECT (SELECT id from object_types where name='openprint::Product'), product_id, name, value from product_specifications;`) or die $dbh->errstr();
		$dbh->do('DROP TABLE product_specifications');
	}
print "done.\n";
$dbh->disconnect();
1;
__END__
