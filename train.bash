#!/bin/bash

set -xe

cd "$(git rev-parse --show-toplevel)"

source '.env'

[ -n "$tag" ]
[ -n "$docker_hub_user" ]
[ -n "$docker_hub_repo" ]

export IMAGE="$docker_hub_user/$docker_hub_repo"
export VERSION="$tag-oss"

if ! [ -d sourcegraph ]; then
  git clone git@github.com:sourcegraph/sourcegraph.git
fi
cd sourcegraph

git fetch --all --tags
git checkout "tags/$tag" -b "$tag-release-branch-$docker_hub_user" || echo foo >/dev/null

if [ 'Linux' == "$(uname -s)" ]; then
  sudo apt-get install musl-tools
fi

cd cmd/server
./pre-build.sh
./build.sh

docker image tag "${docker_hub_user}/${docker_hub_repo}:latest" "${docker_hub_user}/${docker_hub_repo}:${tag}"
docker image tag "${docker_hub_user}/${docker_hub_repo}:latest" "${docker_hub_user}/${docker_hub_repo}:${VERSION}"

docker image push --all-tags "${docker_hub_user}/${docker_hub_repo}:latest"

echo '===========
=  Done!  =
==========='
