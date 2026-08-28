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
if [ "${RUN_PLAYWRIGHT}" == "true" ]; then
  RUN_SELENIUM=false
else
  RUN_SELENIUM=true
fi

# Setup aws cli
export AWS_ACCESS_KEY_ID="${AWS_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_KEY}"
export AWS_DEFAULT_REGION=us-east-1

# Install tools for testing. RUN_PLAYWRIGHT-flagged entries run this job on
#   node:24 (Debian) instead of docker:29.4.3 (Alpine) -- see
#   gitlab-ci.template's per-entry `image:` -- because Playwright's bundled
#   Chromium needs glibc, which Alpine's musl libc doesn't provide. docker.io
#   is already installed by that job's own before_script (needed there
#   before the default before_script's `docker login` runs). Debian's awscli
#   package is an older v1 build, but this script only ever makes basic EC2
#   calls (describe-images, run-instances, describe-instances,
#   create/delete-key-pair) that v1 handles fine -- same reasoning already
#   accepted for the Alpine path's own apk aws-cli package below, whatever
#   version that happens to be.
if [ "${RUN_PLAYWRIGHT}" == "true" ]; then
  apt-get update && apt-get install -y --no-install-recommends awscli jq git openssh-client
else
  apk add \
    aws-cli \
    curl \
    jq \
    git \
    openssh-client
fi

# GitLab Secure File, same as kasmweb's own e2e-test job (.gitlab-ci.yml):
#   downloads project Secure Files (distinct from CI/CD variables) into
#   SECURE_FILES_DOWNLOAD_PATH via the community installer. Only needed on
#   the RUN_PLAYWRIGHT leg -- Selenium's kasm-tester has no license handling
#   at all -- but this alone doesn't need the ARCH==x86_64 check the
#   Playwright-specific steps below use, matching the tool-install branch
#   above.
if [ "${RUN_PLAYWRIGHT}" == "true" ]; then
  export SECURE_FILES_DOWNLOAD_PATH="/tmp/"
  curl --silent "https://gitlab.com/gitlab-org/incubation-engineering/mobile-devops/load-secure-files/-/raw/main/installer" | bash
fi

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

