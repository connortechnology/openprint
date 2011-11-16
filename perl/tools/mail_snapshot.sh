#!/bin/bash
# ----------------------------------------------------------------------
# mikes handy rotating-filesystem-snapshot utility
# ----------------------------------------------------------------------
# this needs to be a lot more general, but the basic idea is it makes
# rotating backup-snapshots of the path given in the first parameter to the path in the second paramter
# ----------------------------------------------------------------------

unset PATH      # suggestion from H. Milz: avoid accidental use of $PATH

# ------------- system commands used by this script --------------------
ID=/usr/bin/id;
ECHO=/bin/echo;

MOUNT=/bin/mount;
MKDIR=/bin/mkdir
RM=/bin/rm;
MV=/bin/mv;
CP=/bin/cp;
TOUCH=/bin/touch;


# ------------- the script itself --------------------------------------

# rotating snapshots of /home (fixme: this should be more general)

# step 1: delete the oldest snapshot, if it exists:
if [ -d "$2.3" ] ; then                     \
	$RM -rf "$2.3" ;                            \
else
	echo "No $2.3 to delete"
fi ;

# step 2: shift the middle snapshots(s) back by one, if they exist
if [ -d "$2.2" ] ; then
	$MV "$2.2" "$2.3"
fi;
if [ -d "$2.1" ] ; then
	$MV "$2.1" "$2.2"
fi;
if [ -d "$2.0" ] ; then
	$MV "$2.0" "$2.1"
fi;

#echo "$CP -al $2.0 $2.1"
$CP -al "$1" "$2.0"

# step 5: update the mtime of hourly.0 to reflect the snapshot time
$TOUCH "$2.0"
