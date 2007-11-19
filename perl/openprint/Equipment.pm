package openprint::Equipment;
@ISA = qw( openprint::Object );
use strict;
require openprint::Object;
use openprint ();
require openprint::EquipmentSpecification;
require sql;

my $debug = 0;
my %find_cache;
my %fields = (
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
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;

	my $hash_key = join(';',map { $_, ref $params{$_} eq 'HASH' ? join(';',%{$params{$_}}) :$params{$_} } sort keys %params );
#$openprint::log->debug("Hash key: $hash_key");
	return @{$find_cache{$hash_key}} if $find_cache{$hash_key};
	my $sql;
	my @values;
	$sql = q{SELECT * FROM tbl_Equipment WHERE 1>0};

	if ( $params{'id'} ) {
		if ( ref $params{id} eq 'ARRAY' ) {
			if ( @{$params{id}} > 1 ) {
			$sql .= ' AND lngindex IN (' . join(',', map {'?'} @{$params{id}}  ) . ')';
			push @values, @{$params{id}};
			} else {
			$sql .= ' AND lngindex=?';
			push @values, $params{id};
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
			$sql .= q{ AND (SELECT strValue FROM tbl_Equipment_Specifications WHERE lngEquipmentIndex=tbl_Equipment.lngIndex AND strName=? LIMIT 1)=?};
			push @values, $name, $params{'Specifications'}{$name};
		} # end foreach
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
	if ( $params{'category'} ) {
		$sql .= q{ AND strCategory=?};
		push @values, $params{'category'};
	} # end if

	$sql .= " OR $params{'or'}" if $params{'or'};
	$sql .= " ORDER BY $params{'order'}" if ( $params{'order'} );
	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->error( "Error loading Equipment ($sql) (@values) :" . $openprint::dbh->errstr );
		return;
	} elsif ( $debug ) {
	#$openprint::log->debug( 'Number of results: ' . @$data );
		$openprint::log->debug( $sql . join(',',@values) );
	} # end if
	
	@{$find_cache{$hash_key}} = map { new openprint::Equipment( $_->{lngindex}, $_ ) } @$data;
	return @{$find_cache{$hash_key}};
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( q{SELECT * FROM tbl_Equipment WHERE lngIndex=?}, {}, $$self{'id'} );
	} # end if
	@$self{keys %fields} = @$data{@fields{keys %fields}};
} # end sub load

sub fits {
   my ( $self, $width, $height, $calliper ) = @_;

   if ( $self->specification('Maximum Sheet Width') or $self->specification('Maximum Sheet Length') ) {
	   my $imp = openprint::imposition::fit( $width, $height, $self->specification('Maximum Sheet Width'),$self->specification('Maximum Sheet Length') );
#$log->debug("Impo: $imp{'Imposition'} $imp{'Rows'}x$imp{'Cols'}");
	   if ( ! $imp->imposition() ) {
		   return sprintf('Too big %s x %s on %s x %s', $width, $height, $self->specification('Maximum Sheet Width'),$self->specification('Maximum Sheet Length') );
	   } # end if
   } # end if

   if ( $self->specification('Minimum Sheet Width') or $self->specification('Minimum Sheet Length') ) {
	   my $imp = openprint::imposition::fit( $self->specification('Minimum Sheet Width'),$self->specification('Minimum Sheet Length'), $width, $height );
	   if ( ! $imp->imposition() ) {
		   return sprintf('Too small %s x %s on %s x %s', $width, $height, $self->specification('Minimum Sheet Width'),$self->specification('Minimum Sheet Length') );
	   } # end if
   } # end if

   if ( $self->specification('Minimum Calliper') and 1*$calliper < 1*$self->specification('Minimum Calliper') ) {
	   return "Project is too thin. Project Calliper: $calliper Inches, Equipment Min Calliper: " . $self->specification('Minimum Calliper') .' Inches.';
   } # end if
   if ( $self->specification('Maximum Calliper') and 1*$calliper > 1*$self->specification('Maximum Calliper') ) {
	   return "Project is too thick. Project Calliper: $calliper Inches, Equipment Max Calliper: " . $self->specifications('Maximum Calliper') .' Inches.';
   } # end if

} # end sub fits

