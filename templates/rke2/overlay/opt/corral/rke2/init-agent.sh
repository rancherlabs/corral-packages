#!/bin/bash

config="server: https://${CORRAL_kube_api_host}:9345
token: ${CORRAL_node_token}
"

if [ "${CORRAL_registry_fqdn}" ]; then
  config+="system-default-registry: ${CORRAL_registry_fqdn}"
fi

mkdir -p /etc/rancher/rke2
cat > /etc/rancher/rke2/config.yaml <<- EOF
${config}
EOF

FULL_COMMAND="${CORRAL_rke2_install_command} INSTALL_RKE2_TYPE=\"agent\" sh ${CORRAL_sh_args}"

eval ${FULL_COMMAND}
systemctl enable rke2-agent.service --now
RET=1
until [ ${RET} -eq 0 ]; do
        systemctl start rke2-agent.service
        RET=$?
        sleep 10
done
