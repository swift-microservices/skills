---
type: regex
target: { source: file, path: .github/workflows/pull_request.yml }
pattern: 'unit_tests\.yml'
match: not_contains
---
