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

DOCKERHOST=`cat /hostetc/hostname`

sed -i "s/<PRIVATEKEY>/$CORALOGIX_PRIVATEKEY/" /etc/prometheus/prometheus.yml 
sed -i "s|<ENDPOINT>|$CORALOGIX_ENDPOINT|" /etc/prometheus/prometheus.yml 
sed -i "s/<HOSTNAME>/$DOCKERHOST/" /etc/prometheus/prometheus.yml

/bin/prometheus $@