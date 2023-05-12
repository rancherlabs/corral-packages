#!/bin/bash
set -ex

CORRAL_rancher_host=${CORRAL_rancher_host:="${CORRAL_fqdn}"}
CORRAL_internal_rancher_host=${CORRAL_internal_rancher_host:="${CORRAL_internal_fqdn}"}

kubectl patch ingress rancher -n cattle-system --type=json -p='[{"op": "add", "path": "/spec/rules/-", "value": {"host": "'${CORRAL_rancher_host}'","http":{"paths":[{"backend":{"service":{"name":"rancher","port":{"number":80}}},"pathType":"ImplementationSpecific"}]}}}]'

kubectl patch ingress rancher -n cattle-system --type=json -p='[{"op": "add", "path": "/spec/tls/0/hosts/-", "value":  "'${CORRAL_rancher_host}'"}]'

kubectl patch setting server-url --type=json -p='[{"op": "add", "path": "/value", "value":  "'https://${CORRAL_internal_rancher_host}'"}]'

echo "corral_set rancher_host=$CORRAL_rancher_host"
echo "corral_set rancher_url=https://$CORRAL_rancher_host"