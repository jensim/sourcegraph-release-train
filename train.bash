#!/bin/bash

set -xe

cd "$(git rev-parse --show-toplevel)"

[ -n "$docker_username" ]
[ -n "$docker_password" ]
[ -n "$docker_repo" ]

docker login --username "$docker_username" --password "$docker_password"

curl https://api.github.com/repos/sourcegraph/sourcegraph/tags -o /tmp/sourcegraph_tags.json
tag="$(jq -r '.[] |.name' /tmp/sourcegraph_tags.json | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1)"

curl https://hub.docker.com/v2/repositories/jensim/sourcegraph-server-oss/tags -o /tmp/docker_tags.json

if jq -r '.results[] | .name' /tmp/docker_tags.json | grep "$tag" ; then
  echo "======================================
=  Tag '$tag' already in docker hub  =
======================================"
  exit 0
fi

export IMAGE="$docker_username/$docker_repo"
export VERSION="$tag-oss"

if ! [ -d sourcegraph ]; then
  git clone git@github.com:sourcegraph/sourcegraph.git
fi
cd sourcegraph

git checkout "tags/$tag" -b "$tag-release-branch-$docker_username" || echo foo >/dev/null

if [ 'Linux' == "$(uname -s)" ]; then
  sudo apt-get install musl-tools
fi

cd cmd/server
./pre-build.sh
./build.sh

image_line="$(docker image ls "${docker_username}/${docker_repo}:latest" | tail -n 1)"
image_id="$(sed  's/^[^ ]* *[^ ]* *\([^ ]*\).*$/\1/g' <<< "$image_line")"

docker image tag "${docker_username}/${docker_repo}:latest" "${docker_username}/${docker_repo}:${tag}"
docker image tag "${docker_username}/${docker_repo}:latest" "${docker_username}/${docker_repo}:${VERSION}"

docker image push --all-tags "${image_id}"

echo '===========
=  Done!  =
==========='
