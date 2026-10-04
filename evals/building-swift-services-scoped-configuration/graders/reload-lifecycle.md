---
type: llm
focus: { source: file, path: acme-catalog/Sources/Catalog/Serve/Serve.swift }
---

PASS if Catalog's root creates two `TimedCertificateReloader`s before their transports — one from the `tls` scope for the gRPC server and clients and one from `temporal.tls` for the Temporal client — passes each to its transport, and adds each exactly once to the `ServiceGroup`.

FAIL if Temporal uses the service reloader or pair, a reloader is never added to the `ServiceGroup`, or the root contains validation guards or inline certificate parsing.
