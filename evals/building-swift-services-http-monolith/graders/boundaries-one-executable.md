---
type: regex
target: { source: file, path: acme-backend/Package.swift }
match: "count:1"
pattern: '\.executableTarget\('
---
