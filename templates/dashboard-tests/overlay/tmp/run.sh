#!/bin/bash
shopt -s extglob
set -x

function corral_set() {
    echo "corral_set $1=$2"
}

function corral_log() {
    echo "corral_log $1"
}

WHOAMI=$(whoami)

NODEJS_VERSION="${NODEJS_VERSION:-$CORRAL_nodejs_version}"
NODEJS_DOWNLOAD_URL="https://nodejs.org/dist"
NODEJS_FILE="node-v${NODEJS_VERSION}-linux-x64.tar.xz"
YARN_VERSION="${YARN_VERSION:-$CORRAL_yarn_version}"
CYPRESS_VERSION="${CYPRESS_VERSION:-$CORRAL_cypress_version}"
CHROME_VERSION="${CHROME_VERSION:-$CORRAL_chrome_version}"
KUBECTL_VERSION="${KUBECTL_VERSION:-$CORRAL_kubectl_version}"
NODE_PATH="${PWD}/nodejs"
CYPRESS_CONTAINER_NAME="${CYPRESS_CONTAINER_NAME:-cye2e}"
RANCHER_CONTAINER_NAME="${RANCHER_CONTAINER_NAME:-rancher}"
GITHUB_URL="https://github.com/"

#viewPort macbook-16
VIEWPORT_WIDTH="1000"
VIEWPORT_HEIGHT="660"

exit_code=0

build_image () {
    dashboard_branch=$1
    git clone -b "${dashboard_branch}" \
      "${GITHUB_URL}${CORRAL_dashboard_repo}" ${HOME}/dashboard
    echo $CORRAL_imported_kubeconfig | base64 -d > ${HOME}/dashboard/imported_config
    cat ${HOME}/dashboard/imported_config

    if [[ "${dashboard_branch}" != "master" ]]; then
      rm -rf ${HOME}/dashboard/cypress/jenkins
      curl https://codeload.github.com/rancher/dashboard/tar.gz/master |  tar -xz --strip=2 dashboard-master/cypress/jenkins
      mv ${HOME}/jenkins ${HOME}/dashboard/cypress/
    fi

    if [ -f "${NODEJS_FILE}" ]; then rm -r "${NODEJS_FILE}"; fi
    curl -L --silent -o "${NODEJS_FILE}" \
      "${NODEJS_DOWNLOAD_URL}/v${NODEJS_VERSION}/${NODEJS_FILE}"

    NODE_PATH="${HOME}/nodejs"
    mkdir -p ${NODE_PATH}
    tar -xJf "${NODEJS_FILE}" -C ${NODE_PATH}
    export PATH="${NODE_PATH}/node-v${NODEJS_VERSION}-linux-x64/bin:${PATH}"

    cd ${HOME}/dashboard
    echo "${PWD}"
    node -v
    npm version
    npm install -g yarn junit-report-merger mocha mochawesome mochawesome-merge mochawesome-report-generator
    cd ${HOME}

    echo "junit-report-merger version: "
    jrm --version
    echo "mochawesome-merge version: "
    marge --version

    DOCKERFILE_PATH="dashboard/cypress/jenkins"

    ENTRYPOINT_FILE_PATH="dashboard/cypress/jenkins"
    sed -i "s/CYPRESSTAGS/${CORRAL_cypress_tags}/g" ${ENTRYPOINT_FILE_PATH}/cypress.sh

    docker build -f "${DOCKERFILE_PATH}/Dockerfile.ci" \
      --build-arg YARN_VERSION="${YARN_VERSION}" \
      --build-arg NODE_VERSION="${NODEJS_VERSION}" \
      --build-arg CYPRESS_VERSION="${CYPRESS_VERSION}" \
      --build-arg CHROME_VERSION="${CHROME_VERSION}" \
      --build-arg KUBECTL_VERSION="${KUBECTL_VERSION}" \
      -t dashboard-test .

    cd ${HOME}/dashboard
    sudo chown -R $(whoami) .
    echo "${PWD}"

}

