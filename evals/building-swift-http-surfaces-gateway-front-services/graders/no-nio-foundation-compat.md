---
type: regex
target: { source: file, path: acme-api/Package.swift }
pattern: '"NIOFoundationCompat"'
match: not_contains
---
