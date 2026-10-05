---
type: llm
focus: { source: file, path: acme-api/Package.swift }
---

PASS if all of these hold:
- The source targets are exactly `API` and the executable `Acme`, plus a test target named `APITests`. Extra product dependencies in any target (for example `HummingbirdTesting` in `APITests`) are fine.
- The `API` target runs the `OpenAPIGenerator` plugin.
- No `.target`, `.executableTarget`, or `.testTarget` declaration has a name containing Core or Postgres; product dependencies such as `GRPCCore` or `NIOCore`, and the `acme-core` package, are expected and allowed. No postgres-nio, postgres-migrations, or swift-persistence package is declared.
