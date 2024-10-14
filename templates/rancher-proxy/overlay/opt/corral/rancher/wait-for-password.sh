#!/bin/bash
set -ex

function corral_set() {
    echo "corral_set $1=$2"
}

function corral_log() {
    echo "corral_log $1"
}

if [[ $CORRAL_rancher_version == "2.5.*" ]]; then
  echo "corral_set bootstrap_password=admin"
  return 0
fi

if [ ${CORRAL_bootstrap_password} -ne "" ]; then
  echo "bootstrap_password=${CORRAL_bootstrap_password}"
  exit 0
fi

echo "waiting for bootstrap password"
until [ "$(kubectl -n cattle-system get secret/bootstrap-secret -o json --ignore-not-found=true | jq -r '.data.bootstrapPassword | length > 0')" == "true" ]; do
  sleep 0.1
  echo -n "."
done
echo

echo "corral_set bootstrap_password=$(kubectl -n cattle-system get secret/bootstrap-secret -o json | jq -r '.data.bootstrapPassword' | base64 -d)"
bootstrap_password=$(kubectl -n cattle-system get secret/bootstrap-secret -o json | jq -r '.data.bootstrapPassword' | base64 -d)


corral_log "Bastion public address: ${CORRAL_registry_ip}" 

corral_log "Bastion private address: ${CORRAL_registry_private_ip}"

corral_log "Save private key: echo \"${CORRAL_corral_private_key}\" | tr -d '\"' > id_rsa"

corral_log "Save public key: echo \"${CORRAL_corral_public_key}\" | tr -d '\"' > id_rsa.pub"

corral_log "Follow squid proxy logs: ssh -i id_rsa root@${CORRAL_registry_ip} \"sudo docker exec $CORRAL_squid_container tail -f /var/log/squid/access.log\" "

corral_log "Connect to bastion node: ssh -i id_rsa root@${CORRAL_registry_ip}"

corral_log "From bastion, connect to rancher server node with: ssh ubuntu@${CORRAL_kube_api_host}"

corral_log "Rancher instance running at: https://$CORRAL_rancher_host/dashboard/?setup=$bootstrap_password"
