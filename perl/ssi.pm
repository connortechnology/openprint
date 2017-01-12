use strict;
package ssi;

use constant Debug => 0;

require Date::Calc;

# For Hash stuff
use File::Basename;

require sets;
require sql;
require openprint;
require File::Slurp;

use vars qw( $r %variable %session %param %config $log $dbh );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*r = \$openprint::r;

require Date::Parse;
require Date::Format;
require DateTime::Format::Pg;
require DateTime::TimeZone;
my $parser = 'DateTime::Format::Pg';

#Used for resource hashed links
my %hash_cache;

#Used for writeTip
my $Glossary;

# Used for translations
my $Lexicon;

sub slurp_content {
	my ( $file ) = @_;

#$log->debug("Slurping file $file");

	if ( ! ( $file =~ /^\// ) ) {
		# Use a path relative to the current page
		my $path = $variable{uri};
		$path =~ s/(.*\/).*/$1/;
		$file = $path . $file;
	} # end if
	my $content = '';
	if ( -e $config{SkinPath}.$file ) {
		$content = File::Slurp::read_file($config{SkinPath}.$file,err_mode => 'carp' );
	} elsif ( -e $config{SkinPath}.'/html/'.$file ) {
		$content = File::Slurp::read_file($config{SkinPath}.'/html/'.$file,err_mode => 'carp' );
	} elsif ( $ENV{DOCUMENT_ROOT} and ( -e ($ENV{DOCUMENT_ROOT}.$file) ) ) {
		$content = File::Slurp::read_file($ENV{DOCUMENT_ROOT}.$file,err_mode => 'carp' );
	} elsif ( $config{DOCUMENT_ROOT} and ( -e $config{DOCUMENT_ROOT}.$file ) ) {
		$content = File::Slurp::read_file($config{DOCUMENT_ROOT}.$file,err_mode => 'carp' );
	} else {
		$content = File::Slurp::read_file($file,err_mode => 'carp' );
	} # end if
	if ( ! $content ) {
		$log->warn( "No content found for $file" );
	}
	return $content;
} # end sub slurp_content

sub include {
	my ( $file, $variable ) = @_;
	$variable = \%variable if ! $variable;

	my $content = slurp_content( $file );
	return variable_substitution( \$content, $variable );
} # end sub include

#i'm adding more and more recursion in an attempt to make this faster.
# this big bottleneck is all the regexp searches through the text.
# the text is huge, so the more we break it down, the faster these get.
sub variable_substitution {
	my ( $text, $variable ) = @_;

	$variable = \%openprint::variable if ! $variable;

	my $result = '';
	my $after = $$text;

	while ( $after ) {
		if ( $after =~ /(.*?)<\?\s*(.*?)\s*\?>(.*)/ms ) {
			$result .= $1;
			(my $command, $after ) = ( $2, $3 );
			$after =~ s/^\s+$//m;

			if ( $command =~ /^while\s*\(\s*(.*)\s*\)/ ) {
				my $condition = $1;
				if ( $after =~ /(.*?)<\?\s*endwhile\s*\(\s*\Q$condition\E\s*\)\s*\?>(.*)/si ) {
					( my $middle, $after ) = ( $1, $2 );
					while ( eval $condition ) {
						$result .= variable_substitution( \$middle, $variable );
					} # end while
					$log->error( "Eval error of ($condition), Reason: " . $@ ) if $@;
				} else {
					$log->error("Unable to find terminating while ($command)");
				} # end if
			} elsif ( $command =~ /^if\s*\(\s*(.*)\s*\)/ ) {
				my $dataname = $1;
				if ( $after =~ /(.*?)<\?\s*endif\s*\(\s*\Q$dataname\E\s*\)\s*\?>(.*)/si ) {
					( my $middle, $after ) = ( $1, $2 );
					if ( $after =~ /^\n\r?$/ ) {
						$after = '';
					} elsif ( $after =~ /^\r?\n$/ ) {
						$after = '';
					} # end if

					my $elsetext = '';

					if ( $middle =~ /(.*?)<\?\s*else\s*\(\s*\Q$dataname\E\s*\)\s*\?>(.*)/si ) {
						( $middle, $elsetext ) = ( $1, $2 );
					} # end if

					$_ = eval $dataname;
					$log->error( "Eval error of if ($dataname), Reason:" . $@ ) if $@;
					if ( $_ ) {
						$result .= variable_substitution( \$middle, $variable );
					} elsif ( $elsetext ne '' ) {
						$result .= variable_substitution( \$elsetext, $variable );
					} # end if
				} else {
					$log->error("Unable to find terminating if ( $command ) in $after");
				} # end if
			} elsif ( $command =~ /^eval\s*\(\s*(.*)\s*\)/ms ) {
				$_ = eval $1;
				$log->error( "Eval error of ($1), Reason: " . $@ ) if $@;
			} elsif ( $command =~ /^echo\s*\(\s*(.*)\s*\)/ms ) {
				$_ = eval $1;
				$result .= $_;
				$log->error( "Eval error ($@) of ($1), Reason: " . $@ ) if $@;
			} elsif ( $command =~ /^translate\s*\(\s*([\S]+)\s*\)/ms ) {
				$result .= translate($1);
			} elsif ( $command =~ /^hash_link\s*\(\s*'?([^\s']+)'?\s*\)/ms ) {
				$result .= hash_link($1);
			} elsif ( $command =~ /^hecho\s*\(\s*(.*)\s*\)/ms ) {
				$_ = eval $1;
				$result .= html_escape($_);
				$log->error( "Eval error of ($1), Reason: " . $@ ) if $@;
			} elsif ( $command =~ /^checked\s*\(\s*(.*)\s*\)/ms ) {
				$result .= checked( eval $1 );
			} elsif ( $command =~ /^include\s*\(\s*'?([^'\)]*)'?\s*\)/ms ) {
				$result .= include( $1, $variable );
			} elsif ( $command =~ /^slurp\s*\(\s*'?([^'\)]*)'?\s*\)/ms ) {
				$result .= slurp_content( $1 );
			} else {
				$result .= $$variable{$command};
			} # end if
		} else {
			return $result.$after;
		} # end if have a command
	} # end while after
	return $result;
} # end sub variable_substitution

