#!/bin/bash -e

# The third instance receives events via flume and sends them to the next instance using fluentd.

instance_id="instance3"

cat << EOF > /usr/local/bin/instanceid
#!/bin/bash
echo "$instance_id"
EOF
chmod +x /usr/local/bin/instanceid

etcd_token=${etcd_token}
etcd_discovery_url=${etcd_discovery_url}
${file("cloud-init/etcd.sh")}

yum install -y java-1.8.0-openjdk

curl --output /opt/flume.tar.gz https://dlcdn.apache.org/flume/1.9.0/apache-flume-1.9.0-bin.tar.gz
sha="$(curl -L http://www.apache.org/dist/flume/1.9.0/apache-flume-1.9.0-bin.tar.gz.sha512)"
echo "$sha /opt/flume.tar.gz" | sha512sum -c || {
  echo "Failed to validate flume archive"
  exit 1
}
tar xf /opt/flume.tar.gz -C /opt && rm /opt/flume.tar.gz
mv /opt/apache-flume-* /opt/flume

cat << EOF > /opt/flume-conf.properties
instance3-flume.sources = thriftsource
instance3-flume.channels = thechannel
instance3-flume.sinks = filesink

instance3-flume.sources.thriftsource.type = thrift
instance3-flume.sources.thriftsource.channels = thechannel
instance3-flume.sources.thriftsource.bind = 0.0.0.0
instance3-flume.sources.thriftsource.port = 4141

instance3-flume.channels.thechannel.type = memory

instance3-flume.sinks.filesink.type = file_roll
instance3-flume.sinks.filesink.channel = thechannel
instance3-flume.sinks.filesink.sink.directory = /opt/flume-events-for-fluentd
instance3-flume.sinks.filesink.sink.rollInterval = 0
EOF

mkdir -p /opt/flume-conf
cat << EOF > /opt/flume-conf/log4j.properties
log4j.rootLogger=INFO,file
log4j.appender.file=org.apache.log4j.RollingFileAppender
log4j.appender.file.layout=org.apache.log4j.SimpleLayout
log4j.appender.file.file=/var/log/flume.log
EOF
# No matter what I set for max heap here, this flume seems to run the system out of memory and get OOM killed under
# high event volume.
cat << EOF > /opt/flume-conf/flume-env.sh
JAVA_OPTS="-Xmx256m"
EOF

mkdir /opt/flume-events-for-fluentd
chmod 755 /opt/flume-events-for-fluentd

cat << EOF > /opt/logrotate-flume-events-for-fluentd
/opt/flume-events-for-fluentd {
    size 250M
    rotate 3
}
EOF

cat << EOF > /etc/yum.repos.d/td.repo
[treasuredata]
name=TreasureData
baseurl=http://packages.treasuredata.com/4/amazon/2/\$basearch
gpgcheck=1
gpgkey=https://packages.treasuredata.com/GPG-KEY-td-agent
EOF

yum install -y td-agent
systemctl stop td-agent

n=0
while [ -z "$instance4_ip" ] && [ $n -lt 100 ]; do
  echo "Waiting for instance4_ip in etcd..."
  instance4_ip="$(/opt/etcd/etcdctl get instance4_ip --print-value-only)" || echo "etcd not ready yet"
  n=$((n+1))
  sleep 1
done
[ -z "$instance4_ip" ] && {
  echo "Timed out waiting for instance4_ip in etcd"
  exit 1
}

cat << EOF > /etc/td-agent/td-agent.conf
<source>
  @type tail
  path /opt/flume-events-for-fluentd/*
  pos_file /opt/fluent-input-pos_file
  tag flumestuff
  <parse>
    @type none
  </parse>
</source>
<match *>
  @type http

  endpoint http://$instance4_ip:8888
  open_timeout 2
  json_array true

  <format>
    @type json
  </format>
  <buffer>
    flush_interval 1s
  </buffer>
</match>
EOF

touch /opt/fluent-input-pos_file
chown td-agent /opt/fluent-input-pos_file

unset etcd_registered
while [ -z "$etcd_registered" ]; do
  /opt/etcd/etcdctl put $${instance_id}_ip "$my_ip" && etcd_registered=true
done

#echo "* * * * * root /usr/sbin/logrotate /opt/logrotate-flume-events-for-fluentd" >> /etc/crontab
systemctl start td-agent
nohup /opt/flume/bin/flume-ng agent \
  -n $${instance_id}-flume \
  -f /opt/flume-conf.properties \
  -c /opt/flume-conf &> /var/log/flume.out &

cat << EOF > /usr/local/bin/lsevents
#!/bin/bash
ls -la /opt/flume-events-for-fluentd
EOF
chmod +x /usr/local/bin/lsevents
