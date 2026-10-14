---
type: llm
focus: { source: file, path: .github/workflows/tests.yml }
---

PASS if all of these hold:
- The two release toolchains get `-Xswiftc -warnings-as-errors --explicit-target-dependency-import-check error -Xswiftc -require-explicit-sendable` and the two snapshots the same without `-Xswiftc -warnings-as-errors`.
- The tests connect to the PostgreSQL service by its service hostname (`postgres`) on port 5432, with a user, password, and database matching the service's own settings.
- Nothing tolerates failure: no `continue-on-error`, no `|| true`, no skipping or mocking when the database is unavailable.

FAIL if the database settings do not match the service, a step tolerates failure, or the tests can pass without a database.
