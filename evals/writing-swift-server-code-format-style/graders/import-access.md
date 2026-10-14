---
type: regex
target: { source: file, path: Sources/BillingCore/InvoiceText.swift }
pattern: '#if canImport\(FoundationEssentials\)\s+(?:package|public) import FoundationEssentials\s+#else\s+(?:package|public) import Foundation\s+#endif'
---
