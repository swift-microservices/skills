---
type: llm
focus: { source: file, path: acme-accounts/Sources/Accounts/Serve/Serve.swift }
---

PASS if serve builds one long-lived `TemporalClient` (target and mTLS transport security from its own `temporal.tls` reloader, configuration from `TemporalClient.Configuration(configReader:)` over the `temporal` scope), adds that client and its reloader to the `ServiceGroup`, and injects the Temporal workflow-client adapter into the registration use case.
FAIL if serve registers Workflows or Activities, reuses the service `tls` pair for Temporal, or leaves the client or reloader out of the `ServiceGroup`.
