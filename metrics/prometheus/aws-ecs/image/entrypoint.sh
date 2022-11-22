#!/bin/sh
set -e

# Get docker host 
DOCKERHOST=`cat /hostetc/hostname`

# Get Cluster name from the ecs-agent
CLUSTERNAME=`wget -qO- http://172.17.0.1:51678/v1/metadata | sed -e 's/[{}]/''/g' | awk -F , '{split($1,a,"\"");print a[4]}'`

# Get host public ip
HOSTPUBLICIP=`wget -qO- http://checkip.amazonaws.com`

# Variables check
if [[ -z $CORALOGIX_PRIVATEKEY ]]; then
  echo "CORALOGIX_PRIVATEKEY environment variable must be set"
  exit 1
fi

if [[ -z $CORALOGIX_ENDPOINT ]]; then
  echo "CORALOGIX_ENDPOINT environment variable must be set"
  exit 1
fi

if [[ -z $SCRAPE_INTERVAL ]]; then
  echo "SCRAPE_INTERVAL environment variable must be set"
  exit 1
fi

if [[ -z $DOCKERHOST ]]; then
  echo "error while retrieving instance hostname, verify that /etc/hostname is mounted"
  exit 1
fi

if [[ -z $CLUSTERNAME ]]; then
  echo "error while retrieving clustername from ecs-agent"
  exit 1
fi

if [[ -z $HOSTPUBLICIP ]]; then
  echo "error while retrieving host public ip, verify that host has outgoing ports (80,443) open"
  exit 1
fi

sed -i "s/<PRIVATEKEY>/$CORALOGIX_PRIVATEKEY/" /etc/prometheus/prometheus.yml 
sed -i "s|<ENDPOINT>|$CORALOGIX_ENDPOINT|" /etc/prometheus/prometheus.yml
sed -i "s/<SCRAPE-INTERVAL>/$SCRAPE_INTERVAL/g" /etc/prometheus/prometheus.yml 
sed -i "s/<HOSTNAME>/$DOCKERHOST/g" /etc/prometheus/prometheus.yml
sed -i "s/<CLUSTERNAME>/$CLUSTERNAME/" /etc/prometheus/prometheus.yml
sed -i "s/<HOSTPUBLICIP>/$HOSTPUBLICIP/" /etc/prometheus/prometheus.yml

/bin/prometheus $@