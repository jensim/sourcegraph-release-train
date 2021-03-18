#!/bin/bash

set -xe

cd "$(git rev-parse --show-toplevel)"

source '.env'

[ -n "$tag" ]
[ -n "$docker_hub_user" ]
[ -n "$docker_hub_repo" ]

export IMAGE="$docker_hub_user/$docker_hub_repo"
export VERSION="$TAG-oss"

cd sourcegraph

git fetch --all --tags
git checkout "tags/$tag" -b "$tag-release-branch-$docker_hub_user"

cd cmd/server
./pre-build.sh
./build.sh


echo '===========
=  Done!  =
==========='
