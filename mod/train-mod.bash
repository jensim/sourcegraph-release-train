#!/bin/bash

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

mkdir -p mod
openssl genrsa -out /tmp/key.pem 2048
chmod 0700 /tmp/key.pem
ssh-keygen -f /tmp/key.pem -y > mod/key.pub
rm -f mod/key.pem
mv /tmp/key.pem mod/key.pem

git add mod/key.pem mod/key.pub

export IMAGE="$docker_username/$docker_repo"
export VERSION="$tag-mod"
export SOURCEGRAPH_LICENSE_GENERATION_KEY="$PWD/mod/key.pem"

cd sourcegraph

git fetch origin refs/tags/$tag:refs/tags/$tag
git checkout "tags/$tag" -b "$tag-release-branch-$docker_username"

if [ 'Linux' == "$(uname -s)" ]; then
  sudo apt-get install musl-tools
fi

sed -i "s|const publicKeyData = \`ssh-rsa .*$|const publicKeyData = \`$(cat ../mod/key.pub)\`|" 'enterprise/internal/licensing/licensing.go'
rm -f ../mod/license.txt
go run enterprise/internal/license/generate-license.go -private-key "$SOURCEGRAPH_LICENSE_GENERATION_KEY" -tags=dev,enterprise-test,plan:enterprise-0 -users=1000000 -expires=878400h > license.txt
cd ..
mv sourcegraph/license.txt mod/license.txt
git add mod/license.txt
cd sourcegraph

./enterprise/cmd/server/pre-build.sh
./enterprise/cmd/server/build.sh

docker tag "${docker_username}/${docker_repo}:latest" "${docker_username}/${docker_repo}:${tag}"
docker tag "${docker_username}/${docker_repo}:latest" "${docker_username}/${docker_repo}:${VERSION}"

docker push --all-tags "${docker_username}/${docker_repo}"

cd ..
git config --local user.email "jensim+github-actions[bot]@users.noreply.github.com"
git config --local user.name "jensim-github-actions[bot]"
git commit -m "Regen license" -a

echo '===========
=  Done!  =
==========='

