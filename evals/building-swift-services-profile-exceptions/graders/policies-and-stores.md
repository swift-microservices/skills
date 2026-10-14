---
type: llm
focus: { source: file, path: boundaries.md }
---

PASS if policy values (such as code lifetimes) reach use cases as concrete policy values with `.standard` defaults through the initializer, without a policy protocol; and auth-code creation and beginning registration, which touch only nontransactional stores and a port, take no `Database` or scope dependency.

FAIL if the note demands a protocol for each policy, reads configuration inside a use case, or gives those two operations a database generic or `withTransaction` they do not need.
