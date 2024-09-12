#!/bin/bash
set -ex

repos=("latest" "alpha" "stable" "prime", "optimus")
if [[ ! ${repos[*]} =~ ${CORRAL_rancher_chart_repo} ]]; then
  echo 'Error: `rancher_chart_repo` must be one of ["latest", "alpha", "stable", "prime", "optimus"]'
  exit 1
fi

if [ ${CORRAL_rancher_chart_repo} == "optimus" ]; then
  helm repo add "rancher-${CORRAL_rancher_chart_repo}" "${CORRAL_rancher_chart_url}"
  helm repo update
else
  helm repo add "rancher-${CORRAL_rancher_chart_repo}" "${CORRAL_rancher_chart_url}/${CORRAL_rancher_chart_repo}"
  helm repo update
fi

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
  if [ "${CORRAL_env_var_map}" ]; then
    STRIPPED=$(echo ${CORRAL_env_var_map} | tr -d '[]' | tr -d '"' | tr -d ',')
    COUNT=0
    IFS=' ' read -ra NEWARRAY <<< "$STRIPPED"
    for i in "${NEWARRAY[@]}"; do
        IFS='|' read -ra ADDR <<< "$i"
        if [ "${ADDR[0]}" == "RANCHER_PRIME" ]; then
        ADDR[1]=$(echo "${ADDR[1]}"| sed 's/true/\\"true\\"/g')
        fi
        echo "key is ${ADDR[0]}"
        echo "value is ${ADDR[1]}"
        args+=("--set extraEnv[${COUNT}].name=${ADDR[0]} --set extraEnv[${COUNT}].value=${ADDR[1]}")
        COUNT=$((COUNT+1))
    done
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
