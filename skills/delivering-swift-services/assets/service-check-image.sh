#!/bin/bash
# Validate the final service image without contacting deployment infrastructure.
# Usage: check-image.sh IMAGE PRODUCT [WORKER] [BINARY_PATH]
#   WORKER       true when the executable has `worker run` (default false)
#   BINARY_PATH  the executable's path inside the image (default /app/PRODUCT, the worked
#                Containerfile; a swift-container-plugin image puts it at /PRODUCT)
# ALLOW_ROOT_IMAGE=true skips the unprivileged-user check; set it only when AGENTS.md records
# that exception for an image tool that cannot set a user.
set -euo pipefail
image=${1:?image required}
product=${2:?service product required}
worker=${3:-false}
binary=${4:-/app/$product}

image_user=$(docker image inspect --format '{{.Config.User}}' "$image")
case "$image_user" in
  ""|root|root:*|0|0:*)
    if [[ ${ALLOW_ROOT_IMAGE:-false} == true ]]; then
      echo 'Image runs as root: allowed by the recorded project exception' >&2
    else
      echo 'Image must run as an unprivileged user' >&2
      exit 1
    fi
    ;;
esac

if linkage=$(docker run --rm --entrypoint ldd "$image" "$binary" 2>&1); then
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
