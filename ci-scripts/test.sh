#!/bin/bash
set -e

## Parse input ##
NAME=$1
BASE=$2
DOCKERFILE=$3
ARCH=$4
AWS_ID=$5
AWS_KEY=$6

# Setup aws cli
export AWS_ACCESS_KEY_ID="${AWS_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_KEY}"
export AWS_DEFAULT_REGION=us-east-1

# This job runs on node:24 (Debian), not docker:29.4.3 (Alpine), because
# Playwright's bundled Chromium needs glibc. docker.io is already installed
# by that job's own before_script (see gitlab-ci.template).
apt-get update && apt-get install -y --no-install-recommends awscli jq git openssh-client

# Downloads GitLab Secure Files (the license activation key) into
# SECURE_FILES_DOWNLOAD_PATH via the community installer.
export SECURE_FILES_DOWNLOAD_PATH="/tmp/"
curl -f --silent -o /tmp/load-secure-files-installer "https://gitlab.com/gitlab-org/incubation-engineering/mobile-devops/load-secure-files/-/raw/5e1cf0e12fd9e8910f8dc7272e8844db474995cc/installer"
bash /tmp/load-secure-files-installer

## Functions ##
# Ami locater
getami () {
aws ec2 describe-images --filters \
  "Name=name,Values=$1*" \
  "Name=owner-id,Values=$2" \
  "Name=state,Values=available" \
  "Name=architecture,Values=$3" \
  "Name=virtualization-type,Values=hvm" \
  "Name=root-device-type,Values=ebs" \
  "Name=image-type,Values=machine" \
  --query 'sort_by(Images, &CreationDate)[-1].[ImageId]' \
  --output 'text' \
  --region us-east-1
}
# Make sure deployment is ready
function ready_check() {
  while :; do
    sleep 2
    CHECK=$(curl --max-time 5 -sLk https://${IPS[0]}/api/__healthcheck || :)
    if [[ "${CHECK}" =~ .*"true".* ]]; then
      echo "Workspaces at "${IPS[0]}" ready for testing"
      break
    else
      echo "Waiting for Workspaces at "${IPS[0]}" to be ready"
    fi
  done
  sleep 30
}

# Determine deployment based on arch
if [[ "${ARCH}" == "x86_64" ]]; then
  AMI=$(getami "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04" 099720109477 x86_64)
  TYPE=c5.large
  USER=ubuntu
else
  AMI=$(getami "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04" 099720109477 arm64)
  TYPE=c6g.large
  USER=ubuntu
fi

# Setup SSH Key
mkdir -p /root/.ssh
RAND=$(head /dev/urandom | tr -dc 'a-z0-9' | head -c36)

# Kasm instance container logs, written into the Playwright job's existing
# test-results/ artifact tree. Only gathered on a failing Playwright run with
# SKIP_TRACE_ON_FAILURE=false (see turnoff below) -- off by default, same as
# the trace/DB-snapshot artifacts.
LOGS_DIR="kasmweb-checkout/test-results/kasm-logs"
function gather_kasm_logs() {
  mkdir -p "${LOGS_DIR}"
  for IP in "${IPS[@]}"; do
    echo "Gathering Kasm logs from ${IP}..."
    # Individually bounded so a wedged instance can't hang turnoff() and
    # block the poweroff loop below it.
    CONTAINERS=$(timeout 30 ssh \
      -oConnectTimeout=4 \
      -oStrictHostKeyChecking=no \
      ${USER}@${IP} \
      sudo docker container ls --all --format '{{.Names}}' || :)
    for CONTAINER in ${CONTAINERS}; do
      timeout 60 ssh \
        -oConnectTimeout=4 \
        -oStrictHostKeyChecking=no \
        ${USER}@${IP} \
        sudo docker logs "${CONTAINER}" &>"${LOGS_DIR}/${CONTAINER}-${IP}.log" || :
    done
  done
}

# Registered on EXIT (not ERR) so cleanup runs on any exit path, including a
# GitLab job cancellation/timeout signal, which ERR does not catch.
function turnoff() {
  # Captured first, before any command can clobber $?. Nonzero means the
  # script itself died; PLAYWRIGHT_STATUS (below) covers a clean run where
  # the tests failed.
  EXIT_CODE="$?"

  if { [ "${EXIT_CODE}" -ne 0 ] || [ "${PLAYWRIGHT_STATUS:-0}" -ne 0 ]; } \
    && [ "${SKIP_TRACE_ON_FAILURE:-true}" != "true" ]; then
    gather_kasm_logs
  fi

  for IP in "${IPS[@]}"; do
    ssh \
      -oConnectTimeout=4 \
      -oStrictHostKeyChecking=no \
      ${USER}@${IP} \
      "sudo poweroff" || :
  done
  aws ec2 delete-key-pair --key-name ${RAND} || :
}
trap turnoff EXIT

SSH_KEY=$(aws ec2 create-key-pair --key-name ${RAND} | jq -r '.KeyMaterial')
cat >/root/.ssh/id_rsa <<EOL
$SSH_KEY
EOL
chmod 600 /root/.ssh/id_rsa

# Launch instance
cat >/root/user-data <<EOL
#!/bin/bash
shutdown -P +60
EOL
aws ec2 run-instances \
  --image-id ${AMI} \
  --count 1 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=gitlab-os-integration,Value=true}]' \
  --instance-type ${TYPE} \
  --key-name ${RAND} \
  --security-group-ids sg-029d5bc88b001fbe5 \
  --subnet-id subnet-0ee70521f1f979f5f \
  --associate-public-ip-address \
  --user-data file:///root/user-data \
  --block-device-mapping '[ { "DeviceName": "/dev/sda1", "Ebs": { "VolumeSize": 120 } } ]' \
  --instance-initiated-shutdown-behavior terminate > /tmp/instance.json
