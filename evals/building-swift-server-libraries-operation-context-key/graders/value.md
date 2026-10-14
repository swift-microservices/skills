---
type: llm
focus: { source: file, path: swift-request-id/Sources/RequestID/RequestID.swift }
---

PASS if `RequestID` is a public value type that conforms to `Sendable` (and typically `Hashable`), has a public initializer, documents every public declaration with a `///` comment, and declares no `@TaskLocal`, global mutable state, or logging bootstrap.

FAIL if `RequestID` is a class with mutable state, is not `Sendable`, declares a `@TaskLocal`, or reads environment variables.
Grade only against these criteria; do not fail for issues they do not mention.
