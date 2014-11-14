#!/bin/bash
set -e

ETCDCTL_PEERS=172.17.42.1:4001

fsid=$(etcdctl get /ceph/$CLUSTER_NAME/fsid)
monitor_names=""
monitor_ips=""

for monitor in $(etcdctl ls /ceph/$CLUSTER_NAME/monitors); do
    echo "Adding $monitor"
    monitor_names="$monitor_names $(basename $monitor)"
    monitor_ips="$monitor_ips $(etcdctl get $monitor/ip)"
done

if test -z "$monitor_names"; then
    echo "No Monitors Found; Exiting"
    exit 1
fi

cat <<ENDHERE >/etc/ceph/ceph.conf
fsid = $fsid
mon initial members = $monitor_names
mon host = $monitor_ips
auth cluster required = cephx
auth service required = cephx
auth client required = cephx
ENDHERE

echo Getting client key from etcd
etcdctl get /ceph/$CLUSTER_NAME/keyrings/client-admin > /etc/ceph/${CLUSTER_NAME}.client.admin.keyring

echo Getting monitor keyring from etcd
etcdctl get /ceph/$CLUSTER_NAME/keyrings/monitor > /etc/ceph/${CLUSTER_NAME}.mon.keyring
exec /bin/bash
