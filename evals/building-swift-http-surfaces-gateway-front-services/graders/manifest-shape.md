---
type: llm
focus: { source: file, path: acme-api/Package.swift }
---

PASS if all of these hold:
- The source targets are exactly `API` and the executable `Acme`, plus a test target named `APITests`.
- The `API` target runs the `OpenAPIGenerator` plugin.
- No target named with Core or Postgres exists, and no postgres-nio, postgres-migrations, or swift-persistence package is declared.
