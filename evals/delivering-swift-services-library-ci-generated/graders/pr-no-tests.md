---
type: regex
target: { source: file, path: .github/workflows/pull_request.yml }
pattern: 'unit_tests\.yml|swift\s+test'
match: not_contains
---
