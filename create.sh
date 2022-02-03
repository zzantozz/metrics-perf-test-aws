#!/bin/bash

etcd_token="$(uuidgen)"
etcd_discovery_url="$(curl -sf https://discovery.etcd.io/new?size=4)"

terraform apply -var="etcd_token=$etcd_token" -var="etcd_discovery_url=$etcd_discovery_url"
