package openprint::Equipment;
@ISA = qw( openprint::Object );
use strict;
require openprint::Object;
use openprint ();
require openprint::EquipmentSpecification;
require openprint::Fold;
require openprint::Location;
require sql;

my $debug = 1;
my %find_cache;
use vars qw( $table $serial %fields %transforms %defaults );
$table = 'tbl_equipment';
$serial= 'Equipment_Index_seq';
%fields = (
	'id'	=>	'lngindex',
	'strid'	=>	'strid',
	'name'	=>	'strname',
	'description'	=>	'strdescription',
	'category'	=>	'strcategory',
	'supplier'	=>	'strsupplier',
	'useinestimating'	=>	'useinestimating',
	'useinscheduling'	=>	'useinscheduling',
	'image'				=>	'image',
	'jmf_enabled'		=>	'jmf_enabled',
	'instantgate_enabled'		=>	'instantgate_enabled',
	'cost_center'		=>	'cost_center',
	'jdf_id'			=> 	'jdf_id',
	'jdf_name'			=> 	'jdf_name',
	'location_id'		=>	'location_id',
	'cip3_in'			=>	'cip3_in',
	'cip3_out'			=>	'cip3_out',
	'cip3_hold'			=>	'cip3_hold',
	'cip3_merge'		=>	'cip3_merge',
	'cip3_monitor'		=>	'cip3_monitor',
	'smartscheduling'	=>	'smartscheduling',
	'servicetype_id'	=>	'servicetype_id',
	'sorting'			=>	'sorting',
	'message'			=>	'message',
);

%defaults = (
	'location_id'		=>	undef,
	'servicetype_id'	=>	undef,
);

sub init_cache {
	%find_cache = ();
} # end sub init_cache

sub find_one {
	if ( $_[0] eq 'openprint::Equipment' ) {
		shift;
	} # end if
	my %params = @_;
	$params{'limit'}=1;
	my @Results = find(%params);
	return $Results[0] if @Results;
} # end sub find_one
# Returns a paper object specified by the parameters
sub find {
	if ( $_[0] eq 'openprint::Equipment' ) {
		shift;
	} # end if
	my %params = @_;

	my $hash_key = join(';',map { $_, ref $params{$_} eq 'HASH' ? join(';',%{$params{$_}}) :$params{$_} } sort keys %params );
#$openprint::log->debug("Hash key: $hash_key");
	return @{$find_cache{$hash_key}} if $find_cache{$hash_key};
	my $sql;
	my @values;
	$sql = q{SELECT * FROM tbl_Equipment WHERE 1>0};

	if ( exists $params{'id'} ) {
		if ( ref $params{id} eq 'ARRAY' ) {
			if ( @{$params{id}} > 1 ) {
				$sql .= ' AND lngindex IN (' . join(',', map {'?'} @{$params{id}}  ) . ')';
				push @values, @{$params{id}};
			} elsif ( @{$params{id}} == 1 ) {
				$sql .= ' AND lngindex=?';
				push @values, $params{id};
			} else {
			} # en dif
		} else {
			$sql .= ' AND lngindex=?';
			push @values, $params{id};
		} # end if
	} # end if
	if ( $params{'strid'} ) {
		$sql .= q{ AND strID=?};
		push @values, $params{'strid'};
	} # end if
	if ( $params{'Name'} ) {
		$sql .= q{ AND strName=?};
		push @values, $params{'Name'};
	} # end if
	if ( $params{'Specifications'} ) {
# Assume specificatiosn is a hash of key/values to match
		foreach my $name ( keys %{$params{'Specifications'}} ) {
			if ( ref $params{'Specifications'}{$name} eq 'ARRAY' ) {
				$sql .= q{ AND (SELECT strValue FROM tbl_Equipment_Specifications WHERE lngEquipmentIndex=tbl_Equipment.lngIndex AND strName=? LIMIT 1) IN ( } . join(',', map {'?'} @{$params{'Specifications'}{$name}}  ) . ' )';
				push @values, $name, @{$params{'Specifications'}{$name}};
			} else {
				$sql .= q{ AND (SELECT strValue FROM tbl_Equipment_Specifications WHERE lngEquipmentIndex=tbl_Equipment.lngIndex AND strName=? LIMIT 1)=?};
				push @values, $name, $params{'Specifications'}{$name};
			} # end if
		} # end foreach
	} # end if
if ( exists $params{'servicetype_id'} ) {
        if ( ref $params{'servicetype_id'} eq 'ARRAY' ) {
            $sql .= ' AND servicetype_id={?}';
            push @values, $params{'servicetype_id'};
        } else {
            $sql .= ' AND ? = ANY(servicetype_id)';
            push @values, $params{'servicetype_id'};
        } # end if
    } # end if

	if ( $params{'UseInEstimating'} ) {
		$sql .= ' AND UseInEstimating=?';
		push @values, 1;
	} # end if
	if ( $params{'UseInScheduling'} ) {
		$sql .= ' AND UseInScheduling=?';
		push @values, 1;
	} # end if
	if ( $params{'use_in_scheduling'} ) {
		$sql .= ' AND UseInScheduling=?';
		push @values, 1;
	} # end if
	if ( $params{'jmf_enabled'} ) {
		$sql .= ' AND jmf_enabled=?';
		push @values, 1;
	} # end if
	if ( $params{'cip3_monitor'} ) {
		$sql .= ' AND cip3_monitor=?';
		push @values, $params{'cip3_monitor'};
	} # end if
	if ( $params{'category'} ) {
		$sql .= q{ AND strCategory=?};
		push @values, $params{'category'};
	} # end if

	$sql .= " OR $params{'or'}" if $params{'or'};
	$sql .= " ORDER BY $params{'order'}" if ( $params{'order'} );
	$sql .= " LIMIT $params{'limit'}" if $params{'limit'};
	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->error( "Error loading Equipment ($sql) (@values) :" . $openprint::dbh->errstr );
		return;
	} elsif ( $debug ) {
		$openprint::log->debug( "openprint::Equipment::find : SQL($sql) VALUES(". join(',',@values).") # Results: " . @$data );
	} # end if
	
	@{$find_cache{$hash_key}} = map { new openprint::Equipment( $_->{lngindex}, $_ ) } @$data;
	return @{$find_cache{$hash_key}};
} # end sub find

