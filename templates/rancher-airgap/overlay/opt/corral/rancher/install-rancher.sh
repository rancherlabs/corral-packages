#!/bin/bash
set -ex

helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

CORRAL_internal_rancher_host=${CORRAL_internal_rancher_host:="${CORRAL_internal_fqdn}"}
CORRAL_rancher_version=${CORRAL_rancher_version:=$(helm search repo rancher-latest/rancher -o json | jq -r .[0].version)}

helm upgrade \
--install \
--create-namespace \
--set hostname="$CORRAL_internal_rancher_host" \
--set rancherImage="$CORRAL_registry_fqdn/rancher/rancher" \
--set systemDefaultRegistry="$CORRAL_registry_fqdn" \
--version "${CORRAL_rancher_version}" \
--devel \
--wait \
  -n cattle-system rancher rancher-latest/rancher
  
echo "corral_set rancher_version=$CORRAL_rancher_version"
