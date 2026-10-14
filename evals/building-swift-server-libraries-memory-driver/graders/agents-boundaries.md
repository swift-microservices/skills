---
type: llm
focus: { source: file, path: swift-persistence-memory/AGENTS.md }
---

PASS if AGENTS.md states what the package is (its one product, `PersistenceMemory`, and that it depends only on swift-persistence) and what does not belong in it, naming at least one tempting addition and where it lives instead (for example query or connection abstractions, configuration, or a production driver).
FAIL if the file is missing, it omits the package's boundaries, or it describes the package as a deployable service.
Grade only against these criteria; do not fail for issues they do not mention.