# Shutdown Instances function and trap. Registered here -- as soon as RAND
#   (the key-pair name) exists, before the key pair or instance are actually
#   created -- and on EXIT rather than ERR, so cleanup fires no matter how
#   the script terminates: a failing command under `set -e`, normal
#   completion, or a GitLab job cancellation/timeout sending SIGTERM to this
#   process (which ERR never catches -- signals bypass it entirely). Guarded
#   with CLEANED_UP since EXIT still fires once more when the script's own
#   `exit` calls near the end run, after cleanup already happened.
CLEANED_UP=false
function turnoff() {
  if [ "${CLEANED_UP}" == "true" ]; then
    return
  fi
  CLEANED_UP=true
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

# Resolve which installer bundle to use.
INSTALLER_URL="${TEST_INSTALLER}"
if [ "${RUN_PLAYWRIGHT}" == "true" ]; then
  # Rolling develop bundle, not the pinned release above -- calibration needs
  #   the post-1.19.0 API/UI changes the DEVOPS-74 Playwright specs depend
  #   on. Same install.sh-compatible tarball shape as TEST_INSTALLER; kept as
  #   a separate variable so Selenium's own calibration against these images
  #   isn't silently switched to a moving target.
  INSTALLER_URL="${TEST_INSTALLER_ROLLING}"
fi

# Install Kasm workspaces with the stock bundle first. The Playwright
#   calibration path's custom frontend image (below) can't be built until
#   Docker exists on the instance, and Docker doesn't exist until this
#   install.sh run's own install_dependencies.sh call installs it -- so the
#   frontend swap has to happen as a second, targeted step afterward, not
#   folded into this install.
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

# Playwright-calibration-only: swap in a custom frontend image carrying the
#   DEVOPS-74 kasmweb branch's UI/test-ids, built directly into the
#   instance's own Docker daemon -- which only exists now, post-install.
if [ "${RUN_PLAYWRIGHT}" == "true" ]; then
  CUSTOM_PROXY_TAG="pwcalib-${RAND}"

  # install.sh never grants ${USER} docker-group access -- needed so the
  #   DOCKER_HOST=ssh://${USER}@${IP} build below (and imageWarmup.ts's own
  #   `docker pull` once Playwright runs) can reach the socket without sudo
  #   (docker's ssh: transport runs a plain, unprefixed `docker system
  #   dial-stdio` on the remote end). Group membership is re-evaluated per
  #   SSH login, so this is picked up by every later connection with no
  #   restart/re-login needed. Docker (and the docker group) exist now,
  #   since install.sh has already run above.
  ssh \
    -oConnectTimeout=10 \
    -oStrictHostKeyChecking=no \
    ${USER}@"${IPS[0]}" \
    "sudo usermod -aG docker ${USER}"

  # SSH transport for the `docker build` below and for imageWarmup.ts's own
  #   `docker pull` once Playwright runs -- both need to reach the
  #   instance's own daemon, which is a separate daemon from this runner's.
  #   docker's ssh: transport shells out to a bare `ssh` with no per-call
  #   flags, unlike the explicit ssh/scp calls elsewhere in this script, so
  #   it needs its own config. StrictHostKeyChecking is disabled because
  #   this is a fresh instance every run -- there's no prior known_hosts
  #   entry to check against.
  mkdir -p /root/.ssh
  cat >>/root/.ssh/config <<EOF
Host ${IPS[0]}
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
EOF
  chmod 600 /root/.ssh/config

  # Exported (not passed as a one-off `docker -H`) because imageWarmup.ts's
  #   own internal `docker pull` call (once Playwright runs, below) has no
  #   way to take a per-call flag -- DOCKER_HOST is the only way to redirect
  #   it. Safe to change for the rest of this run: RUN_SELENIUM is always
  #   false whenever this branch executes, so nothing later in this script
  #   still needs the original tcp://docker:2375 value.
  export DOCKER_HOST="ssh://${USER}@${IPS[0]}"

  echo "Building custom frontend image from kasmweb@${KASMWEB_VERSION:-develop}"
  # Clear any stale checkout from a prior attempt -- job-level `retry: 1`
  #   would otherwise hit "directory exists and is not empty" here.
  rm -rf kasmweb-checkout
  git clone --depth 1 --branch "${KASMWEB_VERSION:-develop}" \
    "https://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.com/kasm-technologies/internal/kasmweb.git" \
    kasmweb-checkout

  # kasmweb's own `deploy` job uploads this per-branch on every pipeline run
  #   on that branch, explicitly for other repos' dev/test use (see its
  #   comment in kasmweb/.gitlab-ci.yml) -- picks up whatever UI/test-id
  #   changes are on this branch, unlike the pinned release TEST_INSTALLER.
  #   docker_build/Dockerfile.kasmweb just unpacks this tarball into an
  #   nginx image -- no npm/webpack build needed here at all.
  SANITIZED_KASMWEB_VERSION="$(echo "${KASMWEB_VERSION:-develop}" | sed 's/\//_/g')"

  # Minimal build context (just this one file, at the relative path
  #   Dockerfile.kasmweb's `COPY ./output/kasmweb.tar.gz` expects) instead of
  #   the whole kasmweb-checkout tree -- Dockerfile.kasmweb doesn't reference
  #   anything else in that repo, and the full checkout would otherwise get
  #   sent as build context over the ssh transport for nothing. -f still
  #   points at the checkout's copy of the Dockerfile itself (docker build
  #   allows -f to live outside the context dir).
  rm -rf kasmweb-frontend-context
  mkdir -p kasmweb-frontend-context/output
  curl -L -o kasmweb-frontend-context/output/kasmweb.tar.gz \
    "https://kasmweb-build-artifacts.s3.amazonaws.com/kasmweb/${SANITIZED_KASMWEB_VERSION}.tar.gz"

  # Build straight into the instance's own daemon -- no registry push/pull
  #   needed. install/bin/utils/pull (part of install.sh's flow) only
  #   force-repulls image tags containing the literal string "rolling"; any
  #   other tag (like this one) is left alone, and docker compose's default
  #   pull_policy: missing just uses what's already there locally. Tag both
  #   the public and private repo names since it's not known ahead of time
  #   which one this bundle's compose files reference.
  docker build \
    -t "kasmweb/proxy:${CUSTOM_PROXY_TAG}" \
    -t "kasmweb/proxy-private:${CUSTOM_PROXY_TAG}" \
    -f kasmweb-checkout/docker_build/Dockerfile.kasmweb \
    kasmweb-frontend-context

  # Point the running install's proxy service at the custom-built image.
  #   install.sh already collapsed every docker-compose-*.yaml variant down
  #   to one live file by now (ROLE defaults to "all", so it copied
  #   docker/.conf/docker-compose-all.yaml -> docker/docker-compose.yaml --
  #   traced directly in install.sh's role dispatch), and that's the only
  #   file install/bin/start's bare `docker compose up -d` actually reads (no
  #   -f flag, relies on Compose's default discovery) -- so the swap targets
  #   that single live file under /opt/kasm/current, not the extraction
  #   directory. Built as a local script (rather than one long inline ssh
  #   command string) for the same reason kasm_install_remote.sh is: avoids
  #   layering this script's own quoting on top of ssh's remote command
  #   string. Two separate substitutions (no backreference) so the character
  #   class only needs to exclude the surrounding quote style, not capture
  #   around it. Ends with `start` (plain `docker compose up -d`, the same
  #   command install/bin/start itself runs) rather than `restart` --
  #   CUSTOM_PROXY_TAG is a fresh, unique tag every run, so Compose's own
  #   config-diff already recreates just the `proxy` service; nothing else
  #   needs a forced recreate.
  cat >/tmp/kasm_swap_frontend_remote.sh <<EOF
set -e
sudo sed -i \\
  -e "s#kasmweb/proxy:[^\"'[:space:]]\\+#kasmweb/proxy:${CUSTOM_PROXY_TAG}#g" \\
  -e "s#kasmweb/proxy-private:[^\"'[:space:]]\\+#kasmweb/proxy-private:${CUSTOM_PROXY_TAG}#g" \\
  /opt/kasm/current/docker/docker-compose.yaml
sudo /opt/kasm/bin/start
EOF

  scp \
    -oStrictHostKeyChecking=no \
    /tmp/kasm_swap_frontend_remote.sh \
    ${USER}@"${IPS[0]}":/tmp/kasm_swap_frontend_remote.sh
  ssh \
    -oConnectTimeout=10 \
    -oStrictHostKeyChecking=no \
    ${USER}@"${IPS[0]}" \
    "bash /tmp/kasm_swap_frontend_remote.sh"

  # Re-confirm readiness with the swapped frontend before Playwright runs.
  ready_check
fi

# Playwright calibration tester (Phase 2 of the multi-image project, see
#   multi-image-plan.md). Runs directly in this job's shell -- no separate
#   tester image -- since this job's own container (node:24, see
#   gitlab-ci.template) already has Node and can just clone kasmweb, npm
#   install, and run the specs. Replaces kasm-tester on this instance
#   (RUN_SELENIUM is false below) rather than running alongside it, so
#   calibration never contaminates -- or is contaminated by -- a Selenium run
#   against the same DB. Runs on both ARCH legs (x86_64 and aarch64) since
#   RUN_PLAYWRIGHT is no longer gated on ARCH -- previously x86_64 only,
#   because TEST_IMAGES/imageMatrix.ts is amd64-oriented and an aarch64-only
#   divergence here would be neither an image limitation nor a test bug.
#   That amd64-orientation concern hasn't been re-validated for the aarch64
#   leg; open question, not yet resolved.
#
# PLAYWRIGHT_STATUS is captured here (rather than let via `set -e`/the ERR
#   trap) so that `turnoff` below still runs and shuts the instance down
#   cleanly before the script exits on a test failure, matching the existing
#   Selenium branch's STATUS-then-check pattern. Selenium is skipped on this
#   branch for these images (see RUN_SELENIUM above), so PLAYWRIGHT_STATUS is
#   now the only result signal for the job -- wired into the final exit code
#   below.
PLAYWRIGHT_STATUS=0
if [ "${RUN_PLAYWRIGHT}" == "true" ]; then
  echo "Running Playwright calibration tests against ${NAME}"
  # Subshell: keeps the cd and all these exports scoped to just this step,
  #   rather than leaking into the rest of the script (RUN_SELENIUM is false
  #   here regardless, but this keeps it airtight if that ever changes).
  (
    cd kasmweb-checkout
    npm ci
    npx playwright install --with-deps chromium
    export CI=true
    export KASM_ADDR="https://${IPS[0]}"
    export USER_NAME="admin@kasm.local"
    export PASSWORD="${RAND}"
    # ${NAME} is workspaces-images' own canonical name for this app image
    # (chromium, brave, ubuntu-noble-desktop, ...) -- the same generic
    # identity imageMatrix.ts's future capability-skip maps will key on, so
    # it's used verbatim as the label rather than a prefixed or derived one.
    # KASM_TEST_IMAGE_REFS requires an explicit "label|ref" entry (see
    # imageMatrix.ts) precisely so this label doesn't need to be re-derived
    # from the ref on the Playwright side -- one value, used in both places
    # below, can't drift out of sync with itself.
    export KASM_TEST_IMAGE_REFS="${NAME}|${ORG_NAME}/image-cache-private:${ARCH}-${NAME}-${SANITIZED_BRANCH}-${CI_PIPELINE_ID}"
    # activation_key is the Secure File downloaded above -- same
    #   `cat`-the-file pattern kasmweb's own e2e-test job uses, since it's a
    #   multi-line secure file, not a plain CI/CD variable.
    export KASM_LICENSE_KEY="$(cat /tmp/activation_key)"
    # SKIP_DB_SNAPSHOT_ON_FAILURE: pass through as-is from the pipeline's own
    #   CI/CD variable.  Set to "true" by default to bound test-results/ artifact
    #   size across the dozens of per-image runs this pipeline accumulates. Change
    #   to false when a failure needs extra diagnostics.
    export SKIP_DB_SNAPSHOT_ON_FAILURE="${SKIP_DB_SNAPSHOT_ON_FAILURE:-true}"
    # SKIP_TRACE_ON_FAILURE: same reasoning as SKIP_DB_SNAPSHOT_ON_FAILURE
    #   above -- default to "true" here to bound test-results/ artifact size
    #   (trace.zip files can run 70MB+ each) across the many per-image runs
    #   this pipeline accumulates, especially once the image matrix scales up
    #   and a failure surface could hit dozens of images at once. Change to
    #   false on a specific pipeline run when a failure needs a real trace.
    export SKIP_TRACE_ON_FAILURE="${SKIP_TRACE_ON_FAILURE:-true}"
    # DOCKER_HOST is already exported above (needed there for the frontend
    #   image build) and inherited into this subshell -- imageWarmup.ts's own
    #   `docker pull` needs it too, to reach the same instance daemon.
    npx playwright test --project="image-spec:${NAME}" --workers=1
  ) || PLAYWRIGHT_STATUS=$?

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
  # Selenium didn't run on this branch, so there's no ci-status.yml to check
  #   -- PLAYWRIGHT_STATUS (captured above) is the job's only result signal,
  #   and gates this job's exit code directly.
  echo "Selenium skipped on this branch; Playwright calibration tester exit status was ${PLAYWRIGHT_STATUS}"
  if [ "${PLAYWRIGHT_STATUS}" -ne 0 ]; then
    exit "${PLAYWRIGHT_STATUS}"
  fi
fi
