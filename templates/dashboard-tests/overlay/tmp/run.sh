#!/bin/bash
shopt -s extglob
set -x

function corral_set() {
    echo "corral_set $1=$2"
}

function corral_log() {
    echo "corral_log $1"
}

NODEJS_VERSION="${NODEJS_VERSION:-$CORRAL_nodejs_version}"
NODEJS_DOWNLOAD_URL="https://nodejs.org/dist"
NODEJS_FILE="node-${NODEJS_VERSION}-linux-x64.tar.xz"
CYPRESS_DOCKER_TYPE="${CYPRESS_DOCKER_TYPE:-$CORRAL_cypress_docker_type}"
CYPRESS_DOCKER_VERSION="${CYPRESS_DOCKER_VERSION:-$CORRAL_cypress_docker_version}"
CYPRESS_DOCKER_OWNER="cypress-io"
CYPRESS_DOCKER_REPO="cypress-docker-images"
CYPRESS_DOCKER_BRANCH="${CYPRESS_DOCKER_BRANCH:-$CORRAL_cypress_docker_branch}"
GITHUB_CODELOAD_URL="https://codeload.github.com"
GITHUB_CODELOAD_PATH="${GITHUB_CODELOAD_URL}/${CYPRESS_DOCKER_OWNER}/${CYPRESS_DOCKER_REPO}"
NODE_PATH="${PWD}/nodejs"
CYPRESS_CONTAINER_NAME="${CYPRESS_CONTAINER_NAME:-cye2e}"
RANCHER_CONTAINER_NAME="${RANCHER_CONTAINER_NAME:-rancher}"
GITHUB_URL="https://github.com/"

git clone -b "${CORRAL_dashboard_branch}" \
  "${GITHUB_URL}${CORRAL_dashboard_repo}" ${HOME}/dashboard

if [ -f "${NODEJS_FILE}" ]; then rm -r "${NODEJS_FILE}"; fi
curl -L --silent -o "${NODEJS_FILE}" \
  "${NODEJS_DOWNLOAD_URL}/${NODEJS_VERSION}/${NODEJS_FILE}"

NODE_PATH="${HOME}/nodejs"
mkdir -p ${NODE_PATH}
tar -xJf "${NODEJS_FILE}" -C ${NODE_PATH}
export PATH="${NODE_PATH}/node-${NODEJS_VERSION}-linux-x64/bin:${PATH}"
npm_config_loglevel=error

cd ${HOME}/dashboard
echo "${PWD}"
node -v
npm version
npm install -g yarn junit-report-merger mocha mochawesome mochawesome-merge mochawesome-report-generator
cd ${HOME}

if [ -d "${CYPRESS_DOCKER_VERSION}" ]; then rm -r ${CYPRESS_DOCKER_VERSION}; fi

curl --silent "${GITHUB_CODELOAD_PATH}/tar.gz/master" | \
tar -xz --strip=2 \
"${CYPRESS_DOCKER_REPO}-${CYPRESS_DOCKER_BRANCH}/${CYPRESS_DOCKER_TYPE}/${CYPRESS_DOCKER_VERSION}"

DOCKERFILE_PATH="dashboard/cypress/jenkins"
FILES=$(ls "${CYPRESS_DOCKER_VERSION}")
for f in $FILES; do mv -v "${CYPRESS_DOCKER_VERSION}/${f}" "${DOCKERFILE_PATH}" ; done

rm -r "${CYPRESS_DOCKER_VERSION}"
sed -i "/ENTRYPOINT*/d" "${DOCKERFILE_PATH}/Dockerfile"
echo 'ENTRYPOINT ["bash", "dashboard/cypress/jenkins/cypress.sh"]' >>  ${DOCKERFILE_PATH}/Dockerfile
tail -n 1 "${DOCKERFILE_PATH}/Dockerfile"
mv ${DOCKERFILE_PATH}/Dockerfile{,.ci}

ENTRYPOINT_FILE_PATH="dashboard/cypress/jenkins"
sed -i "s/CYPRESSTAGS/${CORRAL_cypress_tags}/g" ${ENTRYPOINT_FILE_PATH}/cypress.sh

docker build -f "${DOCKERFILE_PATH}/Dockerfile.ci" -t "cypress/${CYPRESS_DOCKER_TYPE}:${CYPRESS_DOCKER_VERSION}" .

cd ${HOME}/dashboard
sudo chown -R $(whoami) .
echo "${PWD}"
exit_code=0
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
  curl -s -k -X POST "https://${RANCHER_HOST}/v3/users" \
    -H "Authorization: Bearer ${rancher_token}" \
    -H 'Content-Type: application/json' \
    -d "{\"enabled\": true, \"mustChangePassword\": false, \"password\": \"${CORRAL_rancher_password}\", \"username\": \"standard_user\"}"
}


if [ ${CORRAL_rancher_type} = "existing" ]; then

    TEST_BASE_URL="https://${CORRAL_rancher_host}/dashboard"

    docker run --name "${CORRAL_rancher_host}" -t \
      -e CYPRESS_VIDEO=false \
      -e CYPRESS_VIEWPORT_WIDTH=1280 \
      -e CYPRESS_VIEWPORT_HEIGHT=720 \
      -e TEST_BASE_URL=${TEST_BASE_URL} \
      -e TEST_USERNAME=${CORRAL_rancher_username} \
      -e TEST_PASSWORD=${CORRAL_rancher_password} \
      -e TEST_SKIP_SETUP=true \
      -v "${HOME}":/e2e \
      -w /e2e "cypress/${CYPRESS_DOCKER_TYPE}:${CYPRESS_DOCKER_VERSION}"

    exit_code=$?

elif [ ${CORRAL_rancher_type} = "local" ]; then

    export PATH="${NODE_PATH}/node-${NODEJS_VERSION}-linux-x64/bin:${PATH}"
    # export TEST_INSTRUMENT=true
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
      -e CYPRESS_VIEWPORT_WIDTH=1280 \
      -e CYPRESS_VIEWPORT_HEIGHT=720 \
      -e TEST_BASE_URL=${TEST_BASE_URL} \
      -e TEST_USERNAME=${TEST_USERNAME} \
      -e TEST_PASSWORD=${TEST_PASSWORD} \
      -e TEST_SKIP_SETUP=true \
      -e CATTLE_BOOTSTRAP_PASSWORD=${TEST_PASSWORD} \
      -v "${HOME}":/e2e \
      -w /e2e cypress/"${CYPRESS_DOCKER_TYPE}:${CYPRESS_DOCKER_VERSION}"
    
    exit_code=$?
    echo "EXIT CODE AFTER DOCKER RUN: ${exit_code}"
else
  echo "Unknown RANCHER_TYPE install. Exiting with error."
  exit 1
fi

DASHBOARD_PATH="${HOME}/dashboard"
sudo chown -R $(whoami) .
echo "${PWD}"
find "${HOME}" -type f -iname "*.xml" -not -path "*node_modules*"
find "${HOME}" -type f -iname "*mochawesome*" -not -path "*node_modules*"

jrm "${DASHBOARD_PATH}/results.xml" "${DASHBOARD_PATH}/cypress/jenkins/reports/junit/junit-*"

mochawesome-merge "${DASHBOARD_PATH}/cypress/jenkins/reports/mochawesome/*.json" \
  -o "${DASHBOARD_PATH}/results.json"
marge -o "${DASHBOARD_PATH}" "${DASHBOARD_PATH}/results.json"

if [ -s "${DASHBOARD_PATH}/results.xml" ]; then
    corral_set cypress_completed "completed"
fi
exit ${exit_code}