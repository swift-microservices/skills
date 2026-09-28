---
type: llm
focus: { source: file, path: Tests/UtilityTests/UtilityTests.swift }
---

PASS if the Swift Testing tests call InlineRunner's `run` from a custom actor and from the MainActor with a closure that mutates a non-Sendable reference owned by the caller across a suspension point, and cover a thrown error propagating out of `run`. The file imports every module whose members it uses.
FAIL if the tests only check `record(value:)`, avoid isolation by using Sendable or global state, or never suspend inside the closure.