my %html_replacements = (
	'&'	=>	'&amp;',
	'"'	=>	'&quot;',
	'<' =>	'&lt;',
	'>' =>	'&gt;',
);
my $replacement_string = join '', keys %html_replacements;
sub html_escape {
	my $thing = $_[0];

	$thing =~ s/([\Q$replacement_string\E])/$html_replacements{$1}/g;
	return $thing;
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
	require HTML::Entities;
	my ( $search_data, $checkval, $options ) = @_;
	$options = {} if ! $options;
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
					( $$options{encode} ? HTML::Entities::encode_entities(Encode::encode('utf-8',$$options{prepend}[$n])) : $$options{prepend}[$n] ),
					( sets::isin( $$options{prepend}[$n], $check_array ) ? ' selected="selected"' : '' ),
					( $$options{encode} ? HTML::Entities::encode_entities( Encode::encode('utf-8',$$options{length} ? substr($$options{prepend}[$n + 1],0, $$options{length}) : $$options{prepend}[$n + 1] ) ) : $$options{length} ? substr($$options{prepend}[$n + 1],0, $$options{length}) : $$options{prepend}[$n + 1] ),
					);
		} # end for
	} # end if
	for ( my $n = 0; $n < @{$search_data}; $n += 2) {
		$temp .= sprintf('<option value="%s"%s>%s</option>',
			( $$options{encode} ? HTML::Entities::encode_entities(Encode::encode('utf-8',$$search_data[$n])) : $$search_data[$n] ),
			( sets::isin( $$search_data[$n], $check_array ) ? ' selected="selected"' : '' ),
			( $$options{encode} ? HTML::Entities::encode_entities( Encode::encode('utf-8',$$options{length} ? substr($$search_data[$n + 1],0, $$options{length}) : $$search_data[$n + 1] ) ) : ( $$options{length} ? substr($$search_data[$n + 1],0, $$options{length}) : $$search_data[$n + 1] ) ),
		);
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
	require provinces;
	require states;
	my @states_and_provinces = ();
	push @states_and_provinces, @states::states;
	push @states_and_provinces, @provinces::provinces;
	return make_drop_down( \@states_and_provinces, \@_ );
} # end sub return_states_and_provinces

sub return_states {
	require states;
	return make_drop_down( \@states::states, shift );
} # end sub return_states

sub return_provinces {
	require provinces;
	return make_drop_down( \@provinces::provinces, shift );
} # end sub return_provinces

sub return_countries {
	require countries;
	return make_drop_down( \@countries::countries, [@_] );
} # end sub return_countries

