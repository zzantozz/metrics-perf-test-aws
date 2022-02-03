#!/bin/bash -e

# The first instance generates random events and sends them to the second instance using fluent bit.
# The volume of events generated is controlled by the argument to the spam.sh script in the crontab file.

instance_id="instance1"

cat << EOF > /usr/local/bin/instanceid
#!/bin/bash
echo "$instance_id"
EOF
chmod +x /usr/local/bin/instanceid

etcd_token=${etcd_token}
etcd_discovery_url=${etcd_discovery_url}
${file("cloud-init/etcd.sh")}

cat <<EOF > /etc/yum.repos.d/td-agent-bit.repo
[td-agent-bit]
name     = TD Agent Bit
baseurl  = https://packages.fluentbit.io/amazonlinux/2/\$basearch/
gpgcheck = 1
gpgkey   = https://packages.fluentbit.io/fluentbit.key
enabled  = 1
EOF

yum install --assumeyes td-agent-bit

n=0
while [ -z "$instance2_ip" ] && [ $n -lt 100 ]; do
  echo "Waiting for instance2_ip in etcd..."
  instance2_ip="$(/opt/etcd/etcdctl get instance2_ip --print-value-only)" || echo "etcd not ready yet"
  n=$((n+1))
  sleep 1
done
[ -z "$instance2_ip" ] && {
  echo "Timed out waiting for instance2_ip in etcd"
  exit 1
}

cat <<EOF > /etc/td-agent-bit/td-agent-bit.conf
[SERVICE]
    HTTP_Server On
    HTTP_Listen 0.0.0.0
    HTTP_PORT   2020

[INPUT]
    name tail
    path /opt/random-events/log
    tag random

[OUTPUT]
    name   http
    host   $instance2_ip
    port   8888
    format json
    match  *
EOF

mkdir /opt/random-events
chmod 755 /opt/random-events
touch /opt/random-events/log
# Random events are appended to this file every minute, and the file is logrotated every minute. These things are
# scheduled in cron.

unset etcd_registered
while [ -z "$etcd_registered" ]; do
  /opt/etcd/etcdctl put $${instance_id}_ip "$my_ip" && etcd_registered=true
done

systemctl enable td-agent-bit
systemctl start td-agent-bit

cat <<EOF > /opt/logrotate-random-events
/opt/random-events/log {
    size 250M
    rotate 3
}
EOF
echo "* * * * * root /usr/sbin/logrotate /opt/logrotate-random-events" >> /etc/crontab

cat <<EOF > /opt/spam.sh
tr -dc "a-zA-Z 0-9" < /dev/urandom | fold -w 200 | head -\$1
EOF
echo "* * * * * root bash /opt/spam.sh 10 >> /opt/random-events/log" >> /etc/crontab

cat << EOF > /usr/local/bin/lsevents
#!/bin/bash
ls -la /opt/random-events
EOF
chmod +x /usr/local/bin/lsevents
