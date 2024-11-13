#!/bin/bash
set -ex

apt-get update || true

apt install -y jq || true

curl --proxy http://$CORRAL_registry_private_ip:3219 https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

curl --proxy http://$CORRAL_registry_private_ip:3219 -LO https://storage.googleapis.com/kubernetes-release/release/$(curl --proxy http://$CORRAL_registry_private_ip:3219 -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl

chmod +x ./kubectl
mv ./kubectl /usr/local/bin/kubectl

mkdir ~/.kube

echo $CORRAL_kubeconfig | base64 -d > ~/.kube/config
chmod 400 ~/.kube/config