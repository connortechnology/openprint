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
RSYNC=/usr/bin/rsync;
CHMOD=/bin/chmod;

USAGE="Usage: `/usr/bin/basename $0` [-hv] [-c arg] args"

while getopts hvc: OPT; do
    case "$OPT" in
        h)
            echo $USAGE
            exit 0
            ;;
        v)
            echo "`basename $0` version 0.1"
            exit 0
            ;;
        c)
            CHECK_FILE=$OPTARG
            ;;
        \?)
            # getopts issues an error message
            echo $USAGE >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

if [ $CHECK_FILE ] ; then
	if [ ! -e "$CHECK_FILE" ] ; then
		echo "Check file missing at ($CHECK_FILE)"
		exit 1
	fi;
fi;	
	SOURCE=$1
	DEST=$2

echo "Backing up from $SOURCE to $DEST"

# ------------- the script itself --------------------------------------

# rotating snapshots of /home (fixme: this should be more general)

# step 1: delete the oldest snapshot, if it exists:
if [ -d "$DEST.3" ] ; then                     \
	$CHMOD a+wr -R "$DEST.3"
	$RM -rf "$DEST.3" ;                            \
else
	echo "No $DEST.3 to delete"
fi ;

# step 2: shift the middle snapshots(s) back by one, if they exist
if [ -d "$DEST.2" ] ; then
	$MV "$DEST.2" "$DEST.3"
fi;
if [ -d "$DEST.1" ] ; then
	$MV "$DEST.1" "$DEST.2"
fi;

# step 3: make a hard-link-only (except for dirs) copy of the latest snapshot,
# if that exists
if [ -d "$DEST.0" ] ; then \
	#echo "$CP -al $DEST.0 $DEST.1"
	$CP -al "$DEST.0" "$DEST.1"
else
	#echo "Making $DEST.0"
	$MKDIR -p "$DEST.0"
fi;

# step 4: rsync from the system into the latest snapshot (notice that
# rsync behaves like cp --remove-destination by default, so the destination
# is unlinked first.  If it were not so, this would copy over the other
# snapshot(s) too!
#echo "$RSYNC \"$1\" \"$DEST\""
$RSYNC -a --exclude .gvfs --delete --delete-excluded "$SOURCE" "$DEST.0"

# step 5: update the mtime of hourly.0 to reflect the snapshot time
$TOUCH "$DEST.0"

