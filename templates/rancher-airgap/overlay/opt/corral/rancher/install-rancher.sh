#!/bin/bash
set -ex

if [ -z $CORRAL_rancher_chart_url ]; then
  helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
else
  helm repo add rancher-latest $CORRAL_rancher_chart_url
fi

helm repo update

CORRAL_internal_rancher_host=${CORRAL_internal_rancher_host:="${CORRAL_internal_fqdn}"}
CORRAL_rancher_version=${CORRAL_rancher_version:=$(helm search repo rancher-latest/rancher -o json | jq -r .[0].version)}

if [ -z $CORRAL_registry_cert ]; then
  helm upgrade \
  --install \
  --create-namespace \
  --set hostname="$CORRAL_internal_rancher_host" \
  --set rancherImage="${CORRAL_registry_fqdn}/${CORRAL_rancher_image}" \
  --set systemDefaultRegistry="$CORRAL_registry_fqdn" \
  --set useBundledSystemChart=true \
  --set "extraEnv[0].name=CATTLE_AGENT_IMAGE" --set "extraEnv[0].value=${CORRAL_rancher_image}-agent:v${CORRAL_rancher_version}" \
  --version "${CORRAL_rancher_version}" \
  --devel \
  --wait \
    -n cattle-system rancher rancher-latest/rancher
else
  helm upgrade \
  --install \
  --create-namespace \
  --set hostname="$CORRAL_internal_rancher_host" \
  --set rancherImage="${CORRAL_registry_fqdn}/${CORRAL_rancher_image}" \
  --set systemDefaultRegistry="$CORRAL_registry_fqdn" \
  --set useBundledSystemChart=true \
  --set ingress.tls.source=secret \
  --set "extraEnv[0].name=CATTLE_AGENT_IMAGE" --set "extraEnv[0].value=${CORRAL_rancher_image}-agent:v${CORRAL_rancher_version}" \
  --version "${CORRAL_rancher_version}" \
  --devel \
  --wait \
    -n cattle-system rancher rancher-latest/rancher
fi

echo "corral_set rancher_version=$CORRAL_rancher_version"
