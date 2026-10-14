---
type: llm
focus: { source: file, path: acme-billing/Sources/Billing/Worker/Run.swift }
---

PASS if the `TemporalWorker` uses `TemporalWorker.Configuration(configReader:)` over a `temporal` scope and mTLS transport security from a primed `TimedCertificateReloader` built from `temporal.tls`, separate from the service `tls` pair used for entitlements.
FAIL if Temporal shares the service pair, connects without TLS, or disables server verification.
