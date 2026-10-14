---
type: regex
target: { source: file, path: Package.swift }
pattern: 'name:\s*"CatalogHTTP"(?:(?!\.(?:executableTarget|testTarget|target)\()[\s\S])*?"CatalogCore"(?:(?!\.(?:executableTarget|testTarget|target)\()[\s\S])*?"AcmeHTTP"'
---
