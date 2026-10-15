---
type: regex
target: { source: file, path: acme-sdk/Package.swift }
match: not_contains
pattern: 'resources:\s*\[[^\]]*(?:openapi\.yaml|"\.\.)'
---
