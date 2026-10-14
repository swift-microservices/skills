---
type: regex
target: { source: file, path: acme-backend/Package.swift }
match: not_contains
pattern: 'name:\s*"Notebooks\w*"(?:(?!\.(?:executableTarget|testTarget|target)\()[\s\S])*?"Users(?:Core|Postgres|HTTP)"|name:\s*"Users\w*"(?:(?!\.(?:executableTarget|testTarget|target)\()[\s\S])*?"Notebooks(?:Core|Postgres|HTTP)"'
---