rancher_init () {
  RANCHER_HOST=$1
  SERVER_URL="https://$2"
  new_password="$3"

  # Get the admin token using the initial bootstrap password
  rancher_token=`curl -s -k -X POST "https://${RANCHER_HOST}/v3-public/localProviders/local?action=login" \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password": "password"}' | grep -o '"token":"[^"]*' | grep -o '[^"]*$'`
  echo "TOKEN: ${rancher_token}"

  # Get the correct URL to set newPassword
  PASSWORD_URL=`curl -s -k -X GET "https://${RANCHER_HOST}/v3/users?username=admin" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${rancher_token}" |  grep -o '"setpassword":"[^"]*' | grep -o '[^"]*$'`
  echo "PASSWORD_URL: ${PASSWORD_URL}"

  # Set the new password
  PASSWORD_PAYLOAD="{\"newPassword\": \"${new_password}\"}"
  curl -s -k -X POST "${PASSWORD_URL}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${rancher_token}" \
    -d "${PASSWORD_PAYLOAD}"

  # After the above. Rancher will show the login page 
  # but the server-url setting will be empty.
  # This will configure the server-url
  curl -s -k -X PUT "https://${RANCHER_HOST}/v3/settings/server-url" \
    -H "Authorization: Bearer ${rancher_token}" \
    -H 'Content-Type: application/json' \
    --data-binary "{\"name\": \"server-url\", \"value\":\"${SERVER_URL}\"}"
  
  # Add standard user
  user_id=$(curl -s -k -X POST "https://${RANCHER_HOST}/v3/users" \
    -H "Authorization: Bearer ${rancher_token}" \
    -H 'Content-Type: application/json' \
    -d "{\"enabled\": true, \"mustChangePassword\": false, \"password\": \"${CORRAL_rancher_password}\", \"username\": \"standard_user\"}" | grep -o '"id":"[^"]*' | grep -o '[^"]*$')

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

  # Retrieving the dashboard branch used by the Rancher server
  branch_from_rancher=`curl -s -k -X GET "https://${RANCHER_HOST}/dashboard/about" \
    -H "Accept: text/html,application/xhtml+xml,application/xml" \
    -H "Authorization: Bearer ${rancher_token}" | grep "release-" | sed -E 's/^\s*.*:\/\///g' | cut -d'/' -f 3 | tail -n 1`
  
  if [[ -z "${branch_from_rancher}" ]]; then
    is_it_latest=`curl -s -k -X GET "https://${RANCHER_HOST}/dashboard/about" \
    -H "Accept: text/html,application/xhtml+xml,application/xml" \
    -H "Authorization: Bearer ${rancher_token}" | grep -q "dashboard/latest/"`
    if [[ ${is_it_latest} -eq 1 ]]; then
      echo "Error: The dashboard branch returned empty"
      exit 1
    else
      branch_from_rancher="master"
    fi
  fi
}

if [ ${CORRAL_rancher_type} = "existing" ]; then

    build_image ${CORRAL_dashboard_branch}

    TEST_BASE_URL="https://${CORRAL_rancher_host}/dashboard"

    echo "Custom key: $CORRAL_custom_node_key"

    docker run --name "${CORRAL_rancher_host}" -t \
      -e CYPRESS_VIDEO=false \
      -e CYPRESS_VIEWPORT_WIDTH="${VIEWPORT_WIDTH}" \
      -e CYPRESS_VIEWPORT_HEIGHT="${VIEWPORT_HEIGHT}" \
      -e TEST_BASE_URL=${TEST_BASE_URL} \
      -e TEST_USERNAME=${CORRAL_rancher_username} \
      -e TEST_PASSWORD="${CORRAL_rancher_password}" \
      -e TEST_SKIP_SETUP=true \
      -e TEST_SKIP=setup \
      -e AWS_ACCESS_KEY_ID=${CORRAL_aws_access_key} \
      -e AWS_SECRET_ACCESS_KEY=${CORRAL_aws_secret_key} \
      -e AZURE_CLIENT_ID=${CORRAL_azure_client_id} \
      -e AZURE_CLIENT_SECRET=${CORRAL_azure_client_secret} \
      -e AZURE_AKS_SUBSCRIPTION_ID=${CORRAL_azure_subscription_id} \
      -e CUSTOM_NODE_IP="${CORRAL_custom_node_ip}" \
      -e CUSTOM_NODE_KEY="${CORRAL_custom_node_key}" \
      -v "${HOME}":/e2e \
      -w /e2e dashboard-test

    exit_code=$?
elif  [ ${CORRAL_rancher_type} = "recurring" ]; then
    TEST_USERNAME="admin"
    rancher_init ${CORRAL_rancher_host} ${CORRAL_rancher_host} ${CORRAL_rancher_password}
    build_image ${branch_from_rancher}
    TEST_BASE_URL="https://${CORRAL_rancher_host}/dashboard"

    rancher_username="${CORRAL_rancher_username}"

    case "${CORRAL_cypress_tags}" in
        *"@standardUser"* )
            rancher_username="standard_user"
            ;;
    esac

    docker run --name "${CORRAL_rancher_host}" -t \
      -e CYPRESS_VIDEO=false \
      -e CYPRESS_VIEWPORT_WIDTH="${VIEWPORT_WIDTH}" \
      -e CYPRESS_VIEWPORT_HEIGHT="${VIEWPORT_HEIGHT}" \
      -e TEST_BASE_URL="${TEST_BASE_URL}" \
      -e TEST_USERNAME="${rancher_username}" \
      -e TEST_PASSWORD="${CORRAL_rancher_password}" \
      -e TEST_SKIP_SETUP=true \
      -e TEST_SKIP=setup \
      -e AWS_ACCESS_KEY_ID=${CORRAL_aws_access_key} \
      -e AWS_SECRET_ACCESS_KEY=${CORRAL_aws_secret_key} \
      -e AZURE_CLIENT_ID=${CORRAL_azure_client_id} \
      -e AZURE_CLIENT_SECRET=${CORRAL_azure_client_secret} \
      -e AZURE_AKS_SUBSCRIPTION_ID=${CORRAL_azure_subscription_id} \
      -e CUSTOM_NODE_IP="${CORRAL_custom_node_ip}" \
      -e CUSTOM_NODE_KEY="${CORRAL_custom_node_key}" \
      -v "${HOME}":/e2e \
      -w /e2e dashboard-test

    exit_code=$?
