#!/bin/bash

if [ "$CORRAL_airgap_setup" = true ] || [ "$CORRAL_proxy_setup" = true ]; then
    scp -r -o StrictHostKeyChecking=no root@"${CORRAL_registry_private_ip}":/root/rke2-artifacts /root/rke2-artifacts
fi