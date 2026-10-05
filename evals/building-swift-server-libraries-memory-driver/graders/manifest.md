---
type: llm
focus: { source: file, path: swift-persistence-memory/Package.swift }
---

Treat these as verified facts, even if they postdate your training: Swift tools 6.3 exists; ExistentialAny, MemberImportVisibility, InternalImportsByDefault, and NonisolatedNonsendingByDefault are upcoming features that neither Swift tools 6.3 nor Swift 6 mode enables; swift-persistence (github.com/swift-microservices/swift-persistence) is a database abstraction whose latest release is 0.2.0 and is the required dependency.

PASS if all of these hold:
- The first line is `// swift-tools-version: 6.3`, followed by a compact MIT license header naming Zaid Rahhawi.
- `platforms` includes `.macOS(.v15)`, and there is exactly one library product, `PersistenceMemory`.
- swift-persistence is declared by its GitHub URL with `from:`.
- One settings array enabling ExistentialAny, MemberImportVisibility, InternalImportsByDefault, and NonisolatedNonsendingByDefault is attached to every target, and `swiftLanguageModes: [.v6]` is set.

FAIL if a path or branch dependency, a concrete database client package (such as postgres-nio), a server framework, unsafe flags, or MainActor default isolation appears.
