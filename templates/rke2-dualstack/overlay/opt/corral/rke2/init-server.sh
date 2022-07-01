#!/bin/bash

public_ipv4=$(curl ifconfig.me)
addresses=$(hostname -I)
private_ipv4=$(echo ${addresses} | cut -d " " -f 1)
ipv6=$(echo ${addresses} | cut -d " " -f 3)
nodename=$(hostname -f)

mkdir -p /etc/rancher/rke2
cat > /etc/rancher/rke2/config.yaml <<- EOF
write-kubeconfig-mode: 644
token: ${CORRAL_node_token}
cluster-cidr: 10.42.0.0/16,2001:cafe:42:0::/56
service-cidr: 10.43.0.0/16,2001:cafe:42:1::/112
cni: ${CORRAL_cni}
node-ip: ${private_ipv4},${ipv6}
node-external-ip: ${public_ipv4},${ipv6}
server: https://${CORRAL_kube_api_host}:9345
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
