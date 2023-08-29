#!/bin/bash
set -ex

DOWNLOAD_URL="https://github.com/rancher/rancher/releases/download/"

function corral_set() {
    echo "corral_set $1=$2"
}

function corral_log() {
    echo "corral_log $1"
}

corral_log "Build started for registry $CORRAL_registry_fqdn"
echo "$CORRAL_corral_user_public_key" >> "$HOME"/.ssh/authorized_keys
echo "$CORRAL_registry_cert" | base64 -d > /opt/basic-registry/nginx_config/domain.crt
echo "$CORRAL_registry_key" | base64 -d > /opt/basic-registry/nginx_config/domain.key

corral_log "Downloading Dependencies"

curl -SL https://github.com/docker/compose/releases/download/v$CORRAL_docker_compose_version/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

if [ "enabled" = "$CORRAL_registry_auth" ]; then
    corral_log "Building registry with auth"
    
    USERNAME="corral"
    PASSWORD="$( echo $RANDOM | md5sum | head -c 12)"

    corral_set registry_username "$USERNAME"
    corral_set registry_password "$PASSWORD"

    # This is used to avoid the dependency on apache-utils htpasswd
    SALT=$(openssl rand -base64 3)
    SHA1=$(echo -n "${PASSWORD}${SALT}" | openssl dgst -binary -sha1 | xxd -p | sed "s/$/$(echo -n ${SALT} | xxd -p)/" | xxd -r -p | base64)
    echo "$USERNAME:{SSHA}$SHA1" > /opt/basic-registry/nginx_config/registry.password
else
    corral_log "Building no auth registry"

    sed -i -e 's/auth_basic/#auth_basic/g' /opt/basic-registry/nginx_config/nginx.conf
    sed -i -e 's/add_header/#add_header/g' /opt/basic-registry/nginx_config/nginx.conf
fi

corral_log "Enabling docker registry systemd service"

systemctl enable docker-registry.service
systemctl start docker-registry.service

corral_log "Downloading Rancher registry scripts from release"

wget -O rancher-images.txt "${DOWNLOAD_URL}v${CORRAL_rancher_version}"/rancher-images.txt
wget -O rancher-save-images.sh "${DOWNLOAD_URL}v${CORRAL_rancher_version}"/rancher-save-images.sh
wget -O rancher-load-images.sh "${DOWNLOAD_URL}v${CORRAL_rancher_version}"/rancher-load-images.sh
sed -i 's/docker save/# docker save /g' rancher-save-images.sh
sed -i 's/docker load/# docker load /g' rancher-load-images.sh
chmod +x rancher-save-images.sh 
chmod +x rancher-load-images.sh

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

helm repo add jetstack https://charts.jetstack.io
helm repo update
helm fetch jetstack/cert-manager --version "v${CORRAL_cert_manager_version}"
helm template ./cert-manager-"v${CORRAL_cert_manager_version}".tgz | awk '$1 ~ /image:/ {print $2}' | sed s/\"//g >> ./rancher-images.txt
sort -u rancher-images.txt -o rancher-images.txt

corral_log "Saving images to host. Estimated time 1hr"
if [ "enabled" = "$CORRAL_windows_registry" ]; then
    corral_log "Adding Windows images to registry"
    wget -O rancher-windows-images.txt "${DOWNLOAD_URL}v${CORRAL_rancher_version}"/rancher-windows-images.txt
    sudo snap install go --classic
    go install github.com/google/go-containerregistry/cmd/crane@latest
    export PATH=$PATH:$(pwd)/go/bin/
    export registry=$CORRAL_registry_fqdn
    while IFS= read -r img; do set +e; $(pwd)/go/bin/crane copy $img $registry/$img --insecure --allow-nondistributable-artifacts; done < rancher-images.txt
    while IFS= read -r img; do set +e; $(pwd)/go/bin/crane copy $img $registry/$img --insecure --allow-nondistributable-artifacts; done < rancher-windows-images.txt
    set -e;
else
    corral_log "not adding windows images to this registry"
    bash rancher-save-images.sh --image-list rancher-images.txt

    corral_log "Loading images to registry. Estimated time 1hr"
    bash rancher-load-images.sh --image-list rancher-images.txt --registry "$CORRAL_registry_fqdn"
fi

if [ "enabled" = "$CORRAL_registry_auth" ]; then
    corral_log "Login to the registry to load images"

    docker login -u "$USERNAME" -p "$PASSWORD" "$CORRAL_registry_fqdn"
else
    corral_log "No login needed to load images"
fi

corral_log "Registry Host: $CORRAL_registry_fqdn"