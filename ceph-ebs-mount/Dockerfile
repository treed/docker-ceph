FROM ubuntu:14.04

RUN apt-get update -q
RUN DEBIAN_FRONTEND=noninteractive apt-get install -qy python-pip groff-base
RUN DEBIAN_FRONTEND=noninteractive apt-get install -qy curl
RUN pip install awscli

ADD entrypoint.sh /usr/local/bin/entrypoint.sh


