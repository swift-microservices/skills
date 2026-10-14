---
type: regex
target: { source: file, path: Sources/CatalogWebhooks/DeliveryLog.swift }
pattern: '\bDispatchSemaphore\b|\bNSLock\b|\bNSRecursiveLock\b|\bDispatchQueue\b|\bos_unfair_lock\b|Task\.detached'
match: not_contains
---
