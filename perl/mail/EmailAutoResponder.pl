#!/usr/bin/perl -w

use strict;

require "./EmailAutoResponder_Functions.pl";

# Mainline

Init(shift);

SendHTTPHeaders();

SendHTMLOpening();
SendInstructions();
ProcessInput();
SendMessages();
SendForms();
SendHTMLClosing();

