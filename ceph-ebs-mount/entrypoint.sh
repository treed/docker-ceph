#!/bin/sh
set +e

: ${CLUSTER_NAME:=ceph}

INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)
VOLUME_ID=$(curl http://172.17.42.1:4001/v2/keys/ceph/$CLUSTER_NAME/osd/$OSD_ID/ebs-volume)

aws ec2 attach-volume --instance-id $INSTANCE_ID --volume-id $VOLUME_ID --device /dev/sdf
mkdir -pf /var/lib/ceph/${CLUSTER_NAME}-${OSD_ID}
mount /dev/sdf /var/lib/ceph/${CLUSTER_NAME}-${OSD_ID}
