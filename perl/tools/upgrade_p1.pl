#!/usr/bin/perl
use strict;
my $lib_path = '/var/www/testing/perl';
use lib '/var/www/testing/perl';
use Date::Calc;
require sql;
require logger;
require openprint::Object;
require configuration;
require openprint::Service;
require openprint::Equipment;

use openprint ();
use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;


$log = new logger( 'warn' );

my ( $src_db, $dst_db, $src_host, $year, $month, $day ) = @ARGV;
$src_db = 'point-one' if ! $src_db;
$dst_db = 'point-one' if ! $dst_db;
`/etc/init.d/apache2 reload`;
if ( $year ) {
	( $year, $month, $day ) = Date::Calc::Add_Delta_Days( Date::Calc::Today(), -1 ) if ! $month;

	if ( ! -e "/tmp/$src_db-$month-$day-$year.sql.bz2" ) {
		print "Getting db backup $month-$day-$year\n";
		if ( $src_host ne 'localhost' ) {
			`su postgres -c "scp $src_host:/media/Storage/Backups/localhost/$src_db/$year-$month-$day.sql.bz2 /tmp/$src_db-$month-$day-$year.sql.bz2 "`;
		} else {
			`ln -s /media/Storage/Backups/localhost/$src_db/$year-$month-$day.sql.bz2 /tmp/$src_db-$month-$day-$year.sql.bz2`;
		} 
	} # end if
	if ( ! -e "/tmp/$src_db-$month-$day-$year.sql.bz2" ) {
		die "No db dump /tmp/$src_db-$month-$day-$year.sql.bz2";
	}
	print "Dropping db...";
	`su postgres -c "dropdb $dst_db"`;
	print "done\n";
	print "Create db...";
	`su postgres -c "createdb $dst_db"`;
	print "done\n";
	print "Loading db...";
	`su postgres -c "bunzip2 < /tmp/$src_db-$month-$day-$year.sql.bz2 | psql $dst_db"`;
	print "done\n";
} else {
#grab direclty
	print "Dropping db...";
	`su postgres -c "dropdb $dst_db"`;
	print "done\n";
	print "Create db...";
	`su postgres -c "createdb -E SQL_ASCII $dst_db"`;
	print "done\n";
	print "Loading db...";
	if ( $src_host ) {
		`su postgres -c "ssh $src_host pg_dump -h $src_host point-one | psql $dst_db"`;
	} else {
		`su postgres -c "pg_dump $src_db | psql $dst_db"`;
	} # end if
	print "done\n";

} # end if

`chmod +x $lib_path/tools/db_update.pl`;
print "upgrading structures 2...";
`$lib_path/tools/db_update.pl $dst_db point-one point-one > /tmp/db_update.log` or $log->error($!);
print "upgrading signatures...";
`$lib_path/tools/update_p1_signatures.pl $dst_db point-one point-one >> /tmp/db_update.log` or $log->error($!);
print "done\n";
print 'Turning off backups...';
$dbh = sql::open_sql( $log, ('database'=>$dst_db, 'driver'=>'Pg','login'=>'point-one', 'password'=>'point-one') );
configuration::init_cache( $log, $dbh );
my ( $version, $updated_on, $backup ) = sql::execute( undef, undef, q{SELECT version,updated_on, backup FROM database_info ORDER BY updated_on DESC LIMIT 1} );
sql::insert( undef, undef, 'database_info', 'version', $version+1, 'backup', 'false' );
print "done\n";

foreach my $Service ( openprint::Service::find('name'=>'Imposition') ) {
	foreach my $Price ( $Service->prices() ) {
		if ( $Price->units() eq 'Per Page' ) {
			$Price->units('Per Imposition');
			$Price->save();
		} # end if
	} # end foreach
} # end foreach

