package openprint::paper;

my $debug = 0;

use strict;

require sql;
require openprint::Equipment;
require openprint::Paper;
require openprint::StockName;

sub get_paper {
	my ( $r, $log, $dbh, $variable, %specs ) = @_;

	my @types = ('Sheet');
	push @types, 'Roll';

	my @papers = openprint::Paper::find( 
			( $specs{'Selected'} eq 'Manufacturer' ? ( 'manufacturer_id'=>$specs{'Manufacturer'} ) : () ),
			( $specs{'Selected'} eq 'Group' ? ( 'group_id'=>$specs{'Group'} ) : ()  ),
			( $specs{'Selected'} eq 'Name' ? ( 'name_id'=> $specs{'name_id'} ? $specs{'name_id'} : $specs{'Name'} ) : ()  ),
			( sets::isin( $specs{'Selected'}, [ 'Finish','Colour','Weight' ] ) ? ( 'finish_id'	=> $specs{'Finish'} ) : () ),
			( sets::isin( $specs{'Selected'}, [ 'Colour','Weight' ] ) ? ( 'colour_id'	=> $specs{'Colour'} ) : () ),
			( sets::isin( $specs{'Selected'}, [ 'Weight' ] ) ? ( 'weight_id'	=> $specs{'Weight'} ) : () ),
			( $specs{'width'} ? ( 'width_>='=>$specs{'width'} ) : () ),
			( $specs{'height'} ? ( 'height_>='=>$specs{'height'} ) : () ),
			'type'=>\@types,
				);
	if ( ! @papers ) {
		@papers = openprint::Paper::find( 
			( $specs{'Selected'} eq 'Name' ? ( 'name_id'=> $specs{'name_id'} ? $specs{'name_id'} : $specs{'Name'} ) : ()  ),
			( $specs{'width'} ? ( 'width_>='=>$specs{'width'} ) : () ),
			( $specs{'height'} ? ( 'height_>='=>$specs{'height'} ) : () ),
			'type'=>\@types,
				);
	} # end if
	my %names;
	my %finishes;
	my %colours;
	my %weights;
	foreach my $Paper ( @papers ) {
#$log->debug("Paper: " . $Paper->to_string() );
		$names{$Paper->name()} = $Paper->name_id();
		$finishes{$Paper->finish()} = $Paper->finish_id() if ( ! $specs{'Name'} ) or ( $Paper->name_id() eq $specs{'Name'} ) or ( $Paper->name_id() eq $specs{'name_id'} );
		$colours{$Paper->colour()} = $Paper->colour_id() if ( ! $specs{'Name'} ) or ( $Paper->name_id() eq $specs{'Name'} ) or ( $Paper->name_id() eq $specs{'name_id'} );
		$weights{$Paper->weight()} = $Paper->weight_id() if ( ! $specs{'Name'} ) or ( $Paper->name_id() eq $specs{'Name'} ) or ( $Paper->name_id() eq $specs{'name_id'} );
	} # end foreach

	my @results;
	push @results, jsrs::encode_array( 'Brand', map {$names{$_}, $_ } sort keys %names ) if ($specs{'Selected'} eq 'Manufacturer') or ! $specs{'Selected'};
	push @results, jsrs::encode_array( 'Finish', map { $finishes{$_}, $_ } sort keys %finishes ) if ( ! $specs{'Finish'} ) or ! sets::isin( $specs{'Selected'}, [ 'Finish', 'Colour', 'Weight' ] );
	push @results, jsrs::encode_array( 'Colour', map { $colours{$_}, $_ } sort keys %colours ) if ( ! $specs{'Colour'} ) or ! sets::isin( $specs{'Selected'}, [ 'Finish','Weight' ] );
	if ( $specs{'Selected'} ne 'Weight' ) {
		push @results, jsrs::encode_array( 'Weight', map { $weights{$_}, $_ } 
				sort { $a =~ s/^(\d*)/$1/; $b =~ s/^(\d*)/$1/; return $a <=> $b } keys %weights );
	} # end if
	#push @results, select_sheetsize( $r, $log, $dbh, $variable, $project_index, $name, $spfinish, $colour, $weight, $press );
	push @results, "id~$specs{id}~$specs{id}";

	return join('|', @results ); 
} # end sub get_paper

