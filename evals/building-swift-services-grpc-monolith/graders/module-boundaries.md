---
type: llm
focus: { source: file, path: acme-backend/Package.swift }
---

PASS if the manifest declares one executable (Acme) and, for each of the users and catalog modules, its own Core, Postgres, and GRPC targets (extra provider targets such as `UsersBcrypt` or `UsersJWT` are allowed); no module target depends on another module's targets; and no Core target depends on a database driver, grpc-swift, protobuf, or a logging backend. Each Core target is expected to link `Logging` from swift-log, which is the facade, not a backend; a logging backend is a LogHandler package such as swift-log-loki (`LoggingLoki`), which only `Acme` may link.
FAIL if a module target depends on another module's targets, a Core target links PostgresNIO, PersistencePostgres, GRPCCore, or a LogHandler package, or a second executable or per-module package is declared.
