#!/bin/bash -e

# install scribe, flume, fluentd, fluentbit?
# provision publishers and a final destination of some kind
# dest could be kinesis or dynamodb? careful of cost
# how to measure throughput or time spent in each server?
# instead, could just have a separate set of publisher -> forwarder -> dest for each one
# .
cat <<EOF > /etc/yum.repos.d/td-agent-bit.repo
[td-agent-bit]
name     = TD Agent Bit
baseurl  = https://packages.fluentbit.io/amazonlinux/2/\$basearch/
gpgcheck = 1
gpgkey   = https://packages.fluentbit.io/fluentbit.key
enabled  = 1
EOF

yum install --assumeyes td-agent-bit

cat <<EOF > /etc/td-agent-bit/td-agent-bit.conf
[SERVICE]
    HTTP_Server On
    HTTP_Listen 0.0.0.0
    HTTP_PORT   2020

[INPUT]
    name tail
    path /home/ec2-user/gutenberg-encyclopedia
    tag encyclopedia

[INPUT]
    name tail
    path /home/ec2-user/random-events
    tag random

[INPUT]
    name http
    host 0.0.0.0
    port 8888

[INPUT]
    name   tcp
    host   0.0.0.0
    port   5170
    format none

# The counter is good for testing with small amounts of metrics, but with high volume, it seems to stop working properly
[OUTPUT]
    Name  counter
    Match *

#[OUTPUT]
#    name  stdout
#    match *
EOF

touch /home/ec2-user/gutenberg-encyclopedia
# Grab the encyclopedia when you're ready to start streaming the data:
# curl https://www.gutenberg.org/ebooks/200.txt.utf-8 > /home/ec2-user/gutenberg-encyclopedia

touch /home/ec2-user/random-events
# Random events appended to this file every minute, and the file is logrotated every minute. These things are
# scheduled in cron.

systemctl enable td-agent-bit
systemctl start td-agent-bit

cat <<EOF > /home/ec2-user/logrotate-random-events
/home/ec2-user/random-events {
    size 250M
    rotate 9
    compress
}
EOF
echo "* * * * * root /usr/sbin/logrotate /home/ec2-user/logrotate-random-events" >> /etc/crontab

cat <<EOF > /home/ec2-user/spam.sh
tr -dc "a-zA-Z 0-9" < /dev/urandom | fold -w 200 | head -\$1
EOF
chmod +x /home/ec2-user/spam.sh
echo "* * * * * root bash /home/ec2-user/spam.sh 500000 >> /home/ec2-user/random-events" >> /etc/crontab
