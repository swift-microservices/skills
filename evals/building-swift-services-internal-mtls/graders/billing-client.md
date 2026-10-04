---
type: llm
focus: { source: file, path: acme-billing/Sources/Billing/Serve/Serve.swift }
---

PASS if all of these hold in the billing root:
- One long-lived `GRPCClient` to accounts is created at startup, with mTLS transport security given a `TimedCertificateReloader` and full server verification (directly or through a factory).
- The client carries no bearer or credential interceptor for the internal service.
- The client and the reloader are in the `ServiceGroup`.

FAIL if the client disables server verification, attaches a token, or is created per request.
