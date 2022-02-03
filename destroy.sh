#!/bin/bash

terraform destroy -var="etcd_token=none" -var="etcd_discovery_url=none"
