#!/bin/sh
set -e

function die() {
    echo $1
    exit 1
}

: ${CLUSTER_NAME:=ceph}
: ${DEVICE:=sdf}

INSTANCE_ID=$(curl -q http://169.254.169.254/latest/meta-data/instance-id)
VOLUME_ID=$(curl -q http://172.17.42.1:4001/v2/keys/ceph/$CLUSTER_NAME/osd/$OSD_ID/ebs-volume)

test -n "$VOLUME_ID" || die "Unable to find VOLUME_ID for OSD $OSD_ID"

umount /dev/$DEVICE /var/lib/ceph/${CLUSTER_NAME}-${OSD_ID}
aws ec2 detach-volume --instance-id $INSTANCE_ID --volume-id $VOLUME_ID --device $DEVICE
