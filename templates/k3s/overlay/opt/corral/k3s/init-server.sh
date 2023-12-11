#!/bin/bash

config="write-kubeconfig-mode: 644
server: https://${CORRAL_kube_api_host}:6443
token: ${CORRAL_node_token}
tls-san:
  - ${CORRAL_api_host}
"

mkdir -p /etc/rancher/k3s
cat >/etc/rancher/k3s/config.yaml <<-EOF
${config}
EOF

curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${CORRAL_kubernetes_version} sh -

RET=1
until [ ${RET} -eq 0 ]; do
  curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${CORRAL_kubernetes_version} sh -
  RET=$?
  journalctl -u k3s
  sleep 10
done