INSTANCE=$(cat /tmp/instance.json | jq -r " .Instances[0].InstanceId")
INSTANCES+=("${INSTANCE}")
for INSTANCE_ID in "${INSTANCES[@]}"; do
  echo $INSTANCE_ID
done

# Determine IPs of instances
IPS=()
for INSTANCE_ID in "${INSTANCES[@]}"; do
  while :; do
    sleep 2
    IP=$(aws ec2 describe-instances \
      --instance-id ${INSTANCE_ID} \
      | jq -r '.Reservations[0].Instances[0].PublicIpAddress')
    if [ "${IP}" == 'null' ]; then
      echo "Waiting for Pub IP from instance ${INSTANCE_ID}"
    else
      echo "Instance ${INSTANCE_ID} IP=${IP}"
      IPS+=("${IP}")
      break
    fi
  done
done

# Make sure the instance is up
for IP in "${IPS[@]}"; do
  while :; do
    sleep 2
    UPTIME=$(ssh \
      -oConnectTimeout=4 \
      -oStrictHostKeyChecking=no \
      ${USER}@${IP} \
     'uptime'|| :)
    if [ -z "${UPTIME}" ]; then
      echo "Waiting for ${IP} to be up"
    else
      echo "${IP} up ${UPTIME}"
      break
    fi
  done
done

# Sleep here to ensure subsequent connections don't fail
sleep 30

# Double check we are up
for IP in "${IPS[@]}"; do
  while :; do
    sleep 2
    UPTIME=$(ssh \
      -oConnectTimeout=4 \
      -oStrictHostKeyChecking=no \
      ${USER}@${IP} \
     'uptime'|| :)
    if [ -z "${UPTIME}" ]; then
      echo "Waiting for ${IP} to be up"
    else
      echo "${IP} up ${UPTIME}"
      break
    fi
  done
done

# AWS Ubuntu AMIs are pre-configured to use a regional AWS apt mirror
# (e.g. <region>.ec2.archive.ubuntu.com), which is occasionally broken or
# unavailable. Force the instance to use the official Ubuntu mirrors instead.
if [[ "${ARCH}" == "x86_64" ]]; then
  APT_MIRROR="http://archive.ubuntu.com/ubuntu/"
  APT_SECURITY_MIRROR="http://security.ubuntu.com/ubuntu/"
else
  APT_MIRROR="http://ports.ubuntu.com/ubuntu-ports/"
  APT_SECURITY_MIRROR="http://ports.ubuntu.com/ubuntu-ports/"
fi
cat >/root/sources.list <<EOL
deb ${APT_MIRROR} jammy main restricted universe multiverse
deb ${APT_MIRROR} jammy-updates main restricted universe multiverse
deb ${APT_MIRROR} jammy-backports main restricted universe multiverse
deb ${APT_SECURITY_MIRROR} jammy-security main restricted universe multiverse
EOL
APT_UPDATE_TIMEOUT=300
for IP in "${IPS[@]}"; do
  echo "${IP}: Switching to official Ubuntu mirrors"
  timeout ${APT_UPDATE_TIMEOUT} scp \
    -oConnectTimeout=10 \
    -oStrictHostKeyChecking=no \
    /root/sources.list \
    ${USER}@${IP}:/tmp/
  timeout ${APT_UPDATE_TIMEOUT} ssh \
    -oConnectTimeout=10 \
    -oStrictHostKeyChecking=no \
    ${USER}@${IP} \
    "sudo mv -v /tmp/sources.list /etc/apt/sources.list && sudo rm -vf /etc/apt/sources.list.d/ubuntu.sources && sudo apt-get update -o APT::Update::Error-Mode=any"
done

# Materialize docker config from env var if docker login was not run
if [ ! -f /root/.docker/config.json ] && [ -n "${DOCKER_AUTH_CONFIG:-}" ]; then
  mkdir -p /root/.docker
  printf '%s' "${DOCKER_AUTH_CONFIG}" > /root/.docker/config.json
fi

# Copy over docker auth
for IP in "${IPS[@]}"; do
  scp \
    -oStrictHostKeyChecking=no \
    /root/.docker/config.json \
    ${USER}@${IP}:/tmp/
  ssh \
    -oConnectTimeout=10 \
    -oStrictHostKeyChecking=no \
    ${USER}@${IP} \
    "sudo mkdir -p /root/.docker && sudo mv /tmp/config.json /root/.docker/ && sudo chown root:root /root/.docker/config.json"
