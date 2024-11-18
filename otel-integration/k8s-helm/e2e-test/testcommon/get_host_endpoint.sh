#!/bin/bash

function get_host_endpoint() {
    if [[ "$(uname)" == "Darwin" ]]; then
        HOSTENDPOINT="host.docker.internal"
    else
        # Use jq to parse the JSON and extract the IPv4 Gateway
        HOSTENDPOINT=$(docker network inspect kind \
            | jq -r '.[0].IPAM.Config[] | select(.Gateway != null) | select(.Gateway | test("^[0-9]+\.")) | .Gateway' \
            | head -n 1)

        if [[ -z "$HOSTENDPOINT" ]]; then
            echo "Failed to find host endpoint via docker network inspect"
            exit 1
        fi
    fi

    # Export HOSTENDPOINT for GitHub Actions
    echo "HOSTENDPOINT=$HOSTENDPOINT" >> $GITHUB_ENV
    echo "HOSTENDPOINT is set to $HOSTENDPOINT"
}

get_host_endpoint
