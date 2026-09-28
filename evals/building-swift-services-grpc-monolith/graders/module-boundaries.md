---
type: llm
focus: { source: file, path: acme-backend/Package.swift }
---

PASS if the manifest declares one executable (Acme) and, for each of the users and catalog modules, its own Core, Postgres, and GRPC targets; no module target depends on another module's Core, Postgres, or GRPC target; and no Core target depends on a driver, grpc-swift, protobuf, or a logging backend.
FAIL if a module target depends on another module's targets, a Core target links PostgresNIO or GRPCCore, or a second executable or per-module package is declared.
