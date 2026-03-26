#!/bin/bash

shopt -s extglob
set -e

/tmp/configure.sh

function corral_set() {
    echo "corral_set $1=$2"
}

function corral_log() {
    echo "corral_log $1"
}

NODEJS_VERSION="${NODEJS_VERSION:-${CORRAL_nodejs_version:-24.14.0}}"
NODEJS_DOWNLOAD_URL="https://nodejs.org/dist"
NODEJS_FILE="node-v${NODEJS_VERSION}-linux-x64.tar.xz"
YARN_VERSION="${YARN_VERSION:-${CORRAL_yarn_version:-1.22.22}}"
CYPRESS_VERSION="${CYPRESS_VERSION:-${CORRAL_cypress_version:-11.1.0}}"
CHROME_VERSION="${CHROME_VERSION:-${CORRAL_chrome_version:-}}"
KUBECTL_VERSION="${KUBECTL_VERSION:-${CORRAL_kubectl_version:-v1.29.8}}"
NODE_PATH="${PWD}/nodejs"
CYPRESS_CONTAINER_NAME="${CYPRESS_CONTAINER_NAME:-cye2e}"
RANCHER_CONTAINER_NAME="${RANCHER_CONTAINER_NAME:-rancher}"
GITHUB_URL="https://github.com/"
CORRAL_dashboard_repo="${CORRAL_dashboard_repo:-rancher/dashboard}"

exit_code=0

