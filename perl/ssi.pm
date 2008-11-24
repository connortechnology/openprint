package ssi;

use strict;
use countries;
use states;
use provinces;

use Date::Calc qw(Days_in_Month Month_to_Text);
use HTML::Entities qw(encode_entities);

require sets;
require sql;

use openprint;
use vars qw( $log $dbh %config %session %param );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*session = \%openprint::session;
*param = \%openprint::param;

sub do_new_substitution {
	my ( $r, $log, $dbh, $command, $text, $variable ) = @_;
	if ( $$command =~ /^while\s*\(\s*(.*)\s*\)/ ) {
		my $dataname = $1;
		if ( $$text =~ /(.*?)<\?\s*endwhile\s*\(\s*\Q$dataname\E\s*\)\s*\?>(.*)/si ) {
			my $middle = $1;
			my $end = $2;
			my $replacement_text = '';
			while ( 1 ) {
				$_ = eval $dataname;
				$log->error( "Eval error of ($dataname), Reason: " . $@ ) if $@;
				last if ! $_;
				$replacement_text .= variable_substitution( $r, $log, $dbh, \$middle, $variable );
			} # end while
			return $replacement_text . variable_substitution( $r, $log, $dbh, \$end, $variable );
		} else {
			$log->debug("Unable to find terminating while ($$command)");
			return variable_substitution( $r, $log, $dbh, $text, $variable );
		} # end if
	} elsif ( $$command =~ /^if\s*\(\s*(.*)\s*\)/ ) {
		my $dataname = $1;
		if ( $$text =~ /(.*?)<\?\s*endif\s*\(\s*\Q$dataname\E\s*\)\s*\?>(.*)/si ) {
			my $middle = $1;
			my $end = $2;
			my $replacement_text = '';
			my $elsetext = '';

			if ( $middle =~ /(.*?)<\?\s*else\s*\(\s*\Q$dataname\E\s*\)\s*\?>(.*)/si ) {
				$middle = $1;
				$elsetext = $2;
			} # end if

			$_ = eval $dataname;
			$log->error( "Eval error of if ($dataname), Reason:" . $@ ) if $@;
			if ( $_ ) {
				$replacement_text .= variable_substitution( $r, $log, $dbh, \$middle, $variable );
			} elsif ( $elsetext ne '' ) {
				$replacement_text .= variable_substitution( $r, $log, $dbh, \$elsetext, $variable );
			} # end if
			return $replacement_text . variable_substitution( $r, $log, $dbh, \$end, $variable );
		} else {
			$log->debug("Unable to find terminating if ( $$command )");
			return variable_substitution( $r, $log, $dbh, $text, $variable );
		} # end if
	} elsif ( $$command =~ /pop\s*\((.*)\)\s*=\s*([\%\w]*)/i ) {
		my $variables = $1;
		my $dataname = variable_substitution( $r, $log, $dbh, \$2, $variable );
		my @var_names = split( ',', $variables );
		foreach my $name ( @var_names ) {
			$name =~ s/^\s*(\w+)\s*$/$1/;
			$$variable{$name} = shift @{$$variable{$dataname}};
		} # end foreach
		return variable_substitution( $r, $log, $dbh, $text, $variable );
	} elsif ( $$command =~ /^eval\s*\(\s*(.*)\s*\)/ms ) {
		$_ = eval $1;
		$log->error( "Eval error of ($1), Reason: " . $@ ) if $@;
		return variable_substitution( $r, $log, $dbh, $text, $variable );
	} elsif ( $$command =~ /^echo\s*\(\s*(.*)\s*\)/ms ) {
		my $result = eval $1;
		$log->error( "Eval error of ($1), Reason: " . $@ ) if $@;
		$result .= variable_substitution( $r, $log, $dbh, $text, $variable ) if $text;
		return $result;
	} elsif ( $$command =~ /^hecho\s*\(\s*(.*)\s*\)/ms ) {
		my $result = eval $1;
		$log->error( "Eval error of ($1), Reason: " . $@ ) if $@;
		$result = htmlize($result);
		$result .= variable_substitution( $r, $log, $dbh, $text, $variable ) if $text;
		return $result;
	} else {
		my $replacement = $$variable{$$command};
#my $replacement = variable_substitution( $r, $log, $dbh, $$variable{$command}, $variable );
#$log->debug("Replacement: $command : $replacement");
		return $replacement . variable_substitution( $r, $log, $dbh, $text, $variable );
	} # end if

} # end sub do_new_substitution

