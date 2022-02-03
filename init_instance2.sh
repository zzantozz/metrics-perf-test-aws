#!/bin/bash -e

# The second instance receives events via fluent bit and sends them to the next instance using flume.

instance_id="instance2"

cat << EOF > /usr/local/bin/instanceid
#!/bin/bash
echo "$instance_id"
EOF
chmod +x /usr/local/bin/instanceid

etcd_token=${etcd_token}
etcd_discovery_url=${etcd_discovery_url}
${file("cloud-init/etcd.sh")}

cat << EOF > /etc/yum.repos.d/td-agent-bit.repo
[td-agent-bit]
name     = TD Agent Bit
baseurl  = https://packages.fluentbit.io/amazonlinux/2/\$basearch/
gpgcheck = 1
gpgkey   = https://packages.fluentbit.io/fluentbit.key
enabled  = 1
EOF

yum install --assumeyes td-agent-bit

cat << EOF > /etc/td-agent-bit/td-agent-bit.conf
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
    file /opt/fluent-events-for-flume/log
EOF

mkdir /opt/fluent-events-for-flume
touch /opt/fluent-events-for-flume/log

cat << EOF > /opt/logrotate-fluent-events-for-flume
/opt/fluent-events-for-flume/log {
    size 250M
    rotate 3
}
EOF

yum install -y java-1.8.0-openjdk

curl --output /opt/flume.tar.gz https://dlcdn.apache.org/flume/1.9.0/apache-flume-1.9.0-bin.tar.gz
sha="$(curl -L http://www.apache.org/dist/flume/1.9.0/apache-flume-1.9.0-bin.tar.gz.sha512)"
echo "$sha /opt/flume.tar.gz" | sha512sum -c || {
  echo "Failed to validate flume archive"
  exit 1
}
tar xf /opt/flume.tar.gz -C /opt && rm /opt/flume.tar.gz
mv /opt/apache-flume-* /opt/flume

n=0
while [ -z "$instance3_ip" ] && [ $n -lt 100 ]; do
  echo "Waiting for instance3_ip in etcd..."
  instance3_ip="$(/opt/etcd/etcdctl get instance3_ip --print-value-only)" || echo "etcd not ready yet"
  n=$((n+1))
  sleep 1
done
[ -z "$instance3_ip" ] && {
  echo "Timed out waiting for instance3_ip in etcd"
  exit 1
}

cat << EOF > /opt/flume-conf.properties
instance2-flume.sources = tailsource
instance2-flume.channels = thechannel
instance2-flume.sinks = thriftsink

instance2-flume.sources.tailsource.type = TAILDIR
instance2-flume.sources.tailsource.channels = thechannel
instance2-flume.sources.tailsource.filegroups = thegroup
instance2-flume.sources.tailsource.filegroups.thegroup = /opt/fluent-events-for-flume/log

instance2-flume.channels.thechannel.type = memory

instance2-flume.sinks.thriftsink.type = thrift
instance2-flume.sinks.thriftsink.channel = thechannel
instance2-flume.sinks.thriftsink.hostname = $instance3_ip
instance2-flume.sinks.thriftsink.port = 4141
EOF

mkdir -p /opt/flume-conf
cat << EOF > /opt/flume-conf/log4j.properties
log4j.rootLogger=INFO,file
log4j.appender.file=org.apache.log4j.RollingFileAppender
log4j.appender.file.layout=org.apache.log4j.SimpleLayout
log4j.appender.file.file=/var/log/flume.log
EOF
cat << EOF > /opt/flume-conf/flume-env.sh
JAVA_OPTS="-Xmx256m"
EOF

unset etcd_registered
while [ -z "$etcd_registered" ]; do
  /opt/etcd/etcdctl put $${instance_id}_ip "$my_ip" && etcd_registered=true
done

echo "* * * * * root /usr/sbin/logrotate /opt/logrotate-fluent-events-for-flume/log" >> /etc/crontab
systemctl enable td-agent-bit
systemctl start td-agent-bit
nohup /opt/flume/bin/flume-ng agent \
  -n $${instance_id}-flume \
  -f /opt/flume-conf.properties \
  -c /opt/flume-conf &> /var/log/flume.out &

cat << EOF > /usr/local/bin/lsevents
#!/bin/bash
ls -la /opt/fluent-events-for-flume
EOF
chmod +x /usr/local/bin/lsevents