sub fits {
   my ( $self, $width, $height, $calliper ) = @_;

   if ( $self->specification('Maximum Sheet Width') and $self->specification('Maximum Sheet Length') ) {
	   my $imp = openprint::imposition::fit( $width, $height, $self->specification('Maximum Sheet Width'),$self->specification('Maximum Sheet Length') );
#$log->debug("Impo: $imp{'Imposition'} $imp{'Rows'}x$imp{'Cols'}");
	   if ( ! $imp->imposition() ) {
		   return sprintf('Too big %s x %s on %s x %s', $width, $height, $self->specification('Maximum Sheet Width'),$self->specification('Maximum Sheet Length') );
	   } # end if
	} elsif ( $self->specification('Maximum Sheet Width') ) {
		if (
			( $width > $self->specification('Maximum Sheet Width') ) and
			( $height > $self->specification('Maximum Sheet Width') ) 
			) {
		   return sprintf('Too big %s x %s on %s', $width, $height, $self->specification('Maximum Sheet Width'));
		} # end if
	} elsif ( $self->specification('Maximum Sheet Height') ) {
		if (
			( $width > $self->specification('Maximum Sheet Height') ) and
			( $height > $self->specification('Maximum Sheet Height') ) 
			) {
		   return sprintf('Too big %s x %s on %s', $width, $height, $self->specification('Maximum Sheet Height'));
		} # end if
	} # end if

   if ( $width and $height ) {
	   if ( $self->specification('Minimum Sheet Width') and $self->specification('Minimum Sheet Length') ) {
		   my $imp = openprint::imposition::fit( $self->specification('Minimum Sheet Width'),$self->specification('Minimum Sheet Length'), $width, $height );
		   if ( ! $imp->imposition() ) {
			   return sprintf('Too small %s x %s on %s x %s', $width, $height, $self->specification('Minimum Sheet Width'),$self->specification('Minimum Sheet Length') );
		   } # end if
	   } elsif ( $self->specification('Minimum Sheet Width') ) {
		   if (
				   ( $width < $self->specification('Minimum Sheet Width') ) and
				   ( $height < $self->specification('Minimum Sheet Width') ) 
			  ) {
			   return sprintf('Too big %s x %s on %s', $width, $height, $self->specification('Maximum Sheet Width'));
		   } # end if
	   } elsif ( $self->specification('Minimum Sheet Length') ) {
		   if (
				   ( $width < $self->specification('Minimum Sheet Length') ) and
				   ( $height < $self->specification('Minimum Sheet Length') ) 
			  ) {
			   return sprintf('Too big %s x %s on %s', $width, $height, $self->specification('Maximum Sheet Width'));
		   } # end if
	   } # end if
   } # end if

   if ( $self->specification('Minimum Calliper') and $calliper and ( 1*$calliper < 1*$self->specification('Minimum Calliper') ) ) {
	   return "Project is too thin. Project Calliper: $calliper Inches, Equipment Min Calliper: " . $self->specification('Minimum Calliper') .' Inches.';
   } # end if
   if ( $self->specification('Maximum Calliper') and $calliper and ( 1*$calliper > 1*$self->specification('Maximum Calliper') ) ) {
	   return "Project is too thick. Project Calliper: $calliper Inches, Equipment Max Calliper: " . $self->specifications('Maximum Calliper') .' Inches.';
   } # end if

} # end sub fits

