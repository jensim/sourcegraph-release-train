#!/bin/bash

set -xe

cd "$(git rev-parse --show-toplevel)"

[ -n "$docker_username" ]
[ -n "$docker_password" ]
[ -n "$docker_repo" ]

docker login --username "$docker_username" --password "$docker_password"

curl https://api.github.com/repos/sourcegraph/sourcegraph/tags -o /tmp/sourcegraph_tags.json
tag="$(jq -r '.[] |.name' /tmp/sourcegraph_tags.json | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1)"

curl "https://hub.docker.com/v2/repositories/${docker_username}/${docker_repo}/tags" -o /tmp/docker_tags.json

if jq -r '.results[] | .name' /tmp/docker_tags.json | grep -E "^${tag}$"; then
  echo "======================================
=  Tag '$tag' already in docker hub  =
======================================"
  exit 0
fi

export IMAGE="$docker_username/$docker_repo"
export VERSION="$tag-oss"

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
docker tag "${docker_username}/${docker_repo}:latest" "${docker_username}/${docker_repo}:${VERSION}"

docker push --all-tags "${docker_username}/${docker_repo}"

echo '===========
=  Done!  =
==========='
