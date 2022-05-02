#!/bin/bash
set -ex

mkdir -p /etc/rancher/k3s
cat > /etc/rancher/k3s/config.yaml <<- EOF
server: https://${CORRAL_api_host}:6443
token: ${CORRAL_node_token}
tls-san:
  - ${CORRAL_api_host}
EOF

curl -sfL https://get.k3s.io | KUBERNETES_VERSION=${CORRAL_kubernetes_version} sh -
