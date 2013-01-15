use strict;
package ssi;

use countries;
use states;
use provinces;

use Date::Calc qw(Days_in_Month Month_to_Text);
use HTML::Entities qw(encode_entities);

# For Hash stuff
use List::Util qw(max);
use Digest::MD5 qw(md5_hex);
use File::Basename;
use File::Slurp qw(read_file write_file);
use JSON qw(to_json from_json);

require sets;
require sql;
require JavaScript::Minifier::XS;
require CSS::Minifier;

use openprint ();
use vars qw( $r $log $dbh %config %session %param %variable );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*session = \%openprint::session;
*param = \%openprint::param;
*variable = \%openprint::variable;

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
		$log->error( "Eval error ($@) of ($1), Reason: " . $@ ) if $@;
		$result .= variable_substitution( $r, $log, $dbh, $text, $variable ) if $text;
		return $result;
    } elsif ( $$command =~ /^hash_link\s*\(\s*([\S]+)\s*\)/ms ) {
        my $result = hash_link($1);
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

sub include {
	my ( $file, $variable ) = @_;
	$variable = \%variable if ! $variable;
	if ( ! ( $file =~ /^\// ) ) {
# Use a path relative to the current page
		my $path = $$variable{uri};
		$path =~ s/(.*\/).*/$1/;
		$file = $path . $file;
	} # end if

	my $content = '';
	if ( -f $config{SkinPath}.$file ) {
		$content = misc::load_file( $log, $config{SkinPath}.$file );
	} elsif ( -f $ENV{DOCUMENT_ROOT}.$file ) {
		$content = misc::load_file( $log, $ENV{DOCUMENT_ROOT}.$file );
	} else {
		$content = misc::load_file( $log, $file );
	} # end if

	return variable_substitution( $r, $log, $dbh, \$content, $variable );
}

sub do_include {
	my ( $r, $log, $dbh, $text, $variable ) = @_;
	if ( $$text =~ /(.*?)<!--\s*#include\s+virtual="(.*?)"\s*-->(.*)/ms ) {
		my ( $before, $middle, $after ) = ( $1, $2, $3 );
		#my $file = variable_substitution( $r, $log, $dbh, \$middle, $variable );
		my $file = $middle;
		if ( ! ( $file =~ /^\// ) ) {
# Use a path relative to the current page
			my $path = $$variable{'uri'};
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

sub encode_html {
	my ( $html, $tags ) = @_;

	$html =~ s/\r\n/<br\/>/mg;
	$html =~ s/\n\r/<br\/>/mg;
	$html =~ s/\n/<br\/>/mg;
	return $html;
} # end sub encode_html

sub make_drop_down {
	my ( $search_data, $checkval, $options ) = @_;
	my $check_array;
	if ( ref $checkval eq 'ARRAY' ) {
		$check_array = $checkval;
	} else {
		$check_array = [ $checkval ];
	} # end if

	my $temp = '';
	if ( $$options{prepend} ) {
		for ( my $n = 0; $n < @{$$options{prepend}}; $n += 2) {
			$temp .= sprintf('<option value="%s"%s>%s</option>',
					HTML::Entities::encode_entities(Encode::encode('utf-8',$$options{prepend}[$n])),
					( sets::isin( $$options{prepend}[$n], $check_array ) ? ' selected="selected"' : '' ),
					HTML::Entities::encode_entities( Encode::encode('utf-8',$$options{length} ? substr($$options{prepend}[$n + 1],0, $$options{length}) : $$options{prepend}[$n + 1] ) ) );
		} # end for
	} # end if
	for ( my $n = 0; $n < @{$search_data}; $n += 2) {
		$temp .= sprintf('<option value="%s"%s>%s</option>',
			HTML::Entities::encode_entities(Encode::encode('utf-8',$$search_data[$n])),
			( sets::isin( $$search_data[$n], $check_array ) ? ' selected="selected"' : '' ),
			HTML::Entities::encode_entities( Encode::encode('utf-8',$$options{length} ? substr($$search_data[$n + 1],0, $$options{length}) : $$search_data[$n + 1] ) ) );
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
		my $checked = sets::isin( $$options[$n], @{$checkarray} ) ? ' selected="selected"' : '';
		$temp .= "<option value=\"$$options[$n]\"$checked>" . HTML::Entities::encode_entities( $length ne '' ? substr($$options[$n + 1],0, $length): $$options[$n+1] ) . "</option>\n";
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
	if ( $selected ) {
		$selected = int($selected);
	} elsif ( ! defined $selected ) {
		$selected = (localtime(time))[4]+1;
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

	my $html = qq`<a id="Button$name" href="$$options{href}" class="buttonImageOff $$options{class}" `;
	if ( $$options{'target'} ) {
		$html .= 'target="'.$$options{'target'}.'" ';
	} # end if
	if ( $$options{'onclick'} ) {
		$html .= 'onclick="';
		#if ( ( $openprint::config{'ButtonsUseImages'} and ($openprint::config{'ButtonsUseImages'} eq 'true') ) and $gif ) {
				#$html .= "btnOff('$name');";
		##} # end if
		$html .= $$options{'onclick'}."return false;\" ";
	} # end if
	if ( $$options{'ontouch'} ) {
		$html .= 'ontouch="'.$$options{'ontouch'}.'" ';
	} # end if
	#$html .= "onmouseover=\"if ( typeof(btnOn) == 'function' ) { btnOn('Button$name');}\" onmouseout=\"if ( typeof(btnOff) == 'function' ) { btnOff('Button$name');}\"";
	$html .= '>';
	if ( ( $openprint::config{'ButtonsUseImages'} and ($openprint::config{'ButtonsUseImages'} eq 'true') ) and $$options{'image'} ) {
		$html .= "<img src=\"/images/buttons/off/$$options{image}\" name=\"Button$name\"";
		if ( $$options{'text'} ) {
			$html .= "alt=\"$$options{text}\"";
		} # end if
		$html .= "/>";
	} else {
		$html .= '<span class="l"></span><span class="c" id="'.$name.'c"' . ( $$options{title} ? ' title="'.$$options{title}.'"' : '' ) .'>' . $$options{'text'} .'</span><span class="r"></span>';
	}
	$html .= "</a>\n";
	return $html;
} # end sub button

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
return qq{<span class="TipLink" onmouseover="if ( typeof(tipOn) == 'function' ) {tipOn('$word',3,event);}" onmouseout="if ( typeof(tipOff) == 'function' ) {tipOff('$word');}">$word</span>};
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
		( $year, $month, $day ) = Date::Calc::Localtime( $value ne '' ? Date::Parse::str2time( $value ) : time );
$log->debug("$year-$month-$day");
	} # end if
	if ( ref $options eq 'HASH' ) {
	} elsif ( $options ) {
		$options = {};
		$$options{'onchange'} = $options;
	} # end if
#$openprint::log->debug(" date_select: $value : ($year,$month,$day), order: $$options{order}");
	$$options{'order'} = 'y,m,d' if ! $$options{'order'};
	my @fields;
	if ( $$options{'fields'} ) {
		@fields = split(',', $$options{'fields'} );
	} 
	
	

	my $html = '';
	$html .= sprintf('<span id="%1$s_date">', $prefix );
	foreach my $o ( split(',', $$options{'order'} ) ) {
		if ( ( $o eq 'y' ) and ( (!@fields) or sets::isin( 'year', \@fields ) ) ) {
			$html .= sprintf('<select id="%1$s_year" name="%1$s_year" onchange="setDaysDropDown(this.value,this.form.%1$s_month.value,this.form.%1$s_day,this.form.%1$s_day.value);%2$s"><option value=""></option>', $prefix, $$options{'onchange'} );
			$html .= return_years( undef, undef, $year );
			$html .= '</select>';
		} elsif ( ( $o eq 'm' ) and ( (!@fields) or sets::isin( 'month', \@fields ) ) ) {
			$html .= sprintf('<select id="%1$s_month" name="%1$s_month" onchange="setDaysDropDown(this.form.%1$s_year.value,this.value,this.form.%1$s_day,this.form.%1$s_day.value);%2$s"><option value=""></option>', $prefix, $$options{'onchange'} );
			$html .= getmonths( $month );
			$html .= '</select>';
		} elsif ( ( $o eq 'd' ) and ( (!@fields) or sets::isin( 'day', \@fields ) ) ) {
			$html .= sprintf('<select id="%1$s_day" name="%1$s_day" onchange="%2$s"><option value=""></option>', $prefix, $$options{'onchange'} );
			$html .= getdays( $day, $year, $month );
			$html .= '</select>';
		} # endif
	} # end foreach o
	if ( $$options{'with_clear'} ) {
		$html .= ssi::button( $prefix.'_clear', { onclick=>q`date_clear( $('`.$prefix.q`_year'), $('`.$prefix.q`_month'), $('`.$prefix.q`_day') );`.$$options{'onchange'}, text=>'C',title=>'Clear' } );
	} # end if
	if ( $$options{'with_today'} ) {
		$html .= ssi::button( $prefix.'_today', { onclick=>q`set_today( $('`.$prefix.q`_year'), $('`.$prefix.q`_month'), $('`.$prefix.q`_day') );`.$$options{'onchange'}, text=>'T', title=>'Today' } );
	} # end if
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
		$options = {};
		$$options{'onchange'} = $options;
	} # end if
#$openprint::log->debug(" date_select: $value : ($year,$month,$day), order: $$options{order}");
	$$options{'order'} = 'y,m,d' if ! $$options{'order'};

	my $html = '';
	$html .= sprintf(q`<span id="%1$s_date"><select id="%1$s_year" name="%1$s_year" onchange="setDaysDropDown(this.value,this.form.elements['%1$s_month'].value,this.form.elements['%1$s_day'],this.form.elements['%1$s_day'].value);%2$s">`, $prefix, $$options{'onchange'} );
	$html .= '<option value=""> </option>';
	$html .= return_years( undef, undef, $year );
	$html .= '</select>';
	$html .= sprintf(q`<select id="%1$s_month" name="%1$s_month" onchange="setDaysDropDown(this.form.elements['%1$s_year'].value,this.value,this.form.elements['%1$s_day'],this.form.elements['%1$s_day'].value);%2$s">`, $prefix, $$options{'onchange'} );
	$html .= '<option value=""> </option>';
	$html .= getmonths( $month );
	$html .= '</select>';
	$html .= sprintf('<select id="%1$s_day" name="%1$s_day" onchange="%2$s">', $prefix, $$options{'onchange'} );
	$html .= '<option value=""> </option>';
	$html .= getdays( $day, $year, $month );
	$html .= '</select></span>';
	$html .= sprintf('<span id="%1$s_time" class="time"%3$s><select id="%1$s_hour" name="%1$s_hour" onchange="%2$s"><option value=""></option>%4$s</select> :
	<select id="%1$s_minute" name="%1$s_minute" onchange="%2$s">
	<option value=""> </option>%5$s
	</select></span>
', $prefix, $$options{'onchange'}, 
( ( exists $$options{'with_time'} and ! $$options{'with_time'} ) ? ' style="display: none;"' : '' ),
	make_drop_down( [ map { $_, $_ } ( 0 .. 23 ) ], $hour ),
	make_drop_down( [ map { $_, sprintf('%.2d', $_ ) } ( 0 .. 59 ) ], $min ),
	);
	if ( $$options{'with_clear'} ) {
		$html .= button( $prefix.'_clear', { 'onclick'=>q`date_clear( $('`.$prefix.q`_year'), $('`.$prefix.q`_month'), $('`.$prefix.q`_day') );`.$$options{'onchange'}, 'text'=>'C' } );
	} # end if
	if ( $$options{'with_today'} ) {
		$html .= button( $prefix.'_today', { 'onclick'=>q`set_today( $('`.$prefix.q`_year'), $('`.$prefix.q`_month'), $('`.$prefix.q`_day') );`.$$options{'onchange'}, 'text'=>'T' } );
	} # end if
	return $html;
} # end sub datetime_select

sub datetime_text {
	 my ( $prefix, $value, $onchange ) = @_;

	 my ($year,$month,$day, $hour,$min,$sec) = Date::Calc::Localtime( $value ? Date::Parse::str2time( $value ) : time );
#$openprint::log->debug("$year,$month,$day, $hour:$min:$sec");

	 my $html = '';
	 $html .= sprintf('<span id="%1$s_year">%2$.4d</span>-<span id="%1$s_month">%3$.2d</span>-<span id="%1$s_day">%4$.2d</span> <span id="%1$s_hour">%5$.2d</span>:<span id="%1$s_minute">%6$.2d</span>', $prefix, $year, $month, $day, $hour, $month );
	 return $html;
} # end sub datetime_select

sub save_params {
	my ( $url, @keys ) = @_;
	$session{$url.'?lastupdated'} = time;

	foreach ( @keys ) {
		if ( ref $param{$_} eq 'ARRAY' ) {
			$session{"$url?$_"} = join(',', @{$param{$_}} );
#$openprint::log->debug("Storing ARRAY ($_) (".$session{"$url?$_"}.")");
		} elsif ( exists $param{$_} ) {
			$session{"$url?$_"} = $param{$_};
		} # end if
	} # end foreach
} # end sub save_params

sub write_override {
	my ( $for, $value, $locked_js, $unlocked_js ) = @_;
	if ( 0 ) {
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
				<input type="radio" name="%1$s" value="%2$s" id="%1$s%2$s" %4$s%5$s />
				<label class="radio" for="%1$s%2$s">%3$s</label>
				`, $name, $value, $label, checked( sets::isin( $value, $selected ) ), $onclick ? ' onclick="'.$onclick.'"' : '' );
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

my @input_options = ( 'type','name','id','onblur','onfocus','onkeyup','onkeydown','onchange','class','pattern','ontouch','max', 'placeholder' );

sub input {
	my %options = @_;
	my $html = '<input';
	if ( $options{type} eq 'cardinal' ) {
		if ( $ENV{HTTP_USER_AGENT} =~ /ip(ad|od|hone)/i ) {
			$options{type} = 'text';
			$options{pattern} = '[0-9]*' if ! $options{pattern};
		} else {
			$options{type} = 'number';
		} # end if
		$options{filter} = 'cardinalize(this);' if ! $options{filter};
		$options{onkeyup} = $options{filter}.$options{onkeyup};
	} elsif ( $options{type} eq 'integer' ) {
		if ( $ENV{HTTP_USER_AGENT} =~ /ip(ad|od|hone)/i ) {
			$options{type} = 'text';
			$options{'pattern'} = '[0-9]*' if ! $options{'pattern'};
		} else {
			$options{type} = 'number';
		} # end if
		$options{'onkeyup'} = 'integerize(this);'.$options{'onkeyup'};
	} elsif ( $options{type} eq 'float' ) {
		if ( $ENV{HTTP_USER_AGENT} =~ /ip(ad|od|hone)/i ) {
			$options{type} = 'text';
			$options{'pattern'} = '[0-9]*' if ! $options{'pattern'};
		} else {
			$options{type} = 'number';
		} # end if
		$options{'onkeyup'} = 'floatize(this);'.$options{'onkeyup'};
	} # end if
	$html .= ' value="'.$options{value}.'"' if $options{value} ne '';

	foreach (@input_options) {
		$html .= qq` $_="$options{$_}"` if $options{$_};
	} # end foreach
	#if ( my @unsupported = sets::exclude( [ @button_options, 'required','readonly','value' ], [ keys %options ] ) ) {
#$log->error("ssi::button unsupported options @unsupported");
	#} # end if
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
	$html .= ' size="'.$$options{size}.'"' if $$options{size};
	$html .= ' multiple="multiple"' if $$options{multiple};
	$html .= '>';
	$html .= make_drop_down( $data, $selected, $options );
	$html .= '</select>';
}

my %hash_cache;

# If there is any problem, return the original path, so that the original file can be sent.
sub hash_link {
	my ( $path ) = @_;

	my $src;
	if ( -e $config{SkinPath}.$path ) {
		$src = $config{SkinPath}.$path;
	} elsif ( -e $ENV{DOCUMENT_ROOT}.$path ) {
		$src = $ENV{DOCUMENT_ROOT}.$path;
	} else {
		return $path;
	} # end if

    $config{cache_dir} = $config{SkinPath}.'/cache' if ! $config{cache_dir};

    my $script;
    if ( ( ! $hash_cache{$config{SkinPath}} ) and -f $config{cache_dir}.'/config.json' ) {
        $log->debug("reading config");
        $hash_cache{$config{SkinPath}} = from_json( read_file($config{cache_dir}.'/config.json') );
        $hash_cache{$config{SkinPath}} = {} if ! $hash_cache{$config{SkinPath}};
    } # end if

    if ( 
		( !($script = $hash_cache{$config{SkinPath}}{$path}) )
            || 
		( ! -f $script->{cache_file} )
            || 
		( ( my $timestamp = (stat $src)[9] ) > $script->{timestamp} )
       ) {

		$timestamp = (stat $src)[9] if ! $timestamp;

        my ($base, $dir, $ext) = fileparse $src, qr/\.[^.]+/;
        $ext =~ s/^\.//;
        my $blob = read_file($src);

        if ( $ext eq 'js' ) {
            $blob = &JavaScript::Minifier::XS::minify( $blob );
        } elsif ( $ext eq 'css' ) {
            $blob = &CSS::Minifier::minify( input=>$blob );
        } # end if

        my $hash = md5_hex($blob);
        $hash_cache{$config{SkinPath}}{$path} = $script = {
			src		=>	$src,
            name	=>	"$base-$hash.$ext",
            path	=>	$path,
            cache_file => "$config{cache_dir}/$base-$hash.$ext",
            hash	=> $hash,
            timestamp => $timestamp,
        };
        if (! -f $script->{cache_file}) {
            mkdir $config{cache_dir};
            if ( ! write_file($script->{cache_file},       { atomic => 1, err_mode=>'carp' }, \$blob) ) {
                $log->error( "couldn't cache $script->{cache_file}" );
                return $path;
            } # end if
			`gzip -c -9 "$$script{cache_file}" > "$$script{cache_file}.gz"`;
            write_file($config{cache_dir}.'/config.json', { atomic => 1, err_mode=>'carp' }, to_json($hash_cache{$config{SkinPath}}, {pretty => 1})) or warn "Couldn't save cache control file";
        }   
    }
    ($config{cache_path}?$config{cache_path}:'/cache').'/'.$script->{name};

} # end sub hash_link

sub format_date {
    return $_[0] ? Date::Format::time2str( $config{DateFormat}, Date::Parse::str2time( $_[0] ) ) : '';
}
sub format_datetime {
    return $_[0] ? Date::Format::time2str( $config{DateTimeFormat}, Date::Parse::str2time( $_[0] ) ) : '';
}

1;
__END__
