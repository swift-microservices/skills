---
type: regex
target: { source: file, path: swift-persistence-memory/Sources/PersistenceMemory/MemoryDatabase.swift }
pattern: 'LoggingSystem\.bootstrap|ProcessInfo\.processInfo\.environment|getenv\(|EnvironmentVariablesProvider|Task\.detached'
match: not_contains
---
