#!/bin/bash
set -e

## Parse input ##
NAME=$1
BASE=$2
DOCKERFILE=$3
ARCH=$4
AWS_ID=$5
AWS_KEY=$6
RUN_PLAYWRIGHT=${7:-false}

# On this branch, the Playwright calibration tester replaces Selenium's
#   kasm-tester entirely for the 5 images it covers -- not run alongside it --
#   so the two suites never share a DB/instance. Other images (and every
#   image once RUN_PLAYWRIGHT isn't passed at all, e.g. on develop) are
#   unaffected and keep running kasm-tester exactly as before.
if [ "${RUN_PLAYWRIGHT}" == "true" ] && [ "${ARCH}" == "x86_64" ]; then
  RUN_SELENIUM=false
else
  RUN_SELENIUM=true
fi

# Setup aws cli
export AWS_ACCESS_KEY_ID="${AWS_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_KEY}"
export AWS_DEFAULT_REGION=us-east-1

# Install tools for testing
apk add \
  aws-cli \
  curl \
  jq \
  git \
  openssh-client

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

# Shutdown Instances function and trap
function turnoff() {
  for IP in "${IPS[@]}"; do
    ssh \
      -oConnectTimeout=4 \
      -oStrictHostKeyChecking=no \
      ${USER}@${IP} \
      "sudo poweroff" || :
  done
  aws ec2 delete-key-pair --key-name ${RAND}
}
trap turnoff ERR

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
  # install.sh never grants ${USER} docker-group access -- needed so the
  #   Playwright calibration tester's DOCKER_HOST=ssh://${USER}@${IP} can reach
  #   the socket without sudo (docker's ssh: transport runs a plain, unprefixed
  #   `docker system dial-stdio` on the remote end). Group membership is
  #   re-evaluated per SSH login, so this is picked up by every later
  #   connection with no restart/re-login needed. Gated on RUN_PLAYWRIGHT so
  #   this doesn't change the shared Selenium path's instance for images that
  #   don't opt in.
  if [ "${RUN_PLAYWRIGHT}" == "true" ] && [ "${ARCH}" == "x86_64" ]; then
    ssh \
      -oConnectTimeout=10 \
      -oStrictHostKeyChecking=no \
      ${USER}@${IP} \
      "sudo usermod -aG docker ${USER}"
  fi
done

# Install Kasm workspaces
ssh \
  -oConnectTimeout=4 \
  -oStrictHostKeyChecking=no \
  ${USER}@"${IPS[0]}" \
  "curl -L -o /tmp/installer.tar.gz ${TEST_INSTALLER} && cd /tmp && tar xf installer.tar.gz && sudo bash kasm_release/install.sh -H -u -I -e -P ${RAND} -U ${RAND}"

# Ensure install is up and running
ready_check

# Playwright calibration tester (Phase 2 of the multi-image project, see
#   multi-image-plan.md). Replaces kasm-tester on this instance (RUN_SELENIUM
#   is false below) rather than running alongside it, so calibration never
#   contaminates -- or is contaminated by -- a Selenium run against the same
#   DB. x86_64 only -- TEST_IMAGES/imageMatrix.ts is amd64-oriented, so an
#   aarch64-only divergence here would be neither an image limitation nor a
#   test bug.
#
# Calibration-phase only: PLAYWRIGHT_STATUS is intentionally not wired into
#   this script's final exit code below -- Selenium is skipped on this branch
#   for these images (see RUN_SELENIUM above), so there's no other gate to
#   defer to; the job stays green regardless of the calibration result until
#   skip maps make this suite reliably green on these images.
PLAYWRIGHT_STATUS=0
if [ "${RUN_PLAYWRIGHT}" == "true" ] && [ "${ARCH}" == "x86_64" ]; then
  echo "Building Playwright calibration tester from kasmweb@${KASMWEB_VERSION:-develop}"
  # Clear any stale checkout from a prior attempt -- job-level `retry: 1`
  #   would otherwise hit "directory exists and is not empty" here.
  rm -rf kasmweb-checkout
  git clone --depth 1 --branch "${KASMWEB_VERSION:-develop}" \
    "https://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.com/kasm-technologies/internal/kasmweb.git" \
    kasmweb-checkout

  docker build -t kasm-playwright-tester \
    -f kasmweb-checkout/docker_build/Dockerfile.playwright \
    kasmweb-checkout

  mkdir -p playwright-results

  # DOCKER_HOST=ssh://... -- NOT recording-specific. Kasm's agent on ${IPS[0]}
  #   has its own Docker daemon, separate from this runner's; without this,
  #   imageWarmup.ts's `docker pull` (documented there as talking to "the
  #   shared inner Docker daemon") would either fail outright (no socket
  #   mounted) or silently pull into the wrong daemon, and every image-spec
  #   test depending on that warmup would report "did not run" for every
  #   image. This also happens to be what e2e_sessionRecordingContainer needs
  #   for its `docker exec` into kasm_guac -- but recording stays excluded
  #   below regardless, since its shared-setup separately hard-fails without
  #   real RECORDING_* S3 credentials, which aren't provisioned here yet.
  #
  # Own copy of the key at 600: the existing $(dirname ${CI_PROJECT_DIR})/sshkey
  #   is deliberately 777 for kasm-tester's own (non-OpenSSH) use below; a real
  #   `ssh`/docker ssh: transport refuses a group/world-readable identity file.
  cp /root/.ssh/id_rsa "$PWD/playwright-sshkey"
  chmod 600 "$PWD/playwright-sshkey"

  # System-wide (not user-specific) so it applies regardless of which user the
  #   pinned kasm-playwright-private base image runs as. StrictHostKeyChecking
  #   disabled because this is a fresh EC2 instance every run -- there's no
  #   prior known_hosts entry to check against. Mounted as a full replacement
  #   of /etc/ssh/ssh_config rather than an additive drop-in under
  #   ssh_config.d/ -- whether that base image's config even has the Debian
  #   `Include /etc/ssh/ssh_config.d/*.conf` convention is unverified (private
  #   image, not pullable from this sandbox). Low risk: this config is
  #   self-sufficient for the one thing this container does over SSH.
  cat > "$PWD/playwright-ssh-config" <<EOF