sub do_include {
	my ( $r, $log, $dbh, $text, $variable ) = @_;
	if ( $$text =~ /(.*?)<!--\s*#include\s+virtual="(.*?)"\s*-->(.*)/ms ) {
		my ( $before, $middle, $after ) = ( $1, $2, $3 );
		#my $file = variable_substitution( $r, $log, $dbh, \$middle, $variable );
		my $file = $middle;
		if ( ! ( $file =~ /^\// ) ) {
# Use a path relative to the current page
			my $path = $r->uri();
			$path =~ s/(.*\/).*/$1/;
			$file = $path . $file;
		} # end if
	my $blah = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . $file);
	return $before . variable_substitution( $r, $log, $dbh, \$blah, $variable ).variable_substitution( $r, $log, $dbh, \$after, $variable );
	} # end if
	return $$text;
} # end sub do_include

#i'm adding more and more recursion in an attempt to make this faster.
# this big bottleneck is all the regexp searches through the text.
# the text is huge, so the more we break it down, the faster these get.
sub variable_substitution {
	my ( $r, $log, $dbh, $text, $variable ) = @_;
	if ( $$text =~ /(.*?)<\?\s*(.*?)\s*\?>(.*)/ms ) {
		my ( $before, $middle, $after ) = ( $1, $2, $3 );
		$before .= do_new_substitution( $r, $log, $dbh, \$middle, \$after, $variable );
		return do_include( $r, $log, $dbh, \$before, $variable );
	} # end if
	return do_include( $r, $log, $dbh, $text, $variable );
} # end sub variable_substitution

sub htmlize {
	return if ! @_;
	if ( @_ == 1 ) {
		$_ = shift;
		return if ! defined $_;
		$_ =~ s/&/&amp;/mg;
		$_ =~ s/"/&quot;/mg;
		$_ =~ s/</&lt;/mg;
		$_ =~ s/>/&gt;/mg;
		$_ =~ s/\r\n/<br\/>/mg;
		$_ =~ s/\n\r/<br\/>/mg;
		$_ =~ s/\n/<br\/>/mg;
		return $_;
	} # end if
	for( $_ = 0; $_ < @_; $_ += 1 ) {
		next if ! defined $_[$_];
		$_[$_] =~ s/&/&amp;/mg;
		$_[$_] =~ s/"/&quot;/mg;
		$_[$_] =~ s/</&lt;/mg;
		$_[$_] =~ s/>/&gt;/mg;
		$_[$_] =~ s/\r\n/<br\/>/mg;
		$_[$_] =~ s/\n\r/<br\/>/mg;
		$_[$_] =~ s/\n/<br\/>/mg;
	} # end for
	return @_;
} # end sub htmlize

sub make_drop_down {
	my ( $search_data, $checkval, $length ) = @_;
	my ( $temp, $checked );

	$temp = '';
	for ( my $n = 0; $n < @{$search_data}; $n += 2) {
		$checked = $checkval eq $$search_data[$n] ? ' selected="selected"' : '';
		$temp .= sprintf('<option value="%s"%s>%s</option>', HTML::Entities::encode_entities($$search_data[$n]), $checked, HTML::Entities::encode_entities( $length ? substr($$search_data[$n + 1],0, $length) : $$search_data[$n + 1] ) );
	} # end for
	return $temp;
} # sub make_drop_down

sub fill_drop_down {
	my ( $log, $dbh, $search, $checkval, $length ) = @_;
	my ( $temp, @search_data, $n, $checked);

	@search_data = sql::execute( $log, $dbh, $search );

	return make_drop_down( \@search_data, $checkval, $length );
} # sub customer_drop_down
sub make_select {
	my ( $options, $checkarray, $length ) = @_;

	my $temp = '';

	for ( my $n = 0; $n < @{$options}; $n += 2 ) {
		my $checked = ( sets::isin( $$options[$n], @{$checkarray} ) ? ' selected="selected"' : '' );
		$temp .= "<option value=\"$$options[$n]\"$checked>" . ( $length ne '' ? substr($$options[$n + 1],0, $length): $$options[$n+1] ) . "</option>\n";
	} # end for

	return $temp;
} # end sub make_select

