#!/bin/sh
# image-digest.sh: print the digest a Docker Hub tag points to, to pin an image by digest.
# US-17 (#127). Usage: sh scripts/image-digest.sh <repository> <tag>
#   sh scripts/image-digest.sh library/alpine 3.24.3
# Official images live under library/. Prints the multi-architecture index digest, which is what
# "docker pull" reports, so the pin works on both amd64 and arm64 hosts.
set -eu

if [ $# -ne 2 ]; then
  echo "usage: sh scripts/image-digest.sh <repository> <tag>   e.g. library/alpine 3.24.3" >&2
  exit 2
fi
repo=$1 tag=$2

token=$(curl -fsS -m 20 "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$repo:pull" \
  | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
[ -n "$token" ] || { echo "image-digest: no registry token for $repo" >&2; exit 1; }

digest=$(curl -fsSI -m 20 -H "Authorization: Bearer $token" \
  -H "Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json" \
  "https://registry-1.docker.io/v2/$repo/manifests/$tag" | tr -d '\r' | awk -F': ' 'tolower($1)=="docker-content-digest" {print $2}')
[ -n "$digest" ] || { echo "image-digest: no digest for $repo:$tag" >&2; exit 1; }
echo "$digest"
