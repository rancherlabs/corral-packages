#!/bin/bash

KUBERNETES_VERSION=${CORRAL_kubernetes_version/+/"%2B"}
ARTIFACT_ROOT=/root/rke2-artifacts
mkdir -p $ARTIFACT_ROOT && cd $ARTIFACT_ROOT

curl -OLs https://github.com/rancher/rke2/releases/download/"${KUBERNETES_VERSION}"/rke2-images.linux-amd64.tar.zst
curl -OLs https://github.com/rancher/rke2/releases/download/"${KUBERNETES_VERSION}"/rke2.linux-amd64.tar.gz
curl -OLs https://github.com/rancher/rke2/releases/download/"${KUBERNETES_VERSION}"/sha256sum-amd64.txt
curl -sfL https://get.rke2.io --output install.sh
CORRAL_rke2_install_command="INSTALL_RKE2_ARTIFACT_PATH=/root/rke2-artifacts"
echo "corral_set rke2_install_command=${CORRAL_rke2_install_command}"
CORRAL_sh_args="/root/rke2-artifacts/install.sh"
echo "corral_set sh_args=${CORRAL_sh_args}"