#!/bin/bash
set -e

### Bootstrap the ceph cluster
ETCDCTL_PEERS=172.17.42.1:4001

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

# First check to see if there already is a client admin key; if not make one and add it; if the adding then fails, assume one got added in the meantime
if ! etcdctl get /ceph/$CLUSTER_NAME/keyrings/client-admin > /etc/ceph/ceph.client.admin.keyring; then
    ceph-authtool /etc/ceph/ceph.client.admin.keyring --create-keyring --gen-key -n client.admin --set-uid=0 --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow'
    if ! etcdctl mk /ceph/$CLUSTER_NAME/keyrings/client-admin < /etc/ceph/ceph.client.admin.keyring; then
        etcdctl get /ceph/$CLUSTER_NAME/keyrings/client-admin > /etc/ceph/ceph.client.admin.keyring
    fi
fi

# Same deal with the mon. key

if ! ceph auth get mon. -o /etc/ceph/ceph.mon.keyring; then
    ceph-authtool /etc/ceph/ceph.mon.keyring --create-keyring --gen-key -n mon. --cap mon 'allow *'
fi

echo Getting initial monmap
if ! ceph mon getmap -o /etc/ceph/monmap; then
    echo Initial monmap not found, generating one
    echo monmaptool --create --add ${MON_NAME} ${MON_IP} --fsid $fsid /tmp/monmap
    monmaptool --create --add ${MON_NAME} ${MON_IP} --fsid $fsid /tmp/monmap
    if ! etcdctl mk /ceph/$CLUSTER_NAME/monmap < /tmp/monmap; then
        etcdctl get /ceph/$CLUSTER_NAME/monmap > /tmp/monmap
    fi
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

echo Launching ceph-mon
exec /usr/bin/ceph-mon -d -i ${MON_NAME} --public-addr ${MON_IP}:6789
