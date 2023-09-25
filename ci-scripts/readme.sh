#! /bin/bash

## Parse input ##
NAME=$1

## Run readme updater ##
docker run -v $PWD/docs:/docs \
  -e RELEASE="$KASM_RELEASE" \
  -e DOCKER_USERNAME="$README_USERNAME" \
  -e DOCKER_PASSWORD="$README_PASSWORD" \
  -e DOCKERHUB_REPOSITORY="${ORG_NAME}/${NAME}" \
  kasmweb/dockerhub-updater:develop
