#!/bin/bash

rm -rf /opt/httpd-2.2.3/logs/httpd.pid
echo "" > /var/log/php/error.log
echo "" > /var/log/php/xdebug.log
echo "" > /var/log/apache/access_log
echo "" > /var/log/apache/error_log

tail -f /var/log/php/xdebug.log /var/log/apache/access_log > /dev/stdout & \
tail -f /var/log/php/error.log /var/log/apache/error_log > /dev/stderr & \
/opt/httpd-2.2.3/bin/apachectl -D FOREGROUND
