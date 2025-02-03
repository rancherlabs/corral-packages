#!/bin/bash

set -x   
set -eu

touch .env
echo CYPRESS_VIDEO=false >> .env
echo CYPRESS_VIEWPORT_WIDTH="1000" >> .env
echo CYPRESS_VIEWPORT_HEIGHT="660" >> .env
echo TEST_BASE_URL="https://${CORRAL_rancher_host}/dashboard" >> .env
echo TEST_USERNAME="${CORRAL_rancher_username}" >> .env
echo TEST_PASSWORD="${CORRAL_rancher_password}" >> .env
echo TEST_SKIP_SETUP=true >> .env
echo TEST_SKIP=setup >> .env
echo AWS_ACCESS_KEY_ID=${CORRAL_aws_access_key} >> .env
echo AWS_SECRET_ACCESS_KEY=${CORRAL_aws_secret_key} >> .env
echo AZURE_CLIENT_ID=${CORRAL_azure_client_id} >> .env
echo AZURE_CLIENT_SECRET=${CORRAL_azure_client_secret} >> .env
echo AZURE_AKS_SUBSCRIPTION_ID=${CORRAL_azure_subscription_id} >> .env
echo GKE_SERVICE_ACCOUNT="$(echo ${CORRAL_gke_service_account} | base64)" >> .env
echo CUSTOM_NODE_IP="${CORRAL_custom_node_ip}" >> .env
echo CUSTOM_NODE_KEY="${CORRAL_custom_node_key}" >> .env
echo CUSTOM_NODE_IP_RKE1="${CORRAL_custom_node_ip_rke1}" >> .env
echo CUSTOM_NODE_KEY_RKE1="${CORRAL_custom_node_key_rke1}" >> .env
