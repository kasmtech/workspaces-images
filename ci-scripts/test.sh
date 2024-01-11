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

# Install tools for testing
apk add \
  aws-cli \
  curl \
  jq \
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

# Install Kasm workspaces
ssh \
  -oConnectTimeout=4 \
  -oStrictHostKeyChecking=no \
  ${USER}@"${IPS[0]}" \
  "curl -L -o /tmp/installer.tar.gz ${TEST_INSTALLER} && cd /tmp && tar xf installer.tar.gz && sudo bash kasm_release/install.sh -H -u -I -e -P ${RAND} -U ${RAND}"

# Ensure install is up and running
ready_check

# Pull tester image
docker pull ${ORG_NAME}/kasm-tester:1.15.0

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
  kasmweb/kasm-tester:1.15.0

# Shutdown Instances
turnoff

# Exit 1 if test failed or file does not exist
STATUS=$(curl -sL https://kasm-ci.s3.amazonaws.com/${CI_COMMIT_SHA}/${ARCH}/kasmweb/image-cache-private/${ARCH}-${NAME}-${SANITIZED_BRANCH}-${CI_PIPELINE_ID}/ci-status.yml | awk -F'"' '{print $2}')
if [ ! "${STATUS}" == "PASS" ]; then
  exit 1
fi
