#!/bin/bash
set -ex

helm repo add jetstack https://charts.jetstack.io
helm repo update
kubectl create namespace cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v$CORRAL_cert_manager_version/cert-manager.crds.yaml

helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --version v$CORRAL_cert_manager_version --set http_proxy=http://$CORRAL_registry_private_ip:3219 --set https_proxy=http://$CORRAL_registry_private_ip:3219 --set no_proxy=127.0.0.0/8\\,10.0.0.0/8\\,172.0.0.0/8\\,192.168.0.0/16\\,.svc\\,.cluster.local\\,cattle-system.svc\\,169.254.169.254
# when attempting to install rancher right after the cert-manager install there is some intermitten issues
# allowing it to sleep for at least a 1m fixes the issue.
sleep 1m
