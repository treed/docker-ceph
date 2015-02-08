#!/bin/bash
set -ex

ETCDCTL_PEERS=172.17.42.1:4001

if [ ! -n "$OSD_ID" ]; then
   echo "OSD_ID must be set; call 'ceph osd create' to allocate the next available osd id"
   exit 1
fi

: ${CLUSTER_NAME:=ceph}
: ${WEIGHT:=1.0}
: ${JOURNAL:=/var/lib/ceph/osd/${CLUSTER}-${OSD_ID}/journal}
: ${DATA:=/var/lib/ceph/osd/${CLUSTER}-${OSD_ID}/data}

fsid=$(etcdctl get /ceph/$CLUSTER_NAME/fsid)

# Make sure osd directory exists
mkdir -p /var/lib/ceph/osd/${CLUSTER}-${OSD_ID}

# Check to see if our OSD has been initialized
if [ ! -e /var/lib/ceph/osd/${CLUSTER}-${OSD_ID}/keyring ]; then
   # Create OSD key and file structure
   ceph-osd -i $OSD_ID --mkfs --osd-data ${DATA} --mkjournal --osd-journal ${JOURNAL}

   echo Getting client key from etcd
   etcdctl get /ceph/$CLUSTER_NAME/keyrings/client-admin > /etc/ceph/${CLUSTER_NAME}.client.admin.keyring

   ceph auth get-or-create osd.${OSD_ID} osd 'allow *' mon 'allow profile osd' -o /var/lib/ceph/osd/${CLUSTER}-${OSD_ID}/keyring

   # Add the OSD to the CRUSH map
   if [ ! -n "${HOSTNAME}" ]; then
      echo "HOSTNAME not set; cannot add OSD to CRUSH map"
      exit 1
   fi
   ceph osd crush add ${OSD_ID} ${WEIGHT} root=default host=${HOSTNAME}
fi

if [ $1 == 'ceph-osd' ]; then
   exec ceph-osd -d -i ${OSD_ID} -k /var/lib/ceph/osd/${CLUSTER}-${OSD_ID}/keyring
else
   exec $@
fi
