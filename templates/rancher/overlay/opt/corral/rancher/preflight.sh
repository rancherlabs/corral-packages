#!/bin/bash
set -ex

apt install -y jq

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo $CORRAL_kubeconfig | base64 -d > ~/.kube/config
chmod 400 ~/.kube/config