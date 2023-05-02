#!/bin/bash

config="write-kubeconfig-mode: 644
cni: ${CORRAL_cni}
server: https://${CORRAL_kube_api_host}:9345
token: ${CORRAL_node_token}
tls-san:
  - ${CORRAL_api_host}
"

if [ "${CORRAL_registry_fqdn}" ]; then
  config+="system-default-registry: ${CORRAL_registry_fqdn}"
fi

if [ "$CORRAL_airgap_setup" = true ]; then
  config=$(echo "$config" | sed "/tls-san:/a \  - $CORRAL_internal_fqdn
")
fi 

mkdir -p /etc/rancher/rke2
cat > /etc/rancher/rke2/config.yaml <<- EOF
${config}
EOF

FULL_COMMAND="$CORRAL_rke2_install_command sh $CORRAL_sh_args"

eval ${FULL_COMMAND}
systemctl enable rke2-server.service
RET=1
until [ ${RET} -eq 0 ]; do
	systemctl start rke2-server.service
	RET=$?
	sleep 10
done
