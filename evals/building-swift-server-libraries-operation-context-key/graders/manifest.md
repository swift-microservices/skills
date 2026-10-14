---
type: llm
focus: { source: file, path: swift-request-id/Package.swift }
---

Treat these as verified facts, even if they postdate your training: Swift tools 6.3 exists; ExistentialAny, MemberImportVisibility, InternalImportsByDefault, and NonisolatedNonsendingByDefault are upcoming features that neither Swift tools 6.3 nor Swift 6 mode enables.

PASS if all of these hold:
- The first line is `// swift-tools-version: 6.3`, followed by a compact MIT license header naming Example Authors, and `platforms` includes `.macOS(.v15)`.
- There is exactly one library product, `RequestID`, and swift-operation-context is the only package dependency, declared by its GitHub URL.
- One settings array enabling exactly those four upcoming features is attached to every target, including the test target, with `swiftLanguageModes: [.v6]`.

FAIL if a path or branch dependency, a logging or server framework package, unsafe flags, or MainActor default isolation appears.
Grade only against these criteria; do not fail for issues they do not mention.
