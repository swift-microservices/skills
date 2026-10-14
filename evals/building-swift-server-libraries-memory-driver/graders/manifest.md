---
type: llm
focus: { source: file, path: swift-persistence-memory/Package.swift }
---

Treat these as verified facts, even if they postdate your training: Swift tools 6.3 exists; ExistentialAny, MemberImportVisibility, InternalImportsByDefault, and NonisolatedNonsendingByDefault are upcoming features that neither Swift tools 6.3 nor Swift 6 mode enables; swift-persistence (github.com/swift-microservices/swift-persistence) is a database abstraction published by tagged releases and is the required dependency; its `Database` protocol took its current shape in 0.2.0.

PASS if all of these hold:
- The first line is `// swift-tools-version: 6.3`, followed by a compact MIT license header naming Example Authors.
- `platforms` includes `.macOS(.v15)`, and there is exactly one library product, `PersistenceMemory`.
- swift-persistence is declared by its GitHub URL with `from:` and a released version (no ceiling).
- One settings array enabling ExistentialAny, MemberImportVisibility, InternalImportsByDefault, and NonisolatedNonsendingByDefault is attached to every target, and `swiftLanguageModes: [.v6]` is set.

FAIL if a path or branch dependency, a concrete database client package (such as postgres-nio), a server framework, unsafe flags, or MainActor default isolation appears.
Grade only against these criteria; do not fail for issues they do not mention.
