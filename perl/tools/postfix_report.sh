#!/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

pflogsumm /var/log/mail.log.1 | formail -c -I"Subject: Mail Statistics" -I"From: pflogsumm@localhost" -I"To: iconnor@point-one.com" -I"Received: from www.example.com ([192.168.0.100])" | sendmail iconnor@point-one.com

exit 0
