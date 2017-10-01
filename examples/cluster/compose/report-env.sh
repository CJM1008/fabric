#!/bin/bash
#
# Copyright Greg Haskins All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#


NODES=$1
CONFIG=$2
TLS=$3

getip() {
    HOST=$1

    docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $HOST
}

url() {
    TYPE=$1
    NODE=$2
    PORT=$3

    if [ "$TLS" == "true" ]; then
        TYPE="$1s"
    fi

    echo $TYPE://$(getip $NODE):$PORT
}

http() {
    NODE=$1
    PORT=$2

    echo $(url "http" $NODE $PORT)
}

grpc() {
    NODE=$1
    PORT=$2

    echo $(url "grpc" $NODE $PORT)
}

peerurls() {
    for i in $(seq 1 4); do
        echo "$(url grpc peer$i, 7051)"
    done
}

generate_hosts() {
    for NODE in $NODES; do
        echo "$(getip $NODE) $NODE"
    done
}

includefile() {
    file=$1
    prefix=$2

    echo "|"

    while IFS= read -r line; do
        printf '%s%s\n' "$prefix" "$line"
    done < "$file"
}

echo "========================================================================"
echo "Cluster ready!"
echo "========================================================================"
echo
generate_hosts | sort

cat <<EOF > $CONFIG
#
# Generated by fabric.git/examples/cluster.  DO NOT EDIT!
#
ca:
        url: $(http "ca" "7054")
        certificate: $(includefile build/nodes/ca/ca.crt "              ")

tlsca:
        url: $(http "tlsca" "7054")
        certificate: $(includefile build/nodes/tlsca/ca.crt "              ")

orderer:
        url:  $(grpc "orderer" "7050")
        hostname: orderer
        ca: $(includefile build/nodes/orderer/tls/ca.crt "              ")

peers:
$(for i in $(seq 1 4); do
      echo "       - api: $(grpc peer$i 7051)"
      echo "         events: $(grpc peer$i 7053)"
      echo "         hostname: peer$i"
done)

identity:
        principal: Admin@org1.net
        mspid: Org1MSP
        privatekey: $(includefile build/nodes/cli/tls/server.key  "              ")
        certificate: $(includefile build/nodes/cli/tls/server.crt  "              ")
EOF