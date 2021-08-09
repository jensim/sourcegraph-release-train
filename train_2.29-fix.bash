#!/bin/bash

set -xe

cd "$(git rev-parse --show-toplevel)"

[ -n "$docker_username" ]
[ -n "$docker_password" ]
[ -n "$docker_repo" ]

docker login --username "$docker_username" --password "$docker_password"

tag='v3.29.0'

export IMAGE="$docker_username/$docker_repo"
export VERSION="2.29.fix-oss"

cd sourcegraph

git fetch origin "refs/tags/$tag:refs/tags/$tag"
git checkout "tags/$tag" -b "$tag-release-branch-$docker_username"

if [ 'Linux' == "$(uname -s)" ]; then
  sudo apt-get install musl-tools
fi

cd cmd/server
./pre-build.sh

sed -i 's|additional_images+=("github.com/sourcegraph/sourcegraph/cmd/frontend" "github.com/sourcegraph/sourcegraph/cmd/repo-updater")|additional_images+=("github.com/sourcegraph/sourcegraph/cmd/frontend" "github.com/sourcegraph/sourcegraph/cmd/worker" "github.com/sourcegraph/sourcegraph/cmd/repo-updater")|g' build.sh

./build.sh

docker tag "${docker_username}/${docker_repo}:latest" "${docker_username}/${docker_repo}:${VERSION}"

docker push "${docker_username}/${docker_repo}:${VERSION}"

echo '===========
=  Done!  =
==========='
