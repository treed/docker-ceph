FROM stackbrew/ubuntu:trusty
MAINTAINER Ted Reed <ted.reed@gmail.com>

# Make sure we are up-to-date
RUN apt-get update
RUN apt-get upgrade -y

# Get etcdctl
RUN apt-get install -y wget
RUN cd /tmp && wget https://github.com/coreos/etcd/releases/download/v0.4.6/etcd-v0.4.6-linux-amd64.tar.gz && tar xvf etcd-v0.4.6-linux-amd64.tar.gz
RUN mv /tmp/etcd-v0.4.6-linux-amd64/etcdctl /usr/local/bin
RUN rm -rf /tmp/etcd-v0.4.6-linux-amd64

# Install ceph
RUN apt-get install -y ceph
