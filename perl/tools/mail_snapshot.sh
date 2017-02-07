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

MKDIR=/bin/mkdir
RM=/bin/rm;
MV=/bin/mv;
CP=/bin/cp;
TOUCH=/bin/touch;
BACKUPS=3;

USAGE="Usage: `/usr/bin/basename $0` [-hTv] [-c arg] [ -n int] args"

while getopts hTvc:n: OPT; do
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
		n)
			BACKUPS=$OPTARG;
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

if (( "$BACKUPS" <= "0" )) ; then
	BACKUPS=3
fi;
# ------------- the script itself --------------------------------------

# rotating snapshots of /home (fixme: this should be more general)
	if [ -d "$2.$BACKUPS" ] ; then					 \
		$RM -rf "$2.$BACKUPS" ;							\
	else
		echo "No $2.$BACKUPS to delete"
	fi ;

while (( "$BACKUPS" > "0" )) ; do 
	# step 2: shift the middle snapshots(s) back by one, if they exist
	DEC=$(($BACKUPS-1))
	if [ -d "$2.$DEC" ] ; then
		$MV "$2.$DEC" "$2.$BACKUPS" ;
	fi ;
	let BACKUPS=DEC;
done

#echo "$CP -al $2.0 $2.1"
$TIME$CP -al "$1" "$2.0"
# step 5: update the mtime of hourly.0 to reflect the snapshot time
$TOUCH "$2.0"