sub select_paper {
	my ( $r, $log, $dbh, $variable, $selected, $name, $finish, $colour, $weight, $supplied, $press, $project_index, $type, $specific_width, $specific_height, $flat_width, $flat_height ) = @_;

	my $Project = new openprint::Project( $project_index );
	if ( ! $type ) {
		$type = $Project->Type()->name();
	} # end if

	my @types = ('Sheet');
	if ( (!$project_index) or ( ! $openprint::usergroup::groups_cache{'Web Estimating'} ) or openprint::usergroup::is_user_in( ['Web Estimating'], $openprint::session{'user_id'} ) ) {
		push @types, 'Roll';
	} # end if

	$log->debug("******** START OF select_paper_names, Press: $type $press $flat_width $flat_height*****************");
	my @papers = openprint::Paper::find( 
			( $project_index ? ( 'project_type_id'=>$Project->type_id() ) : (  'project_type_name'=>$type ) ),
			( $selected eq 'Name' ? ( 'name'=>$name ) : ()  ),
			( sets::isin( $selected, [ 'Finish','Colour','Weight' ] ) ? ( 'finish'	=> $finish ) : () ),
			( sets::isin( $selected, [ 'Colour','Weight' ] ) ? ( 'colour'	=> $colour ) : () ),
			( sets::isin( $selected, [ 'Weight' ] ) ? ( 'weight'	=> $weight ) : () ),
			'supplied'	=>	[undef,$supplied eq 'Y' ? 1 : 0],
			'type'		=>	\@types,
			( $flat_width ? ( (sets::isin($type,[ 'Envelopes','NCR' ]) ? 'width' : 'width_>=')=>$flat_width ) : () ),
			( $flat_height ? ( (sets::isin($type,[ 'Envelopes','NCR']) ? 'height' : 'height_>=')=>$flat_height ) : () ),
			);
    if ( $selected eq 'Name' and ! @papers ) {
        @papers = openprint::Paper::find(
                ( $project_index ? ( 'project_type_id'=>$Project->type_id() ) : (  'project_type_name'=>$type ) ),
                ( $selected eq 'Name' ? ( 'name'=>$name ) : ()  ),
                'supplied'  =>  [undef,$supplied eq 'Y' ? 1 : 0],
                'type'      =>  \@types,
                );
    } # end if

	my %names;
	my %finishes;
	my %colours;
	my %weights;
	foreach my $Paper ( @papers ) {
		$names{$Paper->name()} = $Paper->name_id();
		$finishes{$Paper->finish()} = $Paper->finish_id() if ( ! $name ) or ( $Paper->name() eq $name );
		$colours{$Paper->colour()} = $Paper->colour_id() if ( ! $name ) or ( $Paper->name() eq $name );
		$weights{$Paper->weight()} = $Paper->weight_id() if ( ! $name ) or ( $Paper->name() eq $name );
	} # end foreach

	my @results;
	push @results, jsrs::encode_array( 'Brand', map {$_, $_ } sort keys %names ) if ! sets::isin( $selected, ['Name','Finish','Colour','Weight'] );
	push @results, jsrs::encode_array( 'Finish', map { $_, $_ } sort keys %finishes ) if ! sets::isin( $selected, [ 'Finish', 'Colour', 'Weight' ] );
	push @results, jsrs::encode_array( 'Colour', map { $_, $_ } sort keys %colours ) if ( ! $colour ) or ! sets::isin( $selected, [ 'Weight','Colour' ] );
	if ( $selected ne 'Weight' ) {
		push @results, jsrs::encode_array( 'Weight', map { $_, $_ } 
				sort { $a =~ s/^(\d*)/$1/; $b =~ s/^(\d*)/$1/; return $a <=> $b } keys %weights );
	} # end if
	my %papers = get_sheetsizes( $type, $name, $finish, $colour, $weight, $supplied, @papers );
	push @results, jsrs::encode_array( 'SheetSize', map {$_,$papers{$_}} sort keys %papers );
	push @results, "Press~$press~$press";

	return join('|', @results ); 
} # end sub select_paper

