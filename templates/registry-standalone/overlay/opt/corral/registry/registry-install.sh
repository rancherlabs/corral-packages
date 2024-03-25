#!/bin/bash
set -ex

if [ -z $CORRAL_download_url ]; then
	DOWNLOAD_URL="https://github.com/rancher/rancher/releases/download/"
else
	DOWNLOAD_URL="$CORRAL_download_url"
fi

function corral_set() {
	echo "corral_set $1=$2"
}

function corral_log() {
	echo "corral_log $1"
}
if [ "ecr" = "$CORRAL_registry_auth" ]; then
	corral_log "ECR registry"

	wget -O "7zip.tar.xz" https://www.7-zip.org/a/7z2201-linux-x64.tar.xz
	tar xvf 7zip.tar.xz
	ls -al
	wget -O "awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
	./7zz x "awscliv2.zip" -y
	./aws/install

	export AWS_ACCESS_KEY_ID="$CORRAL_aws_access_key"
	export AWS_SECRET_ACCESS_KEY="$CORRAL_aws_secret_key"
	export AWS_DEFAULT_REGION="$CORRAL_registry_ecr_default_region"
	export USERNAME="AWS"
	export ECR="$CORRAL_registry_ecr_fqdn"
	export RANCHER_VERSION="v$CORRAL_rancher_version"

	# Downloading rancher-images.txt, rancher-save-images.sh and rancher-load-images.sh
	wget -O rancher-images.txt "${DOWNLOAD_URL}v${CORRAL_rancher_version}"/rancher-images.txt
	wget -O rancher-save-images.sh "${DOWNLOAD_URL}v${CORRAL_rancher_version}"/rancher-save-images.sh
	wget -O rancher-load-images.sh "${DOWNLOAD_URL}v${CORRAL_rancher_version}"/rancher-load-images.sh
	sed -i 's/docker save/# docker save /g' rancher-save-images.sh
	sed -i 's/docker load/# docker load /g' rancher-load-images.sh
	chmod +x rancher-save-images.sh
	chmod +x rancher-load-images.sh

	# Login to ECR
	ECR_PASSWORD="$(aws ecr get-login-password --region ${AWS_DEFAULT_REGION})"
	corral_set registry_password "${ECR_PASSWORD}"
	docker login -u "${USERNAME}" -p "${ECR_PASSWORD}" "${ECR}"

	# Cutting tags from image names
	while read LINE; do
		echo ${LINE} | cut -d: -f1
	done <rancher-images.txt >test-no-tags.txt

	# Keep unique image names and sort
	sort -u test-no-tags.txt >test-clean.txt

	if [ $CORRAL_registry_ecr_clear_repo ]; then

		# Delete all image repos from ECR
		# This ensure the repo would have images for the Rancher version under test.
		for i in $(cat test-clean.txt); do
			echo $i
			aws ecr delete-repository --repository-name "$i" --force || true
		done

		# Create ECR repos
		for IMAGE in $(cat test-clean.txt); do
			aws ecr create-repository --repository-name ${IMAGE}
		done

	fi

	corral_log "Saving images to host. Estimated time 1hr"
	./rancher-save-images.sh --image-list ./rancher-images.txt

	corral_log "Loading images to ECR. Estimated time 1hr"
	bash rancher-load-images.sh --image-list rancher-images.txt --registry "${ECR}"

	corral_log "ECR push images completed"
