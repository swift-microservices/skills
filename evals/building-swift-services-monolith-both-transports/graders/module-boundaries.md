---
type: llm
focus: { source: file, path: acme-library/Package.swift }
---

PASS if all of these hold:
- There is one executable target, `Acme`, and each of the members and loans modules has its own Core, Postgres, HTTP, and GRPC targets (extra provider targets such as `MembersBcrypt` are allowed).
- No module target depends on another module's targets: nothing in `Loans*` lists a `Members*` target and nothing in `Members*` lists a `Loans*` target. Only `Acme` links both modules. `MembersHTTP` and `LoansHTTP` linking the shared `AcmeHTTP` target (request contexts, error middleware, problem types), and module targets linking the in-package `AcmeAuthentication` or `AcmePersistence`, is required plumbing, not another module.
- No Core target depends on PostgresNIO, PersistencePostgres, grpc-swift, protobuf, Hummingbird, or a LogHandler package such as swift-log-loki; `Logging` from swift-log is the facade and is expected.

FAIL if `LoansCore` (or any Loans target) depends on a Members target or the reverse, a second executable or a per-module package is declared, or a Core target links a driver, transport, or logging backend.
