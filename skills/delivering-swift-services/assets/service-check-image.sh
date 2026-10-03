#!/bin/bash
# Validate the final service image without contacting deployment infrastructure.
set -euo pipefail
image=${1:?image required}
product=${2:?service product required}
worker=${3:-false}

image_user=$(docker image inspect --format '{{.Config.User}}' "$image")
case "$image_user" in
  ""|root|root:*|0|0:*) echo 'Image must run as an unprivileged user' >&2; exit 1 ;;
esac

if linkage=$(docker run --rm --entrypoint ldd "$image" "/app/$product" 2>&1); then
  printf '%s\n' "$linkage"
  if [[ $linkage == *'not found'* ]]; then
    echo 'Runtime library missing from final image' >&2
    exit 1
  fi
elif [[ $linkage == *'not a dynamic executable'* || $linkage == *'statically linked'* ]]; then
  printf '%s\n' "$linkage"
else
  printf '%s\n' "$linkage" >&2
  exit 1
fi

docker run --rm "$image" --help
docker run --rm "$image" serve --help
if [[ $worker == true ]]; then
  docker run --rm "$image" worker run --help
fi