else
	corral_log "Docker registry"
	corral_log "Build started for registry $CORRAL_registry_fqdn"
	echo "$CORRAL_corral_user_public_key" >>"$HOME"/.ssh/authorized_keys
	echo "$CORRAL_registry_cert" | base64 -d >/opt/basic-registry/nginx_config/domain.crt
	echo "$CORRAL_registry_key" | base64 -d >/opt/basic-registry/nginx_config/domain.key

	corral_log "Downloading Dependencies"

	curl -SL https://github.com/docker/compose/releases/download/v$CORRAL_docker_compose_version/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
	ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
	chmod +x /usr/local/bin/docker-compose

	if [ "enabled" = "$CORRAL_registry_auth" ]; then
		corral_log "Building registry with auth"

		USERNAME="corral"
		PASSWORD="$(echo $RANDOM | md5sum | head -c 12)"

		corral_set registry_username "$USERNAME"
		corral_set registry_password "$PASSWORD"

		# This is used to avoid the dependency on apache-utils htpasswd
		SALT=$(openssl rand -base64 3)
		SHA1=$(echo -n "${PASSWORD}${SALT}" | openssl dgst -binary -sha1 | xxd -p | sed "s/$/$(echo -n ${SALT} | xxd -p)/" | xxd -r -p | base64)
		echo "$USERNAME:{SSHA}$SHA1" >/opt/basic-registry/nginx_config/registry.password
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
	helm template ./cert-manager-"v${CORRAL_cert_manager_version}".tgz | awk '$1 ~ /image:/ {print $2}' | sed s/\"//g >>./rancher-images.txt
	sort -u rancher-images.txt -o rancher-images.txt

	if [ "enabled" = "$CORRAL_windows_registry" ]; then
		corral_log "Adding Windows images to registry"
		wget -O rancher-windows-images.txt "${DOWNLOAD_URL}v${CORRAL_rancher_version}"/rancher-windows-images.txt

		source /etc/os-release

		if [[ $NAME == *"SUSE"* || $NAME == *"SLES"* ]]; then
			sudo zypper addrepo --refresh https://download.opensuse.org/repositories/system:/snappy/openSUSE_Leap_$VERSION_ID snappy
			sudo zypper --gpg-auto-import-keys refresh
			sudo zypper dup --from snappy
			sudo zypper install snapd
			source /etc/profile
			sudo systemctl enable --now snapd
			sudo systemctl enable --now snapd.apparmor
			sudo snap install snap-store

		elif [[ $NAME == *"Red Hat"* ]]; then
			if [[ $VERSION_ID == *"7."* ]]; then
				sudo rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
			else
				sudo dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-${VERSION_ID:0:1}.noarch.rpm
				sudo dnf -y upgrade
			fi
			sudo subscription-manager repos --enable "rhel-*-optional-rpms" --enable "rhel-*-extras-rpms"
			sudo yum -y update
			sudo yum -y install snapd
			sudo systemctl enable --now snapd.socket
			sudo ln -s /var/lib/snapd/snap /snap


			sleep 10
			source ~/.bashrc
			sudo snap install snapd

		else
			# assuming using an OS with snap already installed. i.e. Ubuntu
			sudo snap refresh
		fi

		sudo snap install go --classic
		go install github.com/google/go-containerregistry/cmd/crane@latest
		export PATH=$PATH:$(pwd)/go/bin/
		export registry=$CORRAL_registry_fqdn
		while IFS= read -r img; do set +e; $(pwd)/go/bin/crane copy $img $registry/$img --insecure --allow-nondistributable-artifacts; done < rancher-images.txt
		while IFS= read -r img; do set +e; $(pwd)/go/bin/crane copy $img-windows-amd64 $registry/$img-windows-amd64 --insecure --allow-nondistributable-artifacts; done < rancher-images.txt
		while IFS= read -r img; do set +e; $(pwd)/go/bin/crane copy $img $registry/$img --insecure --allow-nondistributable-artifacts; done < rancher-windows-images.txt
		set -e;
	else
		corral_log "Not adding windows images to this registry"
		if [ "enabled" = "$CORRAL_registry_auth" ]; then
			corral_log "Login to the Docker registry to load images"

			docker login -u "$USERNAME" -p "$PASSWORD" "$CORRAL_registry_fqdn"
		else
			corral_log "No login needed to load images to theregistry"
		fi
		corral_log "Saving images to host. Estimated time 1hr"
		bash rancher-save-images.sh --image-list rancher-images.txt

		corral_log "Loading images to the registry. Estimated time 1hr"
		bash rancher-load-images.sh --image-list rancher-images.txt --registry "$CORRAL_registry_fqdn"
	fi

	if [ -z $CORRAL_suse_registry ]; then
		echo "No suse registry defined; expecting rancher/rancher image to exist in registry"
	else
		docker pull "${CORRAL_suse_registry}/rancher/rancher:v${CORRAL_rancher_version}"
		docker tag "${CORRAL_suse_registry}/rancher/rancher:v${CORRAL_rancher_version}" "${CORRAL_registry_fqdn}/rancher/rancher:v${CORRAL_rancher_version}"
		docker push "${CORRAL_registry_fqdn}/rancher/rancher:v${CORRAL_rancher_version}"
		docker pull "${CORRAL_suse_registry}/rancher/rancher-agent:v${CORRAL_rancher_version}"
		docker tag "${CORRAL_suse_registry}/rancher/rancher-agent:v${CORRAL_rancher_version}" "${CORRAL_registry_fqdn}/rancher/rancher-agent:v${CORRAL_rancher_version}"
		docker push "${CORRAL_registry_fqdn}/rancher/rancher-agent:v${CORRAL_rancher_version}"
	fi
fi

corral_log "Registry Host: $CORRAL_registry_fqdn"