sub get_names {
	my ( $type, $name, $finish, $colour, $weight, $supplied ) = @_;

	my @types = ('Sheet');
	if ( ( ! $openprint::usergroup::groups_cache{'Web Estimating'} ) or openprint::usergroup::is_user_in( ['Web Estimating'], $openprint::session{'user_id'} ) ) {
		push @types, 'Roll';
	} # end if

	my @papers = openprint::Paper::find( 
		'project_type_name'=>$type,
			'supplied'	=> [undef,$supplied eq 'Y' ? 1 : 0],
		'type'=>\@types,
		 );
	my %finishes;
	foreach my $Paper ( @papers ) {
		$finishes{$Paper->name()} = $Paper->name_id();
	} # end foreach
	return map { $_, $_ } sort keys %finishes;
} # end sub get_names

sub select_finish {
	my ( $r, $log, $dbh, $variable, $name, $finish, $colour, $weight, $supplied, $press, $project_index, $type, $specific_width, $specific_height ) = @_;
			
	return jsrs::encode_array( 'Finish', get_finishes( $type, $name, $finish, $colour, $weight, $supplied ) );
}

sub get_finishes {
	my ( $type, $name, $finish, $colour, $weight, $supplied ) = @_;
	my @types = ('Sheet');
	if ( ( ! $openprint::usergroup::groups_cache{'Web Estimating'} ) or openprint::usergroup::is_user_in( ['Web Estimating'], $openprint::session{'user_id'} ) ) {
		push @types, 'Roll';
	} # end if
	my @papers = openprint::Paper::find( 
		'project_type_name'=>$type,
		'name'=>$name,
		'supplied'	=> [undef,$supplied eq 'Y' ? 1 : 0],
		'type'=>\@types,
		);
	my %finishes;
	foreach my $Paper ( @papers ) {
		$finishes{$Paper->finish()} = $Paper->finish_id();
	} # end foreach
	return map { $_, $_ } sort keys %finishes;
} # end sub select_finish

sub select_colour {
	my ( $r, $log, $dbh, $variable, $name, $finish, $colour, $weight, $supplied, $press, $project_index, $type, $specific_width, $specific_height ) = @_;

	return jsrs::encode_array( 'Colour', get_colours( $type, $name, $finish, undef, undef, $supplied ) );


} # end sub select_colour

sub get_colours {
	my ( $type, $name, $finish, $colour, $weight, $supplied ) = @_;
	my @types = ('Sheet');
	if ( ( ! $openprint::usergroup::groups_cache{'Web Estimating'} ) or openprint::usergroup::is_user_in( ['Web Estimating'], $openprint::session{'user_id'} ) ) {
		push @types, 'Roll';
	} # end if
	my @papers = openprint::Paper::find( 'project_type_name'=>$type, 'name'=>$name, 'finish'=>$finish, 'weight'=>$weight,
			'supplied'	=> [undef,$supplied eq 'Y' ? 1 : 0],
			'type'=>\@types,
			);
	if ( ! @papers ) {
	@papers = openprint::Paper::find( 'project_type_name'=>$type, 'name'=>$name, 'finish'=>$finish,
			'supplied'	=> [undef,$supplied eq 'Y' ? 1 : 0],
			'type'=>\@types,
			);
	} # end if
	if ( ! @papers ) {
	@papers = openprint::Paper::find( 'project_type_name'=>$type, 'name'=>$name, 'type'=>\@types,
			'supplied'	=> [undef,$supplied eq 'Y' ? 1 : 0],
			);
	} # end if
	my %colours;
	foreach my $Paper ( @papers ) {
		$colours{$Paper->colour()} = $Paper->colour_id();
	} # end foreach
	return map { $_, $_ } sort keys %colours;
}

sub select_weight {
	my ( $r, $log, $dbh, $variable, $name, $finish, $colour, $weight, $supplied, $press, $project_index, $type, $specific_width, $specific_height ) = @_;

	return jsrs::encode_array( 'Weight', get_weights( $type, $name, $finish, $colour, undef, $supplied ) );
} # end sub select_weight

