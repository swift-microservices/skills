---
type: regex
target: { source: file, path: acme-backend/Package.swift }
pattern: '^(?=[\s\S]*name:\s*"NotebooksCore")(?=[\s\S]*name:\s*"NotebooksPostgres")(?=[\s\S]*name:\s*"NotebooksHTTP")'
---
