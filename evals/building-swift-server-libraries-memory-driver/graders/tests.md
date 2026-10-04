---
type: llm
focus: { source: file, path: swift-persistence-memory/Tests/PersistenceMemoryTests/MemoryDatabaseTests.swift }
---

PASS if the tests use swift-testing (not XCTest) with plain imports and prove: a returning operation commits; a throwing operation discards its changes and the caller receives the same error; and the caller-isolation contract, by calling `withTransaction` from a custom actor and from a `@MainActor` test, each closure mutating caller-owned non-Sendable state, suspending inside the closure (for example `await Task.yield()`), and checking isolation on both sides of the suspension (`preconditionIsolated`, `assertIsolated`, or the MainActor equivalents). Cancellation of the caller's task mid-operation is covered.
FAIL if XCTest or `@testable import` is used, the isolation tests never suspend inside the closure, either the actor or the MainActor caller is missing, or rollback is asserted only through a mock rather than the driver.
