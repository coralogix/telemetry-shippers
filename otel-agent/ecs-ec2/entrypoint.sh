#!/bin/sh

CONFIG_PATH=/config.yaml

# decode base64 encoded env var and write to file
echo ${OTEL_CONFIG} | base64 -d > ${CONFIG_PATH}

echo "${CONFIG_PATH}:"
cat ${CONFIG_PATH}

# run otel agent
exec /cora-otel-ecs-ec2 --config ${CONFIG_PATH}
