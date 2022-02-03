## Installs and starts etcd, configured to connect all instances together.
## Because a terraform template can't include a template, you must set two bash vars in the script including this one
## before this file is included: etcd_token and etcd_discovery_url.

if [ -z "$etcd_token" ] || [ -z "$etcd_discovery_url" ]; then
  echo "etcd.sh requires the vars etcd_token and etcd_discovery_url to be set in the calling script"
  echo "etcd_token: $etcd_token"
  echo "etcd_discovery_url: $etcd_discovery_url"
  exit 1
fi

wget -O /opt/etcd.tar.gz https://github.com/etcd-io/etcd/releases/download/v3.5.1/etcd-v3.5.1-linux-amd64.tar.gz
sha="$(curl -L https://github.com/etcd-io/etcd/releases/download/v3.5.1/SHA256SUMS | grep etcd-v3.5.1-linux-amd64.tar.gz | awk '{print $1}')"
echo "$sha /opt/etcd.tar.gz" || {
  echo "etcd archive failed validation"
  exit 1
}
tar xf /opt/etcd.tar.gz -C /opt && rm /opt/etcd.tar.gz
mv /opt/etcd-* /opt/etcd
chown -R root:root /opt/etcd

my_ip="$(/sbin/ifconfig eth0 | grep 'inet ' | awk '{print $2}')"

nohup /opt/etcd/etcd --name "$(hostname)" \
  --initial-advertise-peer-urls http://"$my_ip":2380 \
  --listen-peer-urls http://"$my_ip":2380 \
  --advertise-client-urls http://"$my_ip":2379 \
  --listen-client-urls http://"$my_ip":2379,http://127.0.0.1:2379 \
  --initial-cluster-state new --initial-cluster-token "$etcd_token" \
  --discovery "$etcd_discovery_url" &> /var/log/etcd.log &
