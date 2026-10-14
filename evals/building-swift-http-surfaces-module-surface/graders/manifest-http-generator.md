---
type: regex
target: { source: file, path: Package.swift }
pattern: 'name:\s*"CatalogHTTP"(?:(?!\.(?:executableTarget|testTarget|target)\()[\s\S])*?"OpenAPIRuntime"(?:(?!\.(?:executableTarget|testTarget|target)\()[\s\S])*?\.plugin\(name:\s*"OpenAPIGenerator"'
---