Host *
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  IdentityFile /playwright-sshkey
EOF

  echo "Running Playwright calibration tester against ${NAME}"
  docker run --rm \
    -v "$PWD/playwright-results:/playwright-tests/playwright-results" \
    -v "$PWD/playwright-sshkey:/playwright-sshkey:ro" \
    -v "$PWD/playwright-ssh-config:/etc/ssh/ssh_config:ro" \
    -e CI=true \
    -e "DOCKER_AUTH_CONFIG=${DOCKER_AUTH_CONFIG}" \
    -e "DOCKER_HOST=ssh://${USER}@${IPS[0]}" \
    -e "KASM_ADDR=https://${IPS[0]}" \
    -e "USER_NAME=admin@kasm.local" \
    -e "PASSWORD=${RAND}" \
    -e "KASM_TEST_IMAGE_REFS=${ORG_NAME}/image-cache-private:${ARCH}-${NAME}-${SANITIZED_BRANCH}-${CI_PIPELINE_ID}" \
    -e "KASM_LICENSE_KEY=${KASM_LICENSE_KEY}" \
    kasm-playwright-tester --grep-invert "rdp|recording" \
    || PLAYWRIGHT_STATUS=$?

  echo "Playwright calibration tester exit status: ${PLAYWRIGHT_STATUS}"
fi

if [ "${RUN_SELENIUM}" == "true" ]; then
  # Pull tester image
  docker pull ${ORG_NAME}/kasm-tester:1.18.0

  # Run test
  cp /root/.ssh/id_rsa $(dirname ${CI_PROJECT_DIR})/sshkey
  chmod 777 $(dirname ${CI_PROJECT_DIR})/sshkey
  docker run --rm \
    -e TZ=US/Pacific \
    -e KASM_HOST=${IPS[0]} \
    -e KASM_PORT=443 \
    -e KASM_PASSWORD="${RAND}" \
    -e SSH_USER=$USER \
    -e DOCKERUSER=$DOCKER_HUB_USERNAME \
    -e DOCKERPASS=$DOCKER_HUB_PASSWORD \
    -e TEST_IMAGE="${ORG_NAME}/image-cache-private:${ARCH}-${NAME}-${SANITIZED_BRANCH}-${CI_PIPELINE_ID}" \
    -e AWS_KEY=${KASM_TEST_AWS_KEY} \
    -e AWS_SECRET="${KASM_TEST_AWS_SECRET}" \
    -e SLACK_TOKEN=${SLACK_TOKEN} \
    -e S3_BUCKET=kasm-ci \
    -e COMMIT=${CI_COMMIT_SHA} \
    -e REPO=workspaces-images \
    -e AUTOMATED=true \
    -v $(dirname ${CI_PROJECT_DIR})/sshkey:/sshkey:ro  ${SLIM_FLAG} \
    kasmweb/kasm-tester:1.18.0
fi

# Shutdown Instances
turnoff

if [ "${RUN_SELENIUM}" == "true" ]; then
  # Exit 1 if test failed or file does not exist
  STATUS=$(curl -sL https://kasm-ci.s3.amazonaws.com/${CI_COMMIT_SHA}/${ARCH}/kasmweb/image-cache-private/${ARCH}-${NAME}-${SANITIZED_BRANCH}-${CI_PIPELINE_ID}/ci-status.yml | awk -F'"' '{print $2}')
  if [ ! "${STATUS}" == "PASS" ]; then
    exit 1
  fi
else
  # Calibration-phase only: Selenium didn't run, so there's no ci-status.yml
  #   to check. PLAYWRIGHT_STATUS (captured above) is intentionally still not
  #   wired into this job's exit code -- stays green regardless of the
  #   calibration result until skip maps make the suite reliably green on
  #   these images. Triage failures from the results.xml artifact instead.
  echo "Selenium skipped on this branch; Playwright calibration tester exit status was ${PLAYWRIGHT_STATUS}"
fi
