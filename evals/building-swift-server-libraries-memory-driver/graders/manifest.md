---
type: llm
focus: { source: file, path: swift-persistence-memory/Package.swift }
---

PASS if all of these hold:
- The first line is `// swift-tools-version: 6.3`, followed by a compact MIT license header naming Zaid Rahhawi.
- `platforms` includes `.macOS(.v15)`, and there is exactly one library product, `PersistenceMemory`.
- swift-persistence is declared by its GitHub URL with `from:`.
- One settings array enabling ExistentialAny, MemberImportVisibility, InternalImportsByDefault, and NonisolatedNonsendingByDefault is attached to every target, and `swiftLanguageModes: [.v6]` is set.

FAIL if a path or branch dependency, a database driver, a server framework, unsafe flags, or MainActor default isolation appears.