if ( 0 ) {
sql::update( undef, undef, 'Configuration', ['name=?', 'Press Run Overs Rate'], 'name','MakeReady Overs Rate' );
foreach my $E ( openprint::Equipment::find('strid'=>'Web1') ) {
	foreach my $Spec ( $E->Specifications() ) {
		next if $Spec->name() ne 'Press Run Overs';
		if ( $Spec->value() != 0.05 ) {
			$Spec->delete();
			next;
		} else {
			$Spec->min(undef);
			$Spec->max(undef);
			$Spec->interpolate(0);
			$Spec->save();
		} # end if
	} # end foreach
} # end foreach
}
if ( 0 ) {
new openprint::ProjectType_Template()->save({
	'projecttype_id'	=>	1,
	'type'				=>	'Unbound',
	'description'		=>	'5.375 x 8.375 Finished',
	'finished_width'	=>	5.375,
	'finished_height'	=>	8.375,
	'flat_width'		=>	10.75,
	'flat_height'		=>	8.375,
});
new openprint::ProjectType_Template()->save({
	'projecttype_id'	=>	1,
	'type'				=>	'Unbound',
	'description'		=>	'5.5 x 8.5 Finished',
	'finished_width'	=>	5.5,
	'finished_height'	=>	8.5,
	'flat_width'		=>	11,
	'flat_height'		=>	8.5,
});
new openprint::ProjectType_Template()->save({
	'projecttype_id'	=>	1,
	'type'				=>	'Unbound',
	'description'		=>	'8.5 x 11 Finished',
	'finished_width'	=>	8.5,
	'finished_height'	=>	11,
	'flat_width'		=>	17,
	'flat_height'		=>	11,
});
}
	sql::insert( undef, undef, 'configuration', 'name', 'ProjectViewDisclaimer','value','All CTP quotes must include a digital proof.
All prices are subject to the viewing of artwork, film or electronic file.
Please check specifications for accuracy.
Due to technical limitations, perfecting orders may be subject to a revision if it is necessary to run sheetwork.
If administrative changes are required you will be notified prior to production approval.
This quote is valid for 30 days subject to paper price increase and availability.
Heavy ink coverage will be billed as an extra unless indicated.
Quantities of +/- 5% will represent completion of order and will be charged or credited accordingly.
<br/>
<br/>
If you would like to match our press profiles for proofing purposes the ICC profiles can
be found at:<br/>
<br/>
<a href="http://www.idealliance.org/industry_resources/branding_media_and_color/gracol">
http://www.idealliance.org/industry_resources/branding_media_and_color/gracol</a><br/>
<a href="http://files.idealliance.org/GRACoL/ICC/2006%20GRACoL%20&%20SWOP%20Profiles.zip">
http://files.idealliance.org/GRACoL/ICC/2006%20GRACoL%20&%20SWOP%20Profiles.zip</a><br/>'
,'description', 'Disclaimer to show at bottom of project.', 'category','Miscellaneous Settings' ) if ! exists $config{'ProjectViewDisclaimer'};
	sql::insert( undef, undef, 'configuration', 'name', 'OrderViewDisclaimer','value',
'All CTP quotes must include a digital proof. All prices
are subject to the viewing of artwork, film or electronic file. Please check
specifications for accuracy. Pointone will not be responsible for errors
or omissions. Due to technical limitations, perfecting orders
may be subject to a revision if it is necessary to run sheetwork. Heavy ink
coverage will be billed extra unless specified in the estimate. Scoring
prices are based on folder scores only, die scoring will be an
additional cost unless specified in the estimate. If administrative
changes are required you will be notified prior to production approval. This quote
is valid for 30 days subject to paper price increase and availability.
Quantities of +/- 5% will represent completion of order and will be charged or credited accordingly.'
,'description', 'Disclaimer to show at bottom of an order.', 'category','Miscellaneous Settings' ) if ! exists $config{'OrderViewDisclaimer'};
	sql::insert( undef, undef, 'configuration', 'name', 'QuoteViewDisclaimer','value',
'<p>
Client is responsible to verify all specifications in comparison with original quote request. Size and other
specifications may have been modified to avoid waste and maintain efficiency. Prices are calculated to the
best of our ability, if changes are necessary you will be notified.
</p>
<p>
All CTP quotes must include a digital proof. All prices are subject to the viewing of artwork, film or
electronic file. Please check specifications for accuracy. Pointone will not be responsible for errors or
omissions. Due to technical limitations, perfecting orders may be subject to a revision if it is necessary to
run sheetwork. Heavy ink coverage will be billed extra unless specified in the estimate. Scoring prices
are based on folder scores only, die scoring will be an additional cost unless specified in the estimate. If
administrative changes are required you will be notified prior to production approval. This quote is valid for
30 days subject to paper price increase and availability.  Quantities of +/- 5% will represent completion of
order and will be charged or credited accordingly.
</p>'
,'description', 'Disclaimer to show at bottom of a quote.', 'category','Miscellaneous Settings' ) if ! exists $config{'QuoteViewDisclaimer'};
	sql::insert( undef, undef, 'configuration', 'name', 'RegistrationRequiredFields','value',
'company_name,firstname,lastname,email,Captcha,address1,country,state,city,postalcode,phone,password,verifypassword',
'category','Required Fields', 'description', 'Comma-separated list of fields on the registration page which must be filled in.');
	sql::update( undef, undef, 'tbl_equipment_specifications', [ 'strname=?', 'Press Standard Run Speed'], 'strname','Run Speed' );
	sql::execute( undef, undef, "delete from tbl_equipment_specifications WHERE lngequipmentindex=28 and strname='Press Additional Run Speed'" );
	sql::update( undef, undef, 'tbl_equipment_specifications', [ 'strname=?', 'Press Additional Run Speed' ], 'strname','Run Speed' );
	sql::insert( undef, undef, 'tbl_equipment_specifications', 'lngequipmentindex', 1, 'strname','Run Speed', 'dblmin', 0.0031, 'dblmax', 0.0120, 'strvalue', 9000, 'interpolate', 0, 'strunits', 'Calliper' );
	sql::insert( undef, undef, 'tbl_equipment_specifications', 'lngequipmentindex', 4, 'strname','Run Speed', 'dblmin', 0.0029, 'dblmax', 0.0099, 'strvalue', 9000, 'interpolate', 0, 'strunits', 'Calliper' );
	sql::insert( undef, undef, 'tbl_equipment_specifications', 'lngequipmentindex', 27, 'strname','Run Speed', 'dblmin', 0.0029, 'dblmax', 0.0099, 'strvalue', 9000, 'interpolate', 0, 'strunits', 'Calliper' );
	sql::insert( undef, undef, 'tbl_equipment_specifications', 'lngequipmentindex', 25, 'strname','Run Speed', 'dblmin', 0.0029, 'dblmax', 0.0099, 'strvalue', 9000, 'interpolate', 0, 'strunits', 'Calliper' );
	sql::insert( undef, undef, 'tbl_equipment_specifications', 'lngequipmentindex', 30, 'strname','Run Speed', 'dblmin', 0.0029, 'dblmax', 0.0099, 'strvalue', 9000, 'interpolate', 0, 'strunits', 'Calliper' );
my ( $version, $updated_on, $backup ) = sql::execute( undef, undef, q{SELECT version,updated_on, backup FROM database_info ORDER BY updated_on DESC LIMIT 1} );
sql::insert(undef, undef, 'database_info', 'version', $version+1, 'updated_on', 'NOW()', 'backup', 0 );
$dbh->disconnect();
