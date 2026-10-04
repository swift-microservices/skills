---
type: llm
focus: { source: file, path: acme-billing/Sources/Billing/Worker/Run.swift }
---

PASS if all of these hold in the worker root:
- It is the `run` command of a `worker` group in the billing executable, not part of `serve`.
- It connects to billing's database as the worker role only.
- It creates one long-lived accounts `GRPCClient` with no bearer interceptor and hands Activities a consumer adapter over it.
- The worker, the clients, and their dependencies run in one `ServiceGroup`; there is no gRPC listener and no JWT key.

FAIL if it uses the owner or service database role, reads serving or migration secrets, or connects to accounts' database.
