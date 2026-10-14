---
type: regex
target: { source: file, path: acme-backend/Package.swift }
pattern: '\.package\([^)]*(acme-protos|acme-core|path:)'
match: not_contains
---
