---
type: regex
target: { source: file, path: Sources/CatalogWebhooks/WebhookNotifier.swift }
pattern: '#if canImport\(FoundationEssentials\)\s+(?:(?:package|public) )?import FoundationEssentials\s+#else\s+(?:(?:package|public) )?import Foundation\s+#endif'
---