sub Folds {
	my $self = shift;

	if ( ! $$self{'Folds'} ) {
		@{$$self{'Folds'}} = openprint::Fold::find( 'Equipment'=>$self, 'order'=>'pages,page_columns' );
	} # end if
	return @{$$self{'Folds'}};
} # end sub Folds

sub Fold {
	my $self = shift;
	my %params = @_;
	my $params = \%params;

	if ( ! $$self{'Folds'} ) {
		@{$$self{'Folds'}} = openprint::Fold::find( 'Equipment'=>$self, 'order'=>'lower(name)' );
	} # end if
#$openprint::log->debug("Param" . ref $params );
#foreach my $k ( keys %params ) {
#$openprint::log->debug("Param: $k => $$params{$k}");
#}

	foreach my $Fold ( @{$$self{'Folds'}} ) {
		#$openprint::log->debug("Wanted Pages: $$params{pages}, have $$Fold{pages}") if $debug;
		next if $$params{pages} and ($$Fold{pages} != $$params{pages} );
		$openprint::log->debug("Looking at fold: " . $Fold->name() ) if $debug;
		next if $$params{type} and ( $$Fold{type} ne $$params{type} );

		$openprint::log->debug("Wanted stitching: $$params{stitching}, have $$Fold{stitching}") if $debug;
		next if $$params{stitching} and defined $$Fold{stitching} and $$params{stitching} != $$Fold{stitching};
		$openprint::log->debug("Wanted perfectbind: $$params{perfectbind}, have $$Fold{perfectbind}") if $debug;
		next if $$params{perfectbind} and defined $$Fold{perfectbind} and $$params{perfectbind} != $$Fold{perfectbind};
		$openprint::log->debug("Wanted spinepaste: $$params{spinepaste}, have $$Fold{spinepaste}") if $debug;
		next if $$params{spinepaste} and defined $$Fold{spinepaste} and $$params{spinepaste} != $$Fold{spinepaste};

		$openprint::log->debug("Wanted Page_columns: $$params{page_columns}, have $$Fold{page_columns}") if $debug;
		next if $$Fold{page_columns} and $$params{page_columns} and ($$Fold{page_columns} != $$params{page_columns} );
		$openprint::log->debug("Wanted Page_rows: $$params{page_rows}, have $$Fold{page_rows}") if $debug;
		next if $$Fold{page_rows} and $$params{page_rows} and ($$Fold{page_rows} != $$params{page_rows} );

		$openprint::log->debug("Wanted Page_width: $$params{page_width}, have min:$$Fold{min_width} max:$$Fold{max_width}") if $debug;
		next if ( $params{page_width} and (
				( $$Fold{min_width} and $$Fold{min_width} > $$params{page_width} ) or
				( $$Fold{max_width} and $$Fold{max_width} < $$params{page_width} )
				)) ;
		$openprint::log->debug("Wanted Page_height: $$params{page_height}, have min:$$Fold{min_height} max:$$Fold{max_height}") if $debug;
		next if ( $$params{page_height} and (
				( $$Fold{min_height} and $$Fold{min_height} > $$params{page_height} ) or
				( $$Fold{max_height} and $$Fold{max_height} < $$params{page_height} )
				) );
		#$openprint::log->debug("Wanted imposition: $$params{imposition}, have $$Fold{min_imposition} x $$Fold{'max_imposition}") if $debug;
		next if $$Fold{min_imposition} and $$params{imposition} and ($$Fold{min_imposition} > $$params{imposition});
		next if $$Fold{max_imposition} and $$params{imposition} and ($$Fold{max_imposition} < $$params{imposition});
		$openprint::log->debug("Wanted spinedirection: $$params{spine_direction}, have $$Fold{spine_direction}") if $debug;
		next if $$Fold{spine_direction} and $$params{spine_direction} and ($$Fold{spine_direction} ne $$params{spine_direction} );
		if ( $$params{gsm} ) {
			$openprint::log->debug("Wanted gsm: $$params{gsm}") if $debug;
			my $RunSpeed = $Fold->Specification( $$params{gsm} );
			if ( ! $RunSpeed ) {
$openprint::log->debug("Didn't find runspeed for $$params{gsm}gsm(" . openprint::Paper::gsm_to_weight($$params{gsm})."lbs) on fold " . $Fold->name() . ' on ' . $self->name() );
				next;
			} else {
$openprint::log->debug("Got runspeed $$RunSpeed{runspeed}") if $debug;
			} # end if
		} # end if
$openprint::log->debug("Got fold" . $Fold->description()) if $debug;
		return $Fold;
$openprint::log->debug("NEVER Got fold" . $Fold->description()) if $debug;
	} # end foreach Fold
	return;
} # end sub Fold

