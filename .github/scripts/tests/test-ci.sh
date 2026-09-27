#!/bin/bash
# Exercise the CI helpers against temporary local Git remotes, without network.
# jq expressions and generated fixture code intentionally contain literal variables.
# shellcheck disable=SC2016
set -euo pipefail
root=$(cd "$(dirname "$0")/../../.." && pwd)
suite_tmp=$(mktemp -d)
trap 'rm -rf "$suite_tmp"' EXIT

git_cmd() { git -C "$repo" "$@"; }
assert_equal() {
  [[ $1 == "$2" ]] || { echo "Expected '$2', got '$1'" >&2; return 1; }
}
assert_contains() {
  [[ $1 == *"$2"* ]] || { echo "Expected text to contain '$2': $1" >&2; return 1; }
}
state_update() {
  jq "$@" "$state" > "$state.tmp"
  mv "$state.tmp" "$state"
}
setup() {
  case_dir="$suite_tmp/$test"
  repo="$case_dir/repo"
  remote="$case_dir/remote.git"
  state="$case_dir/github.json"
  mkdir -p "$repo/.github/scripts" "$repo/skills/example" "$repo/.claude-plugin" "$repo/.codex-plugin" "$case_dir/bin"
  git_cmd init --initial-branch=main
  git_cmd config user.name 'Release Test'
  git_cmd config user.email test@example.invalid
  git_cmd config commit.gpgsign false
  git_cmd config tag.gpgsign false
  cp "$root/.github/scripts/create-release.sh" "$root/.github/scripts/validate.sh" "$repo/.github/scripts/"
  printf '%s\n' '---' 'name: example' 'description: Example. Use when testing.' '---' 'Example.' > "$repo/skills/example/SKILL.md"
  for manifest in .claude-plugin/plugin.json .codex-plugin/plugin.json; do
    jq -n '{name: "example", version: "0.3.0"}' > "$repo/$manifest"
  done
  git_cmd add .
  git_cmd commit -m 'Initial release'
  git_cmd tag -a 0.3.0 -m 'Version 0.3.0'
  git_cmd init --bare "$remote"
  git_cmd remote add origin "$remote"
  git_cmd push origin main --tags
  initial=$(git_cmd rev-parse HEAD)
  jq -n '{latest: "0.3.0", pages: [[]], calls: []}' > "$state"
  cp "$root/.github/scripts/tests/fake-gh.sh" "$case_dir/bin/gh"
  chmod +x "$case_dir/bin/gh"
  export PATH="$case_dir/bin:$PATH" FAKE_GH_STATE="$state" GITHUB_REPOSITORY=example/skills GITHUB_REF=refs/heads/main GH_TOKEN=test-token
}
merged_pr() {
  local number=$1 labels='[]'
  shift
  if [[ $# -gt 0 ]]; then labels=$(printf '%s\n' "$@" | jq -Rsc 'split("\n")[:-1] | map({name: .})'); fi
  git_cmd switch -c "pr-$number"
  echo "Change $number" > "$repo/change-$number.txt"
  git_cmd add .
  git_cmd commit -m "Change $number"
  git_cmd switch main
  git_cmd merge --no-ff "pr-$number" -m "Merge PR #$number"
  git_cmd push origin main
  pr_json=$(jq -n --arg sha "$(git_cmd rev-parse HEAD)" --argjson labels "$labels" \
    '{merged_at: "2020-01-01T00:00:00Z", merge_commit_sha: $sha, labels: $labels}')
}
use_pr() { state_update --argjson pr "$pr_json" '.pages = [[$pr]]'; }
release() { (cd "$repo" && bash .github/scripts/create-release.sh "$@") > "$case_dir/output" 2>&1; }
expect_release_failure() {
  if release; then echo 'Expected release to fail' >&2; return 1; fi
}
validate() { (cd "$repo" && bash .github/scripts/validate.sh) > "$case_dir/output" 2>&1; }
expect_validation_failure() {
  if validate; then echo 'Expected validation to fail' >&2; return 1; fi
  assert_contains "$(cat "$case_dir/output")" "$1"
}
assert_version() {
  local version=$1 manifest
  assert_equal "$(git_cmd rev-parse "$version^{}")" "$(git_cmd ls-remote origin refs/heads/main | cut -f1)"
  for manifest in .claude-plugin/plugin.json .codex-plugin/plugin.json; do
    assert_equal "$(git_cmd show "$version:$manifest" | jq -r '.version')" "$version"
  done
  assert_equal "$(jq -r '.latest' "$state")" "$version"
  assert_contains "$(jq -r '.notes' "$state")" 'Generated notes'
}

test_patch() {
  merged_pr 1 '🔨 semver/patch'; use_pr
  release
  assert_version 0.3.1
  assert_equal "$(git_cmd log -1 --format=%s)" 'Version 0.3.1'
  assert_contains "$(jq -r '.calls[2][]' "$state")" 'configuration_file_path=.github/release.yml'
  assert_contains "$(jq -r '.calls[2][]' "$state")" 'previous_tag_name=0.3.0'
  refs=$(git_cmd ls-remote origin)
  release
  assert_equal "$(git_cmd ls-remote origin)" "$refs"
}
test_minor_and_pagination() {
  merged_pr 1 '🔨 semver/patch'; patch_pr=$pr_json
  merged_pr 2 '🆕 semver/minor'
  state_update --argjson patch "$patch_pr" --argjson minor "$pr_json" --arg initial "$initial" \
    '.pages = [[{merged_at: "2020-01-01", merge_commit_sha: $initial, labels: [{name: "⚠️ semver/major"}]}, $patch], [$minor]]'
  release
  assert_version 0.4.0
}
test_no_release() {
  merged_pr 1 semver/none; none_pr=$pr_json
  merged_pr 2
  state_update --argjson none "$none_pr" --argjson unlabeled "$pr_json" \
    '.pages = [[$none, $unlabeled, ($none | .merged_at = null | .labels = [{name: "🆕 semver/minor"}])]]'
  refs=$(git_cmd ls-remote origin)
  release
  assert_contains "$(cat "$case_dir/output")" 'No merged PRs'
  assert_equal "$(git_cmd ls-remote origin)" "$refs"
}
test_major() {
  merged_pr 1 '⚠️ semver/major' '🔨 semver/patch'; use_pr
  refs=$(git_cmd ls-remote origin)
  expect_release_failure
  assert_contains "$(cat "$case_dir/output")" manually
  assert_equal "$(git_cmd ls-remote origin)" "$refs"
  assert_equal "$(git_cmd status --porcelain)" ''
}
test_dry_run() {
  merged_pr 1 '🔨 semver/patch'; use_pr
  refs=$(git_cmd ls-remote origin)
  release --dry-run
  assert_contains "$(cat "$case_dir/output")" 0.3.1
  assert_equal "$(git_cmd ls-remote origin)" "$refs"
  assert_equal "$(git_cmd status --porcelain)" ''
  assert_equal "$(jq '.calls | length' "$state")" 2
}
test_publication_retry() {
  merged_pr 1 '🔨 semver/patch'; use_pr
  state_update '.fail_publish = true'
  expect_release_failure
  head=$(git_cmd rev-parse HEAD); refs=$(git_cmd ls-remote origin)
  release
  assert_version 0.3.1
  assert_equal "$(git_cmd rev-parse HEAD)" "$head"
  assert_equal "$(git_cmd ls-remote origin)" "$refs"
}
test_notes_failure() {
  merged_pr 1 '🔨 semver/patch'; use_pr
  state_update '.fail_notes = true'
  refs=$(git_cmd ls-remote origin); head=$(git_cmd rev-parse HEAD)
  expect_release_failure
  assert_equal "$(git_cmd ls-remote origin)" "$refs"
  assert_equal "$(git_cmd rev-parse HEAD)" "$head"
  assert_equal "$(git_cmd status --porcelain)" ''
}
test_manifest_mismatch() {
  merged_pr 1 '🔨 semver/patch'; use_pr
  jq -n '{name: "example", version: "0.4.0"}' > "$repo/.codex-plugin/plugin.json"
  git_cmd add .; git_cmd commit -m 'Incorrect version'; git_cmd push origin main
  refs=$(git_cmd ls-remote origin)
  expect_release_failure
  assert_contains "$(cat "$case_dir/output")" 'Both manifests'
  assert_equal "$(git_cmd ls-remote origin)" "$refs"
  expect_validation_failure 'version must match'
}
test_tag_collision() {
  merged_pr 1 '🔨 semver/patch'; use_pr
  git_cmd tag 0.3.1 "$initial"; git_cmd push origin refs/tags/0.3.1
  refs=$(git_cmd ls-remote origin)
  expect_release_failure
  assert_contains "$(cat "$case_dir/output")" 'will not be moved'
  assert_equal "$(git_cmd ls-remote origin)" "$refs"
}
test_stale_main_and_wrong_branch() {
  merged_pr 1 '🔨 semver/patch'; use_pr
  git_cmd push origin "$initial:refs/heads/main" --force
  refs=$(git_cmd ls-remote origin)
  expect_release_failure
  assert_contains "$(cat "$case_dir/output")" 'origin/main has changed'
  assert_equal "$(git_cmd ls-remote origin)" "$refs"
  git_cmd switch pr-1
  expect_release_failure
  assert_contains "$(cat "$case_dir/output")" 'must run on main'
}
test_atomic_push() {
  merged_pr 1 '🔨 semver/patch'; use_pr
  printf '%s\n' '#!/bin/sh' '[ "$1" != "refs/heads/main" ]' > "$remote/hooks/update"
  chmod +x "$remote/hooks/update"
  refs=$(git_cmd ls-remote origin)
  expect_release_failure
  assert_equal "$(git_cmd ls-remote origin)" "$refs"
  assert_equal "$(jq -r '.latest' "$state")" 0.3.0
}
test_validation_frontmatter_and_description() {
  validate
  printf '%s\n' '# No frontmatter' > "$repo/skills/example/SKILL.md"
  expect_validation_failure 'no YAML frontmatter'
  printf '%s\n' '---' 'name: different' 'description: Use when you need it.' '---' 'Body.' > "$repo/skills/example/SKILL.md"
  expect_validation_failure 'does not match its directory'
  assert_contains "$(cat "$case_dir/output")" 'third person'
}
test_validation_links_and_budgets() {
  printf '%s\n' '[Missing](references/missing.md)' '[Windows](references\file.md)' >> "$repo/skills/example/SKILL.md"
  expect_validation_failure 'link to missing file'
  assert_contains "$(cat "$case_dir/output")" Windows-style
  mkdir -p "$repo/skills/example/references/nested"
  printf '%s\n' '# Reference' > "$repo/skills/example/references/nested/example.md"
  printf '%s\n' '[Nested](references/nested/example.md)' >> "$repo/skills/example/SKILL.md"
  expect_validation_failure 'nests deeper'
  awk 'BEGIN {for (i = 0; i < 501; i++) print "Body"}' >> "$repo/skills/example/SKILL.md"
  expect_validation_failure 'keep it under 500'
  awk 'BEGIN {for (i = 0; i < 101; i++) print "Reference"}' > "$repo/skills/example/references/long.md"
  expect_validation_failure 'no ## Contents'
}
test_validation_versions() {
  jq -n '{version: "01.2.3"}' > "$repo/.claude-plugin/plugin.json"
  expect_validation_failure 'stable semantic version'
  echo '{' > "$repo/.claude-plugin/plugin.json"
  expect_validation_failure 'cannot read a plugin version'
}

failed=0
passed=0
for test in test_patch test_minor_and_pagination test_no_release test_major test_dry_run \
  test_publication_retry test_notes_failure test_manifest_mismatch test_tag_collision \
  test_stale_main_and_wrong_branch test_atomic_push test_validation_frontmatter_and_description \
  test_validation_links_and_budgets test_validation_versions; do
  set +e
  (set -e; setup; "$test") > "$suite_tmp/$test.log" 2>&1
  status=$?
  set -e
  if [[ $status == 0 ]]; then
    echo "PASS: $test"
    passed=$((passed + 1))
  else
    echo "FAIL: $test" >&2
    cat "$suite_tmp/$test.log" >&2
    if [[ -f $suite_tmp/$test/output ]]; then cat "$suite_tmp/$test/output" >&2; fi
    failed=$((failed + 1))
  fi
done
echo "$passed passed; $failed failed"
[[ $failed == 0 ]]
