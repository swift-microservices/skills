---
type: regex
target: { source: file, path: Package.swift }
match: not_contains
pattern: 'name:\s*"CatalogHTTP"(?:(?!\.(?:executableTarget|testTarget|target)\()[\s\S])*?(?:"CatalogPostgres"|"CatalogGRPC"|PostgresNIO|PersistencePostgres)'
---
