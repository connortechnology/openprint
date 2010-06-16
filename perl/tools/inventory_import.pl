#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Paper;
require openprint::Skid;
require openprint::RFIDTag;
require openprint::Location;

use openprint ();
use vars qw( $log $dbh %session );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;
$session{'user_id'} = 1085;

$log = new logger( 'warn' );

$openprint::Object::no_cache = 1;
$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2]) );

my ( $filename ) = $ARGV[3];
	
if ( ! open( HANDLE, $filename ) ) {
    print( "Unable to open file: $filename, Reason: $!\n" );
    $dbh->disconnect();
    die;
} # end ife

my $csv = Text::CSV_XS->new();
$_ = <HANDLE>; # drop the title row

while ( <HANDLE> ) {
	my $status = $csv->parse($_);

	my ( $rfidtag_id,$manufacturer,$name, $location_part1, $location_part2, $location_part3, $finish, $colour, $weight, $quality, $type, $length, $width, $calliper, $gsm, $mweight, $owner, $qty_kg, $units, $qty_lbs, $fsc ) = misc::trim($csv->fields());
	next if ! $rfidtag_id;

	if ( ! $weight =~ /\D/ ) {
		$weight .= 'lb';
	} # end if

	$rfidtag_id =~ s/R(.*)/$1/;

	my $Tag = new openprint::RFIDTag( $rfidtag_id );
	$Tag->save( {'id'=>$rfidtag_id} ) if ! $Tag->id();

	my @Locations = openprint::Location->find('name'=>$location_part2.$location_part3);
	if ( @Locations ) {
		$Tag->location_id( $Locations[0]->id() );
		$Tag->save();
	} else {
		$log->warn('Location ' . $location_part2.$location_part3 . ' not found');
	} # end if
	
	my $Skid = $Tag->Skid();
	if ( ! $Skid->id() ) {
		$$Skid{'rfidtag_id'} = $Tag->id();
		$$Skid{'location_id'} = $Tag->location_id();

		my $error = $Skid->save();
		if ( $error ) {
			$log->error( $error );
			next;
		} # end if
	} # end if

	my $Paper;
	my @Papers = openprint::Paper->find( 'name'=>$name, 'finish'=>$finish, 'colour'=>$colour, 'weight'=>$weight, 'type'=>$type, 'width'=>$width, 'length'=>$length );
	if ( ! @Papers ) {
		$Paper = new openprint::Paper();
		$Paper->manufacturer( $manufacturer );
		$Paper->owner( $owner );
		$Paper->name( $name );
		$Paper->finish( $finish );
		$Paper->colour( $colour );
		$Paper->weight( $weight );
		$Paper->quality( $quality );
		$Paper->type( $type );
		$Paper->width( $width );
		$Paper->height( $length ) if $type ne 'Roll';
		$Paper->calliper( $calliper );
		$Paper->gsm();
		$Paper->mweight( $mweight ) if $type ne 'Roll';
		$Paper->fsc_code( $fsc );
		my $error = $Paper->save();
		if ( $error ) {
			$log->error( 'Manufacturer: ' . $manufacturer . ' Owner:' . $owner . ' : ' . $error );
			next;
		} # end if
	} elsif ( @Papers == 1 ) {
		$Paper = $Papers[0];
	} else {
		$log->error('Found more than 1 paper matching' );
		next;
	} # end if
	$Skid->set( $Paper, $qty_lbs );
	my $error = $Skid->save();
	if ( $error ) {
		$log->error( $error );
		next;
	} # end if

} # end while



close(HANDLE);

$dbh->disconnect();
1;
__END__
