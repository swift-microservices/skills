---
type: regex
target: { source: file, path: .github/workflows/builds.yml }
pattern: 'swift\s+test|continue-on-error|\|\|\s*true'
match: not_contains
---
