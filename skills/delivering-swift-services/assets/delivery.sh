#!/bin/bash
# Local delivery, the same steps as CI: publish a main commit's image once as :<commit-sha>, deploy
# it by digest to staging, and to production only after staging ran it. The Makefile sets
# IMAGE_REPOSITORY; the rest comes from the environment or .env.
# Usage: delivery.sh publish|stage|deploy [commit]
set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "error: $*" >&2
  exit 1
}

# A value from the environment, else from .env, without sourcing .env.
setting() {
  local value=${!1:-}
  if [ -z "$value" ] && [ -f .env ]; then
    value=$(sed -n "s/^$1=//p" .env | tail -n 1 | sed 's/^"\(.*\)"$/\1/')
  fi
  printf '%s' "$value"
}

command=${1:-}
commit=$(git rev-parse --verify "${2:-HEAD}^{commit}") || fail "unknown commit ${2:-HEAD}"
short=${commit:0:7}
: "${IMAGE_REPOSITORY:?run through make}"
registry_path=${IMAGE_REPOSITORY#ghcr.io/}

# The digest of :<commit> in GHCR, or nothing when it is not published. The registry credentials
# come from ~/.netrc (machine ghcr.io).
image_digest() {
  local token
  token=$(curl --fail --silent --show-error --netrc \
    "https://ghcr.io/token?service=ghcr.io&scope=repository:$registry_path:pull" | jq -r '.token // empty')
  [ -n "$token" ] || fail "GHCR refused the credentials for ghcr.io in ~/.netrc"
  curl --silent --head --header "Authorization: Bearer $token" \
    --header 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json' \
    "https://ghcr.io/v2/$registry_path/manifests/$commit" |
    awk 'tolower($1) == "docker-content-digest:" { print $2 }' | tr -d '\r'
}

publish() {
  [ "$commit" = "$(git rev-parse HEAD)" ] || fail "publish builds HEAD; check out $short first"
  [ -z "$(git status --porcelain)" ] || fail "the working tree has changes; the image must be exactly the commit"
  git fetch --quiet origin main
  git merge-base --is-ancestor "$commit" origin/main || fail "$short is not on origin/main; images are published only from main"
  # A commit's tag is written once, so a rebuild never replaces the image staging ran.
  local digest
  digest=$(image_digest)
  if [ -n "$digest" ]; then
    echo "$IMAGE_REPOSITORY:$commit is already published"
    return
  fi
  docker buildx build --platform linux/arm64 --secret id=netrc,src="$HOME/.netrc" \
    --label "org.opencontainers.image.revision=$commit" \
    --tag "$IMAGE_REPOSITORY:$commit" --push .
}

# Deploys the commit's image to each application in order, waiting for each to finish.
deploy_to() {
  local environment=$1 ids=$2
  local url token digest image api id name previous result request code attempt deadline deployment status
  url=$(setting DOKPLOY_URL)
  token=$(setting DOKPLOY_TOKEN)
  if [ -z "$token" ] && [ -n "$(setting DOKPLOY_TOKEN_FILE)" ]; then
    token=$(tr -d '[:space:]' < "$(setting DOKPLOY_TOKEN_FILE)")
  fi
  [ -n "$url" ] || fail "set DOKPLOY_URL in .env"
  [ -n "$token" ] || fail "set DOKPLOY_TOKEN_FILE (or DOKPLOY_TOKEN) in .env"
  [ -n "$ids" ] || fail "set the $environment application IDs in .env"
  api="${url%/}/api"

  digest=$(image_digest)
  case "$digest" in
    sha256:*) ;;
    *) fail "$IMAGE_REPOSITORY has no image for $short; run make publish" ;;
  esac
  image="$IMAGE_REPOSITORY:$commit@$digest"

  # Every ID must name an application before any of them changes.
  local names=()
  for id in $ids; do
    name=$(curl --fail --silent --header "x-api-key: $token" "$api/application.one?applicationId=$id" |
      jq -r '.name // empty' 2>/dev/null) || name=""
    [ -n "$name" ] || fail "Dokploy has no application $id that this token can read"
    names+=("$name")
  done

  # Production runs only a commit that every staging application deployed successfully.
  if [ "$environment" = production ]; then
    for id in $(setting STAGING_APPLICATION_IDS); do
      curl --fail --silent --header "x-api-key: $token" "$api/deployment.allByType?id=$id&type=application" |
        jq -e --arg title "$short" 'any(.[]; .title == $title and .status == "done")' > /dev/null ||
        fail "staging application $id has no successful deployment of $short; run make stage first"
    done
  fi

  echo "Deploying $short ($IMAGE_REPOSITORY@$digest) to $environment"
  local i=0
  for id in $ids; do
    name=${names[$i]}
    i=$((i + 1))
    previous=$(curl --fail --silent --header "x-api-key: $token" "$api/deployment.allByType?id=$id&type=application" |
      jq -r '.[0].deploymentId // ""')
    result=$(curl --fail --silent --header "x-api-key: $token" --header 'Content-Type: application/json' \
      --data "$(jq -nc --arg id "$id" --arg image "$image" '{applicationId: $id, dockerImage: $image}')" \
      "$api/application.update") || result=""
    [ "$result" = true ] || fail "Dokploy did not set the image of $name"

    # Dokploy queues each application's deployments, so asking twice is harmless.
    request=$(jq -nc --arg id "$id" --arg title "$short" --arg description "$commit make $environment" \
      '{applicationId: $id, title: $title, description: $description}')
    for attempt in 1 2 3 4 5; do
      code=$(curl --silent --output /dev/null --write-out '%{http_code}' --max-time 120 \
        --header "x-api-key: $token" --header 'Content-Type: application/json' \
        --data "$request" "$api/application.deploy") || code="no response"
      case "$code" in
        200) break ;;
        429|5??|"no response") ;;
        *) fail "Dokploy refused to deploy $name (HTTP $code)" ;;
      esac
      [ "$attempt" -lt 5 ] || fail "Dokploy did not accept the deployment of $name ($code)"
      sleep $((attempt * 15))
    done

    # Wait for a deployment newer than the one before the request to finish.
    deadline=$((SECONDS + 900))
    status=""
    while [ "$SECONDS" -lt "$deadline" ]; do
      sleep 5
      deployment=$(curl --fail --silent --header "x-api-key: $token" \
        "$api/deployment.allByType?id=$id&type=application" | jq -c '.[0] // {}') || continue
      [ "$(jq -r '.deploymentId // ""' <<< "$deployment")" != "$previous" ] || continue
      status=$(jq -r '.status // ""' <<< "$deployment")
      case "$status" in
        "done") break ;;
        error|cancelled) fail "Dokploy's deployment of $name ended $status; its log is in Dokploy" ;;
      esac
    done
    [ "$status" = "done" ] || fail "Dokploy's deployment of $name did not finish within 15 minutes"
    echo "$name runs $short"
  done
}

case "$command" in
  publish) publish ;;
  stage) deploy_to staging "$(setting STAGING_APPLICATION_IDS)" ;;
  deploy) deploy_to production "$(setting PRODUCTION_APPLICATION_IDS)" ;;
  *) fail "usage: $0 publish|stage|deploy [commit]" ;;
esac
