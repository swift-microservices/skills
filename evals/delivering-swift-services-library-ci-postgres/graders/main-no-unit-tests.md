---
type: regex
target: { source: file, path: .github/workflows/main.yml }
pattern: 'unit_tests\.yml'
match: not_contains
---
