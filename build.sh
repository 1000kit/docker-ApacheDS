#!/bin/bash

VERSION="2.0.0-M23"
IMAGE="1000kit/apacheds"

cd "$( dirname "${BASH_SOURCE[0]}" )"
pwd

echo "build base apacheds docker image"
docker build --force-rm -t ${IMAGE}:${VERSION} .

echo "tag image with version ${VERSION}"
docker tag ${IMAGE}:${VERSION} ${IMAGE}:latest


#end