sub Specifications {
	my $self = shift;
	return openprint::EquipmentSpecification::find( 'Equipment'=>$self, 'order'=>'strname, dblmin' );
} # end sub Specifications

sub specification {
	my $Specification = Specification( @_ );
	if ( ! $Specification ) {
		return;
	} # end if
	return $$Specification{'value'};
} # end sub specification

sub Specification {
	my ( $self, $name, $range ) = @_;

	if ( ! $$self{'Specifications'} ) {
		foreach my $Spec ( openprint::EquipmentSpecification::find( 'Equipment'=>$self, 'order'=>'dblmin,dblmax' ) ) {
			push @{$$self{'Specifications'}{$Spec->name()}}, $Spec;
		} # end foreach
	} # end if

	if ( ! $$self{'Specifications'} ) {
		#$openprint::log->warn("No specfications for " . $self->name() );
		return;
	} # end if
	if ( ! $$self{'Specifications'}{$name} ) {
		#$openprint::log->warn("No specfications for ($name) " . $self->name() );
		return;
	} # end if

if ( ! defined $range ) {
	if ( $$self{'Specifications'}{$name} and @{$$self{'Specifications'}{$name}} ) {
		return $$self{'Specifications'}{$name}[0];
	} # end if
	return;
} # end if
#$openprint::log->debug("Looking for $name : $range") if $debug;

	$range = 1*$range;
	my $i = 0;
	my $x;
	my $y;
	for ( ; $i < @{$$self{'Specifications'}{$name}}; $i += 1 ) {
		my $Spec = $$self{'Specifications'}{$name}[$i];
	#$openprint::log->debug("Examining: (" . $Spec->min() . 	') (' . $Spec->max() . ') (' . $Spec->value() . ') ('.$Spec->interpolate() ) if $debug;
		return $Spec if ( (1*$$Spec{min}) == $range ) or ((1*$$Spec{max}) == $range );

		return $Spec if ( 
			(! $$Spec{interpolate})
			and (($$Spec{min} eq '') or ($$Spec{min} <= $range))
			and (($$Spec{max} eq '') or ($$Spec{max} >= $range))
			);

		# first step, find one less than the min
		last if 1*$$Spec{min} > $range;
		#last if ( $Spec->max() eq '' and ! $Spec->interpolate() );
	} # end if
	
	if ( $i and $i <= @{$$self{'Specifications'}{$name}} ) {
		$i -= 1;
		# back up
		$x = $$self{'Specifications'}{$name}[$i];
#$openprint::log->debug("Found spec for $range:" . $x->min() . ' ' . $x->max() . ' : ' . $x->value() ) if $debug;
		return if ( (1*$$x{max}) and ( $$x{max} < $range ) and ! $$x{interpolate} );
	} else {
$openprint::log->debug("Couldn't find monimum for $name : $range on " . $$self{'name'}) if $debug;
		return;	
	}

	for ( ; $i < @{$$self{'Specifications'}{$name}}; $i += 1 ) {
		my $Spec = $$self{'Specifications'}{$name}[$i];
		return $Spec if ( (1*$$Spec{min}) <= $range ) and ( ( (1*$$Spec{max}) >= $range ) or ! (1*$$Spec{max}) );

	#$openprint::log->debug("Examining: ($range) (" . $Spec->min() . 	') (' . 1*$Spec->max() . ') (' . $Spec->value() . ') ('.$Spec->interpolate() ) if $debug;
		# first step, find one less than the min
		last if ( ( (1*$$Spec{max}) > $range) or ( ! (1*$$Spec{max}) ) );
	} # end foreach
	if ( $i and $i < @{$$self{'Specifications'}{$name}} ) {
		$y = $$self{'Specifications'}{$name}[$i];
#$openprint::log->debug("Found spec max " . $y->min() . ' ' . $y->max() . ' : ' . $y->value() ) if $debug;
	} else {
$openprint::log->debug("Equipment::specification Couldn't find maximum for $name") if $debug;
		return;
	} # end if

	if ( $x == $y ) {
		return $x;
	} elsif ( $$x{interpolate} ) {
		my $S = $x->copy();
		$$S{min} = $$S{max} = $range;
		$$S{value} = $$x{value} + ($range - $$x{min})*($$y{value}-$$x{value})/($$y{min}-$$x{min});
#$openprint::log->debug("Returning " . $$S{value}) if $debug;
		return $S;
	} # end if
#$openprint::log->debug("Returning nothing") if $debug;
	return;
} # end sub specification

