#!/bin/bash
set -ex

helm repo add jetstack https://charts.jetstack.io
helm repo update
helm fetch jetstack/cert-manager --version "v${CORRAL_cert_manager_version}"
tar xvzf "cert-manager-v${CORRAL_cert_manager_version}.tgz"
curl -L -o cert-manager/cert-manager-crd.yaml "https://github.com/cert-manager/cert-manager/releases/download/v${CORRAL_cert_manager_version}/cert-manager.crds.yaml"
kubectl create namespace cert-manager
kubectl apply -f cert-manager/cert-manager-crd.yaml

helm install cert-manager "./cert-manager-v${CORRAL_cert_manager_version}.tgz" \
    --namespace cert-manager \
    --set image.repository="${CORRAL_registry_fqdn}/quay.io/jetstack/cert-manager-controller" \
    --set webhook.image.repository="${CORRAL_registry_fqdn}/quay.io/jetstack/cert-manager-webhook" \
    --set cainjector.image.repository="${CORRAL_registry_fqdn}/quay.io/jetstack/cert-manager-cainjector" \
    --set startupapicheck.image.repository="${CORRAL_registry_fqdn}/quay.io/jetstack/cert-manager-ctl"

# when attempting to install rancher right after the cert-manager install there is some intermitten issues
# allowing it to sleep for at least a 1m fixes the issue.
sleep 1m