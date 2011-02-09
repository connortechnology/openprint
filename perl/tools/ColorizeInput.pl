#!/usr/bin/perl

#####################################
###															 ###
### User configuration parameters ###
###															 ###
#####################################

#
# Errors and warnings are detected via an "ORed" regular expression
# match of the tokens below. To add an error type match, add the
# appropriate string to match below.
#
my @error_tokens = ('error',"Error", "ERROR", "ERR");
my @warning_tokens = ('warn',"Warning", "WARNING", "WARN");

#
# Console colors and attributes are set by the following mapping.
# Colors and atrbiutes can be combined using the ";" to separate them.
#
#	 0		 reset all attributes to their defaults
#	 1		 set bold
#	 5		 set blink
#	 7		 set reverse video
#	 22		set normal intensity
#	 25		blink off
#	 27		reverse video off
#
#	 30		black foreground
#	 31		red foreground
#	 32		green foreground
#	 33		brown foreground
#	 34		blue foreground
#	 35		magenta (purple) foreground
#	 36		cyan (light blue) foreground
#	 37		gray foreground
#
#	 40		black background
#	 41		red background
#	 42		green background
#	 43		brown background (yellow actually)
#	 44		blue background
#	 45		magenta background
#	 46		cyan background
#	 47		white background
#
my $error_color = "40;31";
my $warning_color = "40;38";


############################################
###																			###
### End of user configuration parameters ###
###																			###
############################################

#
# The REGEX to search input lines for
#
my $errors = join("|", @error_tokens);
my $warnings = join("|", @warning_tokens);

#
# Variables and subroutines to build the escaped
# sequence for colorizing the line
#
my $escape_start = "\033[";
my $escape_end = "m";

#
# Returns the escape sequence to tell the console to colorize text
#
sub escape_command($) {
	my $color = shift;
	return $escape_start . $color . $escape_end;
}

#
# Returns the escaped 'colored' string based on the input string and color
#
sub color_message($$) {
	my $message = shift;
	my $color = shift;
	return escape_command($color) . $message . escape_command("0");
}

#
# Colorize a string based on whether it matches the 'error' or 'warning' tokens
#
sub colorize_string($) {

	$_[0] =~ s/^\[\w{3} \w{3} \d{2} \d\d:\d\d:\d\d \d{4}\] //;
	$_[0] =~ s/, referer: .*$//;
	$_[0] =~ s/\[client [\d\.]+\] //;

	if ($_[0] =~ m/$errors/) {
		return color_message("ERROR: " . $_[0], $error_color);
	}
	elsif ($_[0] =~ m/$warnings/) {
		return color_message("WARNING: " . $_[0], $warning_color);
	}
	else {
		return $_[0];
	}
}


##########
##			##
## Main ##
##			##
##########

while (<>) {
	print colorize_string($_);
}
