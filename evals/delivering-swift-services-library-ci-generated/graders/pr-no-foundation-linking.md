---
type: regex
target: { source: file, path: .github/workflows/pull_request.yml }
pattern: 'check-foundation-linking'
match: not_contains
---
