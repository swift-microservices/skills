---
type: llm
focus: { source: file, path: acme-billing/Sources/Billing/Worker/Run.swift }
---

PASS if all of these hold in the worker root:
- It is a worker command's composition root (a `Run` command), not part of `serve`, and opens no gRPC listener and reads no JWT key.
- It builds billing's database as the worker role only, one long-lived entitlements `GRPCClient` over mTLS with no bearer interceptor, and the Stripe client behind a Core port injected into the Activity service.
- The `TemporalWorker` registers both the subscription and the fulfillment Activity containers and both Workflows.
- The worker, the clients, and both reloaders run in one `ServiceGroup`.

FAIL if it connects as the owner or service role, shares the service pair with Temporal, disables server verification, or reaches the entitlements database.
