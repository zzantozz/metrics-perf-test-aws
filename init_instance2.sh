#!/bin/bash -e

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
    name http
    host 0.0.0.0
    port 8888

[OUTPUT]
    name file
    file /home/ec2-user/output-http

EOF

touch /home/ec2-user/output-http

systemctl enable td-agent-bit
systemctl start td-agent-bit

cat <<EOF > /home/ec2-user/logrotate-output-http
/home/ec2-user/output-http {
    size 250M
    rotate 3
    compress
}
EOF
echo "* * * * * root /usr/sbin/logrotate /home/ec2-user/logrotate-output-http" >> /etc/crontab
