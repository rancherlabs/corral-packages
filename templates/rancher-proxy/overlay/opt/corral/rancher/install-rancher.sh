#!/bin/bash
set -ex
repos=("latest" "alpha" "stable" "staging" "prime")
if [[ ! ${repos[*]} =~ ${CORRAL_rancher_chart_repo} ]]; then
  echo 'Error: `rancher_chart_repo` must be one of ["latest", "alpha", "stable", "staging", "prime"]'
  exit 1
fi

CORRAL_rancher_host=${CORRAL_rancher_host:="${CORRAL_fqdn}"}
CORRAL_rancher_version=${CORRAL_rancher_version:=$(helm search repo rancher-latest/rancher -o json | jq -r .[0].version)}
minor_version=$(echo "$CORRAL_kubernetes_version" | cut -d. -f2)

kubectl create namespace cattle-system

community=("latest" "alpha" "stable")

if [ "$minor_version" -gt 24 ]; then
    
    args=("rancher-$CORRAL_rancher_chart_repo/rancher" "--namespace cattle-system" "--set global.cattle.psp.enabled=false" "--set hostname=$CORRAL_rancher_host" "--version=$CORRAL_rancher_version" "--set proxy=http://$CORRAL_registry_private_ip:3219")

    if [[  ${community[*]} =~ ${CORRAL_rancher_chart_repo} ]]; then
      if [ ! -z "$CORRAL_rancher_chart_url" ]; then
        helm repo add "rancher-$CORRAL_rancher_chart_repo" "$CORRAL_rancher_chart_url"
      else
        helm repo add "rancher-$CORRAL_rancher_chart_repo" "https://releases.rancher.com/server-charts/$CORRAL_rancher_chart_repo"
      fi
      args2=("")
    fi

    if [[ "$CORRAL_rancher_chart_repo" == "prime" ]]; then
     helm repo add "rancher-prime" "https://charts.rancher.com/server-charts/prime"
     args2=("--set rancherImage=registry.suse.com/rancher/rancher")
    fi

    if [[ "$CORRAL_rancher_chart_repo" == "staging" ]]; then
     helm repo add "rancher-staging" "https://charts.optimus.rancher.io/server-charts/latest"
     args2=("--set rancherImage=stgregistry.suse.com/rancher/rancher")

      if [ ! -z "$CORRAL_rancher_image_tag" ]; then
        args2+=("--set rancherImageTag=$CORRAL_rancher_image_tag")
      fi

      helm repo update
     
      if [ ! -z "$CORRAL_rancher_image" ]; then
          helm upgrade --install rancher ${args[*]} --set noProxy=127.0.0.0/8\\,10.0.0.0/8\\,172.0.0.0/8\\,192.168.0.0/16\\,.svc\\,.cluster.local\\,cattle-system.svc\\,169.254.169.254 ${args2[*]} --set 'extraEnv[0].name=CATTLE_AGENT_IMAGE' --set 'extraEnv[0].value=stgregistry.suse.com/rancher/rancher-agent:'$CORRAL_rancher_image''
      else
        helm upgrade --install rancher ${args[*]} --set noProxy=127.0.0.0/8\\,10.0.0.0/8\\,172.0.0.0/8\\,192.168.0.0/16\\,.svc\\,.cluster.local\\,cattle-system.svc\\,169.254.169.254 ${args2[*]}
      fi
      echo "corral_set rancher_version=$CORRAL_rancher_version"
      echo "corral_set rancher_host=$CORRAL_rancher_host"
      exit 0
    fi

    helm repo update

    if [ ! -z "$CORRAL_rancher_image_tag" ]; then
      args2+=("--set rancherImageTag=$CORRAL_rancher_image_tag")
    fi

    helm upgrade --install rancher ${args[*]} --set noProxy=127.0.0.0/8\\,10.0.0.0/8\\,172.0.0.0/8\\,192.168.0.0/16\\,.svc\\,.cluster.local\\,cattle-system.svc\\,169.254.169.254 ${args2[*]}
else
    helm upgrade --install rancher rancher-$CORRAL_rancher_chart_repo/rancher --namespace cattle-system --set hostname=$CORRAL_rancher_host --version=$CORRAL_rancher_version --set proxy=http://$CORRAL_registry_private_ip:3219 --set noProxy=127.0.0.0/8\\,10.0.0.0/8\\,172.0.0.0/8\\,192.168.0.0/16\\,.svc\\,.cluster.local\\,cattle-system.svc\\,169.254.169.254
fi

echo "corral_set rancher_version=$CORRAL_rancher_version"
echo "corral_set rancher_host=$CORRAL_rancher_host"
