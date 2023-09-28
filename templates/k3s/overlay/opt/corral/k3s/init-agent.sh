#!/bin/bash

curl -sfL https://get.k3s.io | K3S_TOKEN=${CORRAL_node_token} INSTALL_K3S_VERSION=${CORRAL_kubernetes_version} sh -s - agent --server https://${CORRAL_kube_api_host}:6443
