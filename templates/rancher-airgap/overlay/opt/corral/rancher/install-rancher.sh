#!/bin/bash
set -ex

helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

CORRAL_internal_rancher_host=${CORRAL_internal_rancher_host:="${CORRAL_internal_fqdn}"}
CORRAL_rancher_version=${CORRAL_rancher_version:=$(helm search repo rancher-latest/rancher -o json | jq -r .[0].version)}
kubernetes_version=$(kubectl version --short | awk '/Server Version:/ {print $3}')
minor_version=$(echo "$kubernetes_version" | cut -d. -f2)

if [ "$minor_version" -gt 24 ]; then
  helm upgrade \
  --install \
  --create-namespace \
  --set hostname="$CORRAL_internal_rancher_host" \
  --set rancherImage="$CORRAL_registry_fqdn/rancher/rancher" \
  --set systemDefaultRegistry="$CORRAL_registry_fqdn" \
  --set global.cattle.psp.enabled=false \
  --version "${CORRAL_rancher_version}" \
  --devel \
  --wait \
    -n cattle-system rancher rancher-latest/rancher
else
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
fi
  
echo "corral_set rancher_version=$CORRAL_rancher_version"
