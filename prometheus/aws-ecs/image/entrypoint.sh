#!/bin/sh
set -e

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

DOCKERHOST=`cat /hostetc/hostname`
CLUSTERNAME=`wget -qO- http://172.17.0.1:51678/v1/metadata | sed -e 's/[{}]/''/g' | awk -F , '{split($1,a,"\"");print a[4]}'`
HOSTPUBLICIP=`wget -qO- http://checkip.amazonaws.com`

sed -i "s/<PRIVATEKEY>/$CORALOGIX_PRIVATEKEY/" /etc/prometheus/prometheus.yml 
sed -i "s|<ENDPOINT>|$CORALOGIX_ENDPOINT|" /etc/prometheus/prometheus.yml
sed -i "s/<SCRAPE-INTERVAL>/$SCRAPE_INTERVAL/g" /etc/prometheus/prometheus.yml 
sed -i "s/<HOSTNAME>/$DOCKERHOST/g" /etc/prometheus/prometheus.yml
sed -i "s/<CLUSTERNAME>/$CLUSTERNAME/" /etc/prometheus/prometheus.yml
sed -i "s/<HOSTPUBLICIP>/$HOSTPUBLICIP/" /etc/prometheus/prometheus.yml

/bin/prometheus $@