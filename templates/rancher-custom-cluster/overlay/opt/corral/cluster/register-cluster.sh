#!/bin/bash
set -ex

if [ "$CORRAL_proxy_setup" = true ]; then

reg_command=$(echo ${CORRAL_registration_command} | sed "s/"\\\""/"\""/g")
eval ${reg_command}

else

eval ${CORRAL_registration_command}

fi
