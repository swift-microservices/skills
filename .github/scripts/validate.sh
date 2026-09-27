#!/bin/bash
# Validate skill structure, reference links and synchronized plugin versions.
set -euo pipefail
cd "$(dirname "$0")/../.."

failures=0
count=0
fail() {
  echo "$1: $2" >&2
  failures=$((failures + 1))
}

links() {
  awk '{
    line = $0
    while (match(line, /\]\([^)]*\)/)) {
      target = substr(line, RSTART + 2, RLENGTH - 3)
      sub(/#.*/, "", target)
      if (target != "") print target
      line = substr(line, RSTART + RLENGTH)
    }
  }' "$1"
}

for skill_dir in skills/*; do
  [[ -d $skill_dir ]] || continue
  count=$((count + 1))
  skill="$skill_dir/SKILL.md"
  if [[ ! -f $skill ]]; then
    fail "$skill_dir" 'no SKILL.md'
    continue
  fi
  if ! frontmatter=$(awk '
    NR == 1 { if ($0 != "---") exit 1; next }
    $0 == "---" { closed = 1; exit }
    { print }
    END { if (!closed) exit 1 }
  ' "$skill"); then
    fail "$skill" 'no YAML frontmatter'
    continue
  fi
  name=$(awk '/^name:/ {sub(/^name:[[:space:]]*/, ""); sub(/[[:space:]]*$/, ""); print; exit}' <<< "$frontmatter")
  description=$(awk '/^description:/ {sub(/^description:[[:space:]]*/, ""); sub(/[[:space:]]*$/, ""); print; exit}' <<< "$frontmatter")
  if [[ ! $name =~ ^[a-z0-9-]+$ || ${#name} -gt 64 ]]; then
    fail "$skill" 'name must be 1-64 lowercase letters, digits, or hyphens'
  fi
  [[ $name == "${skill_dir##*/}" ]] || fail "$skill" "name '$name' does not match its directory"
  case $name in *anthropic*|*claude*) fail "$skill" 'name contains a reserved word' ;; esac
  if [[ -z $description || ${#description} -gt 1024 ]]; then
    fail "$skill" 'description must be 1-1024 characters'
  fi
  if [[ $description =~ (^|[^[:alnum:]_])(I|you|we)($|[^[:alnum:]_]) ]]; then
    fail "$skill" 'description must be written in the third person'
  fi
  [[ $description == *'Use when'* ]] || fail "$skill" 'description must say when to use the skill ("Use when ...")'
  body_lines=$(awk 'NR > 1 && $0 == "---" && !body {body = 1; next} body {n++} END {print n + 0}' "$skill")
  if [[ -z $(tail -c 1 "$skill") || $body_lines == 0 ]]; then
    body_lines=$((body_lines + 1))
  fi
  [[ $body_lines -le 500 ]] || fail "$skill" "body is $body_lines lines; keep it under 500"

  while IFS= read -r doc; do
    [[ -f $doc ]] || continue
    if [[ $doc != "$skill" && $(wc -l < "$doc") -gt 100 ]] && ! grep -q '## Contents' "$doc"; then
      fail "$doc" 'over 100 lines with no ## Contents section'
    fi
    while IFS= read -r target; do
      if [[ $doc == "$skill" && $target == *\\* ]]; then
        fail "$doc" "Windows-style path '$target'"
      fi
      case $target in http://*|https://*|mailto:*) continue ;; esac
      if [[ $target == /* ]]; then resolved=$target; else resolved="${doc%/*}/$target"; fi
      [[ -e $resolved ]] || fail "$doc" "link to missing file '$target'"
      if [[ $doc == "$skill" ]]; then
        parts=$(awk -F/ '{for (i = 1; i <= NF; i++) if ($i != "" && $i != ".") n++; print n + 0}' <<< "$target")
        [[ $parts -le 2 ]] || fail "$doc" "link '$target' nests deeper than one level"
      elif [[ $target == */* && $target != ../* ]]; then
        fail "$doc" "reference '$target' links another level down; link from SKILL.md instead"
      fi
    done < <(links "$doc")
  done < <(find "$skill_dir" -name '*.md' -print)
done

versions=()
for manifest in .claude-plugin/plugin.json .codex-plugin/plugin.json; do
  if version=$(jq -er '.version | select(type == "string")' "$manifest"); then
    [[ $version =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] \
      || fail "$manifest" 'version must be a stable semantic version'
    versions+=("$version")
  else
    fail "$manifest" 'cannot read a plugin version from the manifest'
  fi
done
if [[ ${#versions[@]} == 2 && ${versions[0]} != "${versions[1]}" ]]; then
  fail .codex-plugin/plugin.json 'version must match the Claude plugin manifest'
fi

# These checks are offline; live Codex/Claude evals remain an explicit local run.
for scaffold in evals/*/scaffold.sh; do
  [[ -f $scaffold ]] || continue
  bash -n "$scaffold" || fail "$scaffold" 'invalid Bash syntax'
done
if ! python3 - <<'PY'
import ast
from pathlib import Path

for path in Path('evals').glob('*/checks/*.py'):
    ast.parse(path.read_text(), filename=str(path))
PY
then
  fail evals 'invalid Python syntax'
fi
[[ $failures == 0 ]] || exit 1
echo "OK: $count skills and eval script syntax validated"