sub return_years {
	my ( $start, $end, $selected ) = @_;
	$start = $openprint::config{startYear} if ! $start;
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
	if ( $year and $month and ( $maxdays > Date::Calc::Days_in_Month( $year, $month ) ) ) {
		$maxdays = Date::Calc::Days_in_Month( $year, $month );
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
	if ( $year and $month and $day > Date::Calc::Days_in_Month( $year, $month ) ) {
		$day = Date::Calc::Days_in_Month( $year, $month );
	} # end if
	return ( $year, $month, $day );
} # end sub fix_date

sub get_dates {
	my ( $log, $dbh, $year, $month, $day ) = @_;

	( $year, $month, $day ) = fix_date( int $year, int $month, int $day );

	my ( $startYear ) = $openprint::config{startYear};
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
	( $start ) = $openprint::config{startYear};
	$start = 2002 if ! $start;
	if ( ! $startYear ) {
		$startYear = (localtime(time))[5]+1900;
	} # end if

	$startMonth = $startMonth ? $startMonth : (localtime(time))[4]+1;
	$endYear = $endYear ? $endYear : (localtime(time))[5]+1900;
	$endMonth = $endMonth ? $endMonth : (localtime(time))[4]+1;

	if ( $startDay > Date::Calc::Days_in_Month( $startYear, $startMonth ) ) {
		$startDay = Date::Calc::Days_in_Month( $startYear, $startMonth );
	} # end if
	if ( $endDay > Date::Calc::Days_in_Month( $endYear, $endMonth ) ) {
		$endDay = Date::Calc::Days_in_Month( $endYear, $endMonth );
	} # end if

	$$variable{ddmStartYear} = $$variable{startyears} = getyears( $start, (localtime(time))[5]-100, $startYear );
	$$variable{ddmEndYear} = $$variable{endyears} = getyears( $start, (localtime(time))[5]-100, $endYear );
	$$variable{ddmStartMonth} = $$variable{startmonths} = getmonths($startMonth);
	$$variable{ddmEndMonth} = $$variable{endmonths} = getmonths($endMonth);
	$$variable{ddmStartDay} = $$variable{startdays} = getdays($startDay);
	$$variable{ddmEndDay} = $$variable{enddays} = getdays($endDay ? $endDay : (localtime(time))[3]);

	$$variable{StartDate} = join( '-', $startYear, $startMonth, ( $startDay ? $startDay : 1 ) );
	$$variable{EndDate} = join( '-', $endYear, $endMonth, ( $endDay ? $endDay : (localtime(time))[3] ) );

} # end sub get_start_end_dates

sub button {
	my ( $name, $options ) = @_;

	if ( $$options{href} ) {
		my ( $href ) = $$options{href} =~ /^([^\?]+)/;
		if ( ! ( $href =~ /^\// ) ) {
# Use a path relative to the current page
			my $path = $variable{uri};
			$path =~ s/(.*\/).*/$1/;
			$href = $path . $href;
		} # end if
		my $PageSetting = openprint::Page_Setting::get( $href );
		return if $PageSetting and ! $PageSetting->can_view();
	} else {
		$$options{href} = '#';
	} # end if
	$$options{text} = $name if ! exists $$options{text};

	my $html = qq`<a id="Button$name" href="$$options{href}" class="button $$options{class}" `;
	$html .= qq`title="$$options{title}" ` if $$options{title};
	$html .= 'target="$$options{target}" ' if $$options{target};
	if ( $$options{onclick} ) {
		$html .= 'onclick="';
		$html .= $$options{onclick}."return false;\" ";
	} # end if
	if ( $$options{ontouch} ) {
		$html .= 'ontouch="'.$$options{ontouch}.'" ';
	} # end if
	#$html .= "onmouseover=\"if ( typeof(btnOn) == 'function' ) { btnOn('Button$name');}\" onmouseout=\"if ( typeof(btnOff) == 'function' ) { btnOff('Button$name');}\"";
	$html .= '>';
	if ( $$options{image} ) {
		if ( $openprint::config{ButtonsUseImages} and ($openprint::config{ButtonsUseImages} eq 'true') ) {
			$html .= "<img src=\"/images/buttons/off/$$options{image}\" id=\"ButtonImage$name\"";
		} else {
			$html .= "<img src=\"$$options{image}\" id=\"ButtonImage$name\"";
		} # end if
		if ( $$options{title} ) {
			$html .= " alt=\"$$options{title}\"";
		} # end if
		$html .= '/>';
		if ( $$options{text} ) {
			$html .= $$options{text};
		} # end if
	} elsif ( $openprint::config{SimpleButtons} eq 'Y' ) {
		$html .= $$options{text};
	} else {
		$html .= '<span class="l"></span><span class="c" id="'.$name.'c"' . ( $$options{title} ? ' title="'.$$options{title}.'"' : '' ) .'>' . $$options{text} .'</span><span class="r"></span>';
	}
	$html .= "</a>";
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
		if ( ( $openprint::config{ButtonsUseImages} and ($openprint::config{ButtonsUseImages} eq 'true') ) and $gif ) {
			$html .= "btnOff('$name');";
		} # end if
		$html .= $onclick."return false;\" ";
	} # end if
	#$html .= "onmouseover=\"if ( typeof(btnOn) == 'function' ) { btnOn('Button$name');}\" onmouseout=\"if ( typeof(btnOff) == 'function' ) { btnOff('Button$name');}\"";
	$html .= '>';
	if ( ( $openprint::config{ButtonsUseImages} and ($openprint::config{ButtonsUseImages} eq 'true') ) and $gif ) {
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
	if ( ! defined $Glossary ) {
		%$Glossary = sql::execute( undef, undef, 'SELECT word, definition FROM Glossary' );
	} # end if
	if ( $$Glossary{$word} ) {
		return sprintf(q`<span class="TipLink" onmouseover="tipOn('%1$s',3,event);" onmouseout="tipOff('%1$s');">%1$s</span>`, $word );
	} else {
		return $word;
	} # endif
} # end  sub writeTip

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
	$$options{order} = 'y,m,d' if ! $$options{order};
	my @fields;
	if ( $$options{fields} ) {
		@fields = split(',', $$options{fields} );
	} 
	
	my ( $start_year, $start_month, $start_day ) = split( '-', $$options{start} ) if $$options{start};
	my ( $end_year, $end_month, $end_day ) = split( '-', $$options{end} ) if $$options{end};

	my $class = 'DateSelector';
	$class .= 'C' if $$options{with_clear};
	$class .= 'T' if $$options{with_today};

	my $html = '<span class="'.$class.'">';
	$html .= sprintf('<span id="%1$s_date">', $prefix );
	foreach my $o ( split(',', $$options{order} ) ) {
		if ( ( $o eq 'y' ) and ( (!@fields) or sets::isin( 'year', \@fields ) ) ) {
			$html .= sprintf(q`<select id="%1$s_year" name="%1$s_year" onchange="setDaysDropDown(this.value,this.form.elements['%1$s_month'].value,this.form.elements['%1$s_day'],this.form.elements['%1$s_day'].value);%2$s"><option value=""> </option>`, $prefix, $$options{onchange} );
			$html .= return_years( $start_year, $end_year, $year );
			$html .= '</select>';
#$log->debug($html);
		} elsif ( ( $o eq 'm' ) and ( (!@fields) or sets::isin( 'month', \@fields ) ) ) {
			$html .= sprintf(q`<select id="%1$s_month" name="%1$s_month" onfocus="this.previousValue=this.value" onchange="setDaysDropDown(this.form.elements['%1$s_year'].value,this.value,this.form.elements['%1$s_day'],this.form.elements['%1$s_day'].value, this.previousValue);%2$s;this.previousValue=this.value;"><option value=""> </option>`, $prefix, $$options{onchange} );
			$html .= getmonths( $month );
			$html .= '</select>';
#$log->debug($html);
		} elsif ( ( $o eq 'd' ) and ( (!@fields) or sets::isin( 'day', \@fields ) ) ) {
			$html .= sprintf('<select id="%1$s_day" name="%1$s_day" onchange="%2$s"><option value=""> </option>', $prefix, $$options{onchange} );
			$html .= getdays( $day, int($year), int($month) );
			$html .= '</select>';
#$log->debug($html);
		} # endif
	} # end foreach o
	if ( $$options{with_clear} ) {
		$html .= button( $prefix.'_clear', { 'onclick'=>q`date_clear( $('`.$prefix.q`_year'), $('`.$prefix.q`_month'), $('`.$prefix.q`_day') );`.$$options{onchange}, text=>'C', title=>'Clear', class=>'Clear'} );
	} # end if
	if ( $$options{with_today} ) {
		$html .= button( $prefix.'_today', { 'onclick'=>q`set_today( $('`.$prefix.q`_year'), $('`.$prefix.q`_month'), $('`.$prefix.q`_day') );`.$$options{onchange}, text=>'T', title=>'Today', class=>'Today'} );
	} # end if
	$html .= '<span id="'.$prefix.'_alert"></span>';
	$html .= '</span></span>';
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
		$$options{onchange} = $_;
	} # end if
#$openprint::log->debug(" date_select: $value : ($year,$month,$day), order: $$options{order}");
	$$options{order} = 'y,m,d' if ! $$options{order};

	my $class = 'DateTimeSelector';
	$class .= 'C' if $$options{with_clear};
	$class .= 'T' if $$options{with_today};

	my $html = '<span class="'.$class.'">';
	$html .= sprintf(q`<span id="%1$s_date"><select id="%1$s_year" name="%1$s_year" onchange="setDaysDropDown(this.value,this.form.elements['%1$s_month'].value,this.form.elements['%1$s_day'],this.form.elements['%1$s_day'].value);%2$s">
`, $prefix, $$options{onchange} );
	$html .= '<option value=""> </option>';
	$html .= return_years( undef, undef, $year );
	$html .= '</select>
';
	$html .= sprintf(q`<select id="%1$s_month" name="%1$s_month" onfocus="this.previousValue=this.value;" onchange="setDaysDropDown(this.form.elements['%1$s_year'].value,this.value,this.form.elements['%1$s_day'],this.form.elements['%1$s_day'].value,this.previousValue);this.previousValue=this.value;%2$s">`, $prefix, $$options{onchange} );
	$html .= '<option value=""> </option>';
	$html .= getmonths( $month );
	$html .= '</select>
';
	$html .= sprintf('<select id="%1$s_day" name="%1$s_day" onchange="%2$s">', $prefix, $$options{onchange} );
	$html .= '<option value=""> </option>';
	$html .= getdays( $day, $year, $month );
	$html .= '</select></span>
';
	$html .= sprintf('<span id="%1$s_time" class="time"%3$s>
<select id="%1$s_hour" name="%1$s_hour" onchange="%2$s"><option value=""></option>%4$s</select> :
	<select id="%1$s_minute" name="%1$s_minute" onchange="%2$s">
	<option value=""> </option>%5$s
	</select></span>', $prefix, $$options{onchange}, 
		( ( exists $$options{with_time} and ! $$options{with_time} ) ? ' style="display: none;"' : '' ),
		make_drop_down( [ map { $_, $_ } ( 0 .. 23 ) ], $hour ),
		make_drop_down( [ map { $_, sprintf('%.2d', $_ ) } ( 0 .. 59 ) ], $min ),
	);
	if ( $$options{with_clear} ) {
		$html .= button( $prefix.'_clear', { 'onclick'=>q`date_clear( $('`.$prefix.q`_year'), $('`.$prefix.q`_month'), $('`.$prefix.q`_day') );`.$$options{onchange}, 'text'=>'C' } );
	} # end if
	if ( $$options{with_today} ) {
		$html .= button( $prefix.'_today', { 'onclick'=>sprintf(q`set_today( $('%1$s_year'), $('%1$s_month'), $('%1$s_day'), $('%1$s_hour'), $('%1$s_minute') );`, $prefix ).$$options{onchange}, 'text'=>'T' } );
	} # end if
	$html .= '<span id="'.$prefix.'_alert"></span></span>';
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
		$openprint::log->debug("save_params: key $_") if Debug;
		if ( ! exists $param{$_} ) {
			$openprint::log->debug("save_params: does not exist in param key $_") if Debug;
			next;
		} 
		if ( ref $param{$_} eq 'ARRAY' ) {
			$session{"$url?$_"} = join(',', @{$param{$_}} );
$openprint::log->debug("Storing ARRAY ($_) (".$session{"$url?$_"}.")") if Debug;
		} else {
			$session{"$url?$_"} = $param{$_};
$openprint::log->debug("Storing ($_) (".$session{"$url?$_"}.")") if Debug;
		} # end if
		$session{$url.'?lastupdated'} = time;
	} # end foreach
} # end sub save_params

