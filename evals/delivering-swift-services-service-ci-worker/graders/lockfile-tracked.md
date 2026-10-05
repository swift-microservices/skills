---
type: regex
target: { source: file, path: .gitignore }
pattern: 'Package\.resolved'
match: not_contains
---
