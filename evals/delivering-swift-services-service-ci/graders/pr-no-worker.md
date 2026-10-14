---
type: regex
target: { source: file, path: .github/workflows/pull_request.yml }
pattern: 'worker:\s*true'
match: not_contains
---
