#!/bin/bash

set -xe

echo 'SourceGraph is no longer OSS.'
exit 1

cd "$(git rev-parse --show-toplevel)"

[ -n "$docker_username" ]
[ -n "$docker_password" ]
[ -n "$docker_repo" ]

docker login --username "$docker_username" --password "$docker_password"

tag="$(cat .latest_version)"

curl "https://hub.docker.com/v2/repositories/${docker_username}/${docker_repo}/tags" -o /tmp/docker_tags.json

if jq -r '.results[] | .name' /tmp/docker_tags.json | grep -E "^${tag}$"; then
  echo "======================================
=  Tag '$tag' already in docker hub  =
======================================"
  exit 0
fi

export IMAGE="$docker_username/$docker_repo"
export VERSION="$tag"

cd sourcegraph

git fetch origin refs/tags/$tag:refs/tags/$tag
git checkout "tags/$tag" -b "$tag-release-branch-$docker_username"

if [ 'Linux' == "$(uname -s)" ]; then
  sudo apt-get install musl-tools
fi

cd cmd/server
./pre-build.sh
./build.sh

docker tag "${docker_username}/${docker_repo}:latest" "${docker_username}/${docker_repo}:${tag}"
docker tag "${docker_username}/${docker_repo}:latest" "${docker_username}/${docker_repo}:${tag}-oss"

docker push --all-tags "${docker_username}/${docker_repo}"

echo '===========
=  Done!  =
==========='