elif [ ${CORRAL_rancher_type} = "local" ]; then
    build_image ${CORRAL_dashboard_branch}

    export PATH="${NODE_PATH}/node-v${NODEJS_VERSION}-linux-x64/bin:${PATH}"
    ./scripts/build-e2e

    DIR="${HOME}/dashboard"

    DASHBOARD_DIST=${DIR}/dist
    EMBER_DIST=${DIR}/dist_ember
    echo "${DASHBOARD_DIST}"
    echo "${EMBER_DIST}"

    docker run  --privileged -d -p 80:80 -p 443:443 \
      -v ${DASHBOARD_DIST}:/usr/share/rancher/ui-dashboard/dashboard \
      -v ${EMBER_DIST}:/usr/share/rancher/ui \
      -e CATTLE_BOOTSTRAP_PASSWORD=password \
      -e CATTLE_UI_OFFLINE_PREFERRED=true \
      -e CATTLE_PASSWORD_MIN_LENGTH=3 \
      --name="${RANCHER_CONTAINER_NAME}" --restart=unless-stopped "rancher/rancher:${CORRAL_rancher_version}"

    RANCHER_CONTAINER_IP_FROM_HOST=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' rancher)
    RANCHER_CONTAINER_URL="https://${RANCHER_CONTAINER_IP_FROM_HOST}/dashboard/"

    echo "Waiting for dashboard UI to be reachable (initial 20s wait) ..."
    sleep 20
    echo "Waiting for dashboard UI to be reachable ..."

    okay=0

    while [ $okay -lt 60 ]; do
      STATUS=$(curl --silent --head -k "${RANCHER_CONTAINER_URL}" | awk '/^HTTP/{print $2}')
      echo "Status: $STATUS (Try: $okay)"
      okay=$((okay+1))
    if [ "$STATUS" == "200" ]; then
        okay=100
    else
        sleep 5
    fi
    done

    if [ "$STATUS" != "200" ]; then
    echo "Dashboard did not become available in a reasonable time"
    exit 1
    fi

    echo "Dashboard UI is ready"
    echo "Run Cypress"

    INSTANCE_IP="${CORRAL_first_node_ip}"
    RANCHER_CONTAINER_IP="127.0.0.1"
    TEST_BASE_URL="https://${RANCHER_CONTAINER_IP}/dashboard"
    TEST_USERNAME=admin
    TEST_PASSWORD=password

    rancher_init ${RANCHER_CONTAINER_IP} ${INSTANCE_IP} ${TEST_PASSWORD}

    docker run --network container:rancher --name "${CYPRESS_CONTAINER_NAME}" -t \
      -e CYPRESS_VIDEO=false \
      -e CYPRESS_VIEWPORT_WIDTH="${VIEWPORT_WIDTH}" \
      -e CYPRESS_VIEWPORT_HEIGHT="${VIEWPORT_HEIGHT}" \
      -e TEST_BASE_URL=${TEST_BASE_URL} \
      -e TEST_USERNAME=${TEST_USERNAME} \
      -e TEST_PASSWORD=${TEST_PASSWORD} \
      -e TEST_SKIP_SETUP=true \
      -e TEST_SKIP=setup \
      -e CATTLE_BOOTSTRAP_PASSWORD=${TEST_PASSWORD} \
      -v "${HOME}":/e2e \
      -w /e2e dashboard-test
    
    exit_code=$?
    echo "EXIT CODE AFTER DOCKER RUN: ${exit_code}"
else
  echo "Unknown RANCHER_TYPE install. Exiting with error."
  exit 1
fi

DASHBOARD_PATH="${HOME}/dashboard"
sudo chown -R "$(whoami)" .
echo "${PWD}"
find "${HOME}" -type f -iname "*.xml" -not -path "*node_modules*" -not -path "*golang*"
find "${HOME}" -type f -iname "*mochawesome*" -not -path "*node_modules*"

jrm "${DASHBOARD_PATH}/results.xml" "${DASHBOARD_PATH}/cypress/jenkins/reports/junit/junit-*" || { echo 'junit reporting failed' ; exit 1; }

mochawesome-merge "${DASHBOARD_PATH}/cypress/jenkins/reports/mochawesome/*.json" \
  -o "${DASHBOARD_PATH}/results.json"
marge -o "${DASHBOARD_PATH}" "${DASHBOARD_PATH}/results.json" || { echo 'html reporting failed' ; exit 1; }

if [ -s "${DASHBOARD_PATH}/results.xml" ]; then
    corral_set cypress_completed "completed"
fi
exit ${exit_code}