sub boolean_override {
	my ( $for, $value, $locked_js, $unlocked_js ) = @_;
	return sprintf(q`<input type="hidden" id="%1$s" name="%1$s" value="%2$s"/><img class="Override" src="/images/%3$s.gif" onclick="var e=$('%1$s');if(e.value!='0'){e.value='0';this.src='/images/unlocked.gif';%5$s} else {e.value='1';this.src='/images/locked.gif';%4$s}" alt=""/>`, 
			$for, 1*$value, ($value ? 'locked' : 'unlocked'), $locked_js, $unlocked_js );
}
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

	my $onclick = $$options{onclick} if $options;
	my $html;
	if ( $$options{default} and ! defined $selected ) {
$log->debug("Selecting default $$options{default} for radio $name");
		$selected = $$options{default};
	} # end if

	while ( my ( $value, $label ) = splice @{$values}, 0, 2 ) {
		$html .= $$options{container}[0] if $$options{container};
		$html .= sprintf(q`
				<input type="radio" name="%1$s" value="%2$s" id="%1$s%6$s%2$s" %4$s%5$s />
				<label class="radio" for="%1$s%6$s%2$s">%3$s</label>
				`, $name, $value, $label, checked( $value eq $selected ), 
				( $onclick ? ' onclick="'.$onclick.'"' : '' ),
				$$options{id},
				);
		$html .= $$options{container}[1] if $$options{container};
	} # end foreach value
	return $html;
} # end sub radio
sub checkboxes {
	my ( $name, $values, $selected, $options ) = @_;

	my $onclick = $$options{onclick} if $options;
	my $html;
	my @container = @{$$options{container}} if $$options{container};
	$values = ['on', '' ] if ! $values;

	while ( my ( $value, $label ) = splice @{$values}, 0, 2 ) {
		$html .= $container[0] if @container;
		$html .= sprintf(q`<input type="checkbox" name="%1$s" value="%2$s" id="%1$s%2$s" %3$s%4$s />`,
				$name, $value, checked( sets::isin( $value, $selected ) ), $onclick ? ' onclick="'.$onclick.'"' : '' );
		if ( $label ) {
			$html .= sprintf(q`<label class="radio" for="%1$s%2$s">%3$s</label>`, $name, $value, $label );
		} # end if
		$html .= $container[1] if @container;
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
	if ( ! ( $$hash{$field.'_year'} and $$hash{$field.'_month'} and $$hash{$field.'_day'} ) ) {
#$log->debug("ssi::date_filter: No date specified for $field");
		return ();
	} # end if
	my ( $year, $month, $day, $hour, $minute, $second ) = @$hash{map { $field.$_ } ( '_year','_month','_day','_hour','_minute','_second' )};
#$log->debug("ssi::date_filter: $year-$month-$day $hour:$minute:$second");
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

	my $TZ = DateTime::TimeZone->new( name => $openprint::config{Timezone} );
	my $datetime = DateTime->new( time_zone => $TZ,
			( year => $year, month=>$month, day=>$day, hour=>$hour, minute=>$minute, second=>$second )
			);

	return ( $sql_field, $parser->format_datetime( $datetime ) );
} # end sub date_filter

my @input_options = ( 'type','name','id','onblur','onfocus','onkeyup','onkeypress', 'onkeydown','onchange','class','pattern','ontouch','min','max', 'step', 'placeholder', 'oninput', 'title', 'decimalplaces', 'style' );

sub input {
	my %options = @_;
	my $html = '<input';
	if ( $options{type} eq 'cardinal' ) {
		$options{step} = '1' if ! exists $options{step};
		if ( $ENV{HTTP_USER_AGENT} =~ /ip(ad|od|hone)/i ) {
			$options{type} = 'text';
			$options{pattern} = '[0-9]*' if ! $options{pattern};
		} elsif ( $ENV{HTTP_USER_AGENT} =~ /Firefox/ ) {
			$options{type} = 'text';
			$options{pattern} = '[0-9]*' if ! $options{pattern};
			delete $options{step};
		} else {
			$options{type} = 'number';
		} # end if
		$options{filter} = 'cardinalize(this);' if ! $options{filter};
		$options{oninput} = $options{filter}.$options{oninput};
		#$options{oninput} = 'this.onkeyup.call(this);' if ! $options{oninput};
	} elsif ( $options{type} eq 'integer' ) {
		if ( $ENV{HTTP_USER_AGENT} =~ /ip(ad|od|hone)/i ) {
			$options{type} = 'text';
			$options{pattern} = '^-?\d*' if ! $options{pattern};
		} elsif ( $ENV{HTTP_USER_AGENT} =~ /Firefox/ ) {
			$options{type} = 'text';
			$options{pattern} = '^-?\d*' if ! $options{pattern};
			delete $options{step};
		} else {
			$options{type} = 'number';
		} # end if
		$options{oninput} = 'integerize(this);'.$options{oninput};
	} elsif ( $options{type} eq 'float' ) {
#$log->debug("USer agent: $ENV{HTTP_USER_AGENT}");
		$options{step} = 'any' if ! exists $options{step};
		if ( $ENV{HTTP_USER_AGENT} =~ /ip(ad|od|hone)/i ) {
			$options{type} = 'text';
			$options{pattern} = '[\+\-]?[.0-9]*' if ! $options{pattern};
		} elsif ( $ENV{HTTP_USER_AGENT} =~ /Firefox/ ) {
			$options{type} = 'text';
			$options{pattern} = '^[\+\-]?[.0-9]*' if ! $options{pattern};
			delete $options{step};
		} else {
			$options{type} = 'number';
		} # end if
		$options{oninput} = 'floatize(this);'.$options{oninput};
    } elsif ( $options{type} eq 'positivefloat' ) {
#$log->debug("USer agent: $ENV{HTTP_USER_AGENT}");
        $options{step} = 'any' if ! exists $options{step};
        if ( $ENV{HTTP_USER_AGENT} =~ /ip(ad|od|hone)/i ) {
            $options{type} = 'text';
            $options{pattern} = '[.0-9]*' if ! $options{pattern};
        } elsif ( $ENV{HTTP_USER_AGENT} =~ /Firefox/ ) {
            $options{type} = 'text';
            $options{pattern} = '[.0-9]*' if ! $options{pattern};
            delete $options{step};
        } else {
            $options{type} = 'number';
        } # end if
        $options{oninput} = 'positive_floatize(this);'.$options{oninput};
	} elsif ( $options{type} eq 'float_calculator' ) {
		if ( $ENV{HTTP_USER_AGENT} =~ /ip(ad|od|hone)/i ) {
			$options{type} = 'text';
			$options{pattern} = '[0-9\*\+=\/\.\-]*' if ! $options{pattern};
        } elsif ( $ENV{HTTP_USER_AGENT} =~ /Firefox/ ) {
            $options{type} = 'text';
			$options{pattern} = '[0-9\*\+=\/\.\-]*' if ! $options{pattern};
            delete $options{step};
		} else {
			$options{type} = 'number';
		} # end if
		$options{step} = 'any' if ! exists $options{step};
		$options{oninput} = 'floatize_calculator(this);'.$options{oninput};
	} elsif ( $options{type} eq 'ip' ) {
		$options{pattern} = '[0-9\/\.:a-fA-F]*' if ! $options{pattern};
		$options{type} = 'text';
		$options{step} = 'any' if ! exists $options{step};
		$options{oninput} = q`this.value=this.value.replace(/[^\.\d%\/\*a-fA-F:]/g,'');`.$options{oninput};
	} elsif ( $options{type} eq 'mac' ) {
		$options{pattern} = '[0-9\-:a-fA-F]*' if ! $options{pattern};
		$options{type} = 'text';
		$options{step} = 'any' if ! exists $options{step};
		$options{oninput} = q`this.value=this.value.replace(/[^\-\d%\/\*a-fA-F:]/g,'');`.$options{oninput};
	} # end if
	$html .= ' value="'.html_escape($options{value}).'"' if $options{value} ne '';

	foreach (@input_options) {
		$html .= qq` $_="$options{$_}"` if exists $options{$_};
	} # end foreach
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
} # end sub select($$$)

sub translate($) {
	if ( ! defined $Lexicon ) {
		%$Lexicon = sql::execute( undef, undef, 'SELECT word, translation FROM Lexicon '  );
	} # end if
	return $$Lexicon{$_[0]} if $$Lexicon{$_[0]};
	return $_[0];
} # end sub translate

sub reset_session($) {
	foreach my $k ( keys %openprint::session ) {
		if ( $k =~ /^$_[0]/ ) {
			delete $openprint::session{$k};
		} #end if
	} # end foreach
	%param = ();
	$variable{ExternalRedirect} = $_[0];
} # end sub reset_session


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

	require JSON;
	require Digest::MD5;

	$config{cache_dir} = $config{SkinPath}.'/cache' if ! $config{cache_dir};

	my $script;
	if ( ( ! $hash_cache{$config{SkinPath}} ) and -f $config{cache_dir}.'/config.json' ) {
		$_ = File::Slurp::read_file($config{cache_dir}.'/config.json');
		if ( $_ ) {
			$hash_cache{$config{SkinPath}} = JSON::from_json( $_ );
			$hash_cache{$config{SkinPath}} = {} if ! $hash_cache{$config{SkinPath}};
		} else {
			$log->error("No content of $config{cache_dir}/config.json");
			$hash_cache{$config{SkinPath}} = {};
		} # end if
	} # end if

	if ( !($script = $hash_cache{$config{SkinPath}}{$path})
			|| ! -f $$script{cache_file}
			|| ( ( my $timestamp = (stat $src)[9] ) > $script->{timestamp} )
	   ) {

		$timestamp = (stat $src)[9] if ! $timestamp;

		my ($base, $dir, $ext) = fileparse $src, qr/\.[^.]+/;
		$ext =~ s/^\.//;
		my $blob = File::Slurp::read_file($src);

		if ( ! $config{debug} ) {
			if ( $ext eq 'js' ) {
				require JavaScript::Minifier::XS;
				eval { $blob = &JavaScript::Minifier::XS::minify( $blob ); };
				$log->error( "Eval error of (minify), Reason: " . $@ ) if $@;

			} elsif ( $ext eq 'css' ) {
				require CSS::Minifier;
				$blob = &CSS::Minifier::minify( input=>$blob );
			} # end if
		} # end if

		my $hash = Digest::MD5::md5_hex($blob);
		$hash_cache{$config{SkinPath}}{$path} = $script = {
			src			=>	$src,
			name		=> "$base-$hash.$ext",
			path		=> $path,
			cache_file	=> "$config{cache_dir}/$base-$hash.$ext",
			hash		=> $hash,
			timestamp	=> $timestamp,
		};
		if ( ! -f $$script{cache_file} ) {
			mkdir $config{cache_dir};
			if ( ! File::Slurp::write_file($script->{cache_file},       { atomic => 1, err_mode=>'carp' }, \$blob) ) {
				$log->error( "couldn't cache $script->{cache_file}" );
				return $path;
			} # end if
			`gzip -c -9 "$$script{cache_file}" > "$$script{cache_file}.gz"`;
			File::Slurp::write_file($config{cache_dir}.'/config.json', { atomic => 1, err_mode=>'carp' }, JSON::to_json($hash_cache{$config{SkinPath}}, {pretty => 1})) or warn "Couldn't save cache control file";
		} # end if
	#} else {
		#my @stat = stat $script->{src};

#$log->debug("HASH CACHED $path ($$script{cache_file} ($timestamp) ($$script{timestamp}) @stat");
	} # end if

	# cache_path is the url part
	return ($config{cache_path}?$config{cache_path}:'/cache').'/'.$script->{name};
} # end sub hash_link

