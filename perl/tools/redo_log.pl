#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Skid;
require openprint::ManifestContent;
require openprint::StockFinish;
require openprint::Paper;
require openprint::PaperInventory;
require openprint::Manifest_Content_Type;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'debug' );

$openprint::Object::no_cache = 1;
$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>'database') );

while ( my $line = <STDIN> ) {
	if ( $line =~ /INSERT INTO PaperFinishes \(longname,shortname\) VALUES \(([^,]+),.+\)/ ) {
		next if sql::execute(undef,undef, 'SELECT * FROM PaperFinishes WHERE longname=?', $1 );
		my $name = $1;
		$line = <STDIN>;
		my ( $id ) = $line =~ /\(SELECT id,longname FROM PaperFinishes WHERE longname=$name\) Results:(\d+),$name/;
		die if ! $id;
		my $Finish = new openprint::StockFinish();
		$_ = $Finish->save({id=>$id, shortname=>$name, longname=>$name}, 1);
		die $_ if $_;
	} elsif ( $line =~ /INSERT INTO PaperWeights \(longname,shortname\) VALUES \(([^,]+),.+\)/ ) {
		next if sql::execute(undef,undef, 'SELECT * FROM PaperWeights WHERE longname=?', $1 );
		my $name = $1;
		$line = <STDIN>;
		my ( $id ) = $line =~ /\(SELECT id,longname FROM PaperWeights WHERE longname=$name\) Results:(\d+),$name/;
		die if ! $id;
		my $Weight = new openprint::StockWeight();
		$_ = $Weight->save({id=>$id, shortname=>$name, longname=>$name}, 1);
		die $_ if $_;
	} elsif ( $line =~ /INSERT INTO PaperColours \(longname,shortname\) VALUES \(([^,]+),.+\)/ ) {
		next if sql::execute(undef,undef, 'SELECT * FROM PaperColours WHERE longname=?', $1 );
		my $name = $1;
		$line = <STDIN>;
		my ( $id ) = $line =~ /\(SELECT id,longname FROM PaperColours WHERE longname=$name\) Results:(\d+),$name/;
		die if ! $id;
		my $Colour = new openprint::StockColour();
		$_ = $Colour->save({id=>$id, shortname=>$name, longname=>$name}, 1);
		die $_ if $_;
	} elsif ( $line =~ /SELECT nextval\('paper_id_seq'\)\) Results:(\d+)/ ) {
$log->debug("Checking for paper $1");
		my $Paper = new openprint::Paper( $1 );
		if ( $Paper->id() ) {
			$log->debug("Paper exists".$Paper->to_string());
			next;
		} 
		$line = <STDIN>;
		my ( $fields, $values ) = $line =~ /INSERT INTO Papers \(([^\)]+)\) VALUES \(([^\)]+)\)/;
		die 'No fields in ' . $line if ! $fields;
		my %sql;
		@sql{split(',', $fields)} = map { $_ eq 'undef' ? undef : $_ } split(',',$values);
		sql::insert( undef, undef, 'papers', %sql );
	} elsif ( $line =~ /INSERT INTO paper_inventory \(skid_id,updated_on,id,docket,delta,user_id,paper_id,instock,poindex,comment,units\) VALUES \(\d+,NOW\(\),(\d+),[^,]+,[^,]+,\d+,(\d+),[^,]+,[^,]+,[^,]+,[^,]+\)\)/ ) {
		my ( $id, $paper_id ) = ($1, $2);
		my $PI = new openprint::PaperInventory( $id );
		if ( ! $PI->id() ) {
			die 'PI not foudn for id ' . $id;
		} elsif ( ! $PI->paper_id() ) {
			sql::update( undef, undef, 'paper_inventory', [ 'id=?', $id ], 'paper_id', $paper_id );
		} elsif ( $PI->paper_id() != $paper_id ) {
			die "PI has different paper_id $$PI{paper_id} != $paper_id";
		} # end if
	} elsif ( $line =~ /UPDATE Skid_Contents SET purpose_id = ,skid_id = \d+,quantity = \d+,id = (\d+),condition_id = ,paper_id = (\d+),units =  WHERE id=\d+/ ) {
		my ( $id, $paper_id ) = ($1, $2);
		my $PI = new openprint::SkidContent( $id );
		if ( ! $PI->id() ) {
			die 'SC not foudn for id ' . $id;
		} elsif ( ! $PI->paper_id() ) {
			sql::update( undef, undef, 'skid_Contents', [ 'id=?', $id ], 'paper_id', $paper_id );
		} elsif ( $PI->paper_id() != $paper_id ) {
			$log->debug( "SC has different paper_id $$PI{paper_id} != $paper_id" );
		} # end if
	} elsif ( $line =~ /UPDATE manifest_content_types SET (.+?) WHERE id=(\d+)/ ) {
		my ( $changes, $id ) = ($1, $2);
		$log->debug("Got manifest update $changes");
		my %changes = map { split ( ' = ', $_ ) } split(',',$changes);
		if ( ! $changes{paper_id} ) {
			$log->debug("No paper id for $changes");
			die;
		}
		
		my $PI = new openprint::Manifest_Content_Type( $id );
		if ( ! $PI->id() ) {
			die 'MCT not foudn for id ' . $id;
		} elsif ( ! $PI->paper_id() ) {
			sql::update( undef, undef, 'manifest_Content_types', [ 'id=?', $id ], 'paper_id', $changes{paper_id} );
		} elsif ( $PI->paper_id() != $changes{paper_id} ) {
			$log->debug( "MCT has different paper_id $$PI{paper_id} != $changes{paper_id}" );
		} # end if
	
	} # end if
}

$dbh->disconnect();
1;
__END__
