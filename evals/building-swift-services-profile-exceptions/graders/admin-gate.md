---
type: llm
focus: { source: file, path: boundaries.md }
---

PASS if the note says the gateway's `AdminRequestContext` gate is an additional check on verified JWT role claims with no database lookup, and that the receiving use case still makes the resource and business authorization decision.

FAIL if it says the gate replaces the use case's check, or that the gate should query a database or the Users service.
