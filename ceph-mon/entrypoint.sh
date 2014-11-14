#!/bin/bash
set -e

ETCDCTL_PEERS=172.17.42.1:4001
mkdir /etc/ceph

fsid=$(etcdctl get /ceph/$CLUSTER_NAME/fsid)
monitor_names=""
monitor_ips=""

for monitor in $(etcdctl ls /ceph/$CLUSTER_NAME/monitors); do
    echo "Adding $monitor"
    monitor_names="$monitor_names $(basename $monitor)"
    monitor_ips="$monitor_ips $(etcdctl get $monitor/ip)"
done

cat <<ENDHERE >/etc/ceph/ceph.conf
fsid = $fsid
mon initial members = $monitor_names
mon host = $monitor_ips
auth cluster required = cephx
auth service required = cephx
auth client required = cephx
ENDHERE

if test -n "$monitor_names"; then
    etcdctl get /ceph/$CLUSTER_NAME/keyrings/client-admin > /etc/ceph/ceph.client.admin.keyring
else
    ceph-authtool /etc/ceph/ceph.client.admin.keyring --create-keyring --gen-key -n client.admin --set-uid=0 --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow'
    etcdctl mk /ceph/$CLUSTER_NAME/keyrings/client-admin < /etc/ceph/ceph.client.admin.keyring
fi

if test -n "$monitor_names"; then
    ceph auth get mon. -o /tmp/ceph.mon.keyring
else
    echo ceph-authtool /etc/ceph/ceph.mon.keyring --create-keyring --gen-key -n mon. --cap mon 'allow *'
    ceph-authtool /etc/ceph/ceph.mon.keyring --create-keyring --gen-key -n mon. --cap mon 'allow *'
fi

echo Getting initial monmap
if test -n "$monitor_names"; then
    ceph mon getmap -o /etc/ceph/monmap
else
    echo monmaptool --create --add ${MON_NAME} ${MON_IP} --fsid $fsid /tmp/monmap
    monmaptool --create --add ${MON_NAME} ${MON_IP} --fsid $fsid /tmp/monmap
fi

echo Importing client keyring into temp keyring
ceph-authtool /tmp/ceph.mon.keyring --create-keyring --import-keyring /etc/ceph/ceph.client.admin.keyring
ceph-authtool /tmp/ceph.mon.keyring --import-keyring /etc/ceph/ceph.mon.keyring

# Make the monitor directory
mkdir -p /var/lib/ceph/mon/ceph-${MON_NAME}

# Prepare the monitor daemon's directory with the map and keyring
ceph-mon --mkfs -i ${MON_NAME} --monmap /tmp/monmap --keyring /tmp/ceph.mon.keyring

# Clean up the temporary key
rm /tmp/ceph.mon.keyring

echo Bootstrapped Monitor, Adding As Active
etcdctl set /ceph/${CLUSTER_NAME}/monitors/${MON_NAME}/ip ${MON_IP}

echo Launching ceph-mon
exec /usr/bin/ceph-mon -d -i ${MON_NAME} --public-addr ${MON_IP}:6789