sub format_date {
	return $_[0] ? Date::Format::time2str( $_[1] ? $_[1] : $config{DateFormat}, Date::Parse::str2time( $_[0] ) ) : '';
} # end sub format_date
sub format_datetime {
	return $_[0] ? Date::Format::time2str( $config{DateTimeFormat}, Date::Parse::str2time( $_[0] ) ) : '';
} # end sub format_datetime
sub format_csv_datetime {
	return $_[0] ? Date::Format::time2str( '%Y-%m-%d %H:%M:%S', Date::Parse::str2time( $_[0] ) ) : '';
} # end sub format_datetime
sub format_csv_date {
	return $_[0] ? Date::Format::time2str( '%Y-%m-%d', Date::Parse::str2time( $_[0] ) ) : '';
} # end sub format_datetime

sub link {
	return '<link rel="stylesheet" type="text/css" href="'.hash_link($_[0]).'"/>';
}

sub include_logs {
	my $Object = $_[0];
	$variable{Object} = $Object;
	setup_date_select( $variable{uri}, 'log_created_on_start', -31 );
	setup_date_select( $variable{uri}, 'log_created_on_end', '' );
	return include('/includes/_logs_container.html');
}
sub include_logs_view {
	my $Object = $_[0];
	$variable{Object} = $Object;
	setup_date_select( $variable{uri}, 'log_created_on_start', -31 );
	setup_date_select( $variable{uri}, 'log_created_on_end', '' );
	return include('/includes/_logs_contents_view.html');
}

1;
__END__
