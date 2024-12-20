#!/bin/bash
set -ex

function corral_set() {
    echo "corral_set $1=$2"
}

function corral_log() {
    echo "corral_log $1"
}

echo "$CORRAL_corral_user_public_key" >> "$HOME"/.ssh/authorized_key

docker run -d -v /opt/basic-proxy/squid/squid.conf:/etc/squid/squid.conf -p 3219:3219 ubuntu/squid

CORRAL_squid_container=$(docker ps --format {{.ID}})

echo "corral_set squid_container=$CORRAL_squid_container"
