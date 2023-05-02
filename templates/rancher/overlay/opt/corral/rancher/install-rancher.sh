#!/bin/bash
set -ex

helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

CORRAL_rancher_host=${CORRAL_rancher_host:="${CORRAL_fqdn}"}
CORRAL_rancher_version=${CORRAL_rancher_version:=$(helm search repo rancher-latest/rancher -o json | jq -r .[0].version)}

args=("--install" "--create-namespace")

if [ -z "${CORRAL_registry_fqdn}" ]; then
	args+=("--set hostname=${CORRAL_rancher_host}" "--version ${CORRAL_rancher_version}")
else
	args+=("--set hostname=${CORRAL_rancher_host}" "--set rancherImage=${CORRAL_registry_fqdn}/rancher/rancher" "--set systemDefaultRegistry=${CORRAL_registry_fqdn}" "--version ${CORRAL_rancher_version}")
fi

args+=("--devel" "--wait" "-n cattle-system" "rancher rancher-latest/rancher")
eval "helm upgrade ${args[@]}"

echo "corral_set rancher_host=$CORRAL_rancher_host"
echo "corral_set rancher_url=https://$CORRAL_rancher_host"
echo "corral_set rancher_version=$CORRAL_rancher_version"
