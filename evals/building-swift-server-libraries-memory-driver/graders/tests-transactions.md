---
type: llm
focus: { source: file, path: swift-persistence-memory/Tests/PersistenceMemoryTests/MemoryDatabaseTests.swift }
---

PASS if the tests use swift-testing (not XCTest) with plain imports (no `@testable`) and, against the real `MemoryDatabase`, prove that a returning operation commits its changes, that a throwing operation discards them while the caller receives the same error, and that cancelling the caller's task mid-operation is covered.
FAIL if XCTest or `@testable import` is used, rollback is asserted only through a mock rather than the driver, or any of the three behaviours is untested.
Grade only against these criteria; do not fail for issues they do not mention.