sub fill_select {
	my ( $log, $dbh, $search, $length, @checkarray ) = @_;
	my @search_data = sql::execute( $log, $dbh, $search );
	return make_select( \@search_data, \@checkarray, $length );
} # sub customer_drop_down

sub return_states_and_provinces {
	my @states_and_provinces = ();
	push @states_and_provinces, @states::states;
	push @states_and_provinces, @provinces::provinces;
	return make_select( \@states_and_provinces, \@_ );
} # end sub return_states_and_provinces

sub return_states {
	return make_drop_down( \@states::states, shift );
} # end sub return_states

sub return_provinces {
	return make_drop_down( \@provinces::provinces, shift );
} # end sub return_provinces

sub return_countries {
	return make_select( \@countries::countries, \@_ );
} # end sub return_countries

sub return_years {
	my ( $start, $end, $selected ) = @_;
	$start = $openprint::config{'startYear'} if ! $start;
	$end = (localtime(time))[5] + 1901 if ! $end;
	$selected = (localtime(time))[5] + 1900 if ! defined $selected;
	my @years = map { $_, $_ } ( $start .. $end );	
	return make_drop_down( \@years, $selected );
} # end sub return_years

sub getyears {
	my ( $startyear, $numyears, $selected ) = @_;
	my $years = '';

	$selected = (localtime(time))[5] + 1900 if ! defined $selected;
	$numyears = 5 if ! $numyears;

	for ( my $year = $startyear; $year < $startyear + $numyears; $year += 1 ) {
		$years .= "<option value=\"$year\" " . ($selected == $year ? 'selected="selected"' : "" ) .">$year</option>\n";
	} # end for

	return $years;
} # end sub getyears

sub getmonths {
	my @months = map { $_, Date::Calc::Month_to_Text( $_ ) } ( 1 .. 12 );
	my $selected = shift;
	$selected = (localtime(time))[4]+1 if ! defined $selected;
	return make_drop_down( \@months, $selected );
} # edn sub getmonths

sub getdays {
	my ( $selected, $year, $month ) = @_;
	my $maxdays = 31;
	if ( $year and $month and ( $maxdays > Days_in_Month( $year, $month ) ) ) {
		$maxdays = Days_in_Month( $year, $month );
	} # en dif
	my @days = map { $_, $_ } ( 1 .. $maxdays );
	$selected = (localtime(time))[3] if ! defined $selected;
	return make_drop_down( \@days, $selected );
} # end sub getdays

sub getemployee_numbers {
	my ( $r, $log, $dbh, $selected ) = @_;
	my ( $temp, $employees );

	my @results = sql::execute( $log, $dbh, 'SELECT * FROM EmployeeNumbers' );
	for ( my $index = 0; $index < @results; $index += 3 ) {
		if ( $results[$index] eq $selected ) {
			$employees .= "<option value=\"$results[$index]\" selected=\"selected\">";
		} else {
			$employees .= "<option value=\"$results[$index]\">";
		} # end if

		$employees .= get_range_text($results[$index+1],$results[$index+2]);
		$employees .= "</option>\n";
	} #end for

	return $employees;
}

sub getannual_sales {
	my ( $r, $log, $dbh, $selected ) = @_;
	my ( $temp, $employees );

	my @results = sql::execute( $log, $dbh, "SELECT ID,Min,Max FROM AnnualSales ORDER BY Id" );
	for ( my $index = 0; $index < @results; $index += 3 ) {
		if ( $results[$index] eq $selected ) {
			$employees .= "<option value=\"$results[$index]\" selected>";
		} else {
			$employees .= "<option value=\"$results[$index]\">";
		} # end if
		
		$employees .= get_range_text($results[$index+1],$results[$index+2]);
		$employees .= "</option>\n";
	} #end for

	return $employees;
} # end sub getannual_sales

sub get_range_text {
	my ( $min, $max ) = @_;
	my $text = '';

	if ( $min eq '' ) {
		$text = 'Under '
	} else {
		$text = $min;
	} # end if
	if ( $max eq '' ) {
		$text .= ' or more';
	} else {
		$text .= ' - ' if $min ne '';
		$text .= $max;
	} # end if
	return $text;
} # end sub get_range_text