sub Specifications {
	my $self = shift;
	return openprint::EquipmentSpecification::find( 'Equipment'=>$self, 'order'=>'strname, dblmin' );
}

sub specification {
	my ( $self, $name, $range ) = @_;

	if ( ! $$self{'Specifications'} ) {
		foreach my $Spec ( openprint::EquipmentSpecification::find( 'Equipment'=>$self, 'order'=>'dblmin,dblmax' ) ) {
			push @{$$self{'Specifications'}{$Spec->name()}}, $Spec;
		} # end foreach
	} # end if

	if ( ! $$self{'Specifications'} ) {
		#$openprint::log->warn("No specfications for " . $self->name() );
		return;
	}
	if ( ! $$self{'Specifications'}{$name} ) {
		#$openprint::log->warn("No specfications for ($name) " . $self->name() );
		return;
	}

if ( ! defined $range ) {
	if ( $$self{'Specifications'}{$name} and @{$$self{'Specifications'}{$name}} ) {
		return $$self{'Specifications'}{$name}[0]->value() 
	}
	return;
} # end if
$openprint::log->debug("Looking for $name : $range") if $debug;

	$range = 1*$range;
	my $i = 0;
	my $x;
	my $y;
	for ( ; $i < @{$$self{'Specifications'}{$name}}; $i += 1 ) {
		my $Spec = $$self{'Specifications'}{$name}[$i];
	$openprint::log->debug("Examining: (" . $Spec->min() . 	') (' . $Spec->max() . ') (' . $Spec->value() . ') ('.$Spec->interpolate() ) if $debug;
		return $Spec->value() if ( 1*($Spec->min()) == $range ) or (1*($Spec->max()) == $range );

		return $Spec->value() if ( 
			( ($Spec->min() eq '') or ($Spec->min() <= $range))
			and
			( ($Spec->max() eq '') or ($Spec->max() >= $range) )
			and ! (1*$Spec->interpolate()) );

		# first step, find one less than the min
		last if ( 1*$Spec->min() > $range );
		#last if ( $Spec->max() eq '' and ! $Spec->interpolate() );
	} # end if
	
	if ( $i and $i <= @{$$self{'Specifications'}{$name}} ) {
		$i -= 1;
		# back up
		$x = $$self{'Specifications'}{$name}[$i];
$openprint::log->debug("Found spec for $range:" . $x->min() . ' ' . $x->max() . ' : ' . $x->value() ) if $debug;
		return if ( (1*$x->max()) and ( $x->max() < $range ) and ! $x->interpolate() );
	} else {
$openprint::log->debug("Couldn't find monimum") if $debug;
		return;	
	}
	
	for ( ; $i < @{$$self{'Specifications'}{$name}}; $i += 1 ) {
		my $Spec = $$self{'Specifications'}{$name}[$i];
		return $Spec->value() if ( $Spec->max() == $range ) or ( !(1*$Spec->max()) and ! (1*$Spec->interpolate()) );

		# first step, find one less than the min
		last if ( $Spec->max() > $range );
	} # end foreach
	if ( $i and $i < @{$$self{'Specifications'}{$name}} ) {
		# back up
		$y = $$self{'Specifications'}{$name}[$i];
$openprint::log->debug("Found spec max " . $y->min() . ' ' . $y->max() . ' : ' . $y->value() ) if $debug;
	} else {
$openprint::log->debug("Couldn't find maximum") if $debug;
		return;
	} # end if

	my $value;
	if ( $x == $y ) {
		$value = $x->value();
	} elsif ( $x->interpolate() ) {
		$value = $x->value() + ($range - $x->min())*($y->value()-$x->value())/($y->min()-$x->min());
	} # end if
#$openprint::log->debug("Returning " . $value) if $debug;

	return $value;
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
	sql::end_transaction( $openprint::dbh, $ac );

	return $new;
} # end sub copy

