---
type: llm
focus: { source: file, path: .github/workflows/tests.yml }
---

PASS if this is a `workflow_call` workflow whose one job runs a matrix of four toolchain containers — `swift:6.3-noble`, Swift 6.4 (`swift:6.4-resolute` or `-noble`), a `nightly-6.4.x` snapshot, and `nightly-main` — with `-Xswiftc -warnings-as-errors --explicit-target-dependency-import-check error -Xswiftc -require-explicit-sendable` on the two releases and the same without `-Xswiftc -warnings-as-errors` on the snapshots; attaches a `postgres:18-alpine` service whose health check is `pg_isready -h 127.0.0.1 …` (TCP); sets `POSTGRES_HOST: postgres`, port 5432, and a user, password, and database matching the service; and runs `swift test --parallel` with the matrix arguments.
FAIL if readiness probes only the Unix socket, the database settings don't match the service, a step tolerates failure, or tests are skipped or replaced by mocks when the database is unavailable.
