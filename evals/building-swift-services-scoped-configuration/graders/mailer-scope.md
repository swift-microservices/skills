---
type: llm
focus: { source: file, path: acme-mailer/Sources/Mailer/Worker/Run.swift }
---

PASS if Mailer's worker root builds only a Temporal reloader from `temporal.tls`, configures the worker with the SDK's native `Configuration(configReader:)`, reads only its worker database role, and adds the reloader and worker to the `ServiceGroup`.

FAIL if it constructs a service `tls` reloader it never uses, reads serving or migration database secrets, or opens a gRPC listener.
