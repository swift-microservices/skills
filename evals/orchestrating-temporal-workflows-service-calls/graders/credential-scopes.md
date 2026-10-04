---
type: llm
focus: { source: file, path: acme-billing/Sources/Billing/Worker/Run.swift }
---

PASS if all of these hold in the worker root:
- The Temporal worker uses the SDK's native `TemporalWorker.Configuration(configReader:)` over a `temporal` scope.
- Two `TimedCertificateReloader`s are created before their transports: one from `tls` for the accounts client and one from `temporal.tls` for the Temporal connection.
- Both reloaders are added exactly once to the `ServiceGroup`.

FAIL if Temporal shares the service pair, a reloader is never run, or either connection disables server verification.
