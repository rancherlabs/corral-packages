#!/bin/bash
set -ex

repos=("latest" "alpha" "stable")
if [[ ! ${repos[*]} =~ ${CORRAL_rancher_chart_repo} ]]; then
  echo 'Error: `rancher_chart_repo` must be one of ["latest", "alpha", "stable"]'
  exit 1
fi

helm repo add "rancher-${CORRAL_rancher_chart_repo}" "${CORRAL_rancher_chart_url}/${CORRAL_rancher_chart_repo}"
helm repo update

CORRAL_rancher_host=${CORRAL_rancher_host:="${CORRAL_fqdn}"}
CORRAL_rancher_version=${CORRAL_rancher_version:=$(helm search repo rancher-"${CORRAL_rancher_chart_repo}"/rancher -o json | jq -r .[0].version)}

args=("--install" "--create-namespace")

if [ -z "${CORRAL_registry_fqdn}" ]; then
  args+=("--set hostname=${CORRAL_rancher_host}" "--version ${CORRAL_rancher_version}")
  if [ "${CORRAL_rancher_image}" ]; then
    args+=("--set rancherImage=${CORRAL_rancher_image}")
  fi
  if [ "${CORRAL_rancher_image_tag}" ]; then
    args+=("--set rancherImageTag=${CORRAL_rancher_image_tag}")
  fi
else
  args+=("--set hostname=${CORRAL_rancher_host}" "--set rancherImage=${CORRAL_registry_fqdn}/rancher/rancher" "--set systemDefaultRegistry=${CORRAL_registry_fqdn}" "--version ${CORRAL_rancher_version}")
fi

if [ -n "${CORRAL_bootstrap_password}" ]; then
  args+=("--set bootstrapPassword=${CORRAL_bootstrap_password}")
fi

if [ ! -z "${CORRAL_lets_encrypt_email}" ]; then
  args+=("--set ingress.tls.source=letsEncrypt" "--set letsEncrypt.email=${CORRAL_lets_encrypt_email}" "--set letsEncrypt.ingress.class=nginx")
fi

args+=("--devel" "--wait" "-n cattle-system" "rancher rancher-${CORRAL_rancher_chart_repo}/rancher")
eval "helm upgrade ${args[*]}"

echo "corral_set rancher_host=$CORRAL_rancher_host"
echo "corral_set rancher_url=https://$CORRAL_rancher_host"
echo "corral_set rancher_version=$CORRAL_rancher_version"