sub get_weights {
	my ( $type, $name, $finish, $colour, $weight, $supplied ) = @_;
	my @types = ('Sheet');
	if ( ( ! $openprint::usergroup::groups_cache{'Web Estimating'} ) or openprint::usergroup::is_user_in( ['Web Estimating'], $openprint::session{'user_id'} ) ) {
		push @types, 'Roll';
	} # end if
	my @papers = openprint::Paper::find( 
			'project_type_name'=>$type,
			'name'=>$name, 'finish'=>$finish, 'colour'=>$colour,
			'supplied'	=> [undef,$supplied eq 'Y' ? 1 : 0],
			'type'=>\@types,
			);
	if ( ! @papers ) {
		@papers = openprint::Paper::find( 
				'project_type_name'=>$type,
				'name'=>$name, 'finish'=>$finish,
			'supplied'	=> [undef,$supplied eq 'Y' ? 1 : 0],
				'type'=>\@types,
				);
	} # end if
	if ( ! @papers ) {
		@papers = openprint::Paper::find( 
				'project_type_name'=>$type,
				'name'=>$name,
			'supplied'	=> [undef,$supplied eq 'Y' ? 1 : 0],
				'type'=>\@types,
				);
	} # end if

	my %weights;
	foreach my $Paper ( @papers ) {
		$weights{$Paper->weight()} = $Paper->weight_id();
	} # end foreach
	return map { $_, $_ } 
		sort { $a =~ s/^(\d*)/$1/; $b =~ s/^(\d*)/$1/; return $a <=> $b } keys %weights;
} # end sub

sub select_by_name {
	my ( $r, $log, $dbh, $variable, $name, $finish, $colour, $weight, $supplied, $press, $project_index, $type, $specific_width, $specific_height ) = @_;
	if ( ! $type ) {
		my $Project = new openprint::Project( $project_index );
		$type = $Project->Type()->name();
	} # end if
	
	return join( '|', 
			select_finish( $r, $log, $dbh, $variable, $name, $finish, $colour, $weight, $supplied, $press, $project_index, $type ),
			select_colour( $r, $log, $dbh, $variable, $name, $finish, $colour, $weight, $supplied, $press, $project_index, $type ),
			select_weight( $r, $log, $dbh, $variable, $name, $finish, $colour, $weight, $supplied, $press, $project_index, $type ),
			select_sheetsize( $r, $log, $dbh, $variable, $project_index, $name, $finish, $colour, $weight, $supplied, $press ),
			"Press~$press~$press"
			);
				
} # end sub select_by_finish

sub select_by_finish {
	my ( $r, $log, $dbh, $variable, $name, $finish, $colour, $weight, $supplied, $press, $project_index, $type, $specific_width, $specific_height ) = @_;

	if ( ! $type ) {
		my $Project = new openprint::Project( $project_index );
		$type = $Project->Type()->name();
	} # end if
	
	return join( '|', 
			select_colour( $r, $log, $dbh, $variable, $name, $finish, $colour, $weight, $supplied, $press, $project_index, $type ),
			select_weight( $r, $log, $dbh, $variable, $name, $finish, $colour, $weight, $supplied, $press, $project_index, $type ),
			select_sheetsize( $r, $log, $dbh, $variable, $project_index, $name, $finish, $colour, $weight, $supplied, $press ),
			"Press~$press~$press"
			);
				
} # end sub select_by_finish
sub select_by_colour {
	my ( $r, $log, $dbh, $variable, $name, $finish, $colour, $weight, $supplied, $press, $project_index, $type, $specific_width, $specific_height ) = @_;
	
	if ( ! $type ) {
		my $Project = new openprint::Project( $project_index );
		$type = $Project->Type()->name();
	} # end if
	return join( '|', 
			select_finish( $r, $log, $dbh, $variable, $name, $finish, $colour, $weight, $supplied, $press, $project_index, $type ), 
			select_weight( $r, $log, $dbh, $variable, $name, $finish, $colour, $weight, $supplied, $press, $project_index, $type ),
			select_sheetsize( $r, $log, $dbh, $variable, $project_index, $name, $finish, $colour, $weight, $supplied, $press ),
			"Press~$press~$press"
			);;
				
} # end sub select_by_weight

sub select_by_weight {
	my ( $r, $log, $dbh, $variable, $name, $finish, $colour, $weight, $supplied, $press, $project_index, $type, $specific_width, $specific_height ) = @_;

	return join( '|', 
			select_finish( $r, $log, $dbh, $variable, $name, $finish, $colour, $weight, $supplied, $press, $project_index, $type ),
			select_colour( $r, $log, $dbh, $variable, $name, $finish, $colour, $weight, $supplied, $press, $project_index, $type ),
			select_sheetsize( $r, $log, $dbh, $variable, $project_index, $name, $finish, $colour, $weight, $supplied, $press ),
			"Press~$press~$press"
			);
				
} # end sub select_by_weight