done

# TEST_INSTALLER_ROLLING for the Playwright tester; see its definition in
# .gitlab-ci.yml for why.
INSTALLER_URL="${TEST_INSTALLER_ROLLING}"

# Install Kasm workspaces from the stock bundle -- its frontend is what
# gets tested; see KASMWEB_VERSION in .gitlab-ci.yml for the spec source.
cat >/tmp/kasm_install_remote.sh <<EOF
set -e
curl -L -o /tmp/installer.tar.gz "${INSTALLER_URL}"
cd /tmp
tar xf installer.tar.gz
sudo bash kasm_release/install.sh -H -u -I -e -P ${RAND} -U ${RAND}
EOF

scp \
  -oStrictHostKeyChecking=no \
  /tmp/kasm_install_remote.sh \
  ${USER}@"${IPS[0]}":/tmp/kasm_install_remote.sh
ssh \
  -oConnectTimeout=4 \
  -oStrictHostKeyChecking=no \
  ${USER}@"${IPS[0]}" \
  "bash /tmp/kasm_install_remote.sh"

# Ensure install is up and running
ready_check

# Grants docker-group access so the ssh: DOCKER_HOST transport below can
# reach the daemon without sudo (imageWarmup.ts's own `docker pull` needs
# it too). Group membership is re-evaluated per SSH login, so no restart
# is needed.
ssh \
  -oConnectTimeout=10 \
  -oStrictHostKeyChecking=no \
  ${USER}@"${IPS[0]}" \
  "sudo usermod -aG docker ${USER}"

# docker's ssh: transport shells out to a bare `ssh` with no per-call
# flags, so it needs its own config to skip host-key checking for this
# fresh instance.
mkdir -p /root/.ssh
cat >>/root/.ssh/config <<EOF
Host ${IPS[0]}
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
EOF
chmod 600 /root/.ssh/config

# Exported, not passed as a one-off `docker -H`, because imageWarmup.ts's
# own `docker pull` call needs it too and can't take a per-call flag.
export DOCKER_HOST="ssh://${USER}@${IPS[0]}"

# The frontend under test is whatever TEST_INSTALLER_ROLLING's backend
# bundle already installed -- this clone only supplies the Playwright spec
# files themselves, pinned to the same branch.
rm -rf kasmweb-checkout
git clone --depth 1 --branch "${KASMWEB_VERSION:-develop}" \
  "https://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.com/kasm-technologies/internal/kasmweb.git" \
  kasmweb-checkout

# Playwright tester. Runs directly in this job's own node:24 shell rather
# than a separate tester image. Runs on both ARCH legs.
#
# PLAYWRIGHT_STATUS is captured explicitly, not left to `set -e`, so
# `turnoff` still runs and shuts the instance down before the script exits.
# It's the job's only result signal.
PLAYWRIGHT_STATUS=0
echo "Running Playwright tests against ${NAME}"
# Subshell scopes the cd and all these exports to just this step.
set +e
(
  set -e
  cd kasmweb-checkout
  npm ci
  npx playwright install --with-deps chromium
  export CI=true
  export KASM_ADDR="https://${IPS[0]}"
  export USER_NAME="admin@kasm.local"
  export PASSWORD="${RAND}"
  # ${NAME} is workspaces-images' own canonical name for this app image,
  # used verbatim as the label so it matches this image's own
  # capability-skip map on the kasmweb side.
  export KASM_TEST_IMAGE_REFS="${NAME}|${ORG_NAME}/image-cache-private:${ARCH}-${NAME}-${SANITIZED_BRANCH}-${CI_PIPELINE_ID}"
  # activation_key is the Secure File downloaded above, not a plain CI/CD
  # variable, so it's read from disk.
  export KASM_LICENSE_KEY="$(cat /tmp/activation_key)"
  # Defaults to "true" to bound per-failure artifact size (pg_dump) across
  # the many per-image runs this pipeline accumulates. Set false to get a
  # DB snapshot for a specific failure.
  export SKIP_DB_SNAPSHOT_ON_FAILURE="${SKIP_DB_SNAPSHOT_ON_FAILURE:-true}"
  # Same reasoning: bounds trace.zip size (70MB+ each) across per-image
  # runs. Also gates gather_kasm_logs above. Set false for a real trace.
  export SKIP_TRACE_ON_FAILURE="${SKIP_TRACE_ON_FAILURE:-true}"
  # DOCKER_HOST is exported above and inherited here; imageWarmup.ts's own
  # `docker pull` needs it to reach the same instance daemon.
  npx playwright test --project="image-spec:${NAME}" --workers=1
)
PLAYWRIGHT_STATUS=$?
set -e

echo "Playwright tester exit status: ${PLAYWRIGHT_STATUS}"
if [ "${PLAYWRIGHT_STATUS}" -ne 0 ]; then
  exit "${PLAYWRIGHT_STATUS}"
fi
