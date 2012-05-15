use strict;
package ssi;

use countries;
use states;
use provinces;

use Date::Calc qw(Days_in_Month Month_to_Text);
use HTML::Entities qw(encode_entities);

require sets;
require sql;

use openprint ();
use vars qw( $r %variable %session %param %config $log $dbh );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*r = \$openprint::r;

sub do_new_substitution {
	my ( $command, $text, $variable ) = @_;
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
				$replacement_text .= variable_substitution( \$middle, $variable );
			} # end while
			return $replacement_text . variable_substitution( \$end, $variable );
		} else {
			$log->error("Unable to find terminating while ($$command)");
			return variable_substitution( $text, $variable );
		} # end if
	} elsif ( $$command =~ /^if\s*\(\s*(.*)\s*\)/ ) {
		my $dataname = $1;
		if ( $$text =~ /(.*?)<\?\s*endif\s*\(\s*\Q$dataname\E\s*\)\s*\?>(.*)/si ) {
			my $middle = $1;
			my $end = $2;
			if ( $end =~ /^\n\r?$/ ) {
				$end = '';
			} elsif ( $end =~ /^\r?\n$/ ) {
				$end = '';
			} # end if
			#$middle =~ s/^\s*(.*)\s*$//;
			my $replacement_text = '';
			my $elsetext = '';

			if ( $middle =~ /(.*?)<\?\s*else\s*\(\s*\Q$dataname\E\s*\)\s*\?>(.*)/si ) {
				$middle = $1;
				$elsetext = $2;
			} # end if

			$_ = eval $dataname;
			$log->error( "Eval error of if ($dataname), Reason:" . $@ ) if $@;
			if ( $_ ) {
				$replacement_text .= variable_substitution( \$middle, $variable );
			} elsif ( $elsetext ne '' ) {
				$replacement_text .= variable_substitution( \$elsetext, $variable );
			} # end if
			$replacement_text .= variable_substitution( \$end, $variable ) if $end;
			return $replacement_text;
		} else {
			$log->error("Unable to find terminating if ( $$command ) in $$text");
			return variable_substitution( $text, $variable );
		} # end if
	} elsif ( $$command =~ /^eval\s*\(\s*(.*)\s*\)/ms ) {
		$_ = eval $1;
		$log->error( "Eval error of ($1), Reason: " . $@ ) if $@;
		return variable_substitution( $text, $variable );
	} elsif ( $$command =~ /^echo\s*\(\s*(.*)\s*\)/ms ) {
		my $result = eval($1);
		$log->error( "Eval error ($@) of ($1), Reason: " . $@ ) if $@;
		$result .= variable_substitution( $text, $variable ) if $text;
		return $result;
	} elsif ( $$command =~ /^hecho\s*\(\s*(.*)\s*\)/ms ) {
		my $result = eval $1;
		$log->error( "Eval error of ($1), Reason: " . $@ ) if $@;
		$result = html_escape($result);
		$result .= variable_substitution( $text, $variable ) if $text;
		return $result;
	} elsif ( $$command =~ /^checked\s*\(\s*(.*)\s*\)/ms ) {
		my $result = checked( eval $1 );
		$result .= variable_substitution( $text, $variable ) if $text;
		return $result;
	} else {
		my $replacement = $$variable{$$command};
#$log->debug("Replacement: $command : $replacement");
		return $replacement . variable_substitution( $text, $variable );
	} # end if

} # end sub do_new_substitution

sub include {
	my ( $file, $variable ) = @_;
	$variable = \%variable if ! $variable;
	my $blah = misc::load_file( $log, $file );
	return variable_substitution( \$blah, $variable );
}

sub do_include {
	my ( $text, $variable ) = @_;
	if ( $$text =~ /(.*?)<!--\s*#include\s+virtual="(.*?)"\s*-->(.*)/ms ) {
		my ( $before, $file, $after ) = ( $1, $2, $3 );
		if ( ! ( $file =~ /^\// ) ) {
# Use a path relative to the current page
			my $path = $$variable{'uri'};
			$path =~ s/(.*\/).*/$1/;
			$file = $path . $file;
		} # end if
		my $content;
		if ( -f $config{'SkinPath'}.$file ) {
			$content = misc::load_file( $log, $config{'SkinPath'}.$file );
		} else {
			$content = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.$file );
		} # endif
		return $before . variable_substitution( \$content, $variable ).variable_substitution( \$after, $variable );
	} # end if
	return $$text;
} # end sub do_include