sub delete {
	my $self = shift;

    my $ac = sql::start_transaction( $openprint::dbh );
    sql::execute( undef, undef, q{DELETE FROM tbl_Equipment_Specifications WHERE lngEquipmentIndex=?}, $$self{id} );
    sql::execute( undef, undef, q{DELETE FROM tbl_Service_Prices WHERE lngEquipmentIndex=?}, $$self{id} );
    sql::execute( undef, undef, q{DELETE FROM tbl_Material_Prices WHERE lngEquipmentIndex=?}, $$self{id} );
    sql::execute( undef, undef, q{DELETE FROM Shifts WHERE equipment_id=?}, $$self{id} );
    sql::execute( undef, undef, q{DELETE FROM tbl_Equipment WHERE lngIndex=?}, $$self{id} );
    sql::end_transaction( $openprint::dbh, $ac );

	openprint::logs::insertLogRecord('6', "Equipment Index: $$self{id} - " . $$self{name}, );
} # end sub delete

sub save {
	my ( $self, $param ) = @_;

	my %sql;
	foreach my $k ( keys %fields ) {
		if ( $param and exists $$param{$k} ) {
			$sql{$fields{$k}} = $$param{$k};
		} else {
			$sql{$fields{$k}} = $$self{$k};
		} # end if
	} # end foreach

	my $ac = sql::start_transaction( $openprint::dbh );

	if ( ! $$self{id} ) {
		@$self{id} = sql::execute( undef, undef, q{nextval('Equipment_Index_seq')} );
		$sql{lngindex} = $$self{id};
		sql::insert( undef, undef, 'tbl_Equipment', \%sql );
		openprint::logs::insertLogRecord('34', "Equipment: " . $self->strid(). " - " . $self->name(),);
	} else {
		sql::update( undef, undef, 'tbl_Equipment', ['lngIndex=?',$$self{id}], \%sql );
		openprint::logs::insertLogRecord('35', "Equipment: " . $self->strid(). ' - ' . $self->name(),);
	} # end if

	sql::execute( undef, undef, q{DELETE FROM tbl_Equipment_Specifications WHERE lngEquipmentIndex=?}, $$self{id} );
	foreach my $key ( keys %$param ) {
		if ( $key =~ /txtSpecificationName(.*)/ and $$param{$key} ne '' ) {
			my $i = $1;
			$$param{'txtSpecificationMin'.$i} =~ s/[^\d\.]//g;
			$$param{'txtSpecificationMax'.$i} =~ s/[^\d\.]//g;
			sql::insert( undef, undef, 'tbl_Equipment_Specifications', [
					'lngEquipmentIndex',    $$self{id},
					'dblMin',               ( $$param{'txtSpecificationMin'.$1} ne '' ? $$param{'txtSpecificationMin'.$1} : undef ),
					'dblMax',               ( $$param{'txtSpecificationMax'.$1} ne '' ? $$param{'txtSpecificationMax'.$1} : undef ),
					'strUnits',             $$param{'txtSpecificationUnits'.$1},
					'strName',              $$param{'txtSpecificationName'.$1},
					'strValue',             $$param{'txtSpecificationValue'.$1},
					'interpolate',          $$param{'interpolate'.$1},
					] );
		} # end if
	} # end foreach

	sql::end_transaction( $openprint::dbh, $ac );
	$self->load();
} # end sub save

sub update_schedule {
	my $self = shift;

	if ( $openprint::config{'Smart Schedule'} ne 'Y' ) {
		$openprint::log->debug("Not using Smart Schedule.  Not Updating Press Schedule");
		return;
	} # end if

    $openprint::log->debug("Updating Press Schedule");
    my ( $start_time ) = sql::execute( undef, undef, q{SELECT NOW()} );
    $_ = q{SELECT DISTINCT ProjectIndex, ServiceIndex, StartTime FROM tbl_Projects, Schedule WHERE Equipment_id=? AND Index=ProjectIndex AND tbl_Projects.strStatus='Approved' ORDER BY StartTime};
    my @data = sql::execute( undef, undef, $_, $$self{id} );
    while ( my ( $project_index, $service_index, undef ) = splice @data, 0, 3 ) {
        sql::update( undef, undef, 'Schedule', ['Equipment_id=? AND ServiceIndex=?', $$self{id}, $service_index],
                'StartTime', $start_time
                );
        ( $start_time ) = sql::execute( undef, undef, q{SELECT StartTime+RunTime FROM Schedule WHERE ServiceIndex=?}, $service_index );
    } # end while

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


1;
__END__
