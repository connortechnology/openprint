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
	if ( $line =~ /INSERT INTO PaperNames \(([^\)]+)\) VALUES \(([^\)]+)\)/ ) {
		my ( $fields, $values ) = ( $1, $2 );
		my %changes;
		@changes{split(',',$fields)} = split(',',$values);

		next if sql::execute(undef,undef, 'SELECT * FROM PaperNames WHERE longname=?', $changes{longname} );
		$line = <STDIN>;
		my ( $id ) = $line =~ /\(SELECT id,longname FROM PaperNames WHERE longname=$changes{longname}\) Results:(\d+),$changes{longname}/;
		die if ! $id;
		my $Finish = new openprint::StockBrand();
		$_ = $Finish->save({id=>$id, shortname=>$changes{longname}, longname=>$changes{longname}}, 1);
		die $_ if $_;
	} elsif ( $line =~ /INSERT INTO PaperFinishes \(([^\)]+)\) VALUES \(([^\)]+)\)/ ) {
		my ( $fields, $values ) = ( $1, $2 );
		my %changes;
		@changes{split(',',$fields)} = split(',',$values);

		next if sql::execute(undef,undef, 'SELECT * FROM PaperFinishes WHERE longname=?', $changes{longname} );
		$line = <STDIN>;
		my ( $id ) = $line =~ /\(SELECT id,longname FROM PaperFinishes WHERE longname=$changes{longname}\) Results:(\d+),$changes{longname}/;
		die if ! $id;
		my $Finish = new openprint::StockFinish();
		$_ = $Finish->save({id=>$id, shortname=>$changes{longname}, longname=>$changes{longname}}, 1);
		die $_ if $_;
	} elsif ( $line =~ /INSERT INTO PaperFinishes/ ) {
		die 'Need generic finishes line';
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
	} elsif ( $line =~ /INSERT INTO Paper_Inventory \(([^\)]+)\) VALUES \((.+)\)\)/ ) {
		my ( $fields, $values ) = ( $1, $2 );
		my %changes;
		@changes{split(',',$fields)} = split(',',$values);
		next if $changes{paper_id} eq 'undef';
		next if $changes{paper_id} eq '';
		my $paper_id = $changes{paper_id};
		delete $changes{paper_id};
		foreach ( keys %changes ) {
			$changes{$_} = undef if $changes{$_} eq 'undef';
			delete $changes{$_} if $changes{$_} eq 'NOW()';
		} 
		if ( $changes{id} ) {
			die 'id foudn for id ' . $changes{id}.' line: '  . $line . ' fields: ' . $fields . "\n" . ' values: ' . $values;
		}
		my @PI = openprint::PaperInventory->find( %changes );
		if ( @PI > 1 ) {
			$log->error( "Too amny PIs" . $line);
			next;
		} elsif ( ! @PI ) {
			$log->warn( "No PIS" . $line );
			next;
		}
		my $PI = shift @PI;
		if ( ! $PI ) {
			die 'PI not foudn for id ' . $changes{id}.' line: '  . $line . ' fields: ' . $fields . "\n" . ' values: ' . $values;
		} elsif ( ! $PI->paper_id() ) {
			sql::update( undef, undef, 'paper_inventory', [ 'id=? AND paper_id IS NULL', $$PI{id} ], 'paper_id', $paper_id );
		} elsif ( $PI->paper_id() != $paper_id ) {
			die "PI has different paper_id $$PI{paper_id} != $paper_id";
		} # end if
	} elsif ( $line =~ /INSERT INTO Paper_Inventory/ ) {
		$log->debug("Filed PI update $line");
	} elsif ( $line =~ /INSERT INTO paper_inventory \(([^\)]+)\) VALUES \((.+)\)\)/ ) {
		my ( $fields, $values ) = ( $1, $2 );
		my %changes;
		@changes{split(',',$fields)} = split(',',$values);
		next if $changes{paper_id} eq 'undef';
		if ( ! $changes{id} ) {
			die 'No id not foudn for id ' . $changes{id}.' line: '  . $line . ' fields: ' . $fields . "\n" . ' values: ' . $values;
		}
		my $PI = new openprint::PaperInventory( $changes{id} );
		if ( ! $PI->id() ) {
			$log->error( 'PI not foudn for id ' . $changes{id}.' line: '  . $line . ' fields: ' . $fields . "\n" . ' values: ' . $values );
			my $Skid = openprint::Skid->find_one(id=>$changes{skid_id}) if $changes{skid_id};
			if ( $Skid ) {
				my ( $date ) = $line =~ /^\[([^\]]+)\]/;
				my $time = Date::Parse::str2time( $date );
				foreach ( keys %changes ) {
					$changes{$_} = undef if $changes{$_} eq 'undef';
					$changes{$_} = Date::Format::time2str( '%Y-%m-%d %H:%M:%S%z', $time ) if $changes{$_} eq 'NOW()';
				} 
				$PI->save(\%changes,1);
			} 
		} elsif ( ! $PI->paper_id() ) {
			sql::update( undef, undef, 'paper_inventory', [ 'id=?', $changes{id} ], 'paper_id', $changes{paper_id} );
		} elsif ( $PI->paper_id() != $changes{paper_id} ) {
			die "PI has different paper_id $$PI{paper_id} != $changes{paper_id}";
		} # end if
	} elsif ( $line =~ /INSERT INTO paper_inventory/ ) {
		$log->debug("Filed pi update $line");
	} elsif ( $line =~ /INSERT INTO paper_allocations \(([^\)]+)\) VALUES \((.+)\)\)/ ) {
		my ( $fields, $values ) = ( $1, $2 );
		my %changes;
		@changes{split(',',$fields)} = split(',',$values);
		next if $changes{paper_id} eq 'undef';
		if ( ! $changes{id} ) {
			die 'No id not foudn for id ' . $changes{id}.' line: '  . $line . ' fields: ' . $fields . "\n" . ' values: ' . $values;
		}
		my $PA = new openprint::PaperAllocation( $changes{id} );
		if ( ! $PA->id() ) {
			#die 'PA not foudn for id ' . $changes{id}.' line: '  . $line . ' fields: ' . $fields . "\n" . ' values: ' . $values;
			next;
		} elsif ( ! $PA->paper_id() ) {
			sql::update( undef, undef, 'paper_allocations', [ 'id=?', $changes{id} ], 'paper_id', $changes{paper_id} );
		} elsif ( $PA->paper_id() != $changes{paper_id} ) {
			die "PA has different paper_id $$PA{paper_id} != $changes{paper_id}";
		} # end if
	} elsif ( $line =~ /INSERT INTO paper_allocations/ ) {
		$log->debug("Filed pa update $line");
	} elsif ( $line =~ /INSERT INTO Skid_Contents \(([^\)]+)\) VALUES \((.+)\)\)/ ) {
		my ( $fields, $values ) = ( $1, $2 );
		my %changes;
		@changes{split(',',$fields)} = split(',',$values);
		next if $changes{paper_id} eq 'undef';
		if ( ! $changes{id} ) {
			die 'No id not foudn for id ' . $changes{id}.' line: '  . $line . ' fields: ' . $fields . "\n" . ' values: ' . $values;
		}
		my $SC = new openprint::SkidContent( $changes{id} );
		if ( ! $SC->id() ) {
			#die 'PA not foudn for id ' . $changes{id}.' line: '  . $line . ' fields: ' . $fields . "\n" . ' values: ' . $values;
			next;
		} elsif ( ! $SC->paper_id() ) {
			sql::update( undef, undef, 'skid_contents', [ 'id=?', $changes{id} ], 'paper_id', $changes{paper_id} );
		} elsif ( $SC->paper_id() != $changes{paper_id} ) {
			#die "SC has different paper_id $$SC{paper_id} != $changes{paper_id}";
		} # end if
	} elsif ( $line =~ /INSERT INTO Skid_Contents/ ) {
		$log->debug("Filed SC update $line");
	} elsif ( $line =~ /UPDATE Skid_Contents SET (.+?) WHERE id=(\d+)/ ) {
		my ( $changes, $id ) = ($1, $2);
		my @changes = split(',',$changes);
		#$log->debug("Got manifest update @changes");
		my %changes;
		foreach ( @changes ) {
			my ( $k, $v  ) = split ( ' = ', $_ );
			$changes{$k} = $v;
		} # end foreach
		if ( ! $changes{paper_id} ) {
			#$log->debug("No paper id for $changes");
			next;
		}
		my $PI = new openprint::SkidContent( $id );
		if ( ! $PI->id() ) {
			$log->error( 'SC not foudn for id ' . $id );
			next;
		} elsif ( ! $PI->paper_id() ) {
			sql::update( undef, undef, 'skid_Contents', [ 'id=?', $id ], 'paper_id', $changes{paper_id} );
		} elsif ( $PI->paper_id() != $changes{paper_id} ) {
			$log->debug( "SC has different paper_id $$PI{paper_id} != $changes{paper_id}" );
		} # end if
	} elsif ( $line =~ /UPDATE manifest_content_types SET (.+?) WHERE id=(\d+)/ ) {
		my ( $changes, $id ) = ($1, $2);
		#$log->debug("Got manifest update $changes");
		my @changes = split(',',$changes);
		#$log->debug("Got manifest update @changes");
		my %changes;
		foreach ( @changes ) {
			my ( $k, $v  ) = split ( ' = ', $_ );
			$changes{$k} = $v;
		} # end foreach
		if ( ! $changes{paper_id} ) {
			#$log->debug("No paper id for $changes");
			next;
		}
		
		my $PI = new openprint::Manifest_Content_Type( $id );
		if ( ! $PI->id() ) {
			$log->error('MCT not foudn for id ' . $id);
		} elsif ( ! $PI->paper_id() ) {
			sql::update( undef, undef, 'manifest_Content_types', [ 'id=?', $id ], 'paper_id', $changes{paper_id} );
		} elsif ( $PI->paper_id() != $changes{paper_id} ) {
			#$log->debug( "MCT has different paper_id $$PI{paper_id} != $changes{paper_id}" );
		} # end if
	
	} # end if
}

$dbh->disconnect();
1;
__END__
