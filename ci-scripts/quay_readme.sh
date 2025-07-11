#! /bin/bash

## Parse input ##
NAME=$1

## Run readme updater ##
docker run -v $PWD/docs:/docs \
  -e RELEASE="$KASM_RELEASE" \
  -e QUAY_API_KEY="$QUAY_API_KEY" \
  -e QUAY_REPOSITORY="${MIRROR_ORG_NAME}/${NAME}" \
  kasmweb/dockerhub-updater:develop
