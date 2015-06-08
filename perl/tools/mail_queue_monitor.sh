#!/bin/bash
#
# Postfix queue length monitoring script (requires msmtp)
#
# This script checks the active, incoming, deferred and maildrop postfix queue directories.
#
# If the number of messages in any of these directories is more than $MAX_QUEUE_LENGTH,
# the script will generate an alert email and send it using msmtp. We use msmtp so that
# we can bypass the local postfix installation (since if the queues are getting big,
# the alert email may not be sent in time to catch the problem).
#

#########################################################
# SET SCRIPT VARS
#########################################################

# Path to msmtp binary (e.g. /usr/bin/msmtp on Debian systems)
MSMTP=/usr/bin/msmtp

# Remote mail host (this is the mail server msmtp will use to send the alert. It should NOT be the local postfix installation)
MAILHOST=backup.mailserver.com

# Remote mail port
MAILPORT=25

# Mail protocol
MAILPROTO=smtp

# Fully qualified domain name of local postfix installation
DOMAIN=primary.mailserver.com

# From address
MAILFROM=postmaster@mailserver.com

# Recipient (this address should not route to the local postfix installation, for obvious reasons)
MAILTO="alerts@anotherdomain.com"

# Email subject
MAILSUBJECT="Postfix queue length alert for ${DOMAIN}"

# MSMTP log file
LOGFILE=/var/log/msmtp.log

# Root of the postfix queue dirs (e.g. /var/spool/postfix on Debian systems). Note: no trailing slash.
QUEUEDIR_ROOT="/var/spool/postfix"

# Max queue length (if there are more messages in a queue than this number, we will send an alert)
MAX_QUEUE_LENGTH=10


#########################################################
# SCRIPT LOGIC STARTS HERE
#########################################################

# Check msmtp binary exists
if [ ! -f ${MSMTP} ]
then
        echo "Cannot find ${MSMTP}. Exiting."
        exit 1
fi

# Get the number of messages sitting in each postfix queue directory
Q_ACTIVE=$(find ${QUEUEDIR_ROOT}/active -type f | wc -l)
Q_INCOMING=$(find ${QUEUEDIR_ROOT}/incoming -type f | wc -l)
Q_DEFERRED=$(find ${QUEUEDIR_ROOT}/deferred -type f | wc -l)
Q_MAILDROP=$(find ${QUEUEDIR_ROOT}/maildrop -type f | wc -l)

# If any of these queues contain more than $MAX_QUEUE_LENGTH issue an alert
if [ ${Q_ACTIVE} -gt ${MAX_QUEUE_LENGTH} -o ${Q_INCOMING} -gt ${MAX_QUEUE_LENGTH} -o ${Q_DEFERRED} -gt ${MAX_QUEUE_LENGTH} -o ${Q_MAILDROP} -gt ${MAX_QUEUE_LENGTH} ]; then

    (
        echo "From: ${MAILFROM} "
        echo "To: ${MAILTO} "
        echo "Mime-Version: 1.0"
        echo 'Content-Type: text/plain; charset="iso-8859-1"'
        echo "Subject: ${MAILSUBJECT}"
        echo ""
        echo "One or more of the postfix queues on ${DOMAIN} has grown beyond ${MAX_QUEUE_LENGTH} messages in length."
    ) | ${MSMTP} --host=${MAILHOST} --port=${MAILPORT} --protocol=${MAILPROTO} --domain=${DOMAIN} --auth=off --tls=off --from=${MAILFROM} --logfile=${LOGFILE} --syslog=off --read-recipients

    exit 2

fi

exit 0