sub copy {
	my $self = shift;

	my $new = new openprint::Equipment();
	foreach my $k ( keys %fields ) {
		$$new{$k} = $$self{$k};
	} # end foreach
	delete $$new{id};
	$$new{name} = 'Copy of ' . $$new{name};
	$new->save();

	my $ac = sql::start_transaction( $openprint::dbh );

	my @specs = sql::execute( undef, undef, q{SELECT dblMin, dblMax, strUnits, strName, strValue, interpolate FROM tbl_Equipment_Specifications WHERE lngEquipmentIndex=?}, $$self{id} );
	while ( my ( $min, $max, $units, $name, $value, $interpolate ) = splice @specs, 0, 6 ) {
		sql::insert( undef, undef, 'tbl_Equipment_Specifications',[
				'lngEquipmentIndex',    $$new{id},
				'dblMin',               ( $min ne '' ? $min : undef ),
				'dblMax',               ( $max ne '' ? $max : undef ),
				'strUnits',             $units,
				'strName',              $name,
				'strValue',             $value,
				'interpolate',			$interpolate,
				] );
	} # end while

# Now do pricing, start with Service Prices
	my @prices = sql::execute( undef, undef, q{SELECT lnglistindex, lngserviceindex, lngmin, lngmax, strunits, dblcost, dblmarkup, dblprice FROM tbl_Service_Prices WHERE lngEquipmentIndex=?}, $$self{id} );
	while ( my ( $list_id, $service_id, $min, $max, $units, $cost, $markup, $price ) = splice @prices, 0, 8 ) {
		sql::insert( undef, undef, 'tbl_Service_Prices',[
				'lnglistindex',     $list_id,
				'lngserviceindex',  $service_id,
				'lngmin',           $min,
				'lngmax',           $max,
				'strunits',         $units,
				'dblcost',          $cost,
				'dblmarkup',        $markup,
				'dblPrice',         $price,
                'lngEquipmentindex', $$new{id},
				]);
	} # end while
	@prices = sql::execute( undef, undef, q{SELECT lnglistindex, lngmaterialindex, lngmin, lngmax, strunits, dblcost, dblmarkup, dblprice FROM tbl_Material_Prices WHERE lngEquipmentIndex=?}, $$self{id} );
	while ( my ( $list_id, $service_id, $min, $max, $units, $cost, $markup, $price ) = splice @prices, 0, 8 ) {
		sql::insert( undef, undef, 'tbl_Material_Prices',[
				'lnglistindex',     $list_id,
				'lngmaterialindex', $service_id,
				'lngmin',           $min,
				'lngmax',           $max,
				'strunits',         $units,
				'dblcost',          $cost,
				'dblmarkup',        $markup,
				'dblPrice',         $price,
				'lngEquipmentindex', $$new{id},
				] );
	} # end while
	# Equipment_shifts
	foreach my $ES ( openprint::Equipment_Shift::find('equipment_id'=>$$self{id}) ) {
		$ES->copy()->save({'equipment_id'=>$$new{id}});
	} # end foreach $ES
	sql::end_transaction( $openprint::dbh, $ac );

	return $new;
} # end sub copy

