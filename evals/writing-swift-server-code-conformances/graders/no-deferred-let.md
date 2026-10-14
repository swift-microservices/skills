---
type: regex
target: { source: file, path: Sources/CatalogWebhooks/WebhookNotifier.swift }
pattern: '\blet\s+\w+\s*:\s*[^=\n{]+\n\s*(?:do|if|switch)\b'
match: not_contains
---
