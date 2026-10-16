---
type: regex
target: { source: file, path: acme-documents/Sources/Documents/Serve/Serve.swift }
pattern: '^(?![\s\S]*PostgresConfiguration\b)[\s\S]*requiredString\(\s*forKey:\s*"internalPassword"\s*,\s*isSecret:\s*true\s*\)'
---
