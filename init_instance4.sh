#!/bin/bash -e

# The fourth instance receives events via fluentd and just writes them to file for now.

instance_id="instance4"

cat << EOF > /usr/local/bin/instanceid
#!/bin/bash
echo "$instance_id"
EOF
chmod +x /usr/local/bin/instanceid

etcd_token=${etcd_token}
etcd_discovery_url=${etcd_discovery_url}
${file("cloud-init/etcd.sh")}

cat << EOF > /etc/yum.repos.d/td.repo
[treasuredata]
name=TreasureData
baseurl=http://packages.treasuredata.com/4/amazon/2/\$basearch
gpgcheck=1
gpgkey=https://packages.treasuredata.com/GPG-KEY-td-agent
EOF

yum install -y td-agent
systemctl stop td-agent

cat << EOF > /etc/td-agent/td-agent.conf
<source>
  @type http
  bind 0.0.0.0
  port 8888
</source>
<match *>
  @type file
  path /opt/fluentd-output/log
  append true
</match>
EOF

mkdir /opt/fluentd-output
chown td-agent /opt/fluentd-output
chmod 755 /opt/fluentd-output

#cat << EOF > /opt/logrotate-fluentd-output
#/opt/fluentd-output {
#    size 250M
#    rotate 3
#}
#EOF

unset etcd_registered
while [ -z "$etcd_registered" ]; do
  /opt/etcd/etcdctl put $${instance_id}_ip "$my_ip" && etcd_registered=true
done

#echo "* * * * * root /usr/sbin/logrotate /opt/logrotate-fluentd-output" >> /etc/crontab
systemctl start td-agent

cat << EOF > /usr/local/bin/lsevents
#!/bin/bash
ls -la  /opt/fluentd-output/log
EOF
chmod +x /usr/local/bin/lsevents
