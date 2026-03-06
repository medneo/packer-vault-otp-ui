#!/bin/bash
set -e

# Load pre-pulled Docker images. Required for deterministic AMI builds.
if [ -z "${DOCKER_IMAGES_TAR_PATH:-}" ] || [ ! -f "${DOCKER_IMAGES_TAR_PATH}" ] || [ ! -s "${DOCKER_IMAGES_TAR_PATH}" ]; then
  echo "ERROR: Docker images tar is required but missing or empty at ${DOCKER_IMAGES_TAR_PATH:-<unset>}"
  exit 1
fi
echo "Loading Docker images from ${DOCKER_IMAGES_TAR_PATH}..."
sudo docker load -i "${DOCKER_IMAGES_TAR_PATH}"