#i'm adding more and more recursion in an attempt to make this faster.
# this big bottleneck is all the regexp searches through the text.
# the text is huge, so the more we break it down, the faster these get.
sub variable_substitution {
	my ( $text, $variable ) = @_;
	if ( $$text =~ /(.*?)<\?\s*(.*?)\s*\?>(.*)/ms ) {
		my ( $before, $middle, $after ) = ( $1, $2, $3 );
		$after =~ s/^\s+$//m;
		$before .= do_new_substitution( \$middle, \$after, $variable );
		return do_include( \$before, $variable );
	} # end if
	return do_include( $text, $variable );
} # end sub variable_substitution

my %html_replacements = (
	'&'	=>	'&amp;',
	'"'	=>	'&quot;',
	'<' =>	'&lt;',
	'>' =>	'&gt;',
);
my $replacement_string = join '', keys %html_replacements;
sub html_escape {
	$_[0]=~ s/([\Q$replacement_string\E])/$html_replacements{$1}/g;
    return $_[0];
}

sub escape_quotes {
	for( $_ = 0; $_ < @_; $_ += 1 ) {
		next if ! defined $_[$_];
		$_[$_] =~ s/"/&quot;/mg;
	} 
	return @_;
} # end sub escape_quotes

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

sub unhtmlize {
	return if ! @_;
	if ( @_ == 1 ) {
		$_ = shift;
		return if ! defined $_;
		$_ =~ s/&amp;/&/mg;
		$_ =~ s/&quot;/"/mg;
		$_ =~ s/&lt;/</mg;
		$_ =~ s/&gt;/>/mg;
		$_ =~ s/<br\/>/\n/mg;
		return $_;
	} # end if
	for( $_ = 0; $_ < @_; $_ += 1 ) {
		next if ! defined $_[$_];
		$_[$_] =~ s/&amp;/&/mg;
		$_[$_] =~ s/&quot;/"/mg;
		$_[$_] =~ s/&lt;/</mg;
		$_[$_] =~ s/&gt;/>/mg;
		$_[$_] =~ s/<br\/>/\n/mg;
	} # end for
	return @_;
} # end sub unhtmlize

sub encode_html {
	my ( $html, $tags ) = @_;

	$html =~ s/\r\n/<br\/>/mg;
	$html =~ s/\n\r/<br\/>/mg;
	$html =~ s/\n/<br\/>/mg;
	return $html;
} # end sub encode_html

sub make_drop_down {
	my ( $search_data, $checkval, $length ) = @_;
	my $check_array; 
	if ( ref $checkval eq 'ARRAY' ) {
		$check_array = $checkval;
	} else {
		$check_array = [ $checkval ];
	} # end if

	my $temp = '';
	for ( my $n = 0; $n < @{$search_data}; $n += 2) {
		$temp .= sprintf('<option value="%s"%s>%s</option>', 
			HTML::Entities::encode_entities(Encode::encode('utf-8',$$search_data[$n])), 
			( sets::isin( $$search_data[$n], $check_array ) ? ' selected="selected"' : '' ),
			HTML::Entities::encode_entities( Encode::encode('utf-8',$length ? substr($$search_data[$n + 1],0, $length) : $$search_data[$n + 1] ) ) );
	} # end for
	return $temp;
} # sub make_drop_down

sub fill_drop_down {
	my ( $log, $dbh, $search, $checkval, $length ) = @_;
	my ( $temp, @search_data, $n, $checked);

	@search_data = sql::execute( $log, $dbh, $search );

	return make_drop_down( \@search_data, $checkval, $length );
} # sub customer_drop_down

sub fill_select {
	my ( $log, $dbh, $search, $length, @checkarray ) = @_;
	my @search_data = sql::execute( $log, $dbh, $search );
	return make_drop_down( \@search_data, \@checkarray, $length );
} # sub customer_drop_down