sub fix_date {
	my ( $year, $month, $day ) = @_;
	$month = int $month;
	$month = 12 if ( $month > 12 );
	$month = 1 if $month < 0;
	if ( $year and $month and $day > Days_in_Month( $year, $month ) ) {
		$day = Days_in_Month( $year, $month );
	} # end if
	return ( $year, $month, $day );
} # end sub fix_date

sub get_dates {
	my ( $log, $dbh, $year, $month, $day ) = @_;

	( $year, $month, $day ) = fix_date( int $year, int $month, int $day );

	my ( $startYear ) = $openprint::config{'startYear'};
	$startYear = 2002 if ! $startYear;

	return (
			getyears( $startYear, (localtime(time))[5]-100, $year ),
			getmonths($month),
			getdays($day, $year, $month ),
			$year ? join('-', $year, $month, $day ) : undef,
			);
}

sub get_start_end_dates {
	my ( $log, $dbh, $variable, $startYear, $startMonth, $startDay, $endYear, $endMonth, $endDay ) = @_;

	my $start;
	( $start ) = $openprint::config{'startYear'};
	$start = 2002 if ! $start;
	if ( ! $startYear ) {
		$startYear = (localtime(time))[5]+1900;
	} # end if

	$startMonth = $startMonth ? $startMonth : (localtime(time))[4]+1;
	$endYear = $endYear ? $endYear : (localtime(time))[5]+1900;
	$endMonth = $endMonth ? $endMonth : (localtime(time))[4]+1;

	if ( $startDay > Days_in_Month( $startYear, $startMonth ) ) {
		$startDay = Days_in_Month( $startYear, $startMonth );
	} # end if
	if ( $endDay > Days_in_Month( $endYear, $endMonth ) ) {
		$endDay = Days_in_Month( $endYear, $endMonth );
	} # end if

	$$variable{'ddmStartYear'} = $$variable{'startyears'} = getyears( $start, (localtime(time))[5]-100, $startYear );
	$$variable{'ddmEndYear'} = $$variable{'endyears'} = getyears( $start, (localtime(time))[5]-100, $endYear );
	$$variable{'ddmStartMonth'} = $$variable{'startmonths'} = getmonths($startMonth);
	$$variable{'ddmEndMonth'} = $$variable{'endmonths'} = getmonths($endMonth);
	$$variable{'ddmStartDay'} = $$variable{'startdays'} = getdays($startDay);
	$$variable{'ddmEndDay'} = $$variable{'enddays'} = getdays($endDay ? $endDay : (localtime(time))[3]);

	$$variable{'StartDate'} = join( '-', $startYear, $startMonth, ( $startDay ? $startDay : 1 ) );
	$$variable{'EndDate'} = join( '-', $endYear, $endMonth, ( $endDay ? $endDay : (localtime(time))[3] ) );

} # end sub get_start_end_dates

sub writeButton {
	my ( $log, $dbh, $name, $gif, $onclick, $href, $text ) = @_;
	if ( $href eq '' ) {
		$href='#';
	} # end if
	my $html = qq{<a id="$name" href="$href" class="buttonImageOff" };
	if ( $onclick ne '' ) {
		$html .= 'onclick="';
		if ( ( $openprint::config{'ButtonsUseImages'} and ($openprint::config{'ButtonsUseImages'} eq 'true') ) and $gif ) {
			$html .= "btnOff('$name');";
		} # end if
		$html .= $onclick."return false;\" ";
	} # end if
	$html .= "onmouseover=\"if ( typeof(btnOn) == 'function' ) { btnOn('$name');}\" onmouseout=\"if ( typeof(btnOff) == 'function' ) { btnOff('$name');}\">";
	if ( ( $openprint::config{'ButtonsUseImages'} and ($openprint::config{'ButtonsUseImages'} eq 'true') ) and $gif ) {
		$html .= "<img src=\"/images/buttons/off/$gif\" border=\"0\" name=\"$name\"";
		if ( $text ne '' ) {
			$html .= "alt=\"$text\"";
		} # end if
		$html .= "/>";
	} else {
		$html .= '<span class="l"></span><span class="c">' . $text .'</span><span class="r"></span>';
	}
	$html .= '</a>';
	return $html;
} # end sub writeButton

