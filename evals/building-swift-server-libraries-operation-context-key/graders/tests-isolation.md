---
type: llm
focus: { source: file, path: swift-request-id/Tests/RequestIDTests/RequestIDTests.swift }
---

PASS if all of these hold:
- The binding is called from a custom actor and from a `@MainActor` test.
- Each closure mutates a non-Sendable reference the caller owns and suspends inside the closure (for example `await Task.yield()`).
- Isolation is checked on both sides of the suspension (`preconditionIsolated`, `assertIsolated`, or the MainActor equivalents).

FAIL if either caller is missing, a closure never suspends, or isolation is not checked after the suspension.
Grade only against these criteria; do not fail for issues they do not mention.
