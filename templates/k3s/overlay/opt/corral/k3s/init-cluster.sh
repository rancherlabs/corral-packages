#!/bin/bash
set -ex

CORRAL_api_host="kube-api.${CORRAL_fqdn}"
echo "corral_set api_host=${CORRAL_api_host}"

mkdir -p /etc/rancher/k3s
cat > /etc/rancher/k3s/config.yaml <<- EOF
cluster-init: true
tls-san:
  - ${CORRAL_api_host}
EOF

apt install -y jq

curl -sfL https://get.k3s.io | KUBERNETES_VERSION=${CORRAL_kubernetes_version} sh -

sed -i "s/127.0.0.1/kube-api.${CORRAL_fqdn}/g" /etc/rancher/k3s/k3s.yaml

echo "corral_set node_token=$(cat /var/lib/rancher/k3s/server/node-token)"

# set user variables
echo "corral_set kubernetes_version=$(kubectl version -o json | jq -r .serverVersion.gitVersion)"
echo "corral_set kubeconfig=$(cat /etc/rancher/k3s/k3s.yaml | base64 -w 0)"
