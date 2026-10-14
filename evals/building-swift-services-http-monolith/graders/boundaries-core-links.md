---
type: regex
target: { source: file, path: acme-backend/Package.swift }
match: not_contains
pattern: 'name:\s*"NotebooksCore"(?:(?!\.(?:executableTarget|testTarget|target)\()[\s\S])*?(?:PostgresNIO|"Hummingbird"|GRPCCore|"Vapor")'
---
