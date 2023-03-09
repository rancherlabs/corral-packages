#!/bin/bash
set -ex

CORRAL_internal_rancher_host=${CORRAL_internal_rancher_host:="${CORRAL_internal_fqdn}"}

kubectl patch ingress rancher -n cattle-system --type=json -p='[{"op": "add", "path": "/spec/rules/-", "value": {"host": "'${CORRAL_internal_rancher_host}'","http":{"paths":[{"backend":{"service":{"name":"rancher","port":{"number":80}}},"pathType":"ImplementationSpecific"}]}}}]'

kubectl patch ingress rancher -n cattle-system --type=json -p='[{"op": "add", "path": "/spec/tls/0/hosts/-", "value":  "'${CORRAL_internal_rancher_host}'"}]'