build_image () {
    dashboard_branch=$1
    target_branch=$1

    # Get target branch based on the rancher image tag
    if [[ "${CORRAL_rancher_image_tag:-}" == "head" ]]; then
        target_branch="master"
    elif [[ "${CORRAL_rancher_image_tag:-}" =~ ^v([0-9]+\.[0-9]+)-head$ ]]; then
        # Extract version number from the rancher image tag (e.g., v2.12-head -> 2.12)
        version_number="${BASH_REMATCH[1]}"
        target_branch="release-${version_number}"
    fi
    
    rm -rf "${HOME}"/dashboard
    git clone -b "${target_branch}" \
      "${GITHUB_URL}${CORRAL_dashboard_repo}" "${HOME}"/dashboard

    cd "${HOME}"/dashboard
    if [ "${target_branch}" != "master" ]; then
        echo "Overlaying cypress/jenkins and dependencies from master onto ${target_branch}"
        git fetch origin master
        git checkout origin/master -- cypress/jenkins package.json yarn.lock cypress.config.ts || true
    fi
    cd "${HOME}"

    shopt -s nocasematch
    if [[ -z "${CORRAL_imported_kubeconfig:-}" ]]; then
      echo "No imported kubeconfig provided"
      cd "${HOME}"
      ENTRYPOINT_FILE_PATH="dashboard/cypress/jenkins"
      sed -i.bak "/kubectl/d" "${ENTRYPOINT_FILE_PATH}/cypress.sh"
      sed -i.bak "/imported_config/d" "${ENTRYPOINT_FILE_PATH}/Dockerfile.ci"
    else 
      echo "Imported kubeconfig found, preparing file"
      echo "${CORRAL_imported_kubeconfig}" | base64 -d > "${HOME}"/dashboard/imported_config
    fi
    shopt -u nocasematch

    if [ -f "${NODEJS_FILE}" ]; then rm -r "${NODEJS_FILE}"; fi
    curl -L --silent -o "${NODEJS_FILE}" \
      "${NODEJS_DOWNLOAD_URL}/v${NODEJS_VERSION}/${NODEJS_FILE}"

    NODE_PATH="${HOME}/nodejs"
    mkdir -p "${NODE_PATH}"
    tar -xJf "${NODEJS_FILE}" -C "${NODE_PATH}"
    export PATH="${NODE_PATH}/node-v${NODEJS_VERSION}-linux-x64/bin:${PATH}"

    cd "${HOME}"/dashboard

    npm install -g yarn@"${YARN_VERSION}"
    yarn config set ignore-engines true --silent
    
    yarn install --frozen-lockfile

    # Debugging node_modules
    if [ -d "node_modules/cypress-multi-reporters" ]; then
      echo "Reporter found in dashboard/node_modules"
    else
      echo "ERROR: Reporter NOT found in dashboard/node_modules"
      for module_path in node_modules/*cypress*; do
        [ -e "${module_path}" ] || continue
        basename "${module_path}"
      done
    fi

    cd "${HOME}"

    DOCKERFILE_PATH="dashboard/cypress/jenkins"
    ENTRYPOINT_FILE_PATH="dashboard/cypress/jenkins"
    sed -i "s/CYPRESSTAGS/${CORRAL_cypress_tags:-}/g" ${ENTRYPOINT_FILE_PATH}/cypress.sh

    docker build --quiet -f "${DOCKERFILE_PATH}/Dockerfile.ci" \
      --build-arg YARN_VERSION="${YARN_VERSION}" \
      --build-arg NODE_VERSION="${NODEJS_VERSION}" \
      --build-arg CYPRESS_VERSION="${CYPRESS_VERSION}" \
      --build-arg CHROME_VERSION="${CHROME_VERSION}" \
      --build-arg KUBECTL_VERSION="${KUBECTL_VERSION}" \
      -t dashboard-test .

    cd "${HOME}"/dashboard
    sudo chown -R "$(whoami)" .
}

rancher_init () {
  RANCHER_HOST=$1
  SERVER_URL="https://$2"
  new_password="$3"

  rancher_token=$(curl -s -k -X POST "https://${RANCHER_HOST}/v3-public/localProviders/local?action=login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"admin\",\"password\": \"password\"}" | grep -o '"token":"[^"]*' | grep -o '[^"]*$')

  PASSWORD_URL=$(curl -s -k -X GET "https://${RANCHER_HOST}/v3/users?username=admin" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${rancher_token}" |  grep -o '"setpassword":"[^"]*' | grep -o '[^"]*$')

  PASSWORD_PAYLOAD="{\"newPassword\": \"${new_password}\"}"
  curl -s -k -X POST "${PASSWORD_URL}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${rancher_token}" \
    -d "${PASSWORD_PAYLOAD}"

  curl -s -k -X PUT "https://${RANCHER_HOST}/v3/settings/server-url" \
    -H "Authorization: Bearer ${rancher_token}" \
    -H 'Content-Type: application/json' \
    --data-binary "{\"name\": \"server-url\", \"value\":\"${SERVER_URL}\"}"
  
  user_id=$(curl -s -k -X POST "https://${RANCHER_HOST}/v3/users" \
    -H "Authorization: Bearer ${rancher_token}" \
    -H 'Content-Type: application/json' \
    -d "{\"enabled\": true, \"mustChangePassword\": false, \"password\": \"${CORRAL_rancher_password:-password}\", \"username\": \"standard_user\"}" | grep -o '"id":"[^"]*' | grep -o '[^"]*$')

  curl -s -k -X POST "https://${RANCHER_HOST}/v3/globalrolebindings" \
    -H "Authorization: Bearer ${rancher_token}" \
    -H 'Content-Type: application/json' \
    -d "{\"globalRoleId\": \"user\", \"type\": \"globalRoleBinding\", \"userId\": \"${user_id}\"}"

  project_id=$(curl -s -k "https://${RANCHER_HOST}/v3/projects?name=Default&clusterId=local" \
    -H "Authorization: Bearer ${rancher_token}" \
    -H 'Content-Type: application/json' | grep -o '"id":"[^"]*' | grep -o '[^"]*$')

  curl -s -k -X POST "https://${RANCHER_HOST}/v3/projectroletemplatebindings" \
    -H "Authorization: Bearer ${rancher_token}" \
    -H 'Content-Type: application/json' \
    -d "{\"type\": \"projectroletemplatebinding\", \"roleTemplateId\": \"project-member\", \"projectId\": \"${project_id}\", \"userId\": \"${user_id}\"}"  

  branch_from_rancher=$(curl -s -k -X GET "https://${RANCHER_HOST}/v1/management.cattle.io.settings" \
    -H "Accept: application/json" \
    -H "Authorization: Bearer ${rancher_token}" | grep -o '"default":"[^"]*' | grep -o '[^"]*$' | grep release- | sed -E 's/^\s*.*:\/\///g' | cut -d'/' -f 3 | tail -n 1)

  if [[ -z "${branch_from_rancher}" ]]; then
    is_it_latest=$(curl -s -k -X GET "https://${RANCHER_HOST}/dashboard/about" \
    -H "Accept: text/html,application/xhtml+xml,application/xml" \
    -H "Authorization: Bearer ${rancher_token}" | grep -q "dashboard/latest/") || is_it_latest=1
    if [[ ${is_it_latest} -eq 1 ]]; then
      exit 1
    else
      branch_from_rancher="master"
    fi
  fi
}

if [ "${CORRAL_rancher_type:-existing}" = "existing" ]; then
    build_image "${CORRAL_dashboard_branch:-master}"
    docker run --name "${CORRAL_rancher_host:-}" --env-file "${HOME}/.env" -e NODE_PATH= -t \
      -v "${HOME}":/e2e \
      -w /e2e dashboard-test || exit_code=$?
elif  [ "${CORRAL_rancher_type:-existing}" = "recurring" ]; then
    rancher_init "${CORRAL_rancher_host:-}" "${CORRAL_rancher_host:-}" "${CORRAL_rancher_password:-password}"
    build_image "${branch_from_rancher}"
    case "${CORRAL_cypress_tags:-}" in
        *"@standardUser"* )
            sed -i.bak '/TEST_USERNAME/d' "${HOME}/.env"
            echo TEST_USERNAME="standard_user" >> .env
            ;;
    esac
    docker run --name "${CORRAL_rancher_host:-}" --env-file "${HOME}/.env" -e NODE_PATH= -t \
      -v "${HOME}":/e2e \
      -w /e2e dashboard-test || exit_code=$?
fi

cd "${HOME}/dashboard" || exit 1
./node_modules/.bin/jrm "${HOME}/dashboard/results.xml" "cypress/jenkins/reports/junit/junit-*" || true

if [ -s "${HOME}/dashboard/results.xml" ]; then
    corral_set cypress_exit_code "${exit_code}"
    corral_set cypress_completed "completed"
fi
exit ${exit_code}
