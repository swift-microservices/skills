---
type: llm
focus: { source: file, path: acme-backend/Package.swift }
---

PASS if the manifest declares one executable (Acme) and, for the notebooks module, its own NotebooksCore, NotebooksPostgres, and NotebooksHTTP targets; no module target depends on another module's Core, Postgres, or HTTP target; NotebooksCore depends on no driver, server framework, or logging backend; and no gRPC or protobuf dependency appears.
FAIL if a module target depends on another module's targets, if Core links PostgresNIO, Hummingbird, or a provider SDK, if a second executable or a per-module package is declared, or if gRPC appears.
