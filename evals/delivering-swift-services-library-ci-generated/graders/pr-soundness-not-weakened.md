---
type: regex
target: { source: file, path: .github/workflows/pull_request.yml }
pattern: '(?<!api_breakage)_check_enabled:\s*false'
match: not_contains
---
