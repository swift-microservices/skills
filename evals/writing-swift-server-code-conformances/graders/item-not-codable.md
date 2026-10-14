---
type: regex
target: { source: file, path: Sources/CatalogCore/Items/Item.swift }
pattern: '\bCodable\b|\bEncodable\b|\bDecodable\b'
match: not_contains
---
