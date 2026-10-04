---
type: llm
focus: { source: file, path: acme-accounts/Sources/Accounts/Worker/Run.swift }
---

PASS if all of these hold in the worker root:
- The Temporal worker is configured with the SDK's native `TemporalWorker.Configuration(configReader:)` over a `temporal` scope.
- Its transport uses mTLS with a `TimedCertificateReloader` built from a `temporal.tls` scope, created before the worker and added to the `ServiceGroup`.

FAIL if the worker reuses the service `tls` pair for Temporal, connects without TLS, disables server verification, or reads a JWT key.
