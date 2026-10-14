---
type: llm
focus: { source: file, path: swift-persistence-memory/Sources/PersistenceMemory/MemoryDatabase.swift }
---

PASS if every `public` declaration in the file has a `///` comment beginning with a one-line summary, and any initializer or method that takes a `Logger` takes it as its last parameter (only a trailing operation closure may follow) with no default value.
FAIL if a public declaration has no `///` comment, a `Logger` parameter has a default value or is followed by a non-closure parameter, or the file is a stub.
Grade only against these criteria; do not fail for issues they do not mention.
