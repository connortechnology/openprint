#!/bin/bash
# ----------------------------------------------------------------------
# mikes handy rotating-filesystem-snapshot utility
# ----------------------------------------------------------------------
# this needs to be a lot more general, but the basic idea is it makes
# rotating backup-snapshots of the path given in the first parameter to the path in the second paramter
# ----------------------------------------------------------------------

unset PATH	  # suggestion from H. Milz: avoid accidental use of $PATH

# ------------- system commands used by this script --------------------
ID=/usr/bin/id;
ECHO=/bin/echo;

MOUNT=/bin/mount;
MKDIR=/bin/mkdir;
RM=/bin/rm;
MV=/bin/mv;
CP=/bin/cp;
TOUCH=/bin/touch;
RSYNC=/usr/bin/rsync;
CHMOD=/bin/chmod;
DU=/usr/bin/du;
AWK=/usr/bin/awk;
DATE=/bin/date;
STAT=/usr/bin/stat;
FIND=/usr/bin/find;
BACKUPS=3;

USAGE="Usage: `/usr/bin/basename $0` [-hv] [-n int] [-c arg] [-t type] [-T] args"

while getopts hvn:c:t:T OPT; do
	case "$OPT" in
		h)
			echo $USAGE
			exit 0
			;;
		v)
			echo "`basename $0` version 0.1"
			exit 0
			;;
		n)
			BACKUPS=$OPTARG;
			;;
		c)
			CHECK_FILE=$OPTARG
			;;
		t)
			TYPE=$OPTARG
			;;
		T)
			TIME="/usr/bin/time "
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

shift $((2))
echo "Backing up from $SOURCE to $DEST with $@"
if (( "$BACKUPS" <= "0" )) ; then
	BACKUPS=3
fi;

if [ "$TYPE" != "" ]; then
    TYPE=".$TYPE"
fi;

# ------------- the script itself --------------------------------------
# step 3: make a hard-link-only (except for dirs) copy of the latest snapshot,
# if that exists
if [ -d "$DEST$TYPE.new" ] ; then
	TODAY=$($DATE -I)
	CREATEDON=$($STAT -c %y "$DEST$TYPE.new" | $AWK '{ printf $1 "\n"}')
	if (( "${TODAY//-/}" > "${CREATEDON//-/}" )) ; then 
		$RM -r "$DEST$TYPE.new"
	else 
		echo "$DEST$TYPE.new already exists, last modified on $CREATEDON. Is another backup already running?"
		exit 1
	fi
fi;

if [ -d "$DEST$TYPE.0" ] ; then 
	$CP -al "$DEST$TYPE.0" "$DEST$TYPE.new"
else
	echo "Making $DEST$TYPE.new"
	$MKDIR -p "$DEST$TYPE.new"
fi;
# step 4: rsync from the system into the latest snapshot (notice that
# rsync behaves like cp --remove-destination by default, so the destination
# is unlinked first.  If it were not so, this would copy over the other
# snapshot(s) too!
#echo "$RSYNC \"$1\" \"$DEST\""
if [ -e "$DEST$TYPE.0.du" ] ; then
OLDDU=$(<"$DEST$TYPE.0.du")
else
OLDDU=`$DU -b -sh "$DEST$TYPE.new" |$AWK '{print $1}'`
fi
echo $OLDDU
$TIME$RSYNC -a --delete-delay --delete-excluded $@ "$SOURCE" "$DEST$TYPE.new"
if [ $? != 0 -a $? != 24 ]; then
    echo "rsync return non-zero code. ($?)  Storing this backup as bad."
$MV "$DEST$TYPE.new" "$DEST$TYPE.bad";
	exit $?
fi;

# step 5: update the mtime of hourly.0 to reflect the snapshot time
$TOUCH "$DEST$TYPE.new"
NEWDU=`$DU -b -sh "$DEST$TYPE.new" |$AWK '{print $1}'`
echo $NEWDU

# rotating snapshots of /home (fixme: this should be more general)

# step 1: delete the oldest snapshot, if it exists:
if [ -d "$DEST$TYPE.$BACKUPS" ] ; then
	$CHMOD a+wr -R "$DEST$TYPE.$BACKUPS"
	$MV "$DEST$TYPE.$BACKUPS" "$DEST$TYPE.$BACKUPS.todelete"
	$RM -rf "$DEST$TYPE.$BACKUPS.todelete" ;
else
	echo "No $DEST$TYPE.$BACKUPS to delete"
fi ;

while (( "$BACKUPS" > "0" )) ; do
	# step 2: shift the middle snapshots(s) back by one, if they exist
	DEC=$(($BACKUPS-1))
	if [ -d "$DEST$TYPE.$DEC" ] ; then
		echo "$MV $DEST$TYPE.$DEC $DEST$TYPE.$BACKUPS"
		$MV "$DEST$TYPE.$DEC" "$DEST$TYPE.$BACKUPS" ;
	fi ;
	if [ -e "$DEST$TYPE.$DEC.du" ] ; then
        echo "$MV $DEST$TYPE.$DEC.du $DEST$TYPE.$BACKUPS.du"
        $MV "$DEST$TYPE.$DEC.du" "$DEST$TYPE.$BACKUPS.du" ;
    fi ;

	let BACKUPS=DEC;
done

$MV "$DEST$TYPE.new" "$DEST$TYPE.0";
echo $NEWDU > "$DEST$TYPE.0.du"
$FIND "$DEST$TYPE.0" -type d -executable -exec chmod u+wx {} \;
