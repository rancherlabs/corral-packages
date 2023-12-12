#!/bin/bash
set -ex

apt-get update || true

apt install -y jq || true

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

curl -LO https://storage.googleapis.com/kubernetes-release/release/"$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)"/bin/linux/amd64/kubectl
chmod +x ./kubectl
mv ./kubectl /usr/local/bin/kubectl

mkdir ~/.kube

echo "${CORRAL_kubeconfig}" | base64 -d > ~/.kube/config
chmod 400 ~/.kube/config

RET=1
COUNT=0

until [ ${RET} -eq 0 ] && [ ${COUNT} -eq 2 ]; do
	kubectl get nodes
	RET=$?
	sleep 5
	COUNT=$((COUNT+1))
done
