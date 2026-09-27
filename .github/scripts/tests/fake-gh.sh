#!/bin/bash
# Offline GitHub CLI fixture. Its state lives outside the test Git repository.
set -euo pipefail
state=${FAKE_GH_STATE:?}
call=$(printf '%s\n' "$@" | jq -Rsc 'split("\n")[:-1]')
jq --argjson call "$call" '.calls += [$call]' "$state" > "$state.tmp"
mv "$state.tmp" "$state"
case "$*" in
  api*'/releases/latest') jq '{tag_name: .latest}' "$state" ;;
  'api --paginate '*) jq '.pages' "$state" ;;
  api*'/releases/generate-notes '*)
    [[ $(jq -r '.fail_notes // false' "$state") == false ]] || exit 1
    jq -n '{body: "## SemVer Patch\nGenerated notes\n"}'
    ;;
  'release create '*)
    if [[ $(jq -r '.fail_publish // false' "$state") == true ]]; then
      jq '.fail_publish = false' "$state" > "$state.tmp"
      mv "$state.tmp" "$state"
      exit 1
    fi
    version=$3
    verified=false
    notes=''
    while [[ $# -gt 0 ]]; do
      case $1 in
        --verify-tag) verified=true; shift ;;
        --notes-file) notes=$(cat "$2"); shift 2 ;;
        *) shift ;;
      esac
    done
    $verified || exit 1
    jq --arg version "$version" --arg notes "$notes" '.latest = $version | .notes = $notes' "$state" > "$state.tmp"
    mv "$state.tmp" "$state"
    ;;
  *) echo "Unexpected gh command: $*" >&2; exit 1 ;;
esac
