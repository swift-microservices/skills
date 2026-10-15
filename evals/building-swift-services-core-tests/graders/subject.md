---
type: regex
target: { source: file, path: acme-catalog/Tests/CatalogCoreTests/Mocks/ItemUseCaseMocks.swift }
pattern: '^(?![\s\S]*(?:Date\(\)|Date\.now))[\s\S]*func\s+\w*[Ss]ubject\w*\s*\([^)]*\brole\b'
---