sub select_sheetsize {
	my ( $r, $log, $dbh, $variable, $project_index, $name, $finish, $colour, $weight, $supplied, $press, $type, $flat_width, $flat_height ) = @_;

	return map { 'SheetSize~'.$_.'~'.$_ } get_sheetsizes( $type, $name, $finish, $colour, $weight, $supplied, $flat_width, $flat_height );

} # end sub select_sheetsize

sub get_sheetsizes {
	my ( $type, $name, $finish, $colour, $weight, $supplied, @papers ) = @_;
	my @results;
	$openprint::log->debug("************* START OF select_sheetsize: $type, $name, $finish, $colour, $weight, $supplied ********************");
	
	my @types = ('Sheet');
	if ( ( ! $openprint::usergroup::groups_cache{'Web Estimating'} ) or openprint::usergroup::is_user_in( ['Web Estimating'], $openprint::session{'user_id'} ) ) {
		push @types, 'Roll';
	} # end if
	if ( ! @papers ) {
		@papers = openprint::Paper::find( 'name', $name, 'finish', $finish, 'colour', $colour, 'weight', $weight, 'type'=>\@types,
				'project_type_name'	=>	$type,
				'supplied'	=> [undef,$supplied eq 'Y' ? 1 : 0],
				);
	} # end if
	return if ! @papers;

	my @presses = openprint::Equipment::find( 'category'=>'Printing' );
	return if ! @presses;

	my $min_width = -1;
	my $max_width = -1;
	my $min_height = -1;
	my $max_height = -1;
	foreach my $Press ( @presses ) {
		if ( $_ = $Press->specification('Minimum Sheet Width') and ( $_ < $min_width ) or ( -1 == $min_width ) ) {
			$min_width = $_;
		} # end if
		if ( $_ = $Press->specification('Maximum Sheet Width') and ( $_ > $max_width ) or ( -1 == $max_width ) ) {
			$max_width = $_;
		} # end if
		if ( $_ = $Press->specification('Minimum Sheet Length') and ( $_ < $min_height ) or ( -1 == $min_height ) ) {
			$min_height = $_;
		} # end if
		if ( $_ = $Press->specification('Maximum Sheet Length') and ( $_ > $max_height ) or ( -1 == $max_height ) ) {
			$max_height = $_;
		} # end if
	} # end foreach Press

	$openprint::log->debug("Cut Sheets: Min: $min_width x $min_height Max: $max_width x $max_height") if $debug;

	my @sheets;
	my %results;
	foreach my $Paper ( @papers ) {
		if ( $Paper->type() eq 'Roll' ) {
			$results{$Paper->width()} = $Paper->width().'"';
		} else {
		my ( $width, $height ) = ( $Paper->width(), $Paper->height() );
# cuts paper until it fits
		if ( $max_width and $max_height ) {
			if ( $Paper->cuttable() ) {
				while (
						( $width > $max_width or $height > $max_height )
						and
						( $width > $max_height or $height > $max_width )
					  ) {
					$openprint::log->debug("Cut to fit on press: $width x $height") if $debug;
					if ( $height > $width ) {
						$height /= 2;
					} else {
						$width /= 2;
					} # end if
				} # end while
			} else {
				next if ( $width > $max_width or $height > $max_height )
                        and
                        ( $width > $max_height or $height > $max_width );
			} # end if
		} # end if

		if ( $min_width and $min_height ) {
# while the paper fits on a press
			while ( 
					( $width >= $min_width ) and ( $height >= $min_height ) 
					or ( $width >= $min_height ) and ( $height >= $min_width ) 
				  ) {

				last if $results{$width.'x'.$height};
				$results{$width.'x'.$height} = sprintf('%s" x %s"', $width, $height );
				last if ! $Paper->cuttable();

				$openprint::log->debug("Cut: $width x $height") if $debug;
				if ( $height > $width ) {
					$height /= 2;
				} else {
					$width /= 2;
				} # end if
			} # end while
		} # end if
		} # end if type
	} # end foreach Paper

	return map { $_, $results{$_} }
	sort { 
		my ( $w1, $h1 ) = split('x', $a );
		my ( $w2, $h2 ) = split('x', $b );
		return -1 if $w1 < $w2;
		return 1 if $w1 > $w2;
		return -1 if $h1 < $h2;
		return 1 if $h1 > $h2;
		return 0;
	} keys %results;

} # end sub get_sheetsize 

1;

__END__
