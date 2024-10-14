#!/bin/bash
set -ex

if [ "$CORRAL_proxy_setup" = true ]; then
#proxy settings for .bashrc 
env="
export HTTP_PROXY=http://${CORRAL_registry_private_ip}:3219
export HTTPS_PROXY=http://${CORRAL_registry_private_ip}:3219
export http_proxy=http://${CORRAL_registry_private_ip}:3219
export https_proxy=http://${CORRAL_registry_private_ip}:3219
export proxy_host=${CORRAL_registry_private_ip}:3219
export NO_PROXY=localhost,127.0.0.1,0.0.0.0,10.0.0.0/8,172.16.0.0/12,cattle-system.svc,192.168.0.0/16,169.254.169.254,172.66.47.109,172.66.47.147"
#NO_PROXY -> AWS metadata requires 169.254.169.254 -> cert-manager install requires 172.66.47.109 and 172.66.47.147 


#set .bashrc for ubuntu user
cat > /home/ubuntu/.bashrc <<- EOF
${env}
EOF

#set .bashrc for root user
cat > /root/.bashrc <<- EOF
${env}
EOF

#proxy settings for rke2 server
touch /etc/default/rke2-server
rke2env="
HTTP_PROXY=http://${CORRAL_registry_private_ip}:3219
HTTPS_PROXY=http://${CORRAL_registry_private_ip}:3219
NO_PROXY=127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.169.254,.svc,.cluster.local,cattle-system.svc
CONTAINERD_HTTP_PROXY=http://${CORRAL_registry_private_ip}:3219
CONTAINERD_HTTPS_PROXY=http://${CORRAL_registry_private_ip}:3219
CONTAINERD_NO_PROXY=127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.169.254,.svc,.cluster.local,cattle-system.svc
http_proxy=http://${CORRAL_registry_private_ip}:3219
https_proxy=http://${CORRAL_registry_private_ip}:3219"
cat > /etc/default/rke2-server <<- EOF
${rke2env}
EOF

#proxy settings for rke2 agent
touch /etc/default/rke2-agent
cat > /etc/default/rke2-agent <<- EOF
${rke2env}
EOF

#proxy settings for curl
touch /home/ubuntu/.curlrc
curlenv="proxy=${CORRAL_registry_private_ip}:3219"
cat > /home/ubuntu/.curlrc <<- EOF
${curlenv}
EOF

#proxy settings for curl as root user
touch /root/.curlrc
cat > /root/.curlrc <<- EOF
${curlenv}
EOF

#proxy settings for wget
touch /home/ubuntu/.wgetrc
wgetenv="
use_proxy=yes
http_proxy=${CORRAL_registry_private_ip}:3219
https_proxy=${CORRAL_registry_private_ip}:3219"
cat > /home/ubuntu/.wgetrc <<- EOF
${wgetenv}
EOF

#proxy settings for wget as root user
touch /root/.wgetrc
cat > /root/.wgetrc <<- EOF
${wgetenv}
EOF

#proxy settings for apt-get
touch /etc/apt/apt.conf
aptenv="Acquire::http::Proxy \"http://${CORRAL_registry_private_ip}:3219\";"
cat > /etc/apt/apt.conf <<- EOF
${aptenv}
EOF

fi