sub checked {
	if ( $_[0] ) {
		return 'checked="checked"';
	} # end if
	return '';
} # end sub checked

sub writeTip {
	my $word = shift;
return qq{<span class="TipLink" onmouseover="if ( typeof(tipOn) == 'function' ) {tipOn('$word',3,event);}" onmouseout="if ( typeof(tipOff) == 'function' ) {tipOff('$word');}">$word</span>};
}

sub setup_date_select {
    my ( $page, $prefix, $delta ) = @_;
    if ( ( ! $session{$page.'?'.$prefix.'_start_year'} ) or ( time - $session{'lastupdated'} > 3600 ) ) {
        @session{$page.'?'.$prefix.'_start_year',$page.'?'.$prefix.'_start_month',$page.'?'.$prefix.'_start_day'} = Date::Calc::Add_Delta_Days( Date::Calc::Today(), $delta );
        @session{$page.'?'.$prefix.'_end_year',$page.'?'.$prefix.'_end_month',$page.'?'.$prefix.'_end_day'} = Date::Calc::Today();
    } else {
        @session{$page.'?'.$prefix.'_start_year',$page.'?'.$prefix.'_start_month',$page.'?'.$prefix.'_start_day'} = ssi::fix_date( @session{$page.'?'.$prefix.'_start_year',$page.'?'.$prefix.'_start_month',$page.'?'.$prefix.'_start_day'} );
        @session{$page.'?'.$prefix.'_end_year',$page.'?'.$prefix.'_end_month',$page.'?'.$prefix.'_end_day'} = ssi::fix_date( @session{$page.'?'.$prefix.'_end_year',$page.'?'.$prefix.'_end_month',$page.'?'.$prefix.'_end_day'} );
    } # end if
} # end sub setup_date_select

sub date_select {
	 my ( $prefix, $value, $onchange ) = @_;

	 my ($year,$month,$day, $hour,$min,$sec) = Date::Calc::Localtime( $value ? Date::Parse::str2time( $value ) : time );

	 my $html = '';
	 $html .= sprintf('<span id="%1$s_date"><select name="%1$s_year" onchange="%2$s">', $prefix, $onchange );
	 $html .= return_years( undef, undef, $year );
	 $html .= '</select>';
	 $html .= sprintf('<select name="%1$s_month" onchange="%2$s">', $prefix, $onchange );
	 $html .= getmonths( $month );
	 $html .= '</select>';
	 $html .= sprintf('<select name="%1$s_day" onchange="%2$s">', $prefix, $onchange );
	 $html .= getdays( $day, $year, $month );
	 $html .= '</select></span>';
	 return $html;
} # end sub date_select

sub datetime_select {
	 my ( $prefix, $value, $onchange ) = @_;

	 my ($year,$month,$day, $hour,$min,$sec) = Date::Calc::Localtime( $value ? Date::Parse::str2time( $value ) : time );
#$openprint::log->debug("$year,$month,$day, $hour:$min:$sec");

	 my $html = '';
	 $html .= sprintf('<span id="%1$s_date"><select name="%1$s_year" onchange="%2$s">', $prefix, $onchange );
	 $html .= return_years( undef, undef, $year );
	 $html .= '</select>';
	 $html .= sprintf('<select name="%1$s_month" onchange="%2$s">', $prefix, $onchange );
	 $html .= getmonths( $month );
	 $html .= '</select>';
	 $html .= sprintf('<select name="%1$s_day" onchange="%2$s">', $prefix, $onchange );
	 $html .= getdays( $day, $year, $month );
	 $html .= '</select></span>';
	 $html .= sprintf('<span id="%1$s_time"><select name="%1$s_hour" onchange="%2$s">', $prefix, $onchange );
	 $html .= make_drop_down( [ map { $_, $_ } ( 0 .. 23 ) ], $hour );
	 $html .= '</select>';
	 $html .= ':';
	 $html .= sprintf('<select name="%1$s_minute" onchange="%2$s">', $prefix, $onchange );
	 $html .= make_drop_down( [ map { $_, $_ } ( 0 .. 59 ) ], $min );
	 $html .= '</select></span>';
	 return $html;
} # end sub datetime_select

1;

__END__
~		 
