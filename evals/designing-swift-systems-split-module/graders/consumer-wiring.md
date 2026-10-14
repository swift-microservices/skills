---
type: llm
focus: { source: file, path: split.md }
---

PASS if Catalog keeps its `SubscriptionClient` port and its Core unchanged, and the only change on the consumer side is in acme-backend: `BillingSubscriptionClient` in `Ports/` is deleted and the root injects a gRPC client adapter conforming to the same port (in Catalog's gRPC target), over one long-lived mTLS `GRPCClient` in the `ServiceGroup`.

FAIL if CatalogCore or PublishItemUseCase changes its port, Catalog's Core depends on generated protobuf or gRPC types, or the monolith keeps calling Billing's use case in process.
