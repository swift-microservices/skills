---
type: regex
target: { source: file, path: .github/workflows/main.yml }
pattern: 'check-foundation-linking'
match: not_contains
---
