#!/bin/bash

set -eu

touch .env
{
  echo CYPRESS_VIDEO=false
  echo CYPRESS_VIEWPORT_WIDTH="1000"
  echo CYPRESS_VIEWPORT_HEIGHT="660"
  echo TEST_BASE_URL="https://${CORRAL_rancher_host:-}/dashboard"
  echo TEST_USERNAME="${CORRAL_rancher_username:-admin}"
  echo TEST_PASSWORD="${CORRAL_rancher_password:-password}"
  echo TEST_SKIP_SETUP=true
  echo TEST_SKIP=setup
  echo AWS_ACCESS_KEY_ID="${CORRAL_aws_access_key:-}"
  echo AWS_SECRET_ACCESS_KEY="${CORRAL_aws_secret_key:-}"
  echo AZURE_CLIENT_ID="${CORRAL_azure_client_id:-}"
  echo AZURE_CLIENT_SECRET="${CORRAL_azure_client_secret:-}"
  echo AZURE_AKS_SUBSCRIPTION_ID="${CORRAL_azure_subscription_id:-}"
  echo GKE_SERVICE_ACCOUNT="${CORRAL_gke_service_account:-}"
  echo CUSTOM_NODE_IP="${CORRAL_custom_node_ip:-}"
  echo CUSTOM_NODE_KEY="${CORRAL_custom_node_key:-}"
  echo PERCY_TOKEN="${CORRAL_percy_token:-}"
  echo QASE_REPORT="${CORRAL_qase_report:-false}"
  echo QASE_PROJECT="${CORRAL_qase_project:-SANDBOX}"
  echo QASE_AUTOMATION_TOKEN="${CORRAL_qase_automation_token:-}"
  echo RANCHER_IMAGE_TAG="${CORRAL_rancher_image_tag:-unknown}"
} >> .env
