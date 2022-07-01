#!/bin/bash

public_ipv4=$(curl ifconfig.me)
addresses=$(hostname -I)
private_ipv4=$(echo ${addresses} | cut -d " " -f 1)
ipv6=$(echo ${addresses} | cut -d " " -f 2)

mkdir -p /etc/rancher/rke2
cat > /etc/rancher/rke2/config.yaml <<- EOF
server: https://${CORRAL_kube_api_host}:9345
cni: ${CORRAL_cni}
token: ${CORRAL_node_token}
node-ip: ${private_ipv4},${ipv6}
node-external-ip: ${public_ipv4},${ipv6}
tls-san:
  - ${CORRAL_api_host}
EOF

curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=${CORRAL_kubernetes_version} INSTALL_RKE2_TYPE="agent" sh -
systemctl enable rke2-agent.service --now
RET=1
until [ ${RET} -eq 0 ]; do
    systemctl start rke2-agent.service
    RET=$?
    sleep 10
done