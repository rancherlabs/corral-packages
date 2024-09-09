#!/bin/bash

CORRAL_api_host="${CORRAL_fqdn}"
echo "corral_set api_host=${CORRAL_api_host}"

config="write-kubeconfig-mode: 644
cluster-init: true
cni: ${CORRAL_cni}
tls-san:
  - ${CORRAL_api_host}
  - ${CORRAL_kube_api_host}
"

mkdir -p /etc/rancher/k3s
cat > /etc/rancher/k3s/config.yaml <<-EOF
${config}
EOF

curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${CORRAL_kubernetes_version} sh -

sed -i "s/127.0.0.1/${CORRAL_api_host}/g" /etc/rancher/k3s/k3s.yaml

# set user variables
echo "corral_set node_token=$(cat /var/lib/rancher/k3s/server/node-token)"
echo "corral_set kubeconfig=$(cat /etc/rancher/k3s/k3s.yaml | base64 -w 0)"
