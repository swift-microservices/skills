---
type: regex
target: { source: file, path: Sources/BillingCore/InvoiceText.swift }
pattern: '\b(?:ISO8601)?DateFormatter\s*\(|\bNumberFormatter\s*\(|String\(\s*format:|\bNSNumber\s*\(|\bimport FoundationInternationalization\b'
match: not_contains
---
