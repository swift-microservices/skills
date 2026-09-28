---
type: regex
target: { source: file, path: Package.swift }
pattern: '"NIOFoundationCompat"'
match: not_contains
---
