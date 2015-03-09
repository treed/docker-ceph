#!/usr/bin/env bash

# fail on any command exiting non-zero
set -eo pipefail

export DEBIAN_FRONTEND=noninteractive

# install common packages
apt-get update && apt-get install -y curl net-tools sudo

# install etcdctl
curl -sSL -o /usr/local/bin/etcdctl https://s3-us-west-2.amazonaws.com/opdemand/etcdctl-v0.4.6 \
    && chmod +x /usr/local/bin/etcdctl

curl -sSL https://eunice.tedreed.info/confd -o /usr/local/bin/confd
chmod +x /usr/local/bin/confd

curl -sSL 'https://ceph.com/git/?p=ceph.git;a=blob_plain;f=keys/release.asc' | apt-key add -
echo "deb http://ceph.com/debian-giant trusty main" > /etc/apt/sources.list.d/ceph.list

apt-get update && apt-get install -yq ceph

apt-get clean -y

rm -Rf /usr/share/man /usr/share/doc
rm -rf /tmp/* /var/tmp/*
rm -rf /var/lib/apt/lists/*
