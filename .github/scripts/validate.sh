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
  # A folded (>-), literal (|), or plain multi-line description continues on indented lines.
  description=$(awk '
    /^description:/ {
      found = 1
      value = $0
      sub(/^description:[[:space:]]*/, "", value)
      sub(/[[:space:]]+$/, "", value)
      if (value ~ /^[>|][-+0-9]*$/) value = ""
      next
    }
    found && /^[[:space:]]+[^[:space:]]/ {
      line = $0
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      value = value == "" ? line : value " " line
      next
    }
    found { exit }
    END {
      if (value ~ /^".*"$/ || value ~ /^\047.*\047$/) value = substr(value, 2, length(value) - 2)
      print value
    }
  ' <<< "$frontmatter")
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
  if [[ $description == *[\<\>]* ]]; then
    fail "$skill" 'description must not contain angle brackets'
  fi
  body_lines=$(awk 'NR > 1 && $0 == "---" && !body {body = 1; next} body {n++} END {print n + 0}' "$skill")
  if [[ -z $(tail -c 1 "$skill") || $body_lines == 0 ]]; then
    body_lines=$((body_lines + 1))
  fi
  [[ $body_lines -le 500 ]] || fail "$skill" "body is $body_lines lines; keep it under 500"
  # Estimate tokens as words x 1.3; Claude Code keeps the first 5,000 tokens after compaction.
  body_words=$(awk 'NR > 1 && $0 == "---" && !body {body = 1; next} body' "$skill" | wc -w | tr -d ' ')
  body_tokens=$((body_words * 13 / 10))
  if [[ $body_tokens -gt 5000 ]]; then
    fail "$skill" "body is about $body_tokens tokens; keep it under 5,000"
  elif [[ $body_tokens -gt 4000 ]]; then
    echo "warning: $skill: body is about $body_tokens tokens; aim for 4,000 or fewer" >&2
  fi

  # Each skill needs three positive eval cases; a model-invoked skill also needs a negative one.
  positives=0
  negatives=0
  for case_dir in evals/"$name"-*; do
    [[ -f $case_dir/prompt.md ]] || continue
    case ${case_dir##*/} in
      *-not-for-*)
        if [[ -f $case_dir/graders/skill-not-fired.md ]] && grep -q "$name" "$case_dir/graders/skill-not-fired.md"; then
          negatives=$((negatives + 1))
        fi
        ;;
      *) positives=$((positives + 1)) ;;
    esac
  done
  [[ $positives -ge 3 ]] || fail "$skill" "has $positives positive eval cases; add at least 3"
  if ! grep -q '^disable-model-invocation:[[:space:]]*true' <<< "$frontmatter" && [[ $negatives -lt 1 ]]; then
    fail "$skill" 'has no -not-for- eval case with a skill-not-fired grader naming the skill'
  fi

  while IFS= read -r doc; do
    [[ -f $doc ]] || continue
    if [[ $doc != "$skill" && $(wc -l < "$doc") -gt 100 ]] && ! head -n 15 "$doc" | grep -q '^## Contents'; then
      fail "$doc" 'over 100 lines with no ## Contents section in its first 15 lines'
    fi
    while IFS= read -r target; do
      if [[ $doc == "$skill" && $target == *\\* ]]; then
        fail "$doc" "Windows-style path '$target'"
      fi
      case $target in http://*|https://*|mailto:*) continue ;; esac
      if [[ $target == /* ]]; then resolved=$target; else resolved="${doc%/*}/$target"; fi
      [[ -e $resolved ]] || fail "$doc" "link to missing file '$target'"
      if [[ $target == ../* ]]; then
        : # a sibling skill's file; it only has to exist
      elif [[ $doc == "$skill" ]]; then
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

# These checks are offline; live Claude evals remain an explicit local run.
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
if ! python3 - <<'PY'
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    yaml = None


def parse(text):
    if yaml:
        return yaml.safe_load(text)
    # Without PyYAML, accept top-level `key: value` lines and skip indented or list continuations.
    data = {}
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith('#') or line[0] in ' \t-':
            continue
        match = re.match(r'^([A-Za-z_][\w-]*):(?:\s+(.*))?$', line)
        if not match:
            raise ValueError(f'cannot parse {line!r}')
        data[match.group(1)] = match.group(2)
    return data


ok = True
for path in sorted(Path('evals').glob('*/prompt.md')):
    match = re.match(r'---\n(.*?)\n---\n', path.read_text(), re.S)
    try:
        data = parse(match.group(1)) if match else 'no frontmatter'
    except Exception as error:
        data = error
    if not isinstance(data, dict):
        print(f'{path}: frontmatter does not parse: {data}', file=sys.stderr)
        ok = False
    elif 'allowed_tools' not in data:
        print(f'{path}: frontmatter has no allowed_tools', file=sys.stderr)
        ok = False
for path in sorted(Path('evals').glob('*/case.yaml')):
    try:
        data = parse(path.read_text())
    except Exception as error:
        data = error
    if not isinstance(data, dict):
        print(f'{path}: does not parse: {data}', file=sys.stderr)
        ok = False
sys.exit(0 if ok else 1)
PY
then
  fail evals 'invalid eval case frontmatter'
fi
[[ $failures == 0 ]] || exit 1
echo "OK: $count skills and eval script syntax validated"
