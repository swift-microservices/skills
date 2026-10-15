---
type: regex
target: { source: file, path: README.md }
match: not_contains
pattern: 'func\s+authenticate\([^)]*\)[^{\n]*->\s*\w+\?'
---
