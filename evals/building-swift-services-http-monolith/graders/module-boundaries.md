---
type: llm
focus: { source: file, path: acme-backend/Package.swift }
---

PASS if all of these hold:
- There is one executable target, `Acme`, and the notebooks module has `NotebooksCore`, `NotebooksPostgres`, and `NotebooksHTTP` targets.
- `NotebooksCore` depends only on Persistence, the organization's authentication product, and Logging (no PostgresNIO, Hummingbird, or provider SDK).
- No module target depends on another module's targets.

FAIL if gRPC or protobuf appears, or a second executable or a per-module package is declared.
