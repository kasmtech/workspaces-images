#! /bin/bash

# Ingest cli variables
## Parse input ##
NAME=$1
TYPE=$2
BASE=$3
IS_ROLLING=$4

# Determine if this is a private or public build
if [[ "${CI_COMMIT_REF_NAME}" == release/* ]] || [[ "${CI_COMMIT_REF_NAME}" == "develop" ]]; then
  ENDPOINT="${NAME}"
  APPS="kasm-apps"
else
  ENDPOINT="${NAME}-private"
  APPS="kasm-apps-private"
fi

# Determine if this is a rolling build
if [[ "${SCHEDULED}" != "NO" ]]; then
  if [[ "${SCHEDULE_NAME}" == "NO" ]]; then
    SANITIZED_BRANCH=${SANITIZED_BRANCH}-rolling
  else
    SANITIZED_BRANCH=${SANITIZED_BRANCH}-rolling-${SCHEDULE_NAME}
  fi
fi

# Create workspace and base dockerfile
mkdir -p applayer
cd applayer
echo "FROM scratch" > Dockerfile
echo "ADD ./layer.tar /" >> Dockerfile

# Clean up layer tar to not include overlay info
clean_tar () {
  mkdir cleantar
  tar xf layer.tar -C cleantar/ --exclude="**.wh**"
  rm layer.tar
  cd cleantar
  tar -cf layer.tar *
  mv layer.tar ../
  cd ..
  rm -Rf cleantar/
}

# Multi arch
if [ "${TYPE}" == "multi" ]; then
  for ARCH in x86_64 aarch64; do
    # Create image tarballs
    docker save -o $ARCH.tar ${ORG_NAME}/${ENDPOINT}:${ARCH}-${SANITIZED_BRANCH}
    # Pull out the layer we are looking for
    mkdir $ARCH
    mv $ARCH.tar $ARCH
    cd $ARCH
    tar xf $ARCH.tar
    LAYER_FOLDER=$(du -sk * |sort -nr | sed '3q;d' | awk '{print $2}')
    mv $LAYER_FOLDER/layer.tar ../
    cd ../
    rm -Rf $ARCH
    clean_tar
    # build the image based on this single layer
    docker build -t ${ORG_NAME}/${APPS}:${ARCH}-${BASE}-${NAME}-${SANITIZED_BRANCH} .
    docker push ${ORG_NAME}/${APPS}:${ARCH}-${BASE}-${NAME}-${SANITIZED_BRANCH}
    rm -f layer.tar
  done
  # Manifest
  docker manifest push --purge ${ORG_NAME}/${APPS}:${BASE}-${NAME}-${SANITIZED_BRANCH} || :
  docker manifest create ${ORG_NAME}/${APPS}:${BASE}-${NAME}-${SANITIZED_BRANCH} ${ORG_NAME}/${APPS}:x86_64-${BASE}-${NAME}-${SANITIZED_BRANCH} ${ORG_NAME}/${APPS}:aarch64-${BASE}-${NAME}-${SANITIZED_BRANCH}
  docker manifest annotate ${ORG_NAME}/${APPS}:${BASE}-${NAME}-${SANITIZED_BRANCH} ${ORG_NAME}/${APPS}:aarch64-${BASE}-${NAME}-${SANITIZED_BRANCH} --os linux --arch arm64 --variant v8
  docker manifest push --purge ${ORG_NAME}/${APPS}:${BASE}-${NAME}-${SANITIZED_BRANCH}
# Single arch
else
  # Create image tarballs
  docker save -o image.tar ${ORG_NAME}/${ENDPOINT}:${SANITIZED_BRANCH}
  # Pull out the layer we are looking for
  mkdir image
  mv image.tar image
  cd image
  tar xf image.tar
  LAYER_FOLDER=$(du -sk * |sort -nr | sed '3q;d' | awk '{print $2}')
  mv $LAYER_FOLDER/layer.tar ../
  cd ../
  rm -Rf image
  clean_tar
  # build the image based on this single layer
  docker build -t ${ORG_NAME}/${APPS}:${BASE}-${NAME}-${SANITIZED_BRANCH} .
  docker push ${ORG_NAME}/${APPS}:${BASE}-${NAME}-${SANITIZED_BRANCH}
  rm -f layer.tar
fi

# Cleanup
cd ..
rm -Rf applayer