sub return_states_and_provinces {
	my @states_and_provinces = ();
	push @states_and_provinces, @states::states;
	push @states_and_provinces, @provinces::provinces;
	return make_drop_down( \@states_and_provinces, \@_ );
} # end sub return_states_and_provinces

sub return_states {
	return make_drop_down( \@states::states, shift );
} # end sub return_states

sub return_provinces {
	return make_drop_down( \@provinces::provinces, shift );
} # end sub return_provinces

sub return_countries {
	return make_drop_down( \@countries::countries, [@_] );
} # end sub return_countries

sub return_years {
	my ( $start, $end, $selected ) = @_;
	$start = $openprint::config{'startYear'} if ! $start;
	$end = (localtime(time))[5] + 1901 if ! $end;
	#$selected = (localtime(time))[5] + 1900 if ! defined $selected;
#$log->debug("sub return_years $start .. $end $selected");
	return make_drop_down( [ map { $_, $_ } ( $start .. $end ) ], $selected );
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
	if ( $selected ) {
		$selected = int($selected);
	#} elsif ( ! defined $selected ) {
		#$selected = (localtime(time))[4]+1;
	} # end if
	return make_drop_down( \@months, $selected );
} # edn sub getmonths

sub getdays {
	my ( $selected, $year, $month ) = @_;
	my $maxdays = 31;
	if ( $year and $month and ( $maxdays > Days_in_Month( $year, $month ) ) ) {
		$maxdays = Days_in_Month( $year, $month );
	} # en dif
	my @days = map { $_, $_ } ( 1 .. $maxdays );
	$selected = int($selected);
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

sub button {
	my ( $name, $options ) = @_;

	$$options{'href'} = '#' if ! $$options{'href'};
	$$options{'text'} = $name if ! $$options{'text'};

	my $html = qq`<a id="Button$name" href="$$options{href}" class="button $$options{class}" `;
	$html .= qq`title="$$options{title}" ` if $$options{'title'};
	$html .= 'target="$$options{target}" ' if $$options{'target'};
	if ( $$options{'onclick'} ) {
		$html .= 'onclick="';
		$html .= $$options{'onclick'}."return false;\" ";
	} # end if
	$html .= '>';
	if ( ( $openprint::config{'ButtonsUseImages'} and ($openprint::config{'ButtonsUseImages'} eq 'true') ) and $$options{'image'} ) {
		$html .= "<img src=\"/images/buttons/off/$$options{image}\" name=\"Button$name\"";
		if ( $$options{'text'} ) {
			$html .= "alt=\"$$options{text}\"";
		} # end if
		$html .= "/>";
	} elsif ( $openprint::config{'SimpleButtons'} ) {
		$html .= $$options{'text'};
	} else {
		$html .= '<span class="l"></span><span class="c" id="'.$name.'c"' . ( $$options{title} ? ' title="'.$$options{title}.'"' : '' ) .'>' . $$options{'text'} .'</span><span class="r"></span>';
	}
	$html .= "</a>\n";
	return $html;
} # end sub button

sub writeButton {
	my ( $log, $dbh, $name, $gif, $onclick, $href, $text, $options ) = @_;
	if ( $href eq '' ) {
		$href='#';
	} # end if
	my $html = qq`<a id="Button$name" href="$href" class="button $$options{class}" `;
	if ( $onclick ne '' ) {
		$html .= 'onclick="';
		if ( ( $openprint::config{'ButtonsUseImages'} and ($openprint::config{'ButtonsUseImages'} eq 'true') ) and $gif ) {
			$html .= "btnOff('$name');";
		} # end if
		$html .= $onclick."return false;\" ";
	} # end if
	#$html .= "onmouseover=\"if ( typeof(btnOn) == 'function' ) { btnOn('Button$name');}\" onmouseout=\"if ( typeof(btnOff) == 'function' ) { btnOff('Button$name');}\"";
	$html .= '>';
	if ( ( $openprint::config{'ButtonsUseImages'} and ($openprint::config{'ButtonsUseImages'} eq 'true') ) and $gif ) {
		$html .= "<img src=\"/images/buttons/off/$gif\" name=\"Button$name\"";
		if ( $text ne '' ) {
			$html .= "alt=\"$text\"";
		} # end if
		$html .= "/>";
	} else {
		$html .= '<span class="l"></span><span class="c" id="'.$name.'c">' . $text .'</span><span class="r"></span>';
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
return sprintf(q`<span class="TipLink" onmouseover="if ( typeof(tipOn) == 'function' ) {tipOn('%1$s',3,event);}" onmouseout="if ( typeof(tipOff) == 'function' ) {tipOff('%1$s');}">%1$s</span>`, $word );
}

sub setup_date_select {
	my ( $page, $prefix, $delta ) = @_;
	if ( ( ! ( exists $session{$page.'?'.$prefix.'_year'} and exists $session{$page.'?'.$prefix.'_month'} and exists $session{$page.'?'.$prefix.'_day'} ) ) or ( time - $session{$page.'?lastupdated'} > 3600 ) ) {
		if ( $delta ne '' ) {
			@session{$page.'?'.$prefix.'_year',$page.'?'.$prefix.'_month',$page.'?'.$prefix.'_day'} = Date::Calc::Add_Delta_Days( Date::Calc::Today(), 1*$delta );
		} else {
			@session{$page.'?'.$prefix.'_year',$page.'?'.$prefix.'_month',$page.'?'.$prefix.'_day'} = ( '', '', '' );
		} # end if
	} else {
		@session{$page.'?'.$prefix.'_year',$page.'?'.$prefix.'_month',$page.'?'.$prefix.'_day'} = ssi::fix_date( @session{$page.'?'.$prefix.'_year',$page.'?'.$prefix.'_month',$page.'?'.$prefix.'_day'} );
	} # end if
} # end sub setup_date_select

sub date_select {
	my ( $prefix, $value, $options ) = @_;

	my ( $year,$month,$day );
	if ( ref $value eq 'ARRAY' ) {
		( $year, $month, $day ) = @$value;
	} elsif ( $value eq ' ' ) {
		( $year, $month, $day ) = ( '', '', '' );
	} else {
		( $year, $month, $day ) = split('-', $value );
	} # end if
	if ( ref $options eq 'HASH' ) {
	} elsif ( $options ) {
		$options = {'onchange'=>$options};
	} # end if
#$openprint::log->debug(" date_select: $value : ($year,$month,$day), order: $$options{order}");
	$$options{'order'} = 'y,m,d' if ! $$options{'order'};
	my @fields;
	if ( $$options{'fields'} ) {
		@fields = split(',', $$options{'fields'} );
	} 
	
	my ( $start_year, $start_month, $start_day ) = split( '-', $$options{'start'} ) if $$options{'start'};
	my ( $end_year, $end_month, $end_day ) = split( '-', $$options{'end'} ) if $$options{'end'};

	my $html = '';
	$html .= sprintf('<span id="%1$s_date">', $prefix );
	foreach my $o ( split(',', $$options{'order'} ) ) {
		if ( ( $o eq 'y' ) and ( (!@fields) or sets::isin( 'year', \@fields ) ) ) {
			$html .= sprintf(q`<select id="%1$s_year" name="%1$s_year" onchange="setDaysDropDown(this.value,this.form.elements['%1$s_month'].value,this.form.elements['%1$s_day'],this.form.elements['%1$s_day'].value);%2$s"><option value=""></option>`, $prefix, $$options{'onchange'} );
			$html .= return_years( $start_year, $end_year, $year );
			$html .= '</select>';
#$log->debug($html);
		} elsif ( ( $o eq 'm' ) and ( (!@fields) or sets::isin( 'month', \@fields ) ) ) {
			$html .= sprintf(q`<select id="%1$s_month" name="%1$s_month" onchange="setDaysDropDown(this.form.elements['%1$s_year'].value,this.value,this.form.elements['%1$s_day'],this.form.elements['%1$s_day'].value);%2$s"><option value=""></option>`, $prefix, $$options{'onchange'} );
			$html .= getmonths( $month );
			$html .= '</select>';
#$log->debug($html);
		} elsif ( ( $o eq 'd' ) and ( (!@fields) or sets::isin( 'day', \@fields ) ) ) {
			$html .= sprintf('<select id="%1$s_day" name="%1$s_day" onchange="%2$s"><option value=""></option>', $prefix, $$options{'onchange'} );
			$html .= getdays( $day, $year, $month );
			$html .= '</select>';
#$log->debug($html);
		} # endif
	} # end foreach o
	if ( $$options{'with_clear'} ) {
		$html .= ssi::button( $prefix.'_clear', { 'onclick'=>q`date_clear( $('`.$prefix.q`_year'), $('`.$prefix.q`_month'), $('`.$prefix.q`_day') );`.$$options{'onchange'}, text=>'C', title=>'Clear', class=>'Clear'} );
	} # end if
	if ( $$options{'with_today'} ) {
		$html .= ssi::button( $prefix.'_today', { 'onclick'=>q`set_today( $('`.$prefix.q`_year'), $('`.$prefix.q`_month'), $('`.$prefix.q`_day') );`.$$options{'onchange'}, text=>'T', title=>'Today', class=>'Today'} );
	} # end if
	$html .= '<span id="'.$prefix.'_alert"></span>';
	$html .= '</span>';
	return $html;
} # end sub date_select

sub date_select_session {
	my ( $page, $prefix, $options ) = @_;
	return date_select( $prefix, [ @session{$page.'?'.$prefix.'_year',$page.'?'.$prefix.'_month',$page.'?'.$prefix.'_day'} ], $options );
} # end sub date_select_session

sub datetime_select_session {
	my ( $page, $prefix, $options ) = @_;
	return datetime_select( $prefix, [ @session{
			$page.'?'.$prefix.'_year',
			$page.'?'.$prefix.'_month',
			$page.'?'.$prefix.'_day',
			$page.'?'.$prefix.'_hour',
			$page.'?'.$prefix.'_minute'} ], $options );
} # end sub date_select_session

sub datetime_select {
	my ( $prefix, $value, $options ) = @_;

	my ($year,$month,$day, $hour,$min,$sec);
	if ( ! defined $value ) {
		($year,$month,$day, $hour,$min,$sec) = Date::Calc::Localtime( time );
	} elsif ( ref $value eq 'ARRAY' ) {
		($year,$month,$day, $hour,$min,$sec) = @$value;
	} elsif ( $value ) {
		($year,$month,$day, $hour,$min,$sec) = Date::Calc::Localtime( Date::Parse::str2time( $value ) );
		if ( ! $year ) {
$openprint::log->error("No date from $value");
		}
	} else {
		$year = '';
		$month = '';
	} # end if
#$openprint::log->debug("$year,$month,$day, $hour:$min:$sec");

	if ( ref $options eq 'HASH' ) {
	} elsif ( $options ) {
		$_ = $options;
		$options = {};
		$$options{'onchange'} = $_;
	} # end if
#$openprint::log->debug(" date_select: $value : ($year,$month,$day), order: $$options{order}");
	$$options{'order'} = 'y,m,d' if ! $$options{'order'};

	my $html = '';
	$html .= sprintf(q`<span id="%1$s_date"><select id="%1$s_year" name="%1$s_year" onchange="setDaysDropDown(this.value,this.form.elements['%1$s_month'].value,this.form.elements['%1$s_day'],this.form.elements['%1$s_day'].value);%2$s">
`, $prefix, $$options{'onchange'} );
	$html .= '<option value=""> </option>';
	$html .= return_years( undef, undef, $year );
	$html .= '</select>
';
	$html .= sprintf(q`<select id="%1$s_month" name="%1$s_month" onchange="setDaysDropDown(this.form.elements['%1$s_year'].value,this.value,this.form.elements['%1$s_day'],this.form.elements['%1$s_day'].value);%2$s">`, $prefix, $$options{'onchange'} );
	$html .= '<option value=""> </option>';
	$html .= getmonths( $month );
	$html .= '</select>
';
	$html .= sprintf('<select id="%1$s_day" name="%1$s_day" onchange="%2$s">', $prefix, $$options{'onchange'} );
	$html .= '<option value=""> </option>';
	$html .= getdays( $day, $year, $month );
	$html .= '</select></span>
';
	$html .= sprintf('<span id="%1$s_time" class="time"%3$s>
<select id="%1$s_hour" name="%1$s_hour" onchange="%2$s"><option value=""></option>%4$s</select> :
	<select id="%1$s_minute" name="%1$s_minute" onchange="%2$s">
	<option value=""> </option>%5$s
	</select></span>', $prefix, $$options{'onchange'}, 
		( ( exists $$options{'with_time'} and ! $$options{'with_time'} ) ? ' style="display: none;"' : '' ),
		make_drop_down( [ map { $_, $_ } ( 0 .. 23 ) ], $hour ),
		make_drop_down( [ map { $_, sprintf('%.2d', $_ ) } ( 0 .. 59 ) ], $min ),
	);
	if ( $$options{'with_clear'} ) {
		$html .= button( $prefix.'_clear', { 'onclick'=>q`date_clear( $('`.$prefix.q`_year'), $('`.$prefix.q`_month'), $('`.$prefix.q`_day') );`.$$options{'onchange'}, 'text'=>'C' } );
	} # end if
	if ( $$options{'with_today'} ) {
		$html .= button( $prefix.'_today', { 'onclick'=>sprintf(q`set_today( $('%1$s_year'), $('%1$s_month'), $('%1$s_day'), $('%1$s_hour'), $('%1$s_minute') );`, $prefix ).$$options{'onchange'}, 'text'=>'T' } );
	} # end if
	$html .= '<span id="'.$prefix.'_alert"></span>';
	return $html;
} # end sub datetime_select

sub datetime_text {
	 my ( $prefix, $value, $onchange ) = @_;

	 my ($year,$month,$day, $hour,$min,$sec) = Date::Calc::Localtime( $value ? Date::Parse::str2time( $value ) : time );
#$openprint::log->debug("$year,$month,$day, $hour:$min:$sec");

	 my $html = '';
	 $html .= sprintf('<span id="%1$s_year">%2$.4d</span>-<span id="%1$s_month">%3$.2d</span>-<span id="%1$s_day">%4$.2d</span> <span id="%1$s_hour">%5$.2d</span>:<span id="%1$s_minute">%6$.2d</span>', $prefix, $year, $month, $day, $hour, $month );
	 return $html;
} # end sub datetime_text

sub save_params {
	my ( $url, @keys ) = @_;

	foreach ( @keys ) {
#$openprint::log->debug("key $_");
		next if ! exists $param{$_};
		if ( ref $param{$_} eq 'ARRAY' ) {
			$session{"$url?$_"} = join(',', @{$param{$_}} );
#$openprint::log->debug("Storing ($_) (".$session{"$url?$_"}.")");
		} else {
#$openprint::log->debug("Storing ARRAY ($_) (".$session{"$url?$_"}.")");
			$session{"$url?$_"} = $param{$_};
		} # end if
		$session{$url.'?lastupdated'} = time;
	} # end foreach
} # end sub save_params

sub write_override {
	my ( $for, $value, $locked_js, $unlocked_js ) = @_;
	if ( 1 ) {
		return sprintf(q`<input type="hidden" id="%1$s" name="%1$s" value="%2$s"/><img class="Override" src="/images/%3$s.gif" onclick="var e=$('%1$s');if(e.value){e.value='';this.src='/images/unlocked.gif';%5$s} else {e.value='Y';this.src='/images/locked.gif';%4$s}" alt=""/>`, 
				$for, (sets::isin( $value, ['Y', '1' ] ) ? 'Y' : '' ), (sets::isin( $value, ['Y', '1' ] ) ? 'locked' : 'unlocked'), $locked_js, $unlocked_js );
	} else {
		return sprintf('<input type="checkbox" id="%1$s" name="%1$s" value="%2$s" onclick="if(!this.checked){%5$s}else{%4$s};" %3$s /> <label class="radio" for="%1$s">Override</label>', $for, $value, ssi::checked( $value eq 'Y' ), $locked_js, $unlocked_js );
	} # end if
} # end sub write_override

sub count_lines {
	if ( $_[0] ) {
		my @lines = split( "\n", $_[0] );
		return scalar @lines;
	} else {
		return 2;
	} # end if
} # end sub count_lines

sub radio {
    my ( $name, $values, $selected, $options ) = @_;

    my $onclick = $$options{'onclick'} if $options;
    my $html;

	while ( my ( $value, $label ) = splice @{$values}, 0, 2 ) {
        $html .= sprintf(q`
                <input type="radio" name="%1$s" value="%2$s" id="%1$s%6$s%2$s" %4$s%5$s />
                <label class="radio" for="%1$s%2$s">%3$s</label>
                `, $name, $value, $label, checked( $value eq $selected ), 
				( $onclick ? ' onclick="'.$onclick.'"' : '' ),
				$$options{id},
				);
	} # end foreach value
    return $html;
} # end sub radio
sub checkboxes {
	my ( $name, $values, $selected, $options ) = @_;

	my $onclick = $$options{'onclick'} if $options;
	my $html;

	while ( my ( $value, $label ) = splice @{$values}, 0, 2 ) {
		$html .= sprintf(q`
				<input type="checkbox" name="%1$s" value="%2$s" id="%1$s%2$s" %4$s%5$s />
				<label class="radio" for="%1$s%2$s">%3$s</label>
				`, $name, $value, $label, checked( sets::isin( $value, $selected ) ), $onclick ? ' onclick="'.$onclick.'"' : '' );
	} # end foreach value
	return $html;
} # end sub checkboxes

sub date {
	my ( $field, $hash ) = @_;
	$hash = \%openprint::session if ! $hash;
	return @$hash{$field.'_year',$field.'_month',$field.'_day'};
}

sub date_filter {
	my ( $field, $sql_field, $hash ) = @_;
	$sql_field = $field if ! $sql_field;
	if ( ! $hash ) {
		$hash = \%openprint::session;
		#$log->debug('ssi::date_filter: using session for hash');
	} # end if
		#foreach my $k ( keys %$hash ) {
			#$log->debug("ssi::date_filter hash{$k} => $$hash{$k}");
		#} # end foreach
	if ( ! ( $$hash{$field.'_year'} or $$hash{$field.'_month'} or $$hash{$field.'_day'} ) ) {
#$log->debug("ssi::date_filter: No date specified for $field");
        return ();
    } # end if
    my ( $year, $month, $day, $hour, $minute, $second ) = @$hash{map { $field.$_ } ( '_year','_month','_day','_hour','_minute','_second' )};
#$log->debug("ssi::date_filter: $year-$month-$day $hour:$minute:$second");
    $month = 1 if ! $month;
    $day = 1 if ! $day;
	if ( $field =~ /end$/ ) {
		$hour = 23 if ( ! defined $hour ) or $hour eq '';
		$minute = 59 if ( ! defined $minute ) or $minute eq '';
		$second = 59 if ( ! defined $second ) or $second eq '';
	} else {
		$hour = 0 if ( ! defined $hour ) or $hour eq '';
		$minute = 0 if ( ! defined $minute ) or $minute eq '';
		$second = 0 if ( ! defined $second ) or $second eq '';
	} # end if
#$log->debug("ssi::date_filter: $year-$month-$day $hour:$minute:$second");

    return ( $sql_field, sprintf('%.4d-%.2d-%.2d %.2d:%.2d:%.2d', ( $year, $month, $day, $hour, $minute, $second ) ) );
} # end sub date_filter

sub input {
	my %options = @_;
	my $html = '<input';
	$html .= ' type="'.$options{type}.'"' if $options{type};
	$html .= ' value="'.$options{value}.'"' if $options{value};
	$html .= ' name="'.$options{name}.'"' if $options{name};
	$html .= ' id="'.$options{id}.'"' if $options{id};
	$html .= ' onkeyup="'.$options{onkeyup}.'"' if $options{onkeyup};
	$html .= ' onkeydown="'.$options{onkeydown}.'"' if $options{onkeydown};
	$html .= ' onchange="'.$options{onchange}.'"' if $options{onchange};
	$html .= ' class="'.$options{class}.'"' if $options{class};
	$html .= ' required' if $options{required};
	$html .= ' readonly="readonly"' if $options{readonly};
	$html .= '/>';
	return $html;
} # end sub input
sub select( $$$ ) {
	my ( $data, $selected, $options ) = @_;
	my $html = '<select';
	$html .= ' name="'.$$options{name}.'"' if $$options{name};
	$html .= ' id="'.$$options{id}.'"' if $$options{id};
	$html .= ' onchange="'.$$options{onchange}.'"' if $$options{onchange};
	$html .= '>';
	$html .= make_drop_down( $data, $selected );
	$html .= '</select>';
}

1;
__END__