sub delete {
	my $self = shift;

	delete $openprint::Object::cache{'openprint::Equipment'}{$$self{id}} if $openprint::Object::cache{'openprint::Equipment'};

    my $ac = sql::start_transaction( $openprint::dbh );
    sql::execute( undef, undef, q{DELETE FROM tbl_Equipment_Specifications WHERE lngEquipmentIndex=?}, $$self{id} );
    sql::execute( undef, undef, q{DELETE FROM tbl_Service_Prices WHERE lngEquipmentIndex=?}, $$self{id} );
    sql::execute( undef, undef, q{DELETE FROM tbl_Material_Prices WHERE lngEquipmentIndex=?}, $$self{id} );
    sql::execute( undef, undef, q{DELETE FROM Equipment_Shifts WHERE equipment_id=?}, $$self{id} );
    sql::execute( undef, undef, q{DELETE FROM tbl_Equipment WHERE lngIndex=?}, $$self{id} );
    sql::end_transaction( $openprint::dbh, $ac );

	openprint::logs::insertLogRecord('6', "Equipment Index: $$self{id} - " . $$self{name}, );
} # end sub delete

sub update_schedule {
	my $self = shift;

	if ( $openprint::config{'Smart Schedule'} ne 'Y' ) {
		$openprint::log->debug("Not using Smart Schedule.  Not Updating Press Schedule");
		return;
	} # end if

    my $starttime_seconds = Date::Parse::str2time( sql::execute( undef, undef, q{SELECT NOW()} ) );
	my $runtime;
	foreach my $Job ( openprint::ScheduledJob( 'equipment_id'=>$$self{'id'}, 'order'=>'starttime', 'starttime_null'=>0 ) ) {
		$Job->save({'starttime_seconds'	=> $starttime_seconds });
		$runtime = $Job->runtime_seconds();
	} # end foreach Job

} # end sub update_schedule

sub next {
	my ($self, $params) = shift;
	my $sql = q{SELECT min(strid) FROM tbl_Equipment WHERE strid > ?};
	my @values = ($$self{'name'});
	if ( $params and $$params{category_id} ) {
		$sql .= ' AND category=?';
		push @values, $$params{category_id};
	} # end if
    my ($name) = sql::execute( undef, undef, $sql, @values );
	( $_ ) = sql::execute( undef, undef, q{SELECT lngindex FROM tbl_Equipment WHERE strid=?}, $name );
    return $_;
} # end sub next

sub Next {
	my ($self, $params) = shift;
	return new openprint::Equipment( $self->next($params) );
} # end sub Next

sub prev {
    my ( $self, $params ) = shift;
	my $sql = q{SELECT max(strid) FROM tbl_Equipment WHERE strid < ?};
	my @values = ($$self{'name'});
	if ( $params and $$params{category_id} ) {
		$sql .= ' AND category=?';
		push @values, $$params{category_id};
	} # end if
    my ($name) = sql::execute( undef, undef, $sql, @values );
	( $_ ) = sql::execute( undef, undef, q{SELECT lngindex FROM tbl_Equipment WHERE strid=?}, $name );
    return $_;
} # end sub next

sub Previous {
	my ($self, $params) = shift;
	return new openprint::Equipment( $self->prev($params) );
} # end sub Next

sub Location {
	return new openprint::Location( $_[0]{location_id} );
} # end sub Location

sub Shifts {
} # end sub

sub servicetype_id {
	my ( $self ) = @_;
	return [] if ! $$self{'servicetype_id'};
	return $$self{'servicetype_id'};
} # end sub servicetype_id

sub ServiceTypes {
	return () if ! $_[0]{'servicetype_id'};
	return map { new openprint::ServiceType( $_ ); } @{$_[0]{'servicetype_id'}};
} # end sub ServiceTypes

1;
__END__
