#!/bin/bash

mkdir -p /etc/rancher/rke2
cat > /etc/rancher/rke2/config.yaml <<- EOF
write-kubeconfig-mode: 644
server: https://${CORRAL_kube_api_host}:9345
cni: ${CORRAL_cni}
token: ${CORRAL_node_token}
tls-san:
  - ${CORRAL_api_host}
EOF

curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=${CORRAL_kubernetes_version} sh -
systemctl enable rke2-server.service
RET=1
until [ ${RET} -eq 0 ]; do
    systemctl start rke2-server.service
    RET=$?
    sleep 10
done
