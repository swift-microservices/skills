#!/bin/bash
# Label-based releases, following apple/swift-temporal-sdk's create-release.sh.
# Requires authenticated gh, jq, Git, Python 3, GITHUB_REPOSITORY and GITHUB_REF.
set -euo pipefail

cd "$(dirname "$0")/../.."

fail() {
  echo "Release failed: $*" >&2
  exit 1
}

is_ancestor() {
  local status
  if git merge-base --is-ancestor "$1" "$2"; then
    return 0
  else
    status=$?
    [[ $status == 1 ]] || fail "Cannot inspect commit $1."
    return 1
  fi
}

require_current_main() {
  local remote_head
  remote_head=$(git ls-remote origin refs/heads/main | cut -f1)
  [[ $remote_head == "$head" ]] || fail "origin/main has changed; rerun the workflow on current main."
}

git_bot() {
  git -c 'user.name=github-actions[bot]' \
    -c 'user.email=41898282+github-actions[bot]@users.noreply.github.com' "$@"
}

dry_run=false
case "${1:-}" in
  --dry-run) dry_run=true ;;
  '') ;;
  *) fail "Usage: $0 [--dry-run]" ;;
esac
[[ $# -le 1 ]] || fail "Usage: $0 [--dry-run]"
[[ ${GITHUB_REPOSITORY:-} =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail "Set GITHUB_REPOSITORY to owner/repository."
[[ ${GITHUB_REF:-} == refs/heads/main && $(git branch --show-current) == main ]] || fail "Releases must run on main."
[[ -z $(git status --porcelain) ]] || fail "The working tree must be clean."
head=$(git rev-parse HEAD)
require_current_main

latest_tag=$(gh api "repos/$GITHUB_REPOSITORY/releases/latest" | jq -er '.tag_name')
current_version=${latest_tag#v}
if [[ $current_version =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  major=${BASH_REMATCH[1]}
  minor=${BASH_REMATCH[2]}
  patch=${BASH_REMATCH[3]}
else
  fail "Latest release $latest_tag is not a stable semantic version."
fi
is_ancestor "$latest_tag" "$head" || fail "The latest release tag is not an ancestor of main."

# Paginate and compare commits, so PRs are counted by the tag's contents rather
# than by publication time or the CLI's default page limit.
prs=$(gh api --paginate --slurp "repos/$GITHUB_REPOSITORY/pulls?state=closed&base=main&per_page=100")
pr_rows=$(jq -c '.[][] | select(.merged_at != null and .merge_commit_sha != null)' <<< "$prs")
bump='none'
while IFS= read -r pr; do
  [[ -n $pr ]] || continue
  commit=$(jq -r '.merge_commit_sha' <<< "$pr")
  [[ $commit =~ ^[0-9a-f]{40}$ ]] || fail "Invalid PR merge commit $commit."
  is_ancestor "$commit" "$head" || continue
  if is_ancestor "$commit" "$latest_tag"; then
    continue
  fi
  if jq -e 'any(.labels[]; .name == "⚠️ semver/major")' <<< "$pr" > /dev/null; then
    fail "Major releases must be created manually."
  elif jq -e 'any(.labels[]; .name == "🆕 semver/minor")' <<< "$pr" > /dev/null; then
    bump='minor'
  elif jq -e 'any(.labels[]; .name == "🔨 semver/patch")' <<< "$pr" > /dev/null && [[ $bump == none ]]; then
    bump='patch'
  fi
done <<< "$pr_rows"

case $bump in
  minor) new_version="$major.$((minor + 1)).0" ;;
  patch) new_version="$major.$minor.$((patch + 1))" ;;
  none) echo 'No merged PRs require a release.'; exit 0 ;;
esac
manifests=(.claude-plugin/plugin.json .codex-plugin/plugin.json)
claude_version=$(jq -er '.version' "${manifests[0]}")
codex_version=$(jq -er '.version' "${manifests[1]}")
[[ $claude_version == "$codex_version" && ( $claude_version == "$current_version" || $claude_version == "$new_version" ) ]] \
  || fail "Both manifests must match the latest release or the planned version."

# A publication retry may find the version commit and tag already pushed.
remote_tag=$(git ls-remote origin "refs/tags/$new_version" "refs/tags/$new_version^{}")
if [[ -n $remote_tag ]]; then
  tag_target=$(awk '$2 ~ /\^\{\}$/ {print $1}' <<< "$remote_tag")
  if [[ -z $tag_target ]]; then
    tag_target=$(awk '{print $1}' <<< "$remote_tag")
  fi
  [[ $tag_target == "$head" && $claude_version == "$new_version" ]] \
    || fail "Existing tag $new_version does not match this release; it will not be moved."
else
  [[ -z $(git tag --list "$new_version") ]] \
    || fail "Local tag $new_version already exists without a matching remote tag."
fi
echo "Release $latest_tag → $new_version"
if $dry_run; then
  exit 0
fi

temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT
gh api --method POST "repos/$GITHUB_REPOSITORY/releases/generate-notes" \
  -f "tag_name=$new_version" -f "previous_tag_name=$latest_tag" \
  -f "target_commitish=$head" -f configuration_file_path=.github/release.yml \
  | jq -er '.body' > "$temp_dir/notes.md"
require_current_main
if [[ -z $remote_tag ]]; then
  for manifest in "${manifests[@]}"; do
    jq --arg version "$new_version" '.version = $version' "$manifest" > "$temp_dir/manifest.json"
    cat "$temp_dir/manifest.json" > "$manifest"
  done
  python3 .github/scripts/validate.py
  git add -- "${manifests[@]}"
  if ! git diff --cached --quiet; then
    git_bot commit -m "Version $new_version"
  fi
  git_bot tag -a "$new_version" -m "Version $new_version"
  git push --atomic origin HEAD:refs/heads/main "refs/tags/$new_version"
fi
gh release create "$new_version" --repo "$GITHUB_REPOSITORY" --verify-tag --latest \
  --title "$new_version" --notes-file "$temp_dir/notes.md"
echo "Published $new_version